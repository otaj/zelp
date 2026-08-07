import 'dart:async';

import 'package:flutter/material.dart';
import 'package:zelp/domain/exceptions.dart';
import 'package:zelp/domain/output/output_folder.dart';
import 'package:zelp/models/device.dart';
import 'package:zelp/screens/widgets/clipboard_actions.dart';
import 'package:zelp/screens/widgets/error_banner.dart';
import 'package:zelp/screens/widgets/restorable_scroll_body.dart';
import 'package:zelp/screens/widgets/settings/settings_account_form.dart';
import 'package:zelp/screens/widgets/settings/settings_output_folder_section.dart';
import 'package:zelp/screens/widgets/settings/settings_pairing_keys_section.dart';
import 'package:zelp/services/app_setup_store.dart';
import 'package:zelp/services/credential_store.dart';
import 'package:zelp/services/device_usage_store.dart';
import 'package:zelp/services/download_storage.dart';
import 'package:zelp/services/file_share_service.dart';
import 'package:zelp/services/output_folder_store.dart';
import 'package:zelp/services/zepp_client.dart';
import 'package:zelp/services/zepp_session_runner.dart';

/// First-time setup and Settings: login, continue without login, output folder.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    this.credentialStore,
    this.downloadStorage,
    this.deviceUsageStore,
    this.setupStore,
    this.onAuthChanged,
    this.onSetupComplete,
    this.isFirstTimeSetup = false,
  });

  final CredentialStore? credentialStore;
  final DownloadStorage? downloadStorage;
  final DeviceUsageStore? deviceUsageStore;
  final AppSetupStore? setupStore;

  /// Called after credentials are saved (`true`) or cleared (`false`).
  final ValueChanged<bool>? onAuthChanged;

  /// Called when setup is finished (sign-in with save, or continue without login).
  final VoidCallback? onSetupComplete;

  /// When true, back navigation is blocked until setup is completed.
  final bool isFirstTimeSetup;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  late final CredentialStore _store = widget.credentialStore ?? CredentialStore();
  late final DownloadStorage _downloads = widget.downloadStorage ?? DownloadStorage();
  late final DeviceUsageStore _usage = widget.deviceUsageStore ?? DeviceUsageStore();
  late final AppSetupStore _setup = widget.setupStore ?? AppSetupStore();
  final FileShareService _share = const FileShareService();

  bool _obscurePassword = true;
  bool _loading = false;
  bool _fetchKeys = true;
  bool _signedIn = false;
  bool _firstTimeReadyToLeave = false;
  String? _status;
  String? _error;
  List<Device> _devices = <Device>[];
  OutputFolder _outputFolder = OutputFolder.defaults;
  bool _splitByType = OutputFolderStore.defaultSplitByType;
  bool _semanticNames = OutputFolderStore.defaultSemanticNames;

  @override
  void initState() {
    super.initState();
    unawaited(_loadSavedCredentials());
    unawaited(_loadOutputFolder());
  }

  Future<void> _loadSavedCredentials() async {
    final Credentials? saved = await _store.load();
    if (!mounted) return;
    if (saved == null) {
      setState(() => _signedIn = false);
      return;
    }
    setState(() {
      _emailController.text = saved.email;
      _passwordController.text = saved.password;
      _signedIn = true;
    });
  }

  Future<void> _loadOutputFolder() async {
    final OutputFolder folder = await _downloads.loadSettings();
    if (!mounted) return;
    setState(() {
      _outputFolder = folder;
      _splitByType = _downloads.splitByType;
      _semanticNames = _downloads.semanticNames;
    });
  }

  Future<void> _setSplitByType(bool? value) async {
    if (value == null) return;
    final bool saved = await _downloads.setSplitByType(enabled: value);
    if (!mounted) return;
    setState(() => _splitByType = saved);
  }

  Future<void> _setSemanticNames(bool? value) async {
    if (value == null) return;
    final bool saved = await _downloads.setSemanticNames(enabled: value);
    if (!mounted) return;
    setState(() => _semanticNames = saved);
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _finishSetup({required bool signedIn}) async {
    await _setup.markComplete();
    widget.onAuthChanged?.call(signedIn);
    if (!widget.isFirstTimeSetup) return;
    // Keep the screen open after sign-in so pairing keys can be copied;
    // "Continue without signing in" dismisses immediately.
    if (signedIn) {
      setState(() => _firstTimeReadyToLeave = true);
    } else {
      widget.onSetupComplete?.call();
    }
  }

  void _leaveFirstTimeSetup() => widget.onSetupComplete?.call();

  Future<void> _pickOutputFolder() async {
    final OutputFolder? folder = await _downloads.pickFolder();
    if (!mounted || folder == null) return;
    setState(() => _outputFolder = folder);
  }

  Future<void> _resetOutputFolder() async {
    final OutputFolder folder = await _downloads.resetToDefault();
    if (!mounted) return;
    setState(() => _outputFolder = folder);
  }

  Future<void> _clearOutputFolder() async {
    final ClearFolderWarning warning = await _downloads.clearWarning();
    if (!mounted) return;

    if (!warning.shouldConfirm) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Output folder is already empty')),
      );
      return;
    }

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Clear output folder?'),
        content: Text(warning.message),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final int deleted = await _downloads.clearFolder();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          deleted == 1 ? 'Deleted 1 file' : 'Deleted $deleted files',
        ),
      ),
    );
  }

  Future<void> _continueWithoutLogin() async {
    setState(() {
      _loading = true;
      _error = null;
      _status = null;
      _devices = <Device>[];
    });
    try {
      await _store.clear();
      if (!mounted) return;
      setState(() {
        _signedIn = false;
        _status =
            'Continuing without an account. Firmware is available; '
            'GPS, Watchfaces, and Apps need a sign-in.';
      });
      await _finishSetup(signedIn: false);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _signOut() async {
    setState(() {
      _loading = true;
      _error = null;
      _devices = <Device>[];
    });
    try {
      await _store.clear();
      if (!mounted) return;
      setState(() {
        _signedIn = false;
        _emailController.clear();
        _passwordController.clear();
        _status = 'Signed out.';
      });
      widget.onAuthChanged?.call(false);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _run() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _loading = true;
      _error = null;
      _status = 'Signing in…';
      _devices = <Device>[];
    });

    final Credentials credentials = Credentials(
      email: _emailController.text.trim(),
      password: _passwordController.text,
    );

    try {
      final List<String> errors = <String>[];
      await runZeppSession(
        username: credentials.email,
        password: credentials.password,
        body: (ZeppSession session) async {
          await _store.save(credentials);
          setState(() => _signedIn = true);

          if (_fetchKeys) {
            setState(() => _status = 'Fetching pairing keys…');
            try {
              final ZeppClient client = ZeppClient(session);
              final List<Device> devices = await client.getDevices();
              final List<Device> ordered = await _usage.sortPairingDevices(
                devices: devices,
                macOf: (Device d) => d.mac,
              );
              if (!mounted) return;
              setState(() => _devices = ordered);
              if (devices.isEmpty) {
                errors.add('No paired devices / keys found on this account.');
              }
            } on ZelpException catch (e) {
              errors.add(e.message);
            } on Exception catch (e) {
              errors.add(e.toString());
            }
          }
        },
      );
      if (!mounted) return;
      setState(() {
        _error = errors.isEmpty ? null : errors.join('\n');
        _status = errors.isEmpty
            ? (_fetchKeys ? 'Signed in. Pairing keys loaded.' : 'Signed in. Credentials saved.')
            : (_devices.isNotEmpty ? 'Signed in with notes.' : 'Finished with errors.');
      });
      await _finishSetup(signedIn: true);
    } on ZelpException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _status = null;
      });
    } on Exception catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _status = null;
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _touchDevice(Device device) async {
    await _usage.touchPairing(device.mac);
    if (!mounted) return;
    setState(() {
      _devices = List<Device>.of(_devices)
        ..removeWhere((Device d) => d.mac == device.mac)
        ..insert(0, device);
    });
  }

  Future<void> _shareDeviceKey(Device device) async {
    await _touchDevice(device);
    await _share.shareText(
      'MAC: ${device.mac}\nAuth key: ${device.displayKey}',
      subject: 'Amazfit pairing key',
    );
  }

  Future<void> _copy(String value, String label, {Device? device}) async {
    if (device != null) await _touchDevice(device);
    if (!mounted) return;
    await copyTextWithSnackbar(context, text: value, label: label);
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String title = widget.isFirstTimeSetup ? 'Welcome to Zelp' : 'Settings';

    final bool blockBack = widget.isFirstTimeSetup && !_firstTimeReadyToLeave;

    return PopScope(
      canPop: !blockBack,
      child: Scaffold(
        appBar: AppBar(
          title: Text(title),
          automaticallyImplyLeading: !widget.isFirstTimeSetup,
          actions: <Widget>[
            if (widget.isFirstTimeSetup && _firstTimeReadyToLeave)
              TextButton(
                onPressed: _loading ? null : _leaveFirstTimeSetup,
                child: const Text('Done'),
              ),
          ],
        ),
        body: RestorableScrollBody.view(
          storageId: widget.isFirstTimeSetup ? 'settings_first_time' : 'settings',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                widget.isFirstTimeSetup ? 'Set up Zelp' : 'Account & downloads',
                style: theme.textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                widget.isFirstTimeSetup
                    ? 'Sign in with your Amazfit account to unlock GPS, '
                          'Watchfaces, and Apps — or continue without signing in '
                          'to use Firmware only. Choose where downloads are saved.'
                    : 'Sign in to unlock GPS, Watchfaces, and Apps. Firmware '
                          'works without an account. Optionally fetch Bluetooth '
                          'pairing keys for Gadgetbridge, and choose where '
                          'downloads are saved.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              if (widget.isFirstTimeSetup) ...<Widget>[
                const SizedBox(height: 16),
                Material(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      'Zelp is for personal use only and is not affiliated with, '
                      'endorsed by, or connected to Zepp, Amazfit, or Huami.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 24),
              SettingsAccountForm(
                formKey: _formKey,
                emailController: _emailController,
                passwordController: _passwordController,
                obscurePassword: _obscurePassword,
                fetchKeys: _fetchKeys,
                enabled: !_loading,
                onToggleObscurePassword: () => setState(() => _obscurePassword = !_obscurePassword),
                onFetchKeysChanged: (bool value) => setState(() => _fetchKeys = value),
              ),
              const SizedBox(height: 16),
              SettingsOutputFolderSection(
                outputFolder: _outputFolder,
                splitByType: _splitByType,
                semanticNames: _semanticNames,
                enabled: !_loading,
                onPickFolder: _pickOutputFolder,
                onResetFolder: _resetOutputFolder,
                onClearFolder: _clearOutputFolder,
                onSplitByTypeChanged: _setSplitByType,
                onSemanticNamesChanged: _setSemanticNames,
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _loading ? null : _run,
                icon: _loading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.login),
                label: Text(
                  _loading ? 'Working…' : (_fetchKeys ? 'Sign in & fetch keys' : 'Sign in & save'),
                ),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _loading ? null : _continueWithoutLogin,
                icon: const Icon(Icons.person_off_outlined),
                label: const Text('Continue without signing in'),
              ),
              if (widget.isFirstTimeSetup && _firstTimeReadyToLeave) ...<Widget>[
                const SizedBox(height: 8),
                FilledButton.tonalIcon(
                  onPressed: _loading ? null : _leaveFirstTimeSetup,
                  icon: const Icon(Icons.check),
                  label: const Text('Get started'),
                ),
              ],
              if (_signedIn && !widget.isFirstTimeSetup) ...<Widget>[
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: _loading ? null : _signOut,
                  icon: const Icon(Icons.logout),
                  label: const Text('Sign out'),
                ),
              ],
              if (_status != null) ...<Widget>[
                const SizedBox(height: 16),
                Text(_status!, style: theme.textTheme.bodyMedium),
              ],
              if (_error != null) ...<Widget>[
                const SizedBox(height: 16),
                ErrorBanner(message: _error!),
              ],
              SettingsPairingKeysSection(
                devices: _devices,
                onCopyKey: (Device device) => unawaited(_copy(device.displayKey, 'Auth key', device: device)),
                onCopyMac: (Device device) => unawaited(_copy(device.mac, 'MAC', device: device)),
                onShare: (Device device) => unawaited(_shareDeviceKey(device)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

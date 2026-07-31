import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:zelp/domain/exceptions.dart';
import 'package:zelp/domain/output/output_folder.dart';
import 'package:zelp/models/device.dart';
import 'package:zelp/screens/widgets/error_banner.dart';
import 'package:zelp/screens/widgets/pairing_device_card.dart';
import 'package:zelp/services/app_setup_store.dart';
import 'package:zelp/services/credential_store.dart';
import 'package:zelp/services/device_usage_store.dart';
import 'package:zelp/services/download_storage.dart';
import 'package:zelp/services/file_share_service.dart';
import 'package:zelp/services/output_folder_store.dart';
import 'package:zelp/services/zepp_client.dart';

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

    final ZeppSession session = ZeppSession(
      username: credentials.email,
      password: credentials.password,
    );

    try {
      await session.login();
      await _store.save(credentials);
      setState(() => _signedIn = true);

      final List<String> errors = <String>[];

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

      try {
        await session.logout();
      } on Exception catch (_) {}

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
    await Clipboard.setData(ClipboardData(text: value));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$label copied')));
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
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
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
              Form(
                key: _formKey,
                child: Column(
                  children: <Widget>[
                    TextFormField(
                      controller: _emailController,
                      enabled: !_loading,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const <String>[AutofillHints.email],
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                      validator: (String? value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Enter your Amazfit email';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _passwordController,
                      enabled: !_loading,
                      obscureText: _obscurePassword,
                      autofillHints: const <String>[AutofillHints.password],
                      decoration: InputDecoration(
                        labelText: 'Password',
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          onPressed: () => setState(
                            () => _obscurePassword = !_obscurePassword,
                          ),
                          icon: Icon(
                            _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                          ),
                        ),
                      ),
                      validator: (String? value) {
                        if (value == null || value.isEmpty) {
                          return 'Enter your password';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _fetchKeys,
                onChanged: _loading ? null : (bool? value) => setState(() => _fetchKeys = value ?? false),
                title: const Text('Also fetch Bluetooth pairing keys'),
                subtitle: const Text(
                  'Optional — shown here for Gadgetbridge and similar apps',
                ),
                controlAffinity: ListTileControlAffinity.leading,
              ),
              const SizedBox(height: 16),
              Text('Download folder', style: theme.textTheme.titleMedium),
              const SizedBox(height: 4),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.folder_outlined),
                title: Text(_outputFolder.label),
                subtitle: Text(
                  _outputFolder.kind == OutputFolderKind.defaults
                      ? 'Default folder for downloads and exports'
                      : 'Custom folder for downloads and exports',
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    IconButton(
                      tooltip: 'Select output folder',
                      onPressed: _loading ? null : _pickOutputFolder,
                      icon: const Icon(Icons.folder_open),
                    ),
                    IconButton(
                      tooltip: 'Use default folder',
                      onPressed: _loading || _outputFolder.kind == OutputFolderKind.defaults
                          ? null
                          : _resetOutputFolder,
                      icon: const Icon(Icons.home_outlined),
                    ),
                    IconButton(
                      tooltip: 'Clear output folder',
                      onPressed: _loading ? null : _clearOutputFolder,
                      icon: const Icon(Icons.delete_outline),
                    ),
                  ],
                ),
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _splitByType,
                onChanged: _loading ? null : _setSplitByType,
                title: const Text('Split downloads by type'),
                subtitle: const Text(
                  'Save firmware, apps, watchfaces, and GPS into separate subfolders',
                ),
                controlAffinity: ListTileControlAffinity.leading,
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _semanticNames,
                onChanged: _loading ? null : _setSemanticNames,
                title: const Text('Use semantic filenames'),
                subtitle: const Text(
                  'Rename downloads to name and version (e.g. MyApp_1.2.0.zip)',
                ),
                controlAffinity: ListTileControlAffinity.leading,
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
              if (_devices.isNotEmpty) ...<Widget>[
                const SizedBox(height: 28),
                Text('Pairing keys', style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                ..._devices.map(
                  (Device device) => PairingDeviceCard(
                    device: device,
                    onCopyKey: () => _copy(device.displayKey, 'Auth key', device: device),
                    onCopyMac: () => _copy(device.mac, 'MAC', device: device),
                    onShare: () => _shareDeviceKey(device),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

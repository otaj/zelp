import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../domain/output/output_folder.dart';
import '../domain/output/saved_export.dart';
import '../models/device.dart';
import '../services/credential_store.dart';
import '../services/device_usage_store.dart';
import '../services/download_storage.dart';
import '../services/exceptions.dart';
import '../services/file_share_service.dart';
import '../services/zepp_client.dart';
import 'widgets/error_banner.dart';
import 'widgets/pairing_device_card.dart';

/// Login, pairing keys, and output-folder configuration.
class CredentialsScreen extends StatefulWidget {
  const CredentialsScreen({
    super.key,
    this.credentialStore,
    this.downloadStorage,
    this.deviceUsageStore,
    this.onAuthChanged,
  });

  final CredentialStore? credentialStore;
  final DownloadStorage? downloadStorage;
  final DeviceUsageStore? deviceUsageStore;

  /// Called after credentials are saved (`true`) or cleared (`false`).
  final ValueChanged<bool>? onAuthChanged;

  @override
  State<CredentialsScreen> createState() => _CredentialsScreenState();
}

class _CredentialsScreenState extends State<CredentialsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  late final _store = widget.credentialStore ?? CredentialStore();
  late final _downloads = widget.downloadStorage ?? DownloadStorage();
  late final _usage = widget.deviceUsageStore ?? DeviceUsageStore();
  final _share = const FileShareService();

  bool _remember = true;
  bool _obscurePassword = true;
  bool _loading = false;
  bool _fetchKeys = true;
  String? _status;
  String? _error;
  List<Device> _devices = [];
  SavedExport? _keysExport;
  OutputFolder _outputFolder = OutputFolder.defaults;

  @override
  void initState() {
    super.initState();
    _loadSavedCredentials();
    _loadOutputFolder();
  }

  Future<void> _loadSavedCredentials() async {
    final saved = await _store.load();
    if (!mounted || saved == null) return;
    setState(() {
      _emailController.text = saved.email;
      _passwordController.text = saved.password;
      _remember = true;
    });
  }

  Future<void> _loadOutputFolder() async {
    final folder = await _downloads.loadSettings();
    if (!mounted) return;
    setState(() => _outputFolder = folder);
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _pickOutputFolder() async {
    final folder = await _downloads.pickFolder();
    if (!mounted || folder == null) return;
    setState(() => _outputFolder = folder);
  }

  Future<void> _resetOutputFolder() async {
    final folder = await _downloads.resetToDefault();
    if (!mounted) return;
    setState(() => _outputFolder = folder);
  }

  Future<void> _clearOutputFolder() async {
    final warning = await _downloads.clearWarning();
    if (!mounted) return;

    if (!warning.shouldConfirm) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Output folder is already empty')),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear output folder?'),
        content: Text(warning.message),
        actions: [
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

    final deleted = await _downloads.clearFolder();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          deleted == 1 ? 'Deleted 1 file' : 'Deleted $deleted files',
        ),
      ),
    );
  }

  Future<void> _run() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _loading = true;
      _error = null;
      _status = 'Signing in…';
      _devices = [];
      _keysExport = null;
    });

    final credentials = Credentials(
      email: _emailController.text.trim(),
      password: _passwordController.text,
    );

    final session = ZeppSession(
      username: credentials.email,
      password: credentials.password,
    );

    try {
      await session.login();

      // Persist for gated tabs (GPS / Watchfaces / Apps).
      if (_remember) {
        await _store.save(credentials);
        widget.onAuthChanged?.call(true);
      } else {
        await _store.clear();
        widget.onAuthChanged?.call(false);
      }

      final errors = <String>[];
      if (!_remember) {
        errors.add(
          'Signed in for this action only. Turn on “Remember credentials” '
          'to open GPS, Watchfaces, and Apps.',
        );
      }

      if (_fetchKeys) {
        setState(() => _status = 'Fetching pairing keys…');
        try {
          final client = ZeppClient(session);
          final devices = await client.getDevices();
          final ordered = await _usage.sortPairingDevices(
            devices: devices,
            macOf: (d) => d.mac,
          );
          if (!mounted) return;
          setState(() => _devices = ordered);
          if (devices.isEmpty) {
            errors.add('No paired devices / keys found on this account.');
          } else {
            try {
              final keysExport = await _exportPairingKeys(ordered);
              if (mounted) setState(() => _keysExport = keysExport);
            } catch (e) {
              errors.add('Could not save pairing keys file: $e');
            }
          }
        } on ZelpException catch (e) {
          errors.add(e.message);
        } catch (e) {
          errors.add(e.toString());
        }
      }

      try {
        await session.logout();
      } catch (_) {}

      if (!mounted) return;
      setState(() {
        _error = errors.isEmpty ? null : errors.join('\n');
        _status = errors.isEmpty
            ? (_fetchKeys ? 'Signed in. Pairing keys updated.' : 'Signed in.')
            : (_devices.isNotEmpty || _remember
                  ? 'Signed in with notes.'
                  : 'Finished with errors.');
      });
    } on ZelpException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _status = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _status = null;
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<SavedExport> _exportPairingKeys(List<Device> devices) async {
    final buffer = StringBuffer()
      ..writeln('# Amazfit / Zepp pairing keys')
      ..writeln('# Generated by Zelp')
      ..writeln();
    for (final device in devices) {
      buffer
        ..writeln('MAC: ${device.mac}')
        ..writeln('Auth key: ${device.displayKey}')
        ..writeln('Active: ${device.active}')
        ..writeln();
    }
    final bytes = Uint8List.fromList(utf8.encode(buffer.toString()));
    return _downloads.saveFile(fileName: 'pairing_keys.txt', bytes: bytes);
  }

  Future<void> _touchDevice(Device device) async {
    await _usage.touchPairing(device.mac);
    if (!mounted) return;
    setState(() {
      _devices = List.of(_devices)
        ..removeWhere((d) => d.mac == device.mac)
        ..insert(0, device);
    });
  }

  Future<void> _shareExport(SavedExport export) async {
    try {
      await _share.shareExport(export);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Share failed: $e')));
    }
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
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Credentials')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Amazfit / Zepp', style: theme.textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(
              'Sign in with your Amazfit account to unlock GPS, Watchfaces, '
              'and Apps. Firmware works without sign-in. Optionally fetch '
              'Bluetooth pairing keys for Gadgetbridge, and choose where '
              'downloads are saved.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _emailController,
                    enabled: !_loading,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                    validator: (value) {
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
                    autofillHints: const [AutofillHints.password],
                    decoration: InputDecoration(
                      labelText: 'Password',
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        onPressed: () => setState(
                          () => _obscurePassword = !_obscurePassword,
                        ),
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                      ),
                    ),
                    validator: (value) {
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
              value: _remember,
              onChanged: _loading
                  ? null
                  : (value) => setState(() => _remember = value ?? false),
              title: const Text('Remember credentials'),
              subtitle: const Text(
                'Needed to open GPS, Watchfaces, and Apps later',
              ),
              controlAffinity: ListTileControlAffinity.leading,
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _fetchKeys,
              onChanged: _loading
                  ? null
                  : (value) => setState(() => _fetchKeys = value ?? false),
              title: const Text('Also fetch Bluetooth pairing keys'),
              subtitle: const Text(
                'Optional — for Gadgetbridge and similar apps',
              ),
              controlAffinity: ListTileControlAffinity.leading,
            ),
            const SizedBox(height: 16),
            Text('Output folder', style: theme.textTheme.titleMedium),
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
                children: [
                  IconButton(
                    tooltip: 'Select output folder',
                    onPressed: _loading ? null : _pickOutputFolder,
                    icon: const Icon(Icons.folder_open),
                  ),
                  IconButton(
                    tooltip: 'Use default folder',
                    onPressed:
                        _loading ||
                            _outputFolder.kind == OutputFolderKind.defaults
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
                _loading
                    ? 'Working…'
                    : (_fetchKeys ? 'Sign in & fetch keys' : 'Sign in'),
              ),
            ),
            if (_status != null) ...[
              const SizedBox(height: 16),
              Text(_status!, style: theme.textTheme.bodyMedium),
            ],
            if (_error != null) ...[
              const SizedBox(height: 16),
              ErrorBanner(message: _error!),
            ],
            if (_devices.isNotEmpty) ...[
              const SizedBox(height: 28),
              Text('Pairing keys', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              ..._devices.map(
                (device) => PairingDeviceCard(
                  device: device,
                  onCopyKey: () =>
                      _copy(device.displayKey, 'Auth key', device: device),
                  onCopyMac: () => _copy(device.mac, 'MAC', device: device),
                  onShare: () => _shareDeviceKey(device),
                ),
              ),
              if (_keysExport != null)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.description_outlined),
                  title: Text(_keysExport!.fileName),
                  subtitle: Text(
                    'Saved to ${_keysExport!.displayPath}',
                    maxLines: 2,
                  ),
                  trailing: IconButton(
                    tooltip: 'Share keys file',
                    onPressed: () => _shareExport(_keysExport!),
                    icon: const Icon(Icons.share_outlined),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

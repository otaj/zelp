import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../domain/output/output_folder.dart';
import '../domain/output/saved_export.dart';
import '../models/gps_file_type.dart';
import '../services/credential_store.dart';
import '../services/download_storage.dart';
import '../services/exceptions.dart';
import '../services/file_share_service.dart';
import '../services/zepp_client.dart';
import 'widgets/error_banner.dart';

/// GPS assistance downloads (uses credentials + output folder from Credentials).
class GpsFilesScreen extends StatefulWidget {
  const GpsFilesScreen({
    super.key,
    this.credentialStore,
    this.downloadStorage,
    this.settingsEpoch = 0,
  });

  final CredentialStore? credentialStore;
  final DownloadStorage? downloadStorage;

  /// Bumped by [MainShell] when the GPS tab is selected so account/folder
  /// labels pick up changes made on the Credentials tab.
  final int settingsEpoch;

  @override
  State<GpsFilesScreen> createState() => _GpsFilesScreenState();
}

class _GpsFilesScreenState extends State<GpsFilesScreen> {
  late final _store = widget.credentialStore ?? CredentialStore();
  late final _downloads = widget.downloadStorage ?? DownloadStorage();
  final _share = const FileShareService();

  bool _loading = false;
  bool _buildUihh = false;
  final Set<GpsFileType> _selectedGps = {GpsFileType.epo};
  String? _status;
  String? _error;
  String? _accountEmail;
  List<SavedExport> _gpsFiles = [];
  OutputFolder _outputFolder = OutputFolder.defaults;

  bool get _fetchGps => _selectedGps.isNotEmpty || _buildUihh;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void didUpdateWidget(covariant GpsFilesScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.settingsEpoch != widget.settingsEpoch) {
      _reload();
    }
  }

  Future<void> _reload() async {
    final saved = await _store.load();
    final folder = await _downloads.loadSettings(force: true);
    if (!mounted) return;
    setState(() {
      _accountEmail = saved?.email;
      _outputFolder = folder;
    });
  }

  void _toggleGps(GpsFileType type, bool? selected) {
    setState(() {
      if (selected ?? false) {
        _selectedGps.add(type);
      } else {
        _selectedGps.remove(type);
      }
    });
  }

  void _toggleUihh(bool? selected) {
    setState(() => _buildUihh = selected ?? false);
  }

  Future<void> _run() async {
    if (!_fetchGps) {
      setState(
        () => _error =
            'Select at least one GPS type or enable Build gps_uihh.bin.',
      );
      return;
    }

    final credentials = await _store.load();
    if (credentials == null) {
      setState(
        () => _error =
            'No saved account. Sign in on Credentials with '
            '“Remember credentials” turned on.',
      );
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _status = 'Signing in…';
      _gpsFiles = [];
      _accountEmail = credentials.email;
    });

    final session = ZeppSession(
      username: credentials.email,
      password: credentials.password,
    );

    try {
      await session.login();
      final client = ZeppClient(session);
      final errors = <String>[];

      setState(() => _status = 'Downloading GPS files…');
      try {
        final result = await client.downloadGpsFiles(
          types: Set<GpsFileType>.from(_selectedGps),
          buildUihh: _buildUihh,
          storage: _downloads,
        );
        if (!mounted) return;
        setState(() => _gpsFiles = result.exports);
        if (result.warnings.isNotEmpty) {
          errors.addAll(result.warnings);
        }
      } on ZelpException catch (e) {
        errors.add(e.message);
      } catch (e) {
        errors.add(e.toString());
      }

      try {
        await session.logout();
      } catch (_) {}

      if (!mounted) return;
      setState(() {
        _error = errors.isEmpty ? null : errors.join('\n');
        _status = errors.isEmpty
            ? 'Done.'
            : (_gpsFiles.isNotEmpty
                  ? 'Finished with warnings.'
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
      if (mounted) {
        await _reload();
        setState(() => _loading = false);
      }
    }
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

  Future<void> _copy(String value, String label) async {
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
      appBar: AppBar(title: const Text('GPS files')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('GPS assistance files', style: theme.textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(
              'Download the GPS packs you need, and optionally build '
              'gps_uihh.bin. Uses the account saved on Credentials.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.folder_outlined),
              title: const Text('Saving to'),
              subtitle: Text(_outputFolder.label),
            ),
            if (_accountEmail != null)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.person_outline),
                title: const Text('Account'),
                subtitle: Text(_accountEmail!),
              )
            else
              Material(
                color: theme.colorScheme.secondaryContainer,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    'No saved account yet. Open Credentials, sign in with '
                    '“Remember credentials”, then come back.',
                    style: TextStyle(
                      color: theme.colorScheme.onSecondaryContainer,
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 16),
            Text(
              'Checked types are saved to your folder. '
              'Building gps_uihh.bin uses temporary GPS packs in memory and '
              'only saves gps_uihh.bin unless you also check those pack types.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            ...GpsFileType.apiOrder.map(
              (type) => CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _selectedGps.contains(type),
                onChanged: _loading ? null : (value) => _toggleGps(type, value),
                title: Text(type.label),
                subtitle: Text(type.description),
                controlAffinity: ListTileControlAffinity.leading,
                dense: true,
              ),
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _buildUihh,
              onChanged: _loading ? null : _toggleUihh,
              title: const Text('Build gps_uihh.bin'),
              subtitle: const Text(
                'Private AGPS ZIP + LLE fetch; export gps_uihh.bin only '
                '(unless those types are also checked)',
              ),
              controlAffinity: ListTileControlAffinity.leading,
              dense: true,
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
                  : const Icon(Icons.download),
              label: Text(
                _loading ? 'Working…' : 'Download selected GPS files',
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
            if (_gpsFiles.isNotEmpty) ...[
              const SizedBox(height: 28),
              Text('Exported GPS files', style: theme.textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(
                'Saved to ${_outputFolder.label}. Use share to send via Android.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              ..._gpsFiles.map(
                (export) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.map_outlined),
                  title: Text(export.fileName),
                  subtitle: Text(export.displayPath, maxLines: 2),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Share',
                        onPressed: () => _shareExport(export),
                        icon: const Icon(Icons.share_outlined),
                      ),
                      IconButton(
                        tooltip: 'Copy path',
                        onPressed: () => _copy(export.displayPath, 'Path'),
                        icon: const Icon(Icons.copy),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

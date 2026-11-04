import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/app_theme.dart';

class ImportExportDialog extends StatefulWidget {
  final String exportedJson;
  final Future<int> Function(String jsonContent) onImportJson;
  final Future<void> Function() onResetDefaults;

  const ImportExportDialog({
    super.key,
    required this.exportedJson,
    required this.onImportJson,
    required this.onResetDefaults,
  });

  @override
  State<ImportExportDialog> createState() => _ImportExportDialogState();
}

class _ImportExportDialogState extends State<ImportExportDialog> {
  late TextEditingController _jsonCtrl;
  String? _statusMessage;
  bool _isError = false;

  @override
  void initState() {
    super.initState();
    _jsonCtrl = TextEditingController(text: widget.exportedJson);
  }

  @override
  void dispose() {
    _jsonCtrl.dispose();
    super.dispose();
  }

  Future<void> _copyJson() async {
    await Clipboard.setData(ClipboardData(text: _jsonCtrl.text));
    if (!mounted) return;
    setState(() {
      _isError = false;
      _statusMessage = 'Copied JSON preset bundle to clipboard.';
    });
  }

  Future<void> _importJson() async {
    try {
      final count = await widget.onImportJson(_jsonCtrl.text);
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Successfully imported $count preset(s).'),
          backgroundColor: AppTheme.success,
        ),
      );
    } catch (e) {
      setState(() {
        _isError = true;
        _statusMessage = 'Failed to parse JSON: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: 580,
        padding: const EdgeInsets.all(18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.import_export,
                  size: 18,
                  color: AppTheme.secondaryCyan,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Import / Export IP Profile Presets (JSON)',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () async {
                    await widget.onResetDefaults();
                    if (context.mounted) Navigator.of(context).pop();
                  },
                  icon: const Icon(Icons.restore, size: 14),
                  label: const Text(
                    'Restore Factory Presets',
                    style: TextStyle(fontSize: 11),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            const Text(
              'Copy the JSON below to share presets across workstations, or paste a JSON bundle and click Import.',
              style: TextStyle(fontSize: 11.5, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 10),
            Container(
              height: 280,
              decoration: BoxDecoration(
                color: AppTheme.cliCardBackground,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppTheme.cliCardBorder),
              ),
              child: TextField(
                controller: _jsonCtrl,
                maxLines: null,
                expands: true,
                style: AppTheme.monoStyle(fontSize: 11),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  fillColor: Colors.transparent,
                  contentPadding: EdgeInsets.all(10),
                ),
              ),
            ),
            if (_statusMessage != null) ...[
              const SizedBox(height: 8),
              Text(
                _statusMessage!,
                style: TextStyle(
                  fontSize: 11.5,
                  color: _isError ? AppTheme.error : AppTheme.success,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            const SizedBox(height: 14),
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: _copyJson,
                  icon: const Icon(Icons.copy, size: 14),
                  label: const Text('Copy JSON'),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Close'),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: _importJson,
                  icon: const Icon(Icons.file_download_outlined, size: 15),
                  label: const Text('Import JSON'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.primaryAccent,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

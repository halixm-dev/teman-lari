import 'package:flutter/material.dart';

import '../../../data/backup/import_preview.dart';

class BackupImportPreviewDialog extends StatefulWidget {
  final BackupImportPreview preview;
  const BackupImportPreviewDialog({super.key, required this.preview});
  @override
  State<BackupImportPreviewDialog> createState() =>
      _BackupImportPreviewDialogState();
}

class _BackupImportPreviewDialogState extends State<BackupImportPreviewDialog> {
  BackupImportMode _mode = BackupImportMode.smartMerge;
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Backup preview'),
    content: SizedBox(
      width: 480,
      child: SingleChildScrollView(child: _contents()),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      const FilledButton(onPressed: null, child: Text('Import unavailable')),
    ],
  );

  Widget _contents() => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('Created (UTC): ${widget.preview.createdAt.toIso8601String()}'),
      Text('App version: ${widget.preview.appVersion}'),
      Text('Schema version: ${widget.preview.schemaVersion}'),
      const SizedBox(height: 16),
      _SectionCounts(preview: widget.preview),
      const SizedBox(height: 16),
      _modes(),
      const Text(
        'Import is unavailable in this version. Local data has not changed.',
      ),
    ],
  );

  Widget _modes() => RadioGroup<BackupImportMode>(
    groupValue: _mode,
    onChanged: (mode) {
      if (mode != null) setState(() => _mode = mode);
    },
    child: const Column(
      children: [
        RadioListTile<BackupImportMode>(
          value: BackupImportMode.smartMerge,
          title: Text('Smart Merge'),
          subtitle: Text(
            'Keep unrelated local data. Add missing records and preserve local values.',
          ),
          contentPadding: EdgeInsets.zero,
        ),
        RadioListTile<BackupImportMode>(
          value: BackupImportMode.replaceAll,
          title: Text('Replace All Local Data'),
          subtitle: Text(
            'Replace the backup-owned local data with this archive.',
          ),
          contentPadding: EdgeInsets.zero,
        ),
      ],
    ),
  );
}

class _SectionCounts extends StatelessWidget {
  final BackupImportPreview preview;
  const _SectionCounts({required this.preview});
  @override
  Widget build(BuildContext context) => Table(
    columnWidths: const {
      0: FlexColumnWidth(3),
      1: FlexColumnWidth(),
      2: FlexColumnWidth(),
    },
    children: [
      _row('Section', 'Local', 'Archive'),
      for (final entry in const {
        'profile': 'Profile fields',
        'activities': 'Activities',
        'heart_rate_streams': 'Heart rate streams',
        'training_plan_state': 'Training plans',
        'equipment': 'Shoes and assignments',
        'rehab_feedback': 'Rehab feedback',
      }.entries)
        _row(
          entry.value,
          '${preview.localCounts[entry.key] ?? 0}',
          '${preview.archiveCounts[entry.key] ?? 0}',
        ),
    ],
  );
  TableRow _row(String label, String local, String archive) => TableRow(
    children: [
      for (final text in [label, local, archive])
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
          child: Text(text),
        ),
    ],
  );
}

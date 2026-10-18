import 'package:flutter/material.dart';

import '../../../data/backup/snapshot_backup_service.dart';

class BackupImportPreviewDialog extends StatefulWidget {
  final BackupImportPreview preview;
  final Future<BackupImportSummary> Function(BackupImportPreview) onApply;
  final VoidCallback onChooseFile;
  const BackupImportPreviewDialog({
    super.key,
    required this.preview,
    required this.onApply,
    required this.onChooseFile,
  });
  @override
  State<BackupImportPreviewDialog> createState() =>
      _BackupImportPreviewDialogState();
}

class _BackupImportPreviewDialogState extends State<BackupImportPreviewDialog> {
  late BackupImportPreview _preview;
  bool _applying = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _preview = widget.preview;
  }

  Future<void> _apply() async {
    if (_applying || _preview.mergeError != null) return;
    setState(() {
      _applying = true;
      _error = null;
    });
    var applied = false;
    try {
      final summary = await widget.onApply(_preview);
      applied = true;
      if (mounted) Navigator.pop(context, summary);
    } on SnapshotImportPreviewStale catch (error) {
      if (!mounted) return;
      setState(() {
        _preview = error.preview;
        _error =
            'Local data changed. Review the updated preview and confirm again.';
      });
    } catch (error) {
      if (mounted) setState(() => _error = backupImportError(error));
    } finally {
      if (mounted && !applied) setState(() => _applying = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_applying,
    child: AlertDialog(
      title: const Text('Backup preview'),
      semanticLabel: 'Backup preview',
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(child: _contents()),
      ),
      actions: _actions(),
    ),
  );

  List<Widget> _actions() => [
    TextButton(
      onPressed: _applying ? null : () => Navigator.pop(context),
      child: const Text('Cancel'),
    ),
    if (_error != null || _preview.mergeError != null)
      TextButton(
        onPressed: _applying
            ? null
            : () {
                widget.onChooseFile();
                Navigator.pop(context);
              },
        child: const Text('Choose another file'),
      ),
    FilledButton(
      onPressed: _applying || _preview.mergeError != null ? null : _apply,
      child: const Text('Import with Smart Merge'),
    ),
  ];

  Widget _contents() => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('Created (UTC): ${_preview.createdAt.toIso8601String()}'),
      Text('App version: ${_preview.appVersion}'),
      Text('Schema version: ${_preview.schemaVersion}'),
      const Text('Times come from each device’s clock.'),
      const SizedBox(height: 16),
      _SectionCounts(preview: _preview),
      const SizedBox(height: 16),
      _modes(),
      const SizedBox(height: 12),
      BackupImportSummaryView(summary: _preview.summary),
      if (_preview.mergeError case final message?) _notice(message),
      if (_error case final message?) _notice(message),
      if (_applying) ...[
        const SizedBox(height: 12),
        const LinearProgressIndicator(semanticsLabel: 'Import in progress'),
        _notice('Importing your backup…'),
      ],
    ],
  );

  Widget _notice(String message) => Padding(
    padding: const EdgeInsets.only(top: 12),
    child: Semantics(liveRegion: true, child: Text(message)),
  );

  Widget _modes() => RadioGroup<BackupImportMode>(
    groupValue: BackupImportMode.smartMerge,
    onChanged: (_) {},
    child: Column(
      children: [
        RadioListTile<BackupImportMode>(
          value: BackupImportMode.smartMerge,
          enabled: !_applying,
          title: const Text('Smart Merge'),
          subtitle: const Text(
            'Keep unrelated local data. Add missing records and preserve local values.',
          ),
          contentPadding: EdgeInsets.zero,
        ),
        const RadioListTile<BackupImportMode>(
          value: BackupImportMode.replaceAll,
          enabled: false,
          title: Text('Replace All Local Data'),
          subtitle: Text('Replace the backup-owned local data with this file.'),
          contentPadding: EdgeInsets.zero,
        ),
      ],
    ),
  );
}

String backupImportError(Object error) => switch (error) {
  FormatException(:final message) => message,
  SnapshotRecoveryException() =>
    'Local recovery needs retry. Your recovery copy is kept.',
  StateError(:final message) => message,
  _ => 'Import could not finish. Try again or choose another file.',
};

class BackupImportSummaryView extends StatelessWidget {
  final BackupImportSummary summary;
  const BackupImportSummaryView({super.key, required this.summary});
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('Activities added: ${summary.addedActivities}'),
      Text('Activities matched: ${summary.matchedActivities}'),
      Text('Workouts matched by details: ${summary.signatureMatches}'),
      Text('Workout IDs updated: ${summary.canonicalIdentityChanges}'),
      Text('Uncertain groups kept separate: ${summary.ambiguousSignatures}'),
      Text('Local values kept: ${summary.retainedConflicts}'),
      Text('Profile fields changed: ${summary.changedPreferences}'),
      Text(
        'Training plan changed: ${summary.changedTrainingPlan ? 'Yes' : 'No'}',
      ),
      Text('Shoes added: ${summary.addedShoes}'),
      Text('Shoes updated: ${summary.updatedShoes}'),
      Text('Shoe assignments changed: ${summary.changedAssignments}'),
      Text('Rehab records added: ${summary.addedFeedback}'),
      Text('Rehab records updated: ${summary.updatedFeedback}'),
      for (final warning in summary.warnings) Text(warning),
    ],
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
      _row('Section', 'Local', 'File'),
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
  TableRow _row(String label, String local, String file) => TableRow(
    children: [
      for (final text in [label, local, file])
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
          child: Text(text),
        ),
    ],
  );
}

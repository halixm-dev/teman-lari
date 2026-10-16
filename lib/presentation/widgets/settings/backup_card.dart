import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/backup/snapshot_backup_service.dart';
import '../../../data/backup/transport/backup_file_transport.dart';
import '../../providers/backup_provider.dart';

class BackupCard extends ConsumerStatefulWidget {
  const BackupCard({super.key});
  @override
  ConsumerState<BackupCard> createState() => _BackupCardState();
}

class _BackupCardState extends ConsumerState<BackupCard> {
  bool _busy = false;
  String? _message;

  Future<void> _export() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final service = ref.read(snapshotBackupServiceProvider);
      ref.invalidate(backupCountsProvider);
      final result = await service.exportBackup(
        ref.read(backupFileTransportProvider),
      );
      if (mounted) {
        setState(
          () => _message = switch (result) {
            BackupDelivery.saved => 'Backup saved.',
            BackupDelivery.cancelled =>
              'Export cancelled. No backup was saved.',
            BackupDelivery.downloadStarted =>
              'Download started. Check your browser downloads.',
            BackupDelivery.shared =>
              'Backup shared with another app. Check that it was saved there.',
          },
        );
      }
    } catch (error) {
      if (mounted) setState(() => _message = 'Backup failed: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final service = ref.watch(snapshotBackupServiceProvider);
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Offline Backup',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            const Text(
              'No account or internet needed. The backup contains readable personal data. Store it somewhere private.',
            ),
            const SizedBox(height: 12),
            const _BackupCounts(),
            const SizedBox(height: 16),
            ValueListenableBuilder<BackupExportPhase>(
              valueListenable: service.exportPhase,
              builder: (context, phase, child) => _controls(phase),
            ),
            if (_message case final message?) ...[
              const SizedBox(height: 12),
              Semantics(liveRegion: true, child: Text(message)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _controls(BackupExportPhase phase) {
    final busy = _busy || phase != BackupExportPhase.idle;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FilledButton.icon(
          onPressed: busy ? null : _export,
          icon: const Icon(Icons.file_download_outlined),
          label: const Text('Export Backup'),
        ),
        if (busy) ...[
          const SizedBox(height: 12),
          const LinearProgressIndicator(semanticsLabel: 'Backup in progress'),
          const SizedBox(height: 8),
          Semantics(
            liveRegion: true,
            child: Text(
              phase == BackupExportPhase.saving
                  ? 'Choose where to save your backup…'
                  : 'Preparing your backup…',
            ),
          ),
        ],
      ],
    );
  }
}

class _BackupCounts extends ConsumerWidget {
  const _BackupCounts();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(snapshotBackupServiceProvider).coordinator.initialized) {
      return const SizedBox.shrink();
    }
    return ref
        .watch(backupCountsProvider)
        .when(
          data: (counts) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Saved training plans: ${counts['training_plans'] ?? 0}'),
              Text('Shoe records and assignments: ${counts['equipment'] ?? 0}'),
              Text('Rehab feedback records: ${counts['rehab_feedback'] ?? 0}'),
            ],
          ),
          error: (_, _) => const Text('Saved-record counts unavailable.'),
          loading: () => const SizedBox.shrink(),
        );
  }
}

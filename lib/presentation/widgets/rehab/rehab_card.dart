import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../domain/entities/rehab_feedback.dart';
import '../../../domain/entities/rehab_journal.dart';
import '../../../domain/entities/rehab_progress.dart';
import '../../../domain/entities/running_stats.dart';
import '../../../domain/entities/rehab_program.dart';
import '../../providers/activities_provider.dart';
import '../../providers/rehab_provider.dart';
import 'rehab_async_button.dart';
import 'rehab_check_in_actions.dart';
import 'rehab_setup_sheet.dart';
import 'rehab_mode_preference.dart';

class RehabCard extends ConsumerWidget {
  final RunningStats? stats;
  final bool allowStart;
  const RehabCard({super.key, this.stats, this.allowStart = false});
  @override
  Widget build(BuildContext context, WidgetRef ref) => ref
      .watch(rehabJournalProvider)
      .when(
        loading: () => const SizedBox.shrink(),
        error: (_, _) => Card(
          child: ListTile(
            title: const Text('Return-to-run check-ins unavailable'),
            trailing: TextButton(
              onPressed: () => ref.invalidate(rehabJournalProvider),
              child: const Text('Retry'),
            ),
          ),
        ),
        data: (journal) {
          final program = journal.program;
          if (program == null) {
            if (!allowStart && stats?.returnContext?.isReturning != true) {
              return const SizedBox.shrink();
            }
            return _entry(
              context,
              ref,
              'Return to running',
              'Start return-to-run',
            );
          }
          if (program.graduatedAt != null) {
            return _entry(
              context,
              ref,
              'Return-to-run complete',
              'Start another return plan',
              mode: program.mode,
            );
          }
          return ref
              .watch(rehabProgressProvider)
              .when(
                loading: () => const SizedBox.shrink(),
                error: (_, _) =>
                    const Text('Could not load return-to-run progress.'),
                data: (progress) => progress == null
                    ? const SizedBox.shrink()
                    : _ActiveRehabCard(journal: journal, progress: progress),
              );
        },
      );

  Widget _entry(
    BuildContext context,
    WidgetRef ref,
    String title,
    String action, {
    ReturnModality mode = ReturnModality.walkRun,
  }) => Card(
    margin: const EdgeInsets.only(bottom: 24),
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const Text(
            'Choose easy return sessions and track your response after each run.',
          ),
          RehabAsyncButton(
            label: action,
            onPressed: () async {
              final baseline =
                  stats ?? await ref.read(runningStatsProvider.future);
              if (context.mounted) {
                await showRehabSetup(
                  context,
                  stats: baseline ?? RunningStats.empty(),
                  mode: mode,
                );
              }
            },
          ),
        ],
      ),
    ),
  );
}

class _ActiveRehabCard extends ConsumerWidget {
  final RehabJournal journal;
  final RehabProgress progress;
  const _ActiveRehabCard({required this.journal, required this.progress});
  @override
  Widget build(BuildContext context, WidgetRef ref) => Card(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Return-to-run', style: Theme.of(context).textTheme.titleLarge),
          Text(
            'Stage ${(progress.stage + 1).clamp(1, progress.program.rampWeeks)} of ${progress.program.rampWeeks}',
          ),
          const SizedBox(height: 12),
          Text(_status()),
          const SizedBox(height: 12),
          RehabModePreference(mode: progress.program.mode),
          if (progress.recoveryUntil case final until?)
            Text(
              'No running before ${DateFormat.yMMMd().add_Hm().format(until.toLocal())}.',
            ),
          const SizedBox(height: 16),
          RehabCheckInActions(journal: journal, progress: progress),
          if (progress.readyToGraduate) ...[
            const SizedBox(height: 16),
            RehabAsyncButton(
              label: 'Review readiness',
              onPressed: () => _confirm(context, ref),
            ),
          ],
        ],
      ),
    ),
  );

  String _status() => progress.readyToGraduate
      ? 'Ramp weeks complete. Your confirmation is required to finish.'
      : switch (progress.status) {
          RehabStatus.pending =>
            'Waiting for complete check-ins. Progression is held.',
          RehabStatus.pass => 'Check-ins cleared. Continue the current stage.',
          RehabStatus.warning =>
            'Stage held. Complete recovery before repeating.',
          RehabStatus.flareUp =>
            'Flare-up: volume reduced. Choose non-impact recovery.',
        };

  Future<void> _confirm(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Ready to leave return-to-run?'),
        content: const Text(
          'Confirm that you feel ready to resume usual training. '
          'If symptoms persist, keep the return plan and seek professional advice.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: const Text('Keep return plan'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialog, true),
            child: const Text('Confirm readiness'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await ref
          .read(rehabJournalProvider.notifier)
          .graduate(progress.program.startedAt);
    }
  }
}

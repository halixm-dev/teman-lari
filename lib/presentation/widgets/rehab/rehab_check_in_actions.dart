import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../domain/entities/rehab_journal.dart';
import '../../../domain/entities/activity.dart';
import '../../../domain/entities/rehab_feedback.dart';
import '../../../domain/entities/rehab_progress.dart';
import '../../providers/rehab_provider.dart';
import 'rehab_check_in_sheet.dart';

class RehabCheckInActions extends ConsumerWidget {
  final RehabJournal journal;
  final RehabProgress progress;
  const RehabCheckInActions({
    super.key,
    required this.journal,
    required this.progress,
  });
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.watch(rehabTimeProvider).value ?? DateTime.now();
    final runs =
        journal.activities
            .where(
              (run) =>
                  run.type == ActivityType.run &&
                  !run.date.isBefore(progress.program.startedAt) &&
                  !run.date.isAfter(now),
            )
            .toList()
          ..sort((a, b) => b.date.compareTo(a.date));
    final run = progress.pendingActivities.firstOrNull ?? runs.firstOrNull;
    if (run == null) {
      return const Text('Record your next run to start check-ins.');
    }
    final existing = journal.feedback
        .where(
          (f) =>
              f.activityId == run.id &&
              f.injurySite == progress.program.injurySite,
        )
        .firstOrNull;
    final date = run.date.toLocal();
    final morningOpen = !now.toLocal().isBefore(
      DateTime(date.year, date.month, date.day + 1),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Check-ins for ${run.name} · ${date.day}/${date.month}'),
        _buttons(context, run, existing, morningOpen),
        if (!morningOpen)
          const Text('Morning check-in opens the day after your run.'),
        if (progress.pendingActivities.length > 1)
          Text(
            '${progress.pendingActivities.length} runs still need complete check-ins.',
          ),
      ],
    );
  }

  Widget _buttons(
    BuildContext context,
    Activity run,
    RehabFeedback? existing,
    bool morningOpen,
  ) => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      OutlinedButton(
        onPressed: () => showRehabCheckIn(
          context,
          activity: run,
          program: progress.program,
          existing: existing,
        ),
        child: const Text('After-run check-in'),
      ),
      OutlinedButton(
        onPressed: morningOpen && existing?.postRunPain != null
            ? () => showRehabCheckIn(
                context,
                activity: run,
                program: progress.program,
                existing: existing,
                window: CheckInWindow.morningAfter,
              )
            : null,
        child: const Text('Next-morning check-in'),
      ),
    ],
  );
}

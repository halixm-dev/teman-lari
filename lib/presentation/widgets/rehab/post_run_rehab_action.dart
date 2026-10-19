import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../domain/entities/activity.dart';
import '../../providers/rehab_provider.dart';
import 'rehab_check_in_sheet.dart';

class PostRunRehabAction extends ConsumerWidget {
  final Activity? activity;
  const PostRunRehabAction({super.key, required this.activity});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final run = activity;
    if (run == null) return const SizedBox.shrink();
    final journal = ref.watch(rehabJournalProvider).value;
    final program = journal?.program;
    if (program == null ||
        program.graduatedAt != null ||
        run.date.isBefore(program.startedAt)) {
      return const SizedBox.shrink();
    }
    final existing = journal?.feedback
        .where(
          (feedback) =>
              feedback.activityId == run.id &&
              feedback.injurySite == program.injurySite,
        )
        .firstOrNull;
    return OutlinedButton(
      onPressed: () => showRehabCheckIn(
        context,
        activity: run,
        program: program,
        existing: existing,
      ),
      child: const Text('After-run pain check-in'),
    );
  }
}

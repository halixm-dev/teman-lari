import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/activities_provider.dart';
import '../theme/app_typography.dart';
import 'compact_activity_card.dart';
import 'manual_run_entry_sheet.dart';

class RecentActivitiesList extends ConsumerStatefulWidget {
  const RecentActivitiesList({super.key});

  @override
  ConsumerState<RecentActivitiesList> createState() =>
      _RecentActivitiesListState();
}

class _RecentActivitiesListState extends ConsumerState<RecentActivitiesList> {
  bool _showAll = false;

  @override
  Widget build(BuildContext context) {
    final statsAsync = ref.watch(runningStatsProvider);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Recent Activities',
                    style: AppTypography.headingLg,
                  ),
                ),
                TextButton.icon(
                  key: const Key('recent_activities_log_manual_run_button'),
                  onPressed: () => showManualRunEntrySheet(context),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Log Manual Run'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            statsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, _) => const Text('Error loading activities'),
              data: (stats) {
                if (stats == null) {
                  return const Text('No activities found');
                }

                final recent =
                    stats.analyzedActivities
                        .where((a) => a.activity.distanceKm > 0)
                        .toList()
                      ..sort(
                        (a, b) => b.activity.date.compareTo(a.activity.date),
                      );
                final displayed = _showAll ? recent : recent.take(5).toList();

                if (displayed.isEmpty) {
                  return const Text('No activities found');
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: displayed.length,
                      separatorBuilder: (_, _) => const Divider(height: 16),
                      itemBuilder: (context, i) {
                        final run = displayed[i];
                        return CompactActivityCard(analyzedRun: run);
                      },
                    ),
                    if (recent.length > 5 && !_showAll) ...[
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _showAll = true;
                          });
                        },
                        child: const Text('Show More'),
                      ),
                    ],
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

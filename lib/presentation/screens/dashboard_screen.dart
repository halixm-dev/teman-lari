import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../core/utils/responsive.dart';
import '../../domain/entities/running_stats.dart';
import '../providers/activities_provider.dart';
import '../providers/preferences_provider.dart';
import '../theme/app_colors.dart';
import '../widgets/fitness_form_card.dart';
import '../widgets/manual_run_entry_sheet.dart';
import '../widgets/recent_activities_list.dart';
import '../widgets/today_workout_card.dart';
import '../widgets/rehab/rehab_card.dart';
import '../widgets/weekly_volume_chart.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(runningStatsProvider);
    final activities = ref.watch(activitiesProvider);
    final nameAsync = ref.watch(athleteNameProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(_greeting(nameAsync.whenOrNull(data: (n) => n))),
        actions: [
          IconButton(
            key: const Key('dashboard_log_manual_run_button'),
            icon: const Icon(Icons.add_task_outlined),
            tooltip: 'Log Manual Run',
            onPressed: () => showManualRunEntrySheet(context),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh activities',
            onPressed: () => ref.read(activitiesProvider.notifier).refresh(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('dashboard_log_manual_run_fab'),
        onPressed: () => showManualRunEntrySheet(context),
        icon: const Icon(Icons.add),
        label: const Text('Log Manual Run'),
        backgroundColor: AppColors.brandOrange,
        foregroundColor: Colors.white,
      ),
      body: ConstrainedContent(
        child: activities.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => _DashboardError(error: e),
          data: (_) => statsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) => Center(child: Text('Error: $err')),
            data: (stats) => stats == null
                ? const Center(child: Text('No data'))
                : _DashboardData(stats: stats),
          ),
        ),
      ),
    );
  }

  String _greeting(String? name) {
    final athlete = (name != null && name.trim().isNotEmpty)
        ? name.trim()
        : 'Runner';
    return 'Hello, $athlete!';
  }
}

class _DashboardError extends ConsumerWidget {
  final Object error;
  const _DashboardError({required this.error});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: Colors.red),
          const SizedBox(height: 16),
          Text('Error: $error'),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () => ref.read(activitiesProvider.notifier).refresh(),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

class _DashboardData extends ConsumerWidget {
  final RunningStats stats;
  const _DashboardData({required this.stats});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return RefreshIndicator(
      onRefresh: () => ref.read(activitiesProvider.notifier).refresh(),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children:
              [
                    FitnessFormCard(stats: stats),
                    const SizedBox(height: 24),
                    const TodayWorkoutCard(),
                    RehabCard(stats: stats),
                    const SizedBox(height: 24),
                    WeeklyVolumeChart(stats: stats),
                    const SizedBox(height: 24),
                    const RecentActivitiesList(),
                  ]
                  .animate(interval: 80.ms)
                  .fade(duration: 450.ms)
                  .slideY(begin: 0.1, end: 0, curve: Curves.easeOutQuad),
        ),
      ),
    );
  }
}

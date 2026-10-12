import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/error_formatter.dart';
import '../../core/utils/date_utils.dart';
import '../../domain/entities/activity.dart';
import '../../domain/entities/analyzed_activity.dart';
import '../providers/activities_provider.dart';
import '../providers/auth_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme_extensions.dart';
import 'scale_on_press.dart';
import 'workout_type_badge.dart';

class CompactActivityCard extends ConsumerStatefulWidget {
  final AnalyzedActivity analyzedRun;

  const CompactActivityCard({super.key, required this.analyzedRun});

  @override
  ConsumerState<CompactActivityCard> createState() =>
      _CompactActivityCardState();
}

class _CompactActivityCardState extends ConsumerState<CompactActivityCard> {
  bool _isUploading = false;

  Future<void> _handleUpload(BuildContext context, Activity run) async {
    setState(() => _isUploading = true);
    try {
      await ref.read(activitiesProvider.notifier).uploadActivity(run.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Uploaded "${run.name}" to Strava successfully.'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Upload failed: ${AppErrorFormatter.format(e)}'),
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: 'Retry',
              onPressed: () => _handleUpload(context, run),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final typoExt = Theme.of(context).extension<AppTypographyExtension>();
    final authState = ref.watch(authProvider);
    final run = widget.analyzedRun.activity;
    final isConnected = authState.isAuthenticated;

    return ScaleOnPress(
      onTap: () {}, // Empty tap for scale feedback
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    run.name,
                    style: Theme.of(context).textTheme.titleSmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                _SyncStatusBadge(isLocal: run.isLocal, activityId: run.id),
                const SizedBox(width: 8),
                WorkoutTypeBadge(type: widget.analyzedRun.type),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              AppDateUtils.formatDate(run.date),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            LayoutBuilder(
              builder: (context, constraints) {
                final statsWidgets = [
                  _CompactStat(
                    icon: Icons.route_outlined,
                    value: '${run.distanceKm.toStringAsFixed(2)} km',
                    typoExt: typoExt,
                  ),
                  _CompactStat(
                    icon: Icons.timer_outlined,
                    value: _formatDuration(run.movingTime),
                    typoExt: typoExt,
                  ),
                  if (run.type == ActivityType.run ||
                      run.type == ActivityType.walk)
                    _CompactStat(
                      icon: Icons.speed_outlined,
                      value: run.paceString,
                      typoExt: typoExt,
                    ),
                  if (run.avgHeartRate != null)
                    _CompactStat(
                      icon: Icons.favorite_border_outlined,
                      value: '${run.avgHeartRate!.round()} bpm',
                      typoExt: typoExt,
                    ),
                ];

                if (constraints.maxWidth < 280) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: statsWidgets
                        .map(
                          (w) => Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: w,
                          ),
                        )
                        .toList(),
                  );
                }

                return Wrap(spacing: 16, runSpacing: 8, children: statsWidgets);
              },
            ),
            if (run.isLocal && isConnected) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: OutlinedButton.icon(
                  key: ValueKey('upload_strava_button_${run.id}'),
                  onPressed: _isUploading
                      ? null
                      : () => _handleUpload(context, run),
                  icon: _isUploading
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.cloud_upload_outlined, size: 16),
                  label: Text(
                    _isUploading ? 'Uploading...' : 'Upload to Strava',
                  ),
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    foregroundColor: AppColors.brandOrange,
                    side: BorderSide(
                      color: AppColors.brandOrange.withValues(alpha: 0.5),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    textStyle: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}

class _SyncStatusBadge extends StatelessWidget {
  final bool isLocal;
  final int activityId;

  const _SyncStatusBadge({required this.isLocal, required this.activityId});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (isLocal) {
      return Container(
        key: ValueKey('sync_badge_local_$activityId'),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceTertiaryDark : AppColors.gray200,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.save_outlined,
              size: 11,
              color: isDark ? AppColors.textSecondaryDark : AppColors.gray700,
            ),
            const SizedBox(width: 4),
            Text(
              'Local',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: isDark ? AppColors.textSecondaryDark : AppColors.gray700,
              ),
            ),
          ],
        ),
      );
    } else {
      return Container(
        key: ValueKey('sync_badge_strava_$activityId'),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: AppColors.brandOrange.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_done_rounded,
              size: 11,
              color: AppColors.brandOrange,
            ),
            SizedBox(width: 4),
            Text(
              'Strava',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.brandOrange,
              ),
            ),
          ],
        ),
      );
    }
  }
}

class _CompactStat extends StatelessWidget {
  final IconData icon;
  final String value;
  final AppTypographyExtension? typoExt;

  const _CompactStat({required this.icon, required this.value, this.typoExt});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(
          icon,
          size: 16,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 4),
        Text(
          value,
          style:
              typoExt?.statValue ??
              Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

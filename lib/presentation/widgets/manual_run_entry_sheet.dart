import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../providers/activities_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// Opens the modal bottom sheet for manual run entry.
Future<void> showManualRunEntrySheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Theme.of(context).brightness == Brightness.dark
        ? AppColors.surfaceSecondaryDark
        : AppColors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(AppSpacing.radiusXl),
      ),
    ),
    builder: (context) => const ManualRunEntrySheet(),
  );
}

class ManualRunEntrySheet extends ConsumerStatefulWidget {
  final DateTime? initialDateTime;

  const ManualRunEntrySheet({super.key, this.initialDateTime});

  static String calculatePaceString(double distanceKm, Duration duration) {
    if (distanceKm > 0 && duration.inSeconds > 0) {
      final paceSeconds = (duration.inSeconds / distanceKm).round();
      final paceMin = paceSeconds ~/ 60;
      final paceSec = paceSeconds % 60;
      return '$paceMin:${paceSec.toString().padLeft(2, '0')} /km';
    }
    return '--:-- /km';
  }

  static String getRpeLabel(int rpe) {
    switch (rpe) {
      case 1:
      case 2:
        return 'Very Light (Warm-up / Recovery)';
      case 3:
      case 4:
        return 'Light (Easy conversational pace)';
      case 5:
      case 6:
        return 'Moderate (Comfortably hard / Aerobic)';
      case 7:
      case 8:
        return 'Hard (Threshold / Heavy breathing)';
      case 9:
      case 10:
        return 'Max Effort (All-out sprint / Exhaustion)';
      default:
        return 'Moderate';
    }
  }

  @override
  ConsumerState<ManualRunEntrySheet> createState() =>
      _ManualRunEntrySheetState();
}

class _ManualRunEntrySheetState extends ConsumerState<ManualRunEntrySheet> {
  final _formKey = GlobalKey<FormState>();

  late DateTime _selectedDateTime;
  final _distanceController = TextEditingController();
  final _hoursController = TextEditingController();
  final _minutesController = TextEditingController();
  final _secondsController = TextEditingController();
  final _nameController = TextEditingController();

  double _rpe = 5.0;
  String? _selectedShoeId;
  bool _isSubmitting = false;
  String? _dateError;
  String? _durationError;

  @override
  void initState() {
    super.initState();
    _selectedDateTime = widget.initialDateTime ?? DateTime.now();
  }

  @override
  void dispose() {
    _distanceController.dispose();
    _hoursController.dispose();
    _minutesController.dispose();
    _secondsController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  String _calculatePace() {
    final dist =
        double.tryParse(_distanceController.text.trim().replaceAll(',', '.')) ??
        0.0;
    final h = int.tryParse(_hoursController.text.trim()) ?? 0;
    final m = int.tryParse(_minutesController.text.trim()) ?? 0;
    final s = int.tryParse(_secondsController.text.trim()) ?? 0;
    final totalSeconds = (h * 3600) + (m * 60) + s;

    return ManualRunEntrySheet.calculatePaceString(
      dist,
      Duration(seconds: totalSeconds),
    );
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDateTime.isAfter(now) ? now : _selectedDateTime,
      firstDate: DateTime(2000),
      lastDate: now,
    );

    if (pickedDate != null) {
      final updated = DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
        _selectedDateTime.hour,
        _selectedDateTime.minute,
      );

      setState(() {
        if (updated.isAfter(now)) {
          _selectedDateTime = now;
        } else {
          _selectedDateTime = updated;
        }
        _dateError = null;
      });
    }
  }

  Future<void> _pickTime() async {
    final now = DateTime.now();
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_selectedDateTime),
    );

    if (pickedTime != null) {
      final updated = DateTime(
        _selectedDateTime.year,
        _selectedDateTime.month,
        _selectedDateTime.day,
        pickedTime.hour,
        pickedTime.minute,
      );

      if (updated.isAfter(now)) {
        setState(() {
          _dateError = 'Workout date/time cannot be in the future';
        });
        return;
      }

      setState(() {
        _selectedDateTime = updated;
        _dateError = null;
      });
    }
  }

  Future<void> _submit() async {
    final now = DateTime.now();
    if (_selectedDateTime.isAfter(now)) {
      setState(() {
        _dateError = 'Workout date/time cannot be in the future';
      });
      return;
    }

    final isFormValid = _formKey.currentState?.validate() ?? false;

    final dist =
        double.tryParse(_distanceController.text.trim().replaceAll(',', '.')) ??
        0.0;
    final h = int.tryParse(_hoursController.text.trim()) ?? 0;
    final m = int.tryParse(_minutesController.text.trim()) ?? 0;
    final s = int.tryParse(_secondsController.text.trim()) ?? 0;
    final totalSeconds = (h * 3600) + (m * 60) + s;

    if (totalSeconds <= 0) {
      setState(() {
        _durationError = 'Duration must be greater than 0';
      });
      return;
    } else {
      setState(() {
        _durationError = null;
      });
    }

    if (!isFormValid || dist <= 0) {
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final rawName = _nameController.text.trim();
      final name = rawName.isNotEmpty ? rawName : 'Run';
      final duration = Duration(seconds: totalSeconds);

      await ref
          .read(activitiesProvider.notifier)
          .addManualActivity(
            date: _selectedDateTime,
            distanceKm: dist,
            duration: duration,
            perceivedExertion: _rpe,
            name: name,
            shoeId: _selectedShoeId,
          );

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Manual run "$name" logged successfully!'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save manual run: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final dateFormat = DateFormat('EEE, MMM d, yyyy');
    final timeFormat = DateFormat('h:mm a');

    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 8,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Grab handle
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(top: 8, bottom: 16),
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppColors.surfaceTertiaryDark
                        : AppColors.gray300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Sheet Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Log Manual Run', style: AppTypography.headingLg),
                  IconButton(
                    icon: const Icon(Icons.close),
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Activity Name (Optional)
              TextFormField(
                key: const Key('manual_run_name_input'),
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Workout Title (Optional)',
                  hintText: 'e.g. Treadmill Run, Morning Jog',
                  prefixIcon: Icon(Icons.directions_run_outlined),
                ),
              ),
              const SizedBox(height: 16),

              // Date & Time Picker Section
              Text('Date & Start Time', style: AppTypography.headingSm),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      key: const Key('manual_run_date_picker_button'),
                      icon: const Icon(Icons.calendar_today_outlined, size: 18),
                      label: Text(
                        dateFormat.format(_selectedDateTime),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onPressed: _pickDate,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      key: const Key('manual_run_time_picker_button'),
                      icon: const Icon(Icons.access_time_outlined, size: 18),
                      label: Text(
                        timeFormat.format(_selectedDateTime),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onPressed: _pickTime,
                    ),
                  ),
                ],
              ),
              if (_dateError != null) ...[
                const SizedBox(height: 4),
                Text(
                  _dateError!,
                  style: TextStyle(color: AppColors.danger, fontSize: 12),
                ),
              ],
              const SizedBox(height: 16),

              // Distance Input
              TextFormField(
                key: const Key('manual_run_distance_input'),
                controller: _distanceController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Distance (km)',
                  hintText: '0.00',
                  prefixIcon: Icon(Icons.route_outlined),
                  suffixText: 'km',
                ),
                onChanged: (_) => setState(() {}),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a distance';
                  }
                  final dist = double.tryParse(
                    value.trim().replaceAll(',', '.'),
                  );
                  if (dist == null || dist <= 0) {
                    return 'Distance must be greater than 0 km';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Duration Input
              Text('Duration', style: AppTypography.headingSm),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      key: const Key('manual_run_hours_input'),
                      controller: _hoursController,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      decoration: const InputDecoration(
                        labelText: 'Hours',
                        hintText: '0',
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      key: const Key('manual_run_minutes_input'),
                      controller: _minutesController,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      decoration: const InputDecoration(
                        labelText: 'Minutes',
                        hintText: '00',
                      ),
                      onChanged: (_) => setState(() {}),
                      validator: (value) {
                        if (value != null && value.trim().isNotEmpty) {
                          final m = int.tryParse(value.trim());
                          if (m == null || m < 0 || m >= 60) {
                            return '0-59';
                          }
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      key: const Key('manual_run_seconds_input'),
                      controller: _secondsController,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      decoration: const InputDecoration(
                        labelText: 'Seconds',
                        hintText: '00',
                      ),
                      onChanged: (_) => setState(() {}),
                      validator: (value) {
                        if (value != null && value.trim().isNotEmpty) {
                          final s = int.tryParse(value.trim());
                          if (s == null || s < 0 || s >= 60) {
                            return '0-59';
                          }
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              if (_durationError != null) ...[
                const SizedBox(height: 4),
                Text(
                  _durationError!,
                  style: TextStyle(color: AppColors.danger, fontSize: 12),
                ),
              ],
              const SizedBox(height: 16),

              // Dynamic Real-time Pace Display
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.surfaceTertiaryDark
                      : AppColors.brandOrangeTint,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  border: Border.all(
                    color: AppColors.brandOrange.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.speed_rounded,
                          color: AppColors.brandOrange,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text('Average Pace', style: AppTypography.headingSm),
                      ],
                    ),
                    Text(
                      _calculatePace(),
                      key: const Key('manual_run_pace_display'),
                      style: AppTypography.statValue.copyWith(
                        color: AppColors.brandOrange,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Perceived Exertion (RPE 1-10) Selector
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Perceived Exertion (RPE)',
                    style: AppTypography.headingSm,
                  ),
                  Text(
                    '${_rpe.round()} / 10',
                    key: const Key('manual_run_rpe_value'),
                    style: AppTypography.headingSm.copyWith(
                      color: AppColors.brandOrange,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Slider(
                key: const Key('manual_run_rpe_slider'),
                value: _rpe,
                min: 1.0,
                max: 10.0,
                divisions: 9,
                activeColor: AppColors.brandOrange,
                inactiveColor: isDark
                    ? AppColors.surfaceTertiaryDark
                    : AppColors.gray200,
                onChanged: (value) => setState(() => _rpe = value),
              ),
              Text(
                ManualRunEntrySheet.getRpeLabel(_rpe.round()),
                key: const Key('manual_run_rpe_label'),
                textAlign: TextAlign.center,
                style: AppTypography.bodySm.copyWith(
                  color: isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.gray700,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 16),

              // Optional Shoe Selector
              DropdownButtonFormField<String?>(
                key: const Key('manual_run_shoe_dropdown'),
                initialValue: _selectedShoeId,
                decoration: const InputDecoration(
                  labelText: 'Shoe (Optional)',
                  prefixIcon: Icon(Icons.roller_skating_outlined),
                ),
                items: const [
                  DropdownMenuItem(value: null, child: Text('None / Default')),
                  DropdownMenuItem(
                    value: 'daily_trainer',
                    child: Text('Daily Trainer'),
                  ),
                  DropdownMenuItem(
                    value: 'tempo_shoe',
                    child: Text('Tempo / Speed Shoe'),
                  ),
                  DropdownMenuItem(
                    value: 'race_shoe',
                    child: Text('Race Day Plated Shoe'),
                  ),
                  DropdownMenuItem(
                    value: 'recovery_shoe',
                    child: Text('Recovery / Max Cushion'),
                  ),
                ],
                onChanged: (val) {
                  setState(() {
                    _selectedShoeId = val;
                  });
                },
              ),
              const SizedBox(height: 24),

              // Submit Button
              SizedBox(
                height: 48,
                child: FilledButton(
                  key: const Key('manual_run_submit_button'),
                  onPressed: _isSubmitting ? null : _submit,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.brandOrange,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                    ),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Log Run',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

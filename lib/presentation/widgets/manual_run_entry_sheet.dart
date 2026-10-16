import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../providers/activities_provider.dart';
import '../providers/equipment_provider.dart';
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
    final totalSeconds = _parseTotalDuration() ?? 0;

    return ManualRunEntrySheet.calculatePaceString(
      dist,
      Duration(seconds: totalSeconds),
    );
  }

  int? _parseTotalDuration() {
    final h = int.tryParse(_hoursController.text.trim()) ?? 0;
    final m = int.tryParse(_minutesController.text.trim()) ?? 0;
    final s = int.tryParse(_secondsController.text.trim()) ?? 0;
    final totalSeconds = (h * 3600) + (m * 60) + s;
    return totalSeconds > 0 ? totalSeconds : null;
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
        _selectedDateTime = updated.isAfter(now) ? now : updated;
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
    final totalSeconds = _parseTotalDuration();
    if (totalSeconds == null) {
      setState(() {
        _durationError = 'Duration must be greater than 0';
      });
      return;
    }
    setState(() => _durationError = null);

    final dist =
        double.tryParse(_distanceController.text.trim().replaceAll(',', '.')) ??
        0.0;
    if (!isFormValid || dist <= 0) return;

    await _saveManualRun(dist, totalSeconds);
  }

  Future<void> _saveManualRun(double dist, int totalSeconds) async {
    setState(() => _isSubmitting = true);

    try {
      final rawName = _nameController.text.trim();
      final name = rawName.isNotEmpty ? rawName : 'Run';
      await ref
          .read(activitiesProvider.notifier)
          .addManualActivity(
            date: _selectedDateTime,
            distanceKm: dist,
            duration: Duration(seconds: totalSeconds),
            perceivedExertion: _rpe,
            name: name,
            shoeId: _selectedShoeId,
          );

      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Manual run "$name" logged successfully!'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save manual run: $e'),
          backgroundColor: AppColors.danger,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Widget _buildGrabHandle(bool isDark) {
    return Center(
      child: Container(
        width: 36,
        height: 4,
        margin: const EdgeInsets.only(top: 8, bottom: 16),
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceTertiaryDark : AppColors.gray300,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text('Log Manual Run', style: AppTypography.headingLg),
        IconButton(
          icon: const Icon(Icons.close),
          tooltip: 'Close',
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }

  Widget _buildNameField() {
    return TextFormField(
      key: const Key('manual_run_name_input'),
      controller: _nameController,
      decoration: const InputDecoration(
        labelText: 'Workout Title (Optional)',
        hintText: 'e.g. Treadmill Run, Morning Jog',
        prefixIcon: Icon(Icons.directions_run_outlined),
      ),
    );
  }

  Widget _buildShoeDropdown() {
    return DropdownButtonFormField<String?>(
      key: const Key('manual_run_shoe_dropdown'),
      initialValue: _selectedShoeId,
      decoration: const InputDecoration(
        labelText: 'Shoe (Optional)',
        prefixIcon: Icon(Icons.roller_skating_outlined),
      ),
      items: [
        const DropdownMenuItem(value: null, child: Text('None / Default')),
        for (final shoe in ref.watch(equipmentProvider).asData?.value ?? [])
          DropdownMenuItem(value: shoe.id, child: Text(shoe.name)),
      ],
      onChanged: (val) => setState(() => _selectedShoeId = val),
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
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
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
      ),
    );
  }

  List<Widget> _buildFields(bool isDark) => [
    _buildGrabHandle(isDark),
    _buildHeader(context),
    const SizedBox(height: 16),
    _buildNameField(),
    const SizedBox(height: 16),
    _DateTimeSection(
      selectedDateTime: _selectedDateTime,
      dateError: _dateError,
      onPickDate: _pickDate,
      onPickTime: _pickTime,
    ),
    const SizedBox(height: 16),
    _DistanceSection(
      controller: _distanceController,
      onChanged: (_) => setState(() {}),
    ),
    const SizedBox(height: 16),
    _DurationPaceSection(
      hoursController: _hoursController,
      minutesController: _minutesController,
      secondsController: _secondsController,
      durationError: _durationError,
      paceString: _calculatePace(),
      isDark: isDark,
      onChanged: (_) => setState(() {}),
    ),
    const SizedBox(height: 20),
    _RpeSelectorSection(
      rpe: _rpe,
      isDark: isDark,
      onRpeChanged: (value) => setState(() => _rpe = value),
    ),
    const SizedBox(height: 16),
    _buildShoeDropdown(),
    const SizedBox(height: 24),
    _buildSubmitButton(),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
            children: _buildFields(isDark),
          ),
        ),
      ),
    );
  }
}

class _DateTimeSection extends StatelessWidget {
  final DateTime selectedDateTime;
  final String? dateError;
  final VoidCallback onPickDate;
  final VoidCallback onPickTime;

  const _DateTimeSection({
    required this.selectedDateTime,
    required this.dateError,
    required this.onPickDate,
    required this.onPickTime,
  });

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('EEE, MMM d, yyyy');
    final timeFormat = DateFormat('h:mm a');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Date & Start Time', style: AppTypography.headingSm),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                key: const Key('manual_run_date_picker_button'),
                icon: const Icon(Icons.calendar_today_outlined, size: 18),
                label: Text(
                  dateFormat.format(selectedDateTime),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                onPressed: onPickDate,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                key: const Key('manual_run_time_picker_button'),
                icon: const Icon(Icons.access_time_outlined, size: 18),
                label: Text(
                  timeFormat.format(selectedDateTime),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                onPressed: onPickTime,
              ),
            ),
          ],
        ),
        if (dateError case final error?) ...[
          const SizedBox(height: 4),
          Text(
            error,
            style: const TextStyle(color: AppColors.danger, fontSize: 12),
          ),
        ],
      ],
    );
  }
}

class _DistanceSection extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  const _DistanceSection({required this.controller, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      key: const Key('manual_run_distance_input'),
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: const InputDecoration(
        labelText: 'Distance (km)',
        hintText: '0.00',
        prefixIcon: Icon(Icons.route_outlined),
        suffixText: 'km',
      ),
      onChanged: onChanged,
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Please enter a distance';
        }
        final dist = double.tryParse(value.trim().replaceAll(',', '.'));
        if (dist == null || dist <= 0) {
          return 'Distance must be greater than 0 km';
        }
        return null;
      },
    );
  }
}

class _DurationPaceSection extends StatelessWidget {
  final TextEditingController hoursController;
  final TextEditingController minutesController;
  final TextEditingController secondsController;
  final String? durationError;
  final String paceString;
  final bool isDark;
  final ValueChanged<String> onChanged;

  const _DurationPaceSection({
    required this.hoursController,
    required this.minutesController,
    required this.secondsController,
    required this.durationError,
    required this.paceString,
    required this.isDark,
    required this.onChanged,
  });

  static String? _validateSexagesimal(String? value) {
    if (value != null && value.trim().isNotEmpty) {
      final v = int.tryParse(value.trim());
      if (v == null || v < 0 || v >= 60) {
        return '0-59';
      }
    }
    return null;
  }

  Widget _buildPaceDisplay() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.surfaceTertiaryDark
            : AppColors.brandOrangeTint,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: AppColors.brandOrange.withValues(alpha: 0.3)),
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
            paceString,
            key: const Key('manual_run_pace_display'),
            style: AppTypography.statValue.copyWith(
              color: AppColors.brandOrange,
            ),
          ),
        ],
      ),
    );
  }

  Widget _durationInput(
    String unit,
    String label,
    TextEditingController controller,
  ) => Expanded(
    child: TextFormField(
      key: Key('manual_run_${unit}_input'),
      controller: controller,
      keyboardType: TextInputType.number,
      textAlign: TextAlign.center,
      decoration: InputDecoration(
        labelText: label,
        hintText: unit == 'hours' ? '0' : '00',
      ),
      onChanged: onChanged,
      validator: unit == 'hours' ? null : _validateSexagesimal,
    ),
  );
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Duration', style: AppTypography.headingSm),
        const SizedBox(height: 8),
        Row(
          children: [
            _durationInput('hours', 'Hours', hoursController),
            const SizedBox(width: 8),
            _durationInput('minutes', 'Minutes', minutesController),
            const SizedBox(width: 8),
            _durationInput('seconds', 'Seconds', secondsController),
          ],
        ),
        if (durationError case final error?) ...[
          const SizedBox(height: 4),
          Text(
            error,
            style: const TextStyle(color: AppColors.danger, fontSize: 12),
          ),
        ],
        const SizedBox(height: 16),
        _buildPaceDisplay(),
      ],
    );
  }
}

class _RpeSelectorSection extends StatelessWidget {
  final double rpe;
  final bool isDark;
  final ValueChanged<double> onRpeChanged;

  const _RpeSelectorSection({
    required this.rpe,
    required this.isDark,
    required this.onRpeChanged,
  });

  @override
  Widget build(BuildContext context) {
    final roundedRpe = rpe.round();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Perceived Exertion (RPE)', style: AppTypography.headingSm),
            Text(
              '$roundedRpe / 10',
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
          value: rpe,
          min: 1.0,
          max: 10.0,
          divisions: 9,
          activeColor: AppColors.brandOrange,
          inactiveColor: isDark
              ? AppColors.surfaceTertiaryDark
              : AppColors.gray200,
          onChanged: onRpeChanged,
        ),
        Text(
          ManualRunEntrySheet.getRpeLabel(roundedRpe),
          key: const Key('manual_run_rpe_label'),
          textAlign: TextAlign.center,
          style: AppTypography.bodySm.copyWith(
            color: isDark ? AppColors.textSecondaryDark : AppColors.gray700,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

class ThresholdPaceUtils {
  static const int minPaceSeconds = 150; // 2:30 min/km
  static const int maxPaceSeconds = 720; // 12:00 min/km

  /// Parses text formatted as MM:SS (e.g. "5:00") into total seconds.
  /// Returns null if blank, malformed, or negative.
  static int? parsePace(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return null;
    if (trimmed.contains(':')) {
      final parts = trimmed.split(':');
      if (parts.length != 2) return null;
      if (parts[0].isEmpty || parts[1].isEmpty) return null;
      if (parts[0].startsWith('-') || parts[1].startsWith('-')) return null;
      final mins = int.tryParse(parts[0]);
      final secs = int.tryParse(parts[1]);
      if (mins == null || secs == null || secs < 0 || secs >= 60 || mins < 0) {
        return null;
      }
      return mins * 60 + secs;
    }
    return null;
  }

  /// Formats total seconds into MM:SS format (e.g. 300 -> "5:00").
  /// Returns empty string if seconds is null.
  static String formatPace(int? seconds) {
    if (seconds == null) return '';
    final mins = seconds ~/ 60;
    final secs = seconds % 60;
    return '$mins:${secs.toString().padLeft(2, '0')}';
  }

  /// Checks if parsed pace seconds is within 2:30–12:00 /km (150–720 s).
  static bool isValidPaceSeconds(int seconds) {
    return seconds >= minPaceSeconds && seconds <= maxPaceSeconds;
  }

  /// Validates a pace input string. Returns error message or null if valid/empty.
  static String? validatePaceString(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return null;
    final parsed = parsePace(trimmed);
    if (parsed == null) {
      return 'Enter pace between 2:30–12:00 /km (e.g. 5:00)';
    }
    if (!isValidPaceSeconds(parsed)) {
      return 'Enter pace between 2:30–12:00 /km';
    }
    return null;
  }
}

class HeartRateCard extends StatelessWidget {
  final TextEditingController restingHrController;
  final TextEditingController maxHrController;
  final TextEditingController? thresholdPaceController;
  final String? restingHrError;
  final String? maxHrError;
  final String? thresholdPaceError;
  final int? storedAge;
  final Widget saveButton;
  final String maxHrHint;
  final String? thresholdPaceHint;

  const HeartRateCard({
    super.key,
    required this.restingHrController,
    required this.maxHrController,
    this.thresholdPaceController,
    this.restingHrError,
    this.maxHrError,
    this.thresholdPaceError,
    this.storedAge,
    required this.saveButton,
    required this.maxHrHint,
    this.thresholdPaceHint,
  });

  static int? parsePace(String text) => ThresholdPaceUtils.parsePace(text);
  static String formatPace(int? seconds) =>
      ThresholdPaceUtils.formatPace(seconds);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _CardHeader(),
            const SizedBox(height: 16),
            _buildRestingField(),
            const SizedBox(height: 16),
            _buildMaxField(),
            if (thresholdPaceController != null) ...[
              const SizedBox(height: 16),
              _buildThresholdPaceField(),
            ],
            if (storedAge != null) ...[
              const SizedBox(height: 12),
              _AgeInfo(age: storedAge!),
            ],
            const SizedBox(height: 20),
            saveButton,
          ],
        ),
      ),
    );
  }

  Widget _buildRestingField() {
    return _buildTextField(
      controller: restingHrController,
      label: 'Resting Heart Rate (bpm)',
      hint: 'blank = auto (60)',
      prefixIcon: Icons.favorite_border,
      errorText: restingHrError,
    );
  }

  Widget _buildMaxField() {
    return _buildTextField(
      controller: maxHrController,
      label: 'Max Heart Rate (bpm)',
      hint: maxHrHint,
      prefixIcon: Icons.bolt,
      errorText: maxHrError,
    );
  }

  Widget _buildThresholdPaceField() {
    return _buildTextField(
      key: const ValueKey('threshold_pace_input'),
      controller: thresholdPaceController!,
      label: 'Threshold Pace (min/km)',
      hint: thresholdPaceHint ?? 'blank = auto (e.g. 5:00)',
      prefixIcon: Icons.speed_rounded,
      errorText: thresholdPaceError,
      keyboardType: TextInputType.datetime,
    );
  }

  Widget _buildTextField({
    Key? key,
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData prefixIcon,
    String? errorText,
    TextInputType keyboardType = TextInputType.number,
  }) {
    return TextField(
      key: key,
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        errorText: errorText,
        prefixIcon: Icon(prefixIcon, color: AppColors.gray500),
        border: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(8)),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(8)),
          borderSide: BorderSide(color: AppColors.brandOrange, width: 2),
        ),
        isDense: true,
      ),
      keyboardType: keyboardType,
    );
  }
}

class _CardHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.favorite, color: AppColors.brandOrange),
        const SizedBox(width: 8),
        Text(
          'Heart Rate Settings',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}

class _AgeInfo extends StatelessWidget {
  final int age;

  const _AgeInfo({required this.age});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.info_outline, size: 16, color: AppColors.gray500),
        const SizedBox(width: 4),
        const Text(
          'Age (from Strava): ',
          style: TextStyle(color: AppColors.gray700),
        ),
        Text(
          '$age yrs',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: AppColors.gray900,
          ),
        ),
      ],
    );
  }
}

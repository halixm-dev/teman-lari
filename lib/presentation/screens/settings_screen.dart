import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/responsive.dart';
import '../providers/preferences_provider.dart';
import '../theme/app_colors.dart';
import '../widgets/settings/about_card.dart';
import '../widgets/settings/heart_rate_card.dart';
import '../widgets/settings/save_button.dart';
import '../widgets/settings/strava_integration_card.dart';
import '../widgets/settings/zones_preview_card.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _restingHrController = TextEditingController();
  final _maxHrController = TextEditingController();
  final _thresholdPaceController = TextEditingController();
  String? _restingHrError;
  String? _maxHrError;
  String? _thresholdPaceError;
  int? _storedAge;

  int? _storedRestingHr;
  int? _storedMaxHr;
  int? _storedThresholdPace;
  bool _isSaving = false;
  bool _showSuccess = false;

  @override
  void initState() {
    super.initState();
    _load();
    _restingHrController.addListener(_onFieldChanged);
    _maxHrController.addListener(_onFieldChanged);
    _thresholdPaceController.addListener(_onFieldChanged);
  }

  @override
  void dispose() {
    _restingHrController.removeListener(_onFieldChanged);
    _maxHrController.removeListener(_onFieldChanged);
    _thresholdPaceController.removeListener(_onFieldChanged);
    _restingHrController.dispose();
    _maxHrController.dispose();
    _thresholdPaceController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final prefs = await ref.read(hrPreferencesProvider.future);
    _restingHrController.removeListener(_onFieldChanged);
    _maxHrController.removeListener(_onFieldChanged);
    _thresholdPaceController.removeListener(_onFieldChanged);

    _restingHrController.text = prefs.restingHr.toString();
    _storedRestingHr = prefs.restingHr;

    final maxStr = prefs.maxHr?.toString() ?? '';
    _maxHrController.text = maxStr;
    _storedMaxHr = prefs.maxHr;

    _thresholdPaceController.text = ThresholdPaceUtils.formatPace(
      prefs.thresholdPaceSeconds,
    );
    _storedThresholdPace = prefs.thresholdPaceSeconds;

    _storedAge = prefs.age;

    _restingHrController.addListener(_onFieldChanged);
    _maxHrController.addListener(_onFieldChanged);
    _thresholdPaceController.addListener(_onFieldChanged);

    if (mounted) setState(() {});
  }

  void _onFieldChanged() {
    final restingText = _restingHrController.text.trim();
    final maxText = _maxHrController.text.trim();
    final paceText = _thresholdPaceController.text.trim();

    String? restingError;
    if (restingText.isNotEmpty) {
      final val = int.tryParse(restingText);
      if (val == null || val < 30 || val > 120) {
        restingError = 'Enter a value between 30–120';
      }
    }

    String? maxError;
    if (maxText.isNotEmpty) {
      final val = int.tryParse(maxText);
      if (val == null || val < 100 || val > 250) {
        maxError = 'Enter a value between 100–250';
      }
    }

    // Cross-validation: Resting HR must be less than Max HR - 20
    if (restingError == null && maxError == null) {
      final maxHr = getEffectiveMaxHr();
      final restingHr = getEffectiveRestingHr(maxHr);
      if (restingHr > maxHr - 20) {
        restingError = 'Resting HR must be at least 20 bpm below Max HR';
      }
    }

    String? paceError;
    if (paceText.isNotEmpty) {
      final parsed = ThresholdPaceUtils.parsePace(paceText);
      if (parsed == null) {
        paceError = 'Enter pace between 2:30–12:00 /km (e.g. 5:00)';
      } else if (!ThresholdPaceUtils.isValidPaceSeconds(parsed)) {
        paceError = 'Enter pace between 2:30–12:00 /km';
      }
    }

    setState(() {
      _restingHrError = restingError;
      _maxHrError = maxError;
      _thresholdPaceError = paceError;
    });
  }

  int getEffectiveMaxHr() {
    final text = _maxHrController.text.trim();
    final val = int.tryParse(text);
    if (val != null && val >= 100 && val <= 250) {
      return val;
    }
    final age = _storedAge;
    if (age != null) {
      return 220 - age;
    }
    return 190;
  }

  int getEffectiveRestingHr(int maxHr) {
    final text = _restingHrController.text.trim();
    final val = int.tryParse(text);
    if (val != null && val >= 30 && val <= 120) {
      return val.clamp(30, maxHr - 20);
    }
    return 60;
  }

  bool _hasChanges() {
    final restingText = _restingHrController.text.trim();
    final maxText = _maxHrController.text.trim();
    final paceText = _thresholdPaceController.text.trim();

    final currentResting = int.tryParse(restingText);
    final currentMax = int.tryParse(maxText);
    final currentPace = ThresholdPaceUtils.parsePace(paceText);

    final effectiveStoredResting = _storedRestingHr ?? 60;
    final effectiveCurrentResting = currentResting ?? 60;

    final changedResting = effectiveCurrentResting != effectiveStoredResting;
    final changedMax = currentMax != _storedMaxHr;
    final changedPace = currentPace != _storedThresholdPace;

    return changedResting || changedMax || changedPace;
  }

  Future<void> _saveChanges() async {
    if (_restingHrError != null ||
        _maxHrError != null ||
        _thresholdPaceError != null) {
      return;
    }

    setState(() {
      _isSaving = true;
      _showSuccess = false;
    });

    final restingText = _restingHrController.text.trim();
    final maxText = _maxHrController.text.trim();
    final paceText = _thresholdPaceController.text.trim();

    try {
      final preferencesNotifier = ref.read(hrPreferencesProvider.notifier);

      if (restingText.isEmpty) {
        await preferencesNotifier.clearRestingHr();
      } else {
        final parsed = int.tryParse(restingText);
        if (parsed != null) {
          await preferencesNotifier.saveRestingHr(parsed);
        }
      }

      if (maxText.isEmpty) {
        await preferencesNotifier.clearMaxHr();
      } else {
        final parsed = int.tryParse(maxText);
        if (parsed != null) {
          await preferencesNotifier.saveMaxHr(parsed);
        }
      }

      if (paceText.isEmpty) {
        await preferencesNotifier.clearThresholdPace();
      } else {
        final parsed = ThresholdPaceUtils.parsePace(paceText);
        if (parsed != null && ThresholdPaceUtils.isValidPaceSeconds(parsed)) {
          await preferencesNotifier.saveThresholdPace(parsed);
        }
      }

      // Reload stored values to reset "Save Changes" button state
      final prefs = await ref.read(hrPreferencesProvider.future);
      _storedRestingHr = prefs.restingHr;
      _storedMaxHr = prefs.maxHr;
      _storedThresholdPace = prefs.thresholdPaceSeconds;

      HapticFeedback.mediumImpact();
      setState(() {
        _isSaving = false;
        _showSuccess = true;
      });

      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          setState(() => _showSuccess = false);
        }
      });
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to save settings: $e')));
      }
    }
  }

  List<Map<String, dynamic>> _calculatePreviewZones() {
    final maxHr = getEffectiveMaxHr();
    final restingHr = getEffectiveRestingHr(maxHr);
    final hrr = maxHr - restingHr;
    const boundaries = [0.60, 0.70, 0.80, 0.90];
    const labels = [
      'Zone 1 - Recovery',
      'Zone 2 - Aerobic Base',
      'Zone 3 - Tempo',
      'Zone 4 - Threshold',
      'Zone 5 - VO2max',
    ];
    const colors = [
      AppColors.info,
      AppColors.success,
      AppColors.warning,
      AppColors.brandOrange,
      AppColors.danger,
    ];

    return List.generate(5, (i) {
      final minBpm = i == 0
          ? restingHr
          : (restingHr + hrr * boundaries[i - 1]).round();
      final maxBpm = i == 4 ? maxHr : (restingHr + hrr * boundaries[i]).round();
      return {
        'label': labels[i],
        'min': minBpm,
        'max': maxBpm,
        'color': colors[i],
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ConstrainedContent(
        child: ListView(
          padding: const EdgeInsets.only(top: 8, bottom: 24),
          children: [
            HeartRateCard(
              restingHrController: _restingHrController,
              maxHrController: _maxHrController,
              thresholdPaceController: _thresholdPaceController,
              restingHrError: _restingHrError,
              maxHrError: _maxHrError,
              thresholdPaceError: _thresholdPaceError,
              storedAge: _storedAge,
              saveButton: _buildSaveButton(),
              maxHrHint: _buildMaxHrHint(),
            ),
            ZonesPreviewCard(zones: _calculatePreviewZones()),
            const _SectionHeader(
              title: 'Integrations',
              icon: Icons.sync_alt_rounded,
            ),
            const StravaIntegrationCard(),
            const _SectionHeader(
              title: 'About',
              icon: Icons.info_outline_rounded,
            ),
            const AboutCard(),
          ],
        ),
      ),
    );
  }

  String _buildMaxHrHint() {
    final age = _storedAge;
    if (age != null) {
      final formula = 220 - age;
      return 'blank = auto (220-age: $formula)';
    }
    return 'blank = auto (190)';
  }

  Widget _buildSaveButton() {
    final hasChanges = _hasChanges();
    final hasError =
        _restingHrError != null ||
        _maxHrError != null ||
        _thresholdPaceError != null;
    final canSave = hasChanges && !hasError && !_isSaving;

    return SettingsSaveButton(
      canSave: canSave,
      isSaving: _isSaving,
      showSuccess: _showSuccess,
      onSave: _saveChanges,
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData? icon;

  const _SectionHeader({required this.title, this.icon});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              size: 18,
              color: isDark ? AppColors.textSecondaryDark : AppColors.gray500,
            ),
            const SizedBox(width: 8),
          ],
          Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: isDark ? AppColors.textSecondaryDark : AppColors.gray700,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

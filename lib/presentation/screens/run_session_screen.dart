import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart' hide ActivityType;
import 'package:go_router/go_router.dart';

import '../../core/services/voice_coach_service.dart';
import '../../core/services/sound_effects_service.dart';

import '../theme/app_colors.dart';
import '../../core/services/gps_service.dart';
import '../../core/services/pedometer_service.dart';
import '../../domain/entities/activity.dart';
import '../../domain/entities/training_plan.dart';
import '../providers/activities_provider.dart';
import '../widgets/run_session/run_controls.dart';
import '../widgets/run_session/run_pacer_display.dart';
import '../widgets/run_session/run_secondary_metrics.dart';
import '../widgets/run_session/run_session_state.dart';
import '../widgets/run_session/run_timer_display.dart';

enum PaceSource { gps, pedometer, none }

class RunSessionScreen extends ConsumerStatefulWidget {
  final TrainingDay day;

  const RunSessionScreen({super.key, required this.day});

  @override
  ConsumerState<RunSessionScreen> createState() => _RunSessionScreenState();
}

class _RunSessionScreenState extends ConsumerState<RunSessionScreen> {
  late RunSessionState _state;
  Timer? _timer;

  final _gpsService = GpsService();
  final _pedometerService = PedometerService();
  StreamSubscription<Position>? _gpsSubscription;
  StreamSubscription<int>? _pedometerSubscription;

  // GPS state
  double _smoothedSpeed = 0.0;
  Position? _lastPosition;
  int _gpsPaceSeconds = 0;
  DateTime? _lastGpsUpdate;
  bool _gpsPermissionGranted = false;
  bool _gpsHasFix = false;

  // Pedometer state
  int _lastStepCount = 0;
  final List<int> _stepHistory = [];

  PaceSource _paceSource = PaceSource.none;

  final _soundFx = SoundEffectsService();
  WorkoutPhase? _lastPhase;
  bool _midpointAnnounced = false;
  bool _isSaved = false;
  bool _isSaving = false;
  bool _saveFailed = false;
  Activity? _pendingActivity;

  static const double _smoothingAlpha = 0.25;
  static const Duration _gpsTimeout = Duration(seconds: 10);
  static const double _minGpsSpeed = 0.5;
  static const int _stepWindowSize = 10;

  @override
  void initState() {
    super.initState();
    final plan = widget.day;
    final segments = RunSessionState.computeSegments(plan);
    _state = RunSessionState(
      plan: plan,
      currentPaceSecondsPerKm: null,
      segments: segments,
    );
    _initSensors();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _gpsSubscription?.cancel();
    _pedometerSubscription?.cancel();
    _soundFx.dispose();
    super.dispose();
  }

  Future<void> _initSensors() async {
    _gpsPermissionGranted = await _gpsService.requestPermission();
    if (!mounted) return;

    if (_gpsPermissionGranted) {
      _gpsSubscription = _gpsService.trackPosition().listen(
        _onGpsPosition,
        onError: (_) {
          if (mounted) setState(() => _gpsHasFix = false);
        },
      );
    }

    _pedometerSubscription = _pedometerService.trackSteps().listen(
      _onPedometerStep,
      onError: (_) {},
    );
  }

  void _onGpsPosition(Position pos) {
    _gpsHasFix = true;
    _lastGpsUpdate = DateTime.now();

    if (!_state.isRunning) {
      _paceSource = PaceSource.gps;
      setState(() {});
    }

    final rawSpeed = pos.speed;

    // Ignore highly inaccurate points for speed calculation
    if (pos.accuracy > 30) return;

    if (rawSpeed > 0) {
      if (_smoothedSpeed == 0) {
        _smoothedSpeed = rawSpeed;
      } else {
        _smoothedSpeed =
            _smoothingAlpha * rawSpeed + (1 - _smoothingAlpha) * _smoothedSpeed;
      }
    } else {
      final last = _lastPosition;
      if (last != null) {
        final dist = Geolocator.distanceBetween(
          last.latitude,
          last.longitude,
          pos.latitude,
          pos.longitude,
        );
        final timeDelta =
            pos.timestamp.difference(last.timestamp).inMilliseconds / 1000.0;

        if (dist < 200 && timeDelta > 0) {
          final calcSpeed = dist / timeDelta;
          if (_smoothedSpeed == 0) {
            _smoothedSpeed = calcSpeed;
          } else {
            _smoothedSpeed =
                _smoothingAlpha * calcSpeed +
                (1 - _smoothingAlpha) * _smoothedSpeed;
          }
        }
      }
    }
    if (_smoothedSpeed > _minGpsSpeed) {
      _gpsPaceSeconds = (1000 / _smoothedSpeed).round();
    }

    final lastPos = _lastPosition;
    if (pos.accuracy < 50 && lastPos != null) {
      final last = lastPos;
      final dist = Geolocator.distanceBetween(
        last.latitude,
        last.longitude,
        pos.latitude,
        pos.longitude,
      );
      if (dist > 0 && dist < 200) {
        setState(() {
          _state = RunSessionState(
            plan: _state.plan,
            phase: _state.phase,
            elapsedSeconds: _state.elapsedSeconds,
            currentPaceSecondsPerKm: _state.currentPaceSecondsPerKm,
            distanceKm: _state.distanceKm + dist / 1000.0,
            isRunning: _state.isRunning,
            isLocked: _state.isLocked,
            isAudioCoachOn: _state.isAudioCoachOn,
            segments: _state.segments,
          );
        });
        _pedometerService.calibrateStrideLength(dist);
      }
    }

    _lastPosition = pos;
  }

  void _onPedometerStep(int steps) {
    _pedometerService.updateSteps(steps);
  }

  void _start() {
    if (_timer?.isActive ?? false) return;

    _lastStepCount = _pedometerService.stepsSinceStart;
    _stepHistory.clear();

    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());

    if (_state.isAudioCoachOn) {
      ref.read(voiceCoachProvider).announcePhaseChange(_state.phase);
    }
    _lastPhase = _state.phase;

    setState(() {
      _state = RunSessionState(
        plan: _state.plan,
        phase: _state.phase,
        elapsedSeconds: _state.elapsedSeconds,
        currentPaceSecondsPerKm: _state.currentPaceSecondsPerKm,
        distanceKm: _state.distanceKm,
        isRunning: true,
        isLocked: _state.isLocked,
        isAudioCoachOn: _state.isAudioCoachOn,
        segments: _state.segments,
      );
    });
  }

  void _pause() {
    _timer?.cancel();
    if (_state.isAudioCoachOn) _soundFx.playPause();
    setState(() {
      _state = RunSessionState(
        plan: _state.plan,
        phase: _state.phase,
        elapsedSeconds: _state.elapsedSeconds,
        currentPaceSecondsPerKm: _state.currentPaceSecondsPerKm,
        distanceKm: _state.distanceKm,
        isRunning: false,
        isLocked: _state.isLocked,
        isAudioCoachOn: _state.isAudioCoachOn,
        segments: _state.segments,
      );
    });
  }

  void _toggleRunning() {
    if (_state.isRunning) {
      _pause();
    } else {
      _start();
    }
  }

  void _tick() {
    final newElapsed = _state.elapsedSeconds + 1;

    final currentSteps = _pedometerService.stepsSinceStart;
    final stepsThisSecond = (currentSteps - _lastStepCount).clamp(0, 5);
    _stepHistory.add(stepsThisSecond);
    if (_stepHistory.length > 30) {
      _stepHistory.removeAt(0);
    }
    _lastStepCount = currentSteps;

    final lastGps = _lastGpsUpdate;
    final gpsTimedOut =
        lastGps == null || DateTime.now().difference(lastGps) > _gpsTimeout;
    final gpsConnected = _gpsPermissionGranted && _gpsHasFix && !gpsTimedOut;
    final gpsSpeedUsable = gpsConnected && _smoothedSpeed > _minGpsSpeed;

    int? newPace;
    if (gpsSpeedUsable) {
      newPace = _gpsPaceSeconds.clamp(120, 1800);
      _paceSource = PaceSource.gps;
    } else {
      final windowSize = _stepHistory.length > _stepWindowSize
          ? _stepWindowSize
          : _stepHistory.length;
      if (windowSize >= 5) {
        final windowSteps = _stepHistory
            .sublist(_stepHistory.length - windowSize)
            .fold(0, (a, b) => a + b);
        if (windowSteps > 3) {
          final distMeters = windowSteps * _pedometerService.strideLength;
          final paceSecPerKm = (windowSize / (distMeters / 1000)).round();
          if (paceSecPerKm >= 120 && paceSecPerKm <= 1800) {
            newPace = paceSecPerKm;
            _paceSource = PaceSource.pedometer;
          } else {
            newPace = null;
            _paceSource = gpsConnected ? PaceSource.gps : PaceSource.none;
          }
        } else {
          newPace = null;
          _paceSource = gpsConnected ? PaceSource.gps : PaceSource.none;
        }
      } else {
        newPace = null;
        _paceSource = gpsConnected ? PaceSource.gps : PaceSource.none;
      }
    }

    var newPhase = _state.phase;
    final total = _state.totalSeconds;
    if (total > 0 && newElapsed >= total) {
      _timer?.cancel();
      newPhase = WorkoutPhase.finished;
    } else {
      int elapsed = 0;
      for (final seg in _state.segments) {
        if (newElapsed < elapsed + seg.durationSeconds) {
          newPhase = seg.phase;
          break;
        }
        elapsed += seg.durationSeconds;
      }
    }

    if (newPhase != _lastPhase) {
      if (newPhase != WorkoutPhase.finished) {
        if (_state.isAudioCoachOn) {
          ref.read(voiceCoachProvider).announcePhaseChange(newPhase);
        }
      }
    }

    if (!_midpointAnnounced &&
        total > 0 &&
        newElapsed >= total ~/ 2 &&
        newPhase != WorkoutPhase.finished) {
      if (_state.isAudioCoachOn) {
        ref.read(voiceCoachProvider).announceMidpoint();
      }
      _midpointAnnounced = true;
    }

    _lastPhase = newPhase;

    setState(() {
      _state = RunSessionState(
        plan: _state.plan,
        phase: newPhase,
        elapsedSeconds: newElapsed,
        currentPaceSecondsPerKm: newPace,
        distanceKm: _state.distanceKm,
        isRunning: newPhase != WorkoutPhase.finished,
        isLocked: _state.isLocked,
        isAudioCoachOn: _state.isAudioCoachOn,
        segments: _state.segments,
      );
    });

    if (newPhase == WorkoutPhase.finished) {
      _saveWorkout();
    }
  }

  void _toggleLock() {
    setState(() {
      _state = RunSessionState(
        plan: _state.plan,
        phase: _state.phase,
        elapsedSeconds: _state.elapsedSeconds,
        currentPaceSecondsPerKm: _state.currentPaceSecondsPerKm,
        distanceKm: _state.distanceKm,
        isRunning: _state.isRunning,
        isLocked: !_state.isLocked,
        isAudioCoachOn: _state.isAudioCoachOn,
        segments: _state.segments,
      );
    });
  }

  void _toggleAudioCoach() {
    setState(() {
      _state = RunSessionState(
        plan: _state.plan,
        phase: _state.phase,
        elapsedSeconds: _state.elapsedSeconds,
        currentPaceSecondsPerKm: _state.currentPaceSecondsPerKm,
        distanceKm: _state.distanceKm,
        isRunning: _state.isRunning,
        isLocked: _state.isLocked,
        isAudioCoachOn: !_state.isAudioCoachOn,
        segments: _state.segments,
      );
    });
  }

  Future<void> _endWorkout() async {
    _timer?.cancel();
    setState(() {
      _state = RunSessionState(
        plan: _state.plan,
        phase: WorkoutPhase.finished,
        elapsedSeconds: _state.elapsedSeconds,
        currentPaceSecondsPerKm: _state.currentPaceSecondsPerKm,
        distanceKm: _state.distanceKm,
        isRunning: false,
        isLocked: _state.isLocked,
        isAudioCoachOn: _state.isAudioCoachOn,
        segments: _state.segments,
      );
    });
    await _saveWorkout();
  }

  Future<void> _saveWorkout() async {
    if (_isSaved || _isSaving) return;
    final activity = _pendingActivity ??= _recordWorkout();
    setState(() {
      _isSaving = true;
      _saveFailed = false;
    });
    try {
      await ref.read(activitiesProvider.notifier).saveCompletedRun(activity);
    } catch (_) {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _saveFailed = true;
        });
      }
      return;
    }
    if (!mounted) return;
    setState(() {
      _isSaving = false;
      _isSaved = true;
    });
    HapticFeedback.heavyImpact();
    if (_state.isAudioCoachOn) {
      ref.read(voiceCoachProvider).announceWorkoutComplete();
    }
  }

  Activity _recordWorkout() {
    final paceSec = _state.distanceKm > 0
        ? (_state.elapsedSeconds / _state.distanceKm).round()
        : (_state.currentPaceSecondsPerKm ?? 300);

    final double? avgCadence = (_lastStepCount > 0 && _state.elapsedSeconds > 0)
        ? (_lastStepCount / (_state.elapsedSeconds / 60.0))
        : null;

    final label = typeLabel(_state.plan.type);
    final name = label.endsWith('Run') ? label : '$label Run';

    return Activity(
      id: -DateTime.now().millisecondsSinceEpoch,
      name: name,
      date: DateTime.now(),
      type: ActivityType.run,
      distanceKm: _state.distanceKm,
      movingTime: Duration(seconds: _state.elapsedSeconds),
      pace: Duration(seconds: paceSec),
      elevationGainM: 0.0,
      trainingLoad: TrainingLoad.moderate,
      avgCadence: avgCadence,
      isLocal: true,
    );
  }

  void _exitToDashboard() {
    if (!_isSaved) return;
    try {
      if (GoRouter.maybeOf(context) != null) {
        if (context.canPop()) {
          context.pop();
        } else {
          context.go('/dashboard');
        }
      } else if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    } catch (_) {
      // Ignore navigation errors in headless test runners
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _isSaved,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          if (_state.phase == WorkoutPhase.finished) {
            _exitToDashboard();
          } else {
            _showExitSheet(context);
          }
        }
      },
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: SafeArea(
          child: Stack(
            children: [
              AbsorbPointer(
                absorbing: _state.isLocked,
                child: OrientationBuilder(
                  builder: (context, orientation) {
                    final isLandscape = orientation == Orientation.landscape;

                    if (isLandscape) {
                      return _buildLandscapeLayout(context);
                    }
                    return _buildPortraitLayout(context);
                  },
                ),
              ),
              if (_state.isLocked) ...[
                Positioned.fill(
                  child: Container(color: Colors.black.withValues(alpha: 0.3)),
                ),
                Positioned(
                  top: 80,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Semantics(
                      button: true,
                      label: 'Unlock screen',
                      child: GestureDetector(
                        onTap: _toggleLock,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primary,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.lock,
                                color: Theme.of(context).colorScheme.onPrimary,
                                size: 18,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Tap to Unlock',
                                style: TextStyle(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onPrimary,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLandscapeLayout(BuildContext context) {
    return Row(
      children: [
        Expanded(
          flex: 3,
          child: Column(
            children: [
              _Header(
                planName: typeLabel(_state.plan.type),
                phase: _state.phase,
                isFinished: _state.phase == WorkoutPhase.finished,
                onExit: () {
                  if (_state.phase == WorkoutPhase.finished) {
                    _exitToDashboard();
                  } else {
                    _showExitSheet(context);
                  }
                },
              ),
              if (_state.phase == WorkoutPhase.finished) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Text(
                    'Workout Complete!',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: _phaseColorLight(_state.phase),
                    ),
                  ),
                ),
                _buildSaveActions(),
              ] else
                Expanded(
                  child: RunTimerDisplay(
                    phaseArcs: _buildPhaseArcs(),
                    timeText: _formatTime(_state.elapsedSeconds),
                    phaseLabel: _currentPhaseLabel(),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          flex: 2,
          child: Column(
            children: [
              if (_state.phase != WorkoutPhase.finished) ...[
                RunPacerDisplay(
                  currentPaceSecondsPerKm: _state.currentPaceSecondsPerKm,
                  fastestTargetSeconds: _state.fastestTarget.inSeconds,
                  slowestTargetSeconds: _state.slowestTarget.inSeconds,
                  isWorkPhase: _state.phase == WorkoutPhase.work,
                ),
                _PaceSourceIndicator(source: _paceSource),
                RunSecondaryMetrics(
                  elapsedSeconds: _state.elapsedSeconds,
                  remainingSeconds: _state.remainingSeconds,
                ),
              ],
              const Spacer(),
              RunControls(
                isRunning: _state.isRunning,
                isLocked: _state.isLocked,
                isAudioCoachOn: _state.isAudioCoachOn,
                isFinished: _state.phase == WorkoutPhase.finished,
                onToggleRunning: _toggleRunning,
                onToggleLock: _toggleLock,
                onToggleAudioCoach: _toggleAudioCoach,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPortraitLayout(BuildContext context) {
    return Column(
      children: [
        _Header(
          planName: typeLabel(_state.plan.type),
          phase: _state.phase,
          isFinished: _state.phase == WorkoutPhase.finished,
          onExit: () {
            if (_state.phase == WorkoutPhase.finished) {
              _exitToDashboard();
            } else {
              _showExitSheet(context);
            }
          },
        ),
        Expanded(
          child: RunTimerDisplay(
            phaseArcs: _buildPhaseArcs(),
            timeText: _formatTime(_state.elapsedSeconds),
            phaseLabel: _currentPhaseLabel(),
          ),
        ),
        if (_state.phase == WorkoutPhase.finished) ...[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text(
              'Workout Complete!',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: _phaseColorLight(_state.phase),
              ),
            ),
          ),
          _buildSaveActions(),
        ] else ...[
          RunPacerDisplay(
            currentPaceSecondsPerKm: _state.currentPaceSecondsPerKm,
            fastestTargetSeconds: _state.fastestTarget.inSeconds,
            slowestTargetSeconds: _state.slowestTarget.inSeconds,
            isWorkPhase: _state.phase == WorkoutPhase.work,
          ),
          _PaceSourceIndicator(source: _paceSource),
          RunSecondaryMetrics(
            elapsedSeconds: _state.elapsedSeconds,
            remainingSeconds: _state.remainingSeconds,
          ),
        ],
        RunControls(
          isRunning: _state.isRunning,
          isLocked: _state.isLocked,
          isAudioCoachOn: _state.isAudioCoachOn,
          isFinished: _state.phase == WorkoutPhase.finished,
          onToggleRunning: _toggleRunning,
          onToggleLock: _toggleLock,
          onToggleAudioCoach: _toggleAudioCoach,
        ),
      ],
    );
  }

  List<PhaseArc> _buildPhaseArcs() {
    final segments = _state.segments;
    if (segments.isEmpty) return [];
    final total = _state.totalSeconds;
    if (total <= 0) return [];

    int elapsed = 0;
    final arcs = <PhaseArc>[];
    for (final seg in segments) {
      final sweep = seg.durationSeconds / total;
      double fill = 0.0;
      if (_state.elapsedSeconds >= elapsed + seg.durationSeconds) {
        fill = 1.0;
      } else if (_state.elapsedSeconds > elapsed) {
        fill = (_state.elapsedSeconds - elapsed) / seg.durationSeconds;
      }
      arcs.add(
        PhaseArc(
          sweepFraction: sweep,
          fillFraction: fill,
          color: phaseColor(seg.type),
        ),
      );
      elapsed += seg.durationSeconds;
    }
    return arcs;
  }

  String? _currentPhaseLabel() {
    if (_state.phase == WorkoutPhase.finished) return null;
    final idx = _state.currentSegmentIndex;
    if (idx < _state.segments.length) {
      return phaseLabelFromType(_state.segments[idx].type);
    }
    return null;
  }

  Widget _buildSaveActions() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Semantics(
            liveRegion: true,
            child: Text(
              _isSaved
                  ? 'Run saved'
                  : _saveFailed
                  ? 'Could not save your run. Tap Retry Save.'
                  : 'Saving your run…',
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 8),
          _buildSaveButton(),
        ],
      ),
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: 240,
      child: FilledButton.icon(
        key: Key(_saveFailed ? 'retrySaveButton' : 'returnToDashboardButton'),
        style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
        onPressed: _isSaving
            ? null
            : _saveFailed
            ? _saveWorkout
            : _isSaved
            ? _exitToDashboard
            : null,
        icon: _isSaving
            ? null
            : Icon(_saveFailed ? Icons.refresh : Icons.arrow_back),
        label: _isSaving
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  semanticsLabel: 'Saving your run',
                ),
              )
            : Text(_saveFailed ? 'Retry Save' : 'Return to Dashboard'),
      ),
    );
  }

  void _showExitSheet(BuildContext context) {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? AppColors.surfaceSecondaryDark
          : AppColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) {
        final theme = Theme.of(context);
        final isDark = theme.brightness == Brightness.dark;
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              left: 24,
              right: 24,
              top: 12,
              bottom: MediaQuery.of(context).padding.bottom + 20,
            ),
            child:
                Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Center(
                          child: Container(
                            width: 36,
                            height: 4,
                            decoration: BoxDecoration(
                              color: isDark
                                  ? AppColors.surfaceTertiaryDark
                                  : AppColors.gray300,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.danger.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.warning_amber_rounded,
                            color: AppColors.danger,
                            size: 32,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'End Workout Early?',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Are you sure you want to stop your current workout session? Your stats and run history will be recorded.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: isDark
                                ? AppColors.textSecondaryDark
                                : AppColors.gray700,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 28),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () {
                                  HapticFeedback.lightImpact();
                                  Navigator.of(sheetContext).pop();
                                },
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: isDark
                                      ? AppColors.textPrimaryDark
                                      : AppColors.gray900,
                                  side: BorderSide(
                                    color: isDark
                                        ? AppColors.surfaceTertiaryDark
                                        : AppColors.gray300,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: const Text(
                                  'Resume',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: FilledButton(
                                onPressed: () async {
                                  Navigator.of(sheetContext).pop();
                                  await _endWorkout();
                                  if (mounted) {
                                    _exitToDashboard();
                                  }
                                },
                                style: FilledButton.styleFrom(
                                  backgroundColor: AppColors.danger,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: const Text(
                                  'End Workout',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    )
                    .animate()
                    .fade(duration: 250.ms)
                    .slideY(begin: 0.08, curve: Curves.easeOutCubic),
          ),
        );
      },
    );
  }

  String _formatTime(int totalSeconds) {
    final m = totalSeconds ~/ 60;
    final s = totalSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
}

class _PaceSourceIndicator extends StatelessWidget {
  final PaceSource source;

  const _PaceSourceIndicator({required this.source});

  @override
  Widget build(BuildContext context) {
    final (icon, label, color) = switch (source) {
      PaceSource.gps => (Icons.satellite_alt, 'GPS', AppColors.success),
      PaceSource.pedometer => (
        Icons.directions_walk,
        'Steps',
        AppColors.warning,
      ),
      PaceSource.none => (Icons.sensors_off, 'No Signal', AppColors.danger),
    };

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final String planName;
  final WorkoutPhase phase;
  final bool isFinished;
  final VoidCallback onExit;

  const _Header({
    required this.planName,
    required this.phase,
    required this.isFinished,
    required this.onExit,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  planName,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  transitionBuilder: (child, animation) {
                    return SlideTransition(
                      position:
                          Tween<Offset>(
                            begin: const Offset(0, -0.5),
                            end: Offset.zero,
                          ).animate(
                            CurvedAnimation(
                              parent: animation,
                              curve: Curves.easeOutCubic,
                            ),
                          ),
                      child: FadeTransition(opacity: animation, child: child),
                    );
                  },
                  child: Row(
                    key: ValueKey(phase),
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: _phaseColor(phase).withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _phaseLabel(phase),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _phaseColorLight(phase),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onExit,
            icon: Icon(Icons.close, color: theme.colorScheme.onSurface),
            tooltip: isFinished ? 'Return to dashboard' : 'Exit workout',
            style: IconButton.styleFrom(
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
              minimumSize: const Size(44, 44),
            ),
          ),
        ],
      ),
    );
  }

  String _phaseLabel(WorkoutPhase phase) {
    return switch (phase) {
      WorkoutPhase.warmup => 'Warm Up',
      WorkoutPhase.work => 'Run',
      WorkoutPhase.recovery => 'Recovery Jog',
      WorkoutPhase.walk => 'Walk',
      WorkoutPhase.cooldown => 'Cool Down',
      WorkoutPhase.finished => 'Complete',
    };
  }
}

Color _phaseColor(WorkoutPhase phase) {
  return switch (phase) {
    WorkoutPhase.warmup => AppColors.success,
    WorkoutPhase.work => AppColors.brandOrange,
    WorkoutPhase.recovery => AppColors.warning,
    WorkoutPhase.walk => const Color(0xFF14B8A6),
    WorkoutPhase.cooldown => AppColors.info,
    WorkoutPhase.finished => AppColors.success,
  };
}

Color _phaseColorLight(WorkoutPhase phase) {
  return switch (phase) {
    WorkoutPhase.warmup => const Color(0xFF6EE7A0),
    WorkoutPhase.work => AppColors.brandOrangeLight,
    WorkoutPhase.recovery => const Color(0xFFFCD34D),
    WorkoutPhase.walk => const Color(0xFF5EEAD4),
    WorkoutPhase.cooldown => const Color(0xFF7CB3F8),
    WorkoutPhase.finished => const Color(0xFF6EE7A0),
  };
}

String typeLabel(WorkoutType type) {
  return switch (type) {
    WorkoutType.easy => 'Easy Run',
    WorkoutType.tempo => 'Tempo Run',
    WorkoutType.intervals => 'Interval Training',
    WorkoutType.longRun => 'Long Run',
    WorkoutType.rest => 'Rest',
    WorkoutType.crossTraining => 'Cross Training',
    WorkoutType.walk => 'Walk',
  };
}

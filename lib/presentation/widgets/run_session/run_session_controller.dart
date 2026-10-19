/// Measurements owned by one recording, including across pauses and retries.
class RunSessionController {
  DateTime? _startedAt;
  double? _lastAltitude;
  double? _elevationGainM;
  bool _isRunning = false;
  DateTime? _recordingSince;
  DateTime? _lastSampleAt;

  DateTime? get startedAt => _startedAt;
  double? get elevationGainM => _elevationGainM;

  void start(DateTime now) {
    _startedAt ??= now;
    _isRunning = true;
    _recordingSince = now;
  }

  void pause() {
    _isRunning = false;
    _lastAltitude = null;
  }

  void recordElevation({
    required double altitude,
    required double altitudeAccuracy,
    required double horizontalAccuracy,
    required DateTime timestamp,
  }) {
    if (!_isRunning) return;
    final recordingSince = _recordingSince;
    final lastSampleAt = _lastSampleAt;
    if ((recordingSince != null && timestamp.isBefore(recordingSince)) ||
        (lastSampleAt != null && !timestamp.isAfter(lastSampleAt))) {
      return;
    }
    _lastSampleAt = timestamp;
    // Zero altitude accuracy denotes an unavailable estimate on some devices.
    if (!altitude.isFinite ||
        !altitudeAccuracy.isFinite ||
        altitudeAccuracy <= 0 ||
        altitudeAccuracy > 20 ||
        !horizontalAccuracy.isFinite ||
        horizontalAccuracy < 0 ||
        horizontalAccuracy > 30) {
      _lastAltitude = null;
      return;
    }
    final last = _lastAltitude;
    if (last != null) {
      final climb = altitude - last;
      _elevationGainM = (_elevationGainM ?? 0) + (climb > 0 ? climb : 0);
    }
    _lastAltitude = altitude;
  }
}

import 'package:checks/checks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teman_lari/presentation/widgets/run_session/run_session_controller.dart';

void main() {
  test(
    'missing elevation stays unknown while a measured flat route is zero',
    () {
      final session = RunSessionController()..start(DateTime(2026, 10, 19));
      check(session.elevationGainM).isNull();
      recordAltitude(session, 0, second: 1, accuracy: 0);
      recordAltitude(session, 0, second: 2, accuracy: 0);
      check(session.elevationGainM).isNull();
      recordAltitude(session, 100, second: 3);
      check(session.elevationGainM).isNull();
      recordAltitude(session, 100, second: 4);
      check(session.elevationGainM).equals(0);
    },
  );

  test('delayed GPS samples cannot change the recorded climb', () {
    final session = RunSessionController()..start(DateTime(2026, 10, 19));
    recordAltitude(session, 100, second: 2);
    recordAltitude(session, 500, second: 1);
    recordAltitude(session, 800, second: 2);
    recordAltitude(session, 110, second: 3);

    check(session.elevationGainM).equals(10);
  });

  test('unreliable elevation cannot invent a climb across a gap', () {
    final session = RunSessionController()..start(DateTime(2026, 10, 19));
    recordAltitude(session, 100, second: 1);
    recordAltitude(session, 112, second: 2);
    recordAltitude(session, 900, second: 3, accuracy: 100);
    recordAltitude(session, 300, second: 4);
    recordAltitude(session, 305, second: 5);

    check(session.elevationGainM).equals(17);
  });

  test('pause excludes movement and resume keeps the original start', () {
    final started = DateTime(2026, 10, 19);
    final session = RunSessionController();
    recordAltitude(session, 50, second: 0);
    session.start(started);
    recordAltitude(session, 100, second: 1);
    recordAltitude(session, 110, second: 2);
    session.pause();
    recordAltitude(session, 200, second: 3);
    session.start(started.add(const Duration(seconds: 4)));
    recordAltitude(session, 300, second: 5);
    recordAltitude(session, 305, second: 6);

    check(session.startedAt).equals(started);
    check(session.elevationGainM).equals(15);
  });

  test('recording adds climbs and excludes descents', () {
    final session = RunSessionController()..start(DateTime(2026, 10, 19));
    recordAltitude(session, 100, second: 1);
    recordAltitude(session, 112, second: 2);
    recordAltitude(session, 108, second: 3);
    recordAltitude(session, 115, second: 4);

    check(session.elevationGainM).equals(19);
  });
}

void recordAltitude(
  RunSessionController session,
  double altitude, {
  required int second,
  double accuracy = 2,
}) {
  session.recordElevation(
    altitude: altitude,
    altitudeAccuracy: accuracy,
    horizontalAccuracy: 5,
    timestamp: DateTime(2026, 10, 19, 0, 0, second),
  );
}

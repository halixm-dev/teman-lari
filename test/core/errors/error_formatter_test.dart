import 'package:flutter_test/flutter_test.dart';
import 'package:teman_lari/core/errors/error_formatter.dart';
import 'package:teman_lari/core/errors/exceptions.dart';
import 'package:teman_lari/core/errors/failures.dart';

void main() {
  group('AppErrorFormatter Unit Tests', () {
    test('formats Strava Inactive Application error into clear human message', () {
      const rawJson =
          '{"message":"Forbidden","errors":[{"resource":"Application","field":"Status","code":"Inactive"}]}';

      final failure = const ServerFailure(rawJson, 403);
      expect(
        AppErrorFormatter.format(failure),
        'Strava application is inactive. Please check your Strava developer settings.',
      );

      final exception = StravaApiException(403, rawJson);
      expect(
        AppErrorFormatter.format(exception),
        'Strava application is inactive. Please check your Strava developer settings.',
      );

      expect(
        AppErrorFormatter.formatMessage(rawJson),
        'Strava application is inactive. Please check your Strava developer settings.',
      );
    });

    test('formats 429 rate limit correctly', () {
      final failure = const ServerFailure('Too many requests', 429);
      expect(
        AppErrorFormatter.format(failure),
        'Rate limit reached, try again in 15 minutes.',
      );
    });

    test('formats 401 unauthorized correctly', () {
      final failure = const ServerFailure('Invalid token', 401);
      expect(
        AppErrorFormatter.format(failure),
        'Authentication expired. Please reconnect your Strava account.',
      );
    });

    test('extracts custom error message from JSON envelope', () {
      const rawJson = '{"message":"Record not found","errors":[]}';
      expect(AppErrorFormatter.formatMessage(rawJson), 'Record not found');
    });

    test('cleans up Exception: prefix', () {
      expect(
        AppErrorFormatter.formatMessage(
          'Exception: SocketException: Failed host lookup',
        ),
        'SocketException: Failed host lookup',
      );
    });

    test('leaves regular error messages untouched', () {
      expect(
        AppErrorFormatter.formatMessage('Network connection timed out'),
        'Network connection timed out',
      );
    });
  });
}

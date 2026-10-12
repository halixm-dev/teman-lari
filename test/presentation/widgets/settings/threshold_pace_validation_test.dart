import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teman_lari/presentation/widgets/settings/heart_rate_card.dart';

void main() {
  group('Threshold Pace Parsing & Formatting (PACE_U01 & PACE_U02)', () {
    test('PACE_U01: parses valid MM:SS strings into total seconds', () {
      expect(ThresholdPaceUtils.parsePace('5:00'), equals(300));
      expect(ThresholdPaceUtils.parsePace('4:15'), equals(255));
      expect(ThresholdPaceUtils.parsePace('03:45'), equals(225));
      expect(ThresholdPaceUtils.parsePace('12:00'), equals(720));
      expect(ThresholdPaceUtils.parsePace('2:30'), equals(150));
      expect(ThresholdPaceUtils.parsePace('  5:00  '), equals(300));
    });

    test('PACE_U01: returns null for invalid or malformed pace strings', () {
      expect(ThresholdPaceUtils.parsePace(''), isNull);
      expect(ThresholdPaceUtils.parsePace('   '), isNull);
      expect(ThresholdPaceUtils.parsePace('5'), isNull);
      expect(ThresholdPaceUtils.parsePace('5:65'), isNull);
      expect(ThresholdPaceUtils.parsePace('-5:00'), isNull);
      expect(ThresholdPaceUtils.parsePace('5:-10'), isNull);
      expect(ThresholdPaceUtils.parsePace('abc'), isNull);
      expect(ThresholdPaceUtils.parsePace('5:00:00'), isNull);
      expect(ThresholdPaceUtils.parsePace(':30'), isNull);
      expect(ThresholdPaceUtils.parsePace('5:'), isNull);
    });

    test('PACE_U02: formats integer seconds into MM:SS format', () {
      expect(ThresholdPaceUtils.formatPace(300), equals('5:00'));
      expect(ThresholdPaceUtils.formatPace(255), equals('4:15'));
      expect(ThresholdPaceUtils.formatPace(315), equals('5:15'));
      expect(ThresholdPaceUtils.formatPace(150), equals('2:30'));
      expect(ThresholdPaceUtils.formatPace(720), equals('12:00'));
      expect(ThresholdPaceUtils.formatPace(null), equals(''));
    });
  });

  group('Physiological Range Boundary Verification (PACE_U03 & PACE_U04)', () {
    test(
      'PACE_U03: verifies boundaries 150s (2:30 /km) to 720s (12:00 /km)',
      () {
        expect(ThresholdPaceUtils.isValidPaceSeconds(150), isTrue);
        expect(ThresholdPaceUtils.isValidPaceSeconds(149), isFalse);
        expect(ThresholdPaceUtils.isValidPaceSeconds(720), isTrue);
        expect(ThresholdPaceUtils.isValidPaceSeconds(721), isFalse);
        expect(ThresholdPaceUtils.isValidPaceSeconds(300), isTrue);
      },
    );

    test(
      'PACE_U04: validatePaceString produces correct validation feedback',
      () {
        expect(ThresholdPaceUtils.validatePaceString(''), isNull);
        expect(ThresholdPaceUtils.validatePaceString('5:00'), isNull);
        expect(ThresholdPaceUtils.validatePaceString('2:30'), isNull);
        expect(ThresholdPaceUtils.validatePaceString('12:00'), isNull);

        final tooFastError = ThresholdPaceUtils.validatePaceString('1:45');
        expect(tooFastError, isNotNull);
        expect(tooFastError, contains('Enter pace between 2:30–12:00 /km'));

        final tooSlowError = ThresholdPaceUtils.validatePaceString('14:00');
        expect(tooSlowError, isNotNull);
        expect(tooSlowError, contains('Enter pace between 2:30–12:00 /km'));

        final invalidFormatError = ThresholdPaceUtils.validatePaceString(
          'invalid',
        );
        expect(invalidFormatError, isNotNull);
        expect(
          invalidFormatError,
          contains('Enter pace between 2:30–12:00 /km'),
        );
      },
    );
  });

  group('HeartRateCard Widget Integration (PACE_W05)', () {
    testWidgets('renders threshold pace field with controller and hint', (
      tester,
    ) async {
      final restingController = TextEditingController(text: '60');
      final maxController = TextEditingController(text: '190');
      final paceController = TextEditingController(text: '5:00');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HeartRateCard(
              restingHrController: restingController,
              maxHrController: maxController,
              thresholdPaceController: paceController,
              saveButton: const ElevatedButton(
                onPressed: null,
                child: Text('Save'),
              ),
              maxHrHint: 'blank = auto (190)',
            ),
          ),
        ),
      );

      expect(find.text('Threshold Pace (min/km)'), findsOneWidget);
      expect(find.text('5:00'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('threshold_pace_input')),
        findsOneWidget,
      );
    });

    testWidgets('displays threshold pace error text when provided', (
      tester,
    ) async {
      final restingController = TextEditingController(text: '60');
      final maxController = TextEditingController(text: '190');
      final paceController = TextEditingController(text: '1:45');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HeartRateCard(
              restingHrController: restingController,
              maxHrController: maxController,
              thresholdPaceController: paceController,
              thresholdPaceError: 'Enter pace between 2:30–12:00 /km',
              saveButton: const ElevatedButton(
                onPressed: null,
                child: Text('Save'),
              ),
              maxHrHint: 'blank = auto (190)',
            ),
          ),
        ),
      );

      expect(find.text('Enter pace between 2:30–12:00 /km'), findsOneWidget);
    });
  });
}

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teman_lari/domain/entities/activity.dart';
import 'package:teman_lari/domain/repositories/activity_repository.dart';
import 'package:teman_lari/presentation/providers/activities_provider.dart';

class FakeActivityRepository implements ActivityRepository {
  List<Activity> activities = [];
  bool refreshCalled = false;
  int? uploadedId;

  @override
  Future<List<Activity>> getAllActivities({int monthsBack = 12}) async {
    return activities;
  }

  @override
  Future<void> refreshActivities({int monthsBack = 12}) async {
    refreshCalled = true;
    await Future<void>.delayed(Duration.zero);
    activities = [
      Activity(
        id: 1,
        name: 'Morning Run',
        date: DateTime(2026, 10, 12),
        type: ActivityType.run,
        distanceKm: 5.0,
        movingTime: const Duration(minutes: 25),
        pace: const Duration(minutes: 5),
        elevationGainM: 20.0,
        trainingLoad: TrainingLoad.easy,
      ),
    ];
  }

  @override
  Future<Map<int, List<double>>> getHeartRateStreams(
    List<int> activityIds,
  ) async {
    return {};
  }

  @override
  Future<Activity> uploadActivity(int localId) async {
    uploadedId = localId;
    await Future<void>.delayed(Duration.zero);
    final uploaded = Activity(
      id: localId,
      name: 'Uploaded Run',
      date: DateTime(2026, 10, 12),
      type: ActivityType.run,
      distanceKm: 10.0,
      movingTime: const Duration(minutes: 50),
      pace: const Duration(minutes: 5),
      elevationGainM: 40.0,
      trainingLoad: TrainingLoad.moderate,
    );
    activities = [uploaded];
    return uploaded;
  }

  @override
  Future<void> saveActivity(Activity activity) async {
    activities.add(activity);
  }
}

void main() {
  group('ActivitiesNotifier lifecycle & unlistened execution regression tests', () {
    test(
      'syncWithStrava succeeds without disposed Ref error when unlistened',
      () async {
        final fakeRepo = FakeActivityRepository();
        final container = ProviderContainer(
          overrides: [activityRepositoryProvider.overrideWithValue(fakeRepo)],
        );
        addTearDown(container.dispose);

        // Invoke syncWithStrava without watching activitiesProvider
        await container.read(activitiesProvider.notifier).syncWithStrava();

        expect(fakeRepo.refreshCalled, isTrue);
        final state = container.read(activitiesProvider);
        expect(state.value, hasLength(1));
        expect(state.value!.first.name, equals('Morning Run'));
      },
    );

    test(
      'refresh succeeds without disposed Ref error when unlistened',
      () async {
        final fakeRepo = FakeActivityRepository();
        final container = ProviderContainer(
          overrides: [activityRepositoryProvider.overrideWithValue(fakeRepo)],
        );
        addTearDown(container.dispose);

        await container.read(activitiesProvider.notifier).refresh();

        expect(fakeRepo.refreshCalled, isTrue);
        final state = container.read(activitiesProvider);
        expect(state.value, hasLength(1));
      },
    );

    test(
      'uploadActivity succeeds without disposed Ref error when unlistened',
      () async {
        final fakeRepo = FakeActivityRepository();
        final container = ProviderContainer(
          overrides: [activityRepositoryProvider.overrideWithValue(fakeRepo)],
        );
        addTearDown(container.dispose);

        final result = await container
            .read(activitiesProvider.notifier)
            .uploadActivity(42);

        expect(fakeRepo.uploadedId, equals(42));
        expect(result.name, equals('Uploaded Run'));
        final state = container.read(activitiesProvider);
        expect(state.value, hasLength(1));
      },
    );

    test(
      'saveCompletedRun persists activity to repository and updates activities state',
      () async {
        final fakeRepo = FakeActivityRepository();
        final container = ProviderContainer(
          overrides: [activityRepositoryProvider.overrideWithValue(fakeRepo)],
        );
        addTearDown(container.dispose);

        final activity = Activity(
          id: -1728734400000,
          name: 'Tempo Run',
          date: DateTime(2026, 10, 12),
          type: ActivityType.run,
          distanceKm: 7.5,
          movingTime: const Duration(minutes: 35),
          pace: const Duration(seconds: 280),
          elevationGainM: 30.0,
          trainingLoad: TrainingLoad.moderate,
          isLocal: true,
        );

        await container
            .read(activitiesProvider.notifier)
            .saveCompletedRun(activity);

        expect(fakeRepo.activities, contains(activity));
        expect(fakeRepo.activities.first.id, isNegative);
        final state = container.read(activitiesProvider);
        expect(state.value, hasLength(1));
        expect(state.value!.first.id, equals(-1728734400000));
        expect(state.value!.first.isLocal, isTrue);
        expect(state.value!.first.name, equals('Tempo Run'));
      },
    );

    test(
      'addManualActivity saves local activity with negative ID, computed load, and updates state',
      () async {
        final fakeRepo = FakeActivityRepository();
        final container = ProviderContainer(
          overrides: [activityRepositoryProvider.overrideWithValue(fakeRepo)],
        );
        addTearDown(container.dispose);

        final testDate = DateTime(2026, 10, 10, 8, 30);
        await container
            .read(activitiesProvider.notifier)
            .addManualActivity(
              date: testDate,
              distanceKm: 10.0,
              duration: const Duration(
                minutes: 50,
              ), // 3000s, pace 300s = 5:00/km
              perceivedExertion: 8.0,
              name: 'Tempo Workout',
            );

        expect(fakeRepo.activities, hasLength(1));
        final saved = fakeRepo.activities.first;
        expect(saved.id, isNegative);
        expect(saved.isLocal, isTrue);
        expect(saved.name, equals('Tempo Workout'));
        expect(saved.date, equals(testDate));
        expect(saved.distanceKm, equals(10.0));
        expect(saved.movingTime, equals(const Duration(minutes: 50)));
        expect(saved.pace, equals(const Duration(seconds: 300)));
        expect(saved.perceivedExertion, equals(8.0));
        // TSS = (3000 / 3600) * (0.8^2) * 100 = 0.8333 * 0.64 * 100 = 53.33 -> moderate (30 <= tss < 60)
        expect(saved.trainingLoad, equals(TrainingLoad.moderate));

        final state = container.read(activitiesProvider);
        expect(state.value, hasLength(1));
        expect(state.value!.first.id, equals(saved.id));
      },
    );
  });
}

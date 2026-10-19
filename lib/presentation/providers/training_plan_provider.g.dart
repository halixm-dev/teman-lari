// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'training_plan_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(trainingPlanConfig)
final trainingPlanConfigProvider = TrainingPlanConfigProvider._();

final class TrainingPlanConfigProvider
    extends
        $FunctionalProvider<
          TrainingPlanConfig,
          TrainingPlanConfig,
          TrainingPlanConfig
        >
    with $Provider<TrainingPlanConfig> {
  TrainingPlanConfigProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'trainingPlanConfigProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$trainingPlanConfigHash();

  @$internal
  @override
  $ProviderElement<TrainingPlanConfig> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  TrainingPlanConfig create(Ref ref) {
    return trainingPlanConfig(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(TrainingPlanConfig value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<TrainingPlanConfig>(value),
    );
  }
}

String _$trainingPlanConfigHash() =>
    r'4843536aa62060bc0aa31ec9c08eff6c2b0e8366';

@ProviderFor(workoutSequenceStrategy)
final workoutSequenceStrategyProvider = WorkoutSequenceStrategyProvider._();

final class WorkoutSequenceStrategyProvider
    extends
        $FunctionalProvider<
          WorkoutSequenceStrategy,
          WorkoutSequenceStrategy,
          WorkoutSequenceStrategy
        >
    with $Provider<WorkoutSequenceStrategy> {
  WorkoutSequenceStrategyProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'workoutSequenceStrategyProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$workoutSequenceStrategyHash();

  @$internal
  @override
  $ProviderElement<WorkoutSequenceStrategy> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  WorkoutSequenceStrategy create(Ref ref) {
    return workoutSequenceStrategy(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(WorkoutSequenceStrategy value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<WorkoutSequenceStrategy>(value),
    );
  }
}

String _$workoutSequenceStrategyHash() =>
    r'172076b0eb0c45a2569b6e3f647f053351e2a420';

@ProviderFor(workoutDescriptions)
final workoutDescriptionsProvider = WorkoutDescriptionsProvider._();

final class WorkoutDescriptionsProvider
    extends
        $FunctionalProvider<
          WorkoutDescriptions,
          WorkoutDescriptions,
          WorkoutDescriptions
        >
    with $Provider<WorkoutDescriptions> {
  WorkoutDescriptionsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'workoutDescriptionsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$workoutDescriptionsHash();

  @$internal
  @override
  $ProviderElement<WorkoutDescriptions> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  WorkoutDescriptions create(Ref ref) {
    return workoutDescriptions(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(WorkoutDescriptions value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<WorkoutDescriptions>(value),
    );
  }
}

String _$workoutDescriptionsHash() =>
    r'ee086f257d283a58a3d9431454aa0611ccf74590';

@ProviderFor(generatePlanUseCase)
final generatePlanUseCaseProvider = GeneratePlanUseCaseProvider._();

final class GeneratePlanUseCaseProvider
    extends
        $FunctionalProvider<
          GeneratePlanUseCase,
          GeneratePlanUseCase,
          GeneratePlanUseCase
        >
    with $Provider<GeneratePlanUseCase> {
  GeneratePlanUseCaseProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'generatePlanUseCaseProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$generatePlanUseCaseHash();

  @$internal
  @override
  $ProviderElement<GeneratePlanUseCase> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  GeneratePlanUseCase create(Ref ref) {
    return generatePlanUseCase(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(GeneratePlanUseCase value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<GeneratePlanUseCase>(value),
    );
  }
}

String _$generatePlanUseCaseHash() =>
    r'520abc12ea40d1ca78618969e4eb6e30e0fc9533';

@ProviderFor(trainingPlan)
final trainingPlanProvider = TrainingPlanProvider._();

final class TrainingPlanProvider
    extends
        $FunctionalProvider<
          AsyncValue<TrainingPlan>,
          TrainingPlan,
          FutureOr<TrainingPlan>
        >
    with $FutureModifier<TrainingPlan>, $FutureProvider<TrainingPlan> {
  TrainingPlanProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'trainingPlanProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$trainingPlanHash();

  @$internal
  @override
  $FutureProviderElement<TrainingPlan> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<TrainingPlan> create(Ref ref) {
    return trainingPlan(ref);
  }
}

String _$trainingPlanHash() => r'2dc10001cb515dc799f2d1817ec18b43bc04be93';

@ProviderFor(WeekInCycleNotifier)
final weekInCycleProvider = WeekInCycleNotifierProvider._();

final class WeekInCycleNotifierProvider
    extends $AsyncNotifierProvider<WeekInCycleNotifier, int> {
  WeekInCycleNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'weekInCycleProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$weekInCycleNotifierHash();

  @$internal
  @override
  WeekInCycleNotifier create() => WeekInCycleNotifier();
}

String _$weekInCycleNotifierHash() =>
    r'de7f00fc89fabacf941269757c053183a46f6110';

abstract class _$WeekInCycleNotifier extends $AsyncNotifier<int> {
  FutureOr<int> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<AsyncValue<int>, int>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<int>, int>,
              AsyncValue<int>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}

@ProviderFor(cycleStartDate)
final cycleStartDateProvider = CycleStartDateProvider._();

final class CycleStartDateProvider
    extends
        $FunctionalProvider<AsyncValue<DateTime>, DateTime, FutureOr<DateTime>>
    with $FutureModifier<DateTime>, $FutureProvider<DateTime> {
  CycleStartDateProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'cycleStartDateProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$cycleStartDateHash();

  @$internal
  @override
  $FutureProviderElement<DateTime> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<DateTime> create(Ref ref) {
    return cycleStartDate(ref);
  }
}

String _$cycleStartDateHash() => r'b46e76de407bb551351abdfcf08679988272582f';

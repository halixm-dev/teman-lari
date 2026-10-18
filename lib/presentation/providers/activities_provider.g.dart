// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'activities_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(localActivityDataSource)
final localActivityDataSourceProvider = LocalActivityDataSourceProvider._();

final class LocalActivityDataSourceProvider
    extends
        $FunctionalProvider<
          LocalActivityDataSource,
          LocalActivityDataSource,
          LocalActivityDataSource
        >
    with $Provider<LocalActivityDataSource> {
  LocalActivityDataSourceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'localActivityDataSourceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$localActivityDataSourceHash();

  @$internal
  @override
  $ProviderElement<LocalActivityDataSource> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  LocalActivityDataSource create(Ref ref) {
    return localActivityDataSource(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(LocalActivityDataSource value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<LocalActivityDataSource>(value),
    );
  }
}

String _$localActivityDataSourceHash() =>
    r'77eb5b489914b06de49feae5388183553b392f6a';

@ProviderFor(activityRepository)
final activityRepositoryProvider = ActivityRepositoryProvider._();

final class ActivityRepositoryProvider
    extends
        $FunctionalProvider<
          ActivityRepository,
          ActivityRepository,
          ActivityRepository
        >
    with $Provider<ActivityRepository> {
  ActivityRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'activityRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$activityRepositoryHash();

  @$internal
  @override
  $ProviderElement<ActivityRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  ActivityRepository create(Ref ref) {
    return activityRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ActivityRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ActivityRepository>(value),
    );
  }
}

String _$activityRepositoryHash() =>
    r'b6513a3d62033695b02e241aac85e240d01fd478';

@ProviderFor(analyzeRunsUseCase)
final analyzeRunsUseCaseProvider = AnalyzeRunsUseCaseProvider._();

final class AnalyzeRunsUseCaseProvider
    extends
        $FunctionalProvider<
          AnalyzeRunsUseCase,
          AnalyzeRunsUseCase,
          AnalyzeRunsUseCase
        >
    with $Provider<AnalyzeRunsUseCase> {
  AnalyzeRunsUseCaseProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'analyzeRunsUseCaseProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$analyzeRunsUseCaseHash();

  @$internal
  @override
  $ProviderElement<AnalyzeRunsUseCase> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  AnalyzeRunsUseCase create(Ref ref) {
    return analyzeRunsUseCase(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AnalyzeRunsUseCase value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AnalyzeRunsUseCase>(value),
    );
  }
}

String _$analyzeRunsUseCaseHash() =>
    r'a70e83c990035221fb5c4bebd4df9b4391413355';

@ProviderFor(ActivitiesNotifier)
final activitiesProvider = ActivitiesNotifierProvider._();

final class ActivitiesNotifierProvider
    extends $AsyncNotifierProvider<ActivitiesNotifier, List<Activity>> {
  ActivitiesNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'activitiesProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$activitiesNotifierHash();

  @$internal
  @override
  ActivitiesNotifier create() => ActivitiesNotifier();
}

String _$activitiesNotifierHash() =>
    r'2dd462e62fa74b08e2cac4e1ea06814b29debec1';

abstract class _$ActivitiesNotifier extends $AsyncNotifier<List<Activity>> {
  FutureOr<List<Activity>> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<AsyncValue<List<Activity>>, List<Activity>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<List<Activity>>, List<Activity>>,
              AsyncValue<List<Activity>>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}

@ProviderFor(runningStats)
final runningStatsProvider = RunningStatsProvider._();

final class RunningStatsProvider
    extends
        $FunctionalProvider<
          AsyncValue<RunningStats?>,
          RunningStats?,
          FutureOr<RunningStats?>
        >
    with $FutureModifier<RunningStats?>, $FutureProvider<RunningStats?> {
  RunningStatsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'runningStatsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$runningStatsHash();

  @$internal
  @override
  $FutureProviderElement<RunningStats?> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<RunningStats?> create(Ref ref) {
    return runningStats(ref);
  }
}

String _$runningStatsHash() => r'8d3ee767a55426b68c83369a95585e32b6df1ae3';

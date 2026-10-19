// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'rehab_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(localRehabRepository)
final localRehabRepositoryProvider = LocalRehabRepositoryProvider._();

final class LocalRehabRepositoryProvider
    extends
        $FunctionalProvider<
          LocalRehabRepository,
          LocalRehabRepository,
          LocalRehabRepository
        >
    with $Provider<LocalRehabRepository> {
  LocalRehabRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'localRehabRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$localRehabRepositoryHash();

  @$internal
  @override
  $ProviderElement<LocalRehabRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  LocalRehabRepository create(Ref ref) {
    return localRehabRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(LocalRehabRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<LocalRehabRepository>(value),
    );
  }
}

String _$localRehabRepositoryHash() =>
    r'3e5418a312af512e613cb2d5584686ebee1e552a';

@ProviderFor(rehabTime)
final rehabTimeProvider = RehabTimeProvider._();

final class RehabTimeProvider
    extends
        $FunctionalProvider<AsyncValue<DateTime>, DateTime, Stream<DateTime>>
    with $FutureModifier<DateTime>, $StreamProvider<DateTime> {
  RehabTimeProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'rehabTimeProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$rehabTimeHash();

  @$internal
  @override
  $StreamProviderElement<DateTime> $createElement($ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<DateTime> create(Ref ref) {
    return rehabTime(ref);
  }
}

String _$rehabTimeHash() => r'df129fd53e223c040a231e7c443fc504a4b2ff3f';

@ProviderFor(RehabJournalNotifier)
final rehabJournalProvider = RehabJournalNotifierProvider._();

final class RehabJournalNotifierProvider
    extends $AsyncNotifierProvider<RehabJournalNotifier, RehabJournal> {
  RehabJournalNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'rehabJournalProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$rehabJournalNotifierHash();

  @$internal
  @override
  RehabJournalNotifier create() => RehabJournalNotifier();
}

String _$rehabJournalNotifierHash() =>
    r'8d7e96d7da51e32e86b53ea63ad123afd6e01e5a';

abstract class _$RehabJournalNotifier extends $AsyncNotifier<RehabJournal> {
  FutureOr<RehabJournal> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<AsyncValue<RehabJournal>, RehabJournal>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<RehabJournal>, RehabJournal>,
              AsyncValue<RehabJournal>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}

@ProviderFor(rehabProgress)
final rehabProgressProvider = RehabProgressProvider._();

final class RehabProgressProvider
    extends
        $FunctionalProvider<
          AsyncValue<RehabProgress?>,
          RehabProgress?,
          FutureOr<RehabProgress?>
        >
    with $FutureModifier<RehabProgress?>, $FutureProvider<RehabProgress?> {
  RehabProgressProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'rehabProgressProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$rehabProgressHash();

  @$internal
  @override
  $FutureProviderElement<RehabProgress?> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<RehabProgress?> create(Ref ref) {
    return rehabProgress(ref);
  }
}

String _$rehabProgressHash() => r'c3c3ca71fecad5582ace848544ee9dc086e41229';

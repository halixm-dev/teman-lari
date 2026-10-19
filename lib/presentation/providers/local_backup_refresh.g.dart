// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'local_backup_refresh.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(LocalBackupRefreshEpoch)
final localBackupRefreshEpochProvider = LocalBackupRefreshEpochProvider._();

final class LocalBackupRefreshEpochProvider
    extends $NotifierProvider<LocalBackupRefreshEpoch, int> {
  LocalBackupRefreshEpochProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'localBackupRefreshEpochProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$localBackupRefreshEpochHash();

  @$internal
  @override
  LocalBackupRefreshEpoch create() => LocalBackupRefreshEpoch();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(int value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<int>(value),
    );
  }
}

String _$localBackupRefreshEpochHash() =>
    r'514b528c88dcab942d904eb7fb88d23ef27062f5';

abstract class _$LocalBackupRefreshEpoch extends $Notifier<int> {
  int build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<int, int>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<int, int>,
              int,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}

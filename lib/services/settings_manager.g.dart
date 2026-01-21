// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'settings_manager.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Central settings manager with automatic persistence and change notification
/// Uses Riverpod's AsyncNotifier for reactive state management

@ProviderFor(Settings)
const settingsProvider = SettingsProvider._();

/// Central settings manager with automatic persistence and change notification
/// Uses Riverpod's AsyncNotifier for reactive state management
final class SettingsProvider
    extends $AsyncNotifierProvider<Settings, AppSettings> {
  /// Central settings manager with automatic persistence and change notification
  /// Uses Riverpod's AsyncNotifier for reactive state management
  const SettingsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'settingsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$settingsHash();

  @$internal
  @override
  Settings create() => Settings();
}

String _$settingsHash() => r'da619aeca828eec3d1ba55705388bdbb5d54a996';

/// Central settings manager with automatic persistence and change notification
/// Uses Riverpod's AsyncNotifier for reactive state management

abstract class _$Settings extends $AsyncNotifier<AppSettings> {
  FutureOr<AppSettings> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<AsyncValue<AppSettings>, AppSettings>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<AppSettings>, AppSettings>,
              AsyncValue<AppSettings>,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}

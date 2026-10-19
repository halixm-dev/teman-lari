# Offline backup verification

Run commands from the repository root after `flutter pub get`.

| Check | Command |
| --- | --- |
| Replacement and recovery | `flutter test test/data/backup/snapshot_replacement_test.dart` |
| Native platform fixture | `flutter test test/data/backup/snapshot_platform_roundtrip_test.dart` |
| Chrome platform fixture | `dart run tool/test_backup_browser.dart` |
| Settings import flows | `flutter test test/presentation/widgets/backup_import_card_test.dart` |
| Offline Settings refresh | `flutter test test/presentation/screens/settings_backup_recovery_test.dart` |

The platform suite uses the same populated `.tlbackup` fixture on both platforms. It checks all six sections after reopening storage, credential exclusion and preservation, linked-record migration during Smart Merge, and identity precision. Native stores use disposable directories; Chrome uses an isolated Flutter test-runner origin and its own IndexedDB stores.

The browser helper writes the fixture into a temporary Dart-define file, avoiding Windows batch command-length limits. It runs through `test/backup_platform_browser.dart` because Flutter on Windows currently generates different path separators for nested HTML test selectors and their generated lookup map. The shared tests remain in `test/data/backup/`; the root entry has no `_test.dart` suffix so native full-suite discovery does not run them twice. The helper removes its temporary definition file afterward and does not change the Flutter SDK.

Actual picker, save/share, browser download/upload, offline operation, and device-reopen flows also require platform QA. Use an isolated installation or browser profile for replacement checks; preserve the athlete's existing data. iOS delivery must be checked on an iOS-capable host and device.

Flutter 3.44.8 on Windows also returns 404 for the test runner's local CanvasKit files because its request handler compares Windows paths to URL paths. The Chrome suite was verified during this implementation by supplying the unchanged installed SDK renderer JS/Wasm files to its isolated test origin. No application API, stored data, or SDK source was mocked or changed. For unattended Chrome verification, use a Flutter runner with working renderer delivery (for example, a supported Linux/macOS CI host). This issue affects Flutter's test host; the built web app serves its renderer assets separately.

// Keep this browser entry at the test root: Flutter on Windows currently uses
// backslashes in the HTML selector but slashes in the generated test map.
// The native full suite discovers the shared tests at their normal location.
import 'data/backup/snapshot_platform_roundtrip_test.dart' as suite;

void main() => suite.main();

import 'package:flutter_test/flutter_test.dart';

import 'tier1_feature_coverage_test.dart' as tier1;
import 'tier2_boundary_corner_test.dart' as tier2;
import 'tier3_cross_feature_test.dart' as tier3;
import 'tier4_real_world_scenarios_test.dart' as tier4;

/// Master Entrypoint for Teman Lari Decoupled Identity & Optional Strava Integration E2E Test Suite.
/// Runs all 4 tiers adhering to TEST_INFRA.md and PROJECT.md specifications:
/// - Tier 1: Feature Coverage (F01–F30)
/// - Tier 2: Boundary Value Analysis & Corner Cases (E01–E18)
/// - Tier 3: Cross-Feature Interactions & Combinations
/// - Tier 4: Real-World End-to-End Application Scenarios (1–5)
void main() {
  group('=== Teman Lari E2E Master Test Suite ===', () {
    tier1.main();
    tier2.main();
    tier3.main();
    tier4.main();
  });
}

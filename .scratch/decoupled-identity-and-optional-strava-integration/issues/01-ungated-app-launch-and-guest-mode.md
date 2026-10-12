# 01: Un-gated App Launch and Local Profile Guest Mode

**What to build:** An un-gated initial app launch experience that boots directly to the dashboard in Local Profile / Guest Mode without requiring Strava OAuth authentication. When offline or unauthenticated, athletes can access the dashboard, view local physiological metrics, and load their training log without being redirected to a login screen or encountering network authentication errors.

**Blocked by:** None (can start immediately)

**Status:** closed

- [x] App launch sequence bypasses mandatory Strava OAuth gating and navigates directly to the main navigation and dashboard screen
- [x] Athlete operates in Local Profile / Guest Mode by default with locally persisted baseline demographic preferences (resting heart rate, maximum heart rate, threshold pace)
- [x] Activity repository serves stored local activities without triggering outbound Strava API requests or throwing authentication errors when unauthenticated
- [x] Dashboard displays athlete greeting and training stats computed from local data without requiring active cloud credentials
- [x] Regression and widget tests verify that launching the app without stored Strava credentials opens the main dashboard smoothly

# 0008: Decoupled Identity Model and Optional Strava Integration

We decided to eliminate mandatory Strava OAuth gating at startup and adopt a local-first runner identity model, repositioning Strava as an optional peripheral integration.

1. **Local-First Identity by Default:**
   - Athletes access all dashboard, planning, and tracking features immediately without requiring any account creation or cloud authentication. Profile parameters (resting heart rate, maximum heart rate, threshold pace) are stored locally.

2. **Strava as an Optional Integration:**
   - Strava authentication is uncoupled from app access and relocated to the Settings screen under Integrations. Users can connect or disconnect their Strava account at any time without impacting local data availability.

3. **Selective Push & Non-Destructive Pull:**
   - Connecting Strava enables one-way importing of remote activities into the local database without overwriting local-only workouts.
   - Offline-recorded runs feature an optional, user-initiated "Upload to Strava" action, preventing unintended duplicate uploads or rate-limit saturation while giving athletes explicit control over external data publication.

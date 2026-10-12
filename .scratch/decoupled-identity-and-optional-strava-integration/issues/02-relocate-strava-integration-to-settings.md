# 02: Relocate Strava Integration to Settings

**What to build:** An optional integrations management hub within the Settings screen where athletes can connect or disconnect their Strava account at will. When disconnected, the integration card highlights features and provides an OAuth connection trigger. When connected, it displays the connected account identity and a safe disconnect option. Disconnecting Strava clears remote authorization tokens without clearing local activities, wiping training plans, or kicking the user out of the app.

**Blocked by:** 01: Un-gated App Launch and Local Profile Guest Mode

**Status:** closed

- [x] Settings screen features a dedicated Integrations section hosting the Strava integration card
- [x] In disconnected state, the Strava card displays a "Connect with Strava" button and summarizes integration benefits (historical imports, profile sync, selective upload)
- [x] Tapping connect triggers the Strava OAuth flow and transitions the integration card to a connected state upon successful authentication
- [x] In connected state, the Strava card displays the connected athlete profile details and a "Disconnect Strava" action
- [x] Disconnecting Strava clears stored OAuth tokens and resets the integration state without wiping local Hive activities, deleting personal settings, or redirecting to a login screen
- [x] Tests verify connecting and disconnecting Strava from Settings, ensuring local database and settings integrity

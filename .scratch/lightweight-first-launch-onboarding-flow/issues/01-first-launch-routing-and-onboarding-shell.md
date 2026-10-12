# 01: First-Launch Routing and Onboarding Shell

**What to build:** An initial application launch detection and routing sequence that differentiates first-time users from returning athletes. When an athlete launches the app for the very first time with clean local storage, the router detects that onboarding is incomplete and directs them to the onboarding sequence. An initial onboarding shell provides an immediate completion or skip path that records onboarding completion status locally and transitions the user to the main dashboard. Subsequent app launches detect the completion flag and boot immediately to the main dashboard and navigation without routing delay.

**Blocked by:** None (can start immediately)

**Status:** resolved

- [x] Persistent preferences storage provides methods to check and update the onboarding completion flag (`has_completed_onboarding`)
- [x] Application router directs first-time launches (where onboarding is uncompleted) to the onboarding route (`/onboarding`)
- [x] Application router directs subsequent launches (where onboarding is completed) directly to the main navigation and dashboard (`/dashboard`)
- [x] An initial onboarding screen shell renders when navigated to `/onboarding`, offering an exit/skip action to finish onboarding
- [x] Triggering completion or skip from the onboarding shell writes `has_completed_onboarding: true` to local storage and navigates to the dashboard
- [x] Automated launch routing tests verify clean-install routing to onboarding, completion transition to dashboard, and subsequent-boot bypass of onboarding

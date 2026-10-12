# Spec: Lightweight First-Launch Onboarding Flow

Status: ready-for-agent

## Problem Statement

When an athlete launches Teman Lari for the first time, they are currently dropped directly onto an empty dashboard with zero guidance, context, or orientation regarding the app's core capabilities. The app greets them with a generic fallback title ("Hello, Runner!") and lacks the fundamental demographic baselines required to compute personalized training metrics.

Conversely, many running applications overburden new athletes with exhaustive, multi-screen setup wizards demanding height, weight, resting heart rate, shoe equipment, target race dates, and mandatory cloud account registration before granting access to basic features. This induces cognitive fatigue and high abandonment rates.

Without capturing basic athlete demographics (specifically athlete name and birth date or age), Teman Lari's on-device physiological engine cannot calculate a personalized baseline maximum heart rate, leaving metrics to fall back to an arbitrary default (190 bpm). Furthermore, without a persistent first-launch state mechanism, the application cannot differentiate between a brand-new user requiring orientation and a returning athlete who needs instantaneous access to their training dashboard.

## Solution

Teman Lari introduces a streamlined, two-step onboarding sequence displayed exclusively on first app launch, engineered to be completed in under 30 seconds.

1. **Two-Step Onboarding Architecture:**
   - **Step 1: Welcome & Value Orientation:**
     - Introduces the athlete to Teman Lari's core value propositions:
       1. *Offline-First Tracking:* Permanent on-device SSOT local store with zero-TTL persistence—track runs anywhere with GPS and sensors without internet connectivity.
       2. *Personalized Training Load Analytics:* On-device computation of Acute Training Load (ATL / Fatigue), Chronic Training Load (CTL / Fitness), and Training Stress Balance (TSB / Form).
       3. *Adaptive Plan Generation:* Dynamic multi-week periodized training schedules that adjust directly to your workload and fitness level.
     - Beautiful, modern presentation adhering to the Teman Lari design language (`AppColors.brandOrange`, clear iconography, responsive layout).
     - Forward navigation action ("Get Started") advancing seamlessly to demographic setup.
   - **Step 2: Basic Demographic Setup:**
     - Captures minimal essential data to personalize the experience:
       1. *Athlete Name:* Displayed on personal dashboard greetings and local profile badges.
       2. *Birth Date / Age:* Used to estimate baseline maximum heart rate.
     - Dynamically calculates and displays an estimated maximum heart rate using the validated Tanaka formula:
       $$\text{HR}_{\max} = \text{round}(208 - 0.7 \times \text{age})$$
     - Clarifies that this estimate establishes baseline training zones and training load metrics, and can be customized at any time in Settings.
     - Provides both an explicit "Complete Setup" action and a non-punitive "Skip" action (defaulting to name "Runner" and fallback HR 190).

2. **Deferred Advanced Configuration:**
   - All secondary and advanced configurations—custom heart rate zones, resting heart rate adjustments, shoe quivers, menstrual cycle tracking, and cloud/Strava integrations—are omitted from initial setup and accessed via Settings, preserving rapid time-to-first-use.

3. **Persistent Routing State:**
   - Onboarding completion is recorded locally in `SharedPreferences` (`has_completed_onboarding: true`).
   - The application router inspects this state on launch:
     - When `has_completed_onboarding` is false or unset: routes directly to `/onboarding`.
     - When `has_completed_onboarding` is true: routes directly to `/dashboard` (`MainNavigationScreen`), ensuring zero-friction, instantaneous startup for returning athletes.
   - Completing or skipping onboarding writes `has_completed_onboarding: true` and transitions the athlete directly to the main dashboard.

## User Stories

1. As a first-time athlete opening Teman Lari, I want to be greeted by an onboarding flow, so that I understand what the app does before using it.
2. As a first-time athlete, I want the onboarding flow to complete in under 30 seconds, so that I can start using the application without tedious questionnaires.
3. As a first-time athlete, I want Step 1 of onboarding to highlight offline-first GPS and sensor tracking, so that I know I can track runs without cellular reception.
4. As a first-time athlete, I want Step 1 of onboarding to highlight autonomous on-device training load analytics (ATL, CTL, TSB), so that I know my metrics are computed privately on my phone.
5. As a first-time athlete, I want Step 1 of onboarding to highlight adaptive training plan generation, so that I know the app can structure my workouts.
6. As a first-time athlete on Step 1, I want a clear "Get Started" action that moves me to Step 2, so that navigation is intuitive and forward-moving.
7. As a first-time athlete on Step 2, I want to enter my preferred athlete name, so that the app addresses me personally on my dashboard and profile.
8. As a first-time athlete on Step 2, I want to select my birth date using a date picker, so that the app accurately determines my current age.
9. As a first-time athlete on Step 2, I want input validation to reject future birth dates or dates resulting in impossible ages (e.g., age < 5 or > 120), so that corrupt demographic data is prevented.
10. As a first-time athlete entering my birth date or age, I want to see an immediate dynamic preview of my estimated maximum heart rate calculated via $208 - 0.7 \times \text{age}$, so that I understand how my age informs my training zones.
11. As a first-time athlete on Step 2, I want a concise explanation indicating that the estimated maximum heart rate can be adjusted anytime in Settings, so that I do not feel locked into the estimation.
12. As a first-time athlete in a hurry, I want an explicit "Skip" button on Step 2, so that I can bypass demographic input and start using the app immediately.
13. As a first-time athlete who taps "Skip", I want the app to apply safe fallback values ("Runner" and default max HR), so that the dashboard functions without missing data.
14. As a first-time athlete who taps "Skip", I want the app to record onboarding as completed, so that I am not prompted with onboarding again on next launch.
15. As a first-time athlete tapping "Complete Setup", I want my entered name, birth date, and Tanaka-calculated maximum heart rate saved to local storage, so that my personal profile is established.
16. As a first-time athlete completing setup, I want `has_completed_onboarding: true` persisted to `SharedPreferences`, so that my completion state is saved permanently on-device.
17. As a first-time athlete finishing onboarding, I want to be transitioned smoothly to the main dashboard (`/dashboard`), so that I can explore my training log.
18. As an athlete who entered their name in onboarding, I want the dashboard header to immediately greet me with "Hello, [Name]!", so that I receive visual confirmation of my setup.
19. As an athlete who entered their birth date in onboarding, I want heart rate zone and training load calculations to immediately use the Tanaka-estimated maximum heart rate, so that my metrics are personalized from day one.
20. As a returning athlete launching Teman Lari for the second time, I want the app to bypass onboarding completely and load `/dashboard` immediately, so that my time-to-first-interaction is instantaneous.
21. As an athlete launching the app in airplane mode for the first time, I want the entire onboarding sequence to function 100% offline with zero network requests, so that I never get blocked by connectivity issues.
22. As a first-time athlete, I want complex configurations like resting HR, shoe quivers, menstrual cycle tracking, and Strava integration to be omitted from onboarding, so that I am not overwhelmed during initial setup.
23. As an athlete on Step 2 of onboarding, I want a "Back" button to return to Step 1, so that I can re-read the feature overview if desired.
24. As an athlete using dark mode, I want the onboarding sequence to render seamlessly in dark theme styling, so that the visual experience matches my system preferences.
25. As an athlete using a tablet or desktop device, I want the onboarding cards and form to be centered with responsive maximum widths, so that the layout looks balanced on wide screens.
26. As an athlete navigating to Settings after onboarding, I want to see my configured name and maximum heart rate already populated in the demographic fields, so that I can review or tweak them anytime.
27. As a developer or tester running automated tests, I want the ability to bypass onboarding by supplying `has_completed_onboarding: true` in mock preferences, so that downstream screen tests remain deterministic and isolated.

## Implementation Decisions

- **Two-Step Onboarding View Architecture:**
  - An `OnboardingScreen` manages the two-step progression with page/step controllers and visual indicators (step dots/steppers):
    - **Step 1 (Welcome & Value Orientation):** Displays brand typography, hero illustration/iconography, and three value propositions:
      1. Offline-First Tracking (zero-TTL SSOT local database).
      2. Autonomous On-Device Analytics (local ATL/CTL/TSB calculations).
      3. Adaptive Plan Generation (automated periodized schedules).
      Includes a primary action button ("Get Started" / "Continue") advancing to Step 2.
    - **Step 2 (Basic Demographic Setup):** Displays input fields for Athlete Name (text field) and Date of Birth (date picker / formatted input).
      - Live estimation card displaying Tanaka maximum heart rate:
        $$\text{Estimated Max HR} = \text{round}(208 - 0.7 \times \text{age})$$
      - Supporting note explaining that resting HR and exact training zones can be customized later in Settings.
      - Action footer with "Back", "Skip", and primary "Complete Setup" buttons.

- **Demographic Calculation & Persistence:**
  - Age computation derives elapsed full years from ISO-8601 birth date (`YYYY-MM-DD`).
  - Tanaka formula execution:
    - $\text{maxHr} = (208 - (0.7 \times \text{age})).\text{round}()$.
  - Upon completing Step 2:
    - Persists `athlete_name` string in preferences storage.
    - Persists `date_of_birth` string in preferences storage.
    - Persists `max_hr` integer in preferences storage.
    - Persists `has_completed_onboarding: true` boolean in preferences storage.
  - Upon skipping Step 2:
    - Leaves custom demographic fields unset or applies defaults.
    - Persists `has_completed_onboarding: true` boolean in preferences storage.

- **Persistent Routing State Machine (`GoRouter` Integration):**
  - Storage key: `has_completed_onboarding` in `SharedPreferences`.
  - Preferences storage exposes:
    - `Future<bool> hasCompletedOnboarding()`
    - `Future<void> setCompletedOnboarding([bool completed = true])`
  - Application routing updates:
    - Dedicated route `/onboarding` pointing to `OnboardingScreen`.
    - Router redirect evaluates onboarding completion:
      - If `has_completed_onboarding` is false or null and navigating to `/dashboard` or `/`, redirect to `/onboarding`.
      - If `has_completed_onboarding` is true and navigating to `/onboarding`, redirect to `/dashboard`.
    - Completing or skipping onboarding calls `setCompletedOnboarding(true)` and invokes `context.go('/dashboard')`.

- **Strict Boundary & Deferred Configuration:**
  - All secondary settings—resting heart rate calibration, threshold pace setting, shoe quiver management, menstrual cycle tracking (ADR 0005), and Strava OAuth (ADR 0008)—are strictly excluded from the onboarding sequence.
  - Informational caption on Step 2 directs the user to Settings for detailed zone tuning.

- **Reactive State Propagation:**
  - Committing demographic data invalidates `athleteNameProvider` and `hrPreferencesProvider`, ensuring `DashboardScreen` immediately displays the athlete's name and downstream physiological calculators immediately reflect the calculated max HR.

## Testing Decisions

- **What makes a good test:**
  - Tests verify user-observable behavior across high-level application seams rather than private widget state variables or controller animations.
  - Tests verify that a clean installation (empty preferences) boots into the onboarding flow, while a returning installation (`has_completed_onboarding: true`) boots directly into the main navigation.
  - Tests verify that completing Step 2 with valid demographic inputs correctly persists the athlete name, birth date, Tanaka-computed maximum heart rate, and onboarding completion flag.
  - Tests verify that clicking "Skip" sets `has_completed_onboarding: true` and transitions to the dashboard without crashing or corrupting state.
  - Tests verify input validation on the birth date field (preventing future dates or unreasonable ages).

- **Modules and Seams to Test:**
  - **Primary Seam 1: Launch Routing Seam (`GoRouter` & `PreferencesStorage` / `SharedPreferences`):**
    - First-launch redirect: Pump application with empty `SharedPreferences` (`{}`). Verify `/onboarding` and `OnboardingScreen` are displayed, and `DashboardScreen` is not displayed.
    - Returning athlete launch: Pump application with `SharedPreferences` containing `{'has_completed_onboarding': true}`. Verify `/dashboard` and `MainNavigationScreen` are displayed immediately without displaying `OnboardingScreen`.
  - **Primary Seam 2: Onboarding Interactive Flow Seam (`OnboardingScreen` & `PreferencesProvider`):**
    - Step progression: Pump `OnboardingScreen`, verify Step 1 value proposition items (Offline Tracking, Analytics, Plan Generation); tap "Get Started", verify transition to Step 2.
    - Back navigation: Tap "Back" on Step 2, verify return to Step 1.
    - Demographic entry & Tanaka calculation: On Step 2, enter athlete name (e.g., "Budi") and birth date corresponding to age 30. Verify the estimated max HR preview shows $208 - (0.7 \times 30) = 187$ bpm. Tap "Complete Setup". Verify `athlete_name`, `date_of_birth`, `max_hr` (187), and `has_completed_onboarding` (true) are persisted to storage, and navigation transitions to `/dashboard`.
    - Skip action: On Step 2, tap "Skip". Verify `has_completed_onboarding` is set to `true`, and navigation transitions to `/dashboard` with greeting "Hello, Runner!".
    - Form validation: On Step 2, select a date in the future. Verify validation error prevents submission and displays helpful feedback.
  - **Primary Seam 3: Demographic Formulation Unit Seam (`PreferencesStorage` & Tanaka Equation):**
    - Verify Tanaka formula calculation for various ages (e.g. age 20 -> 194 bpm, age 30 -> 187 bpm, age 45 -> 177 bpm).
    - Verify `hasCompletedOnboarding()` defaults to `false` and returns `true` after `setCompletedOnboarding(true)`.

- **Prior Art:**
  - `test/presentation/screens/app_launch_routing_test.dart`: Launch routing with `GoRouter` and mocked `SharedPreferences`.
  - `test/data/datasources/preferences_storage_demographics_test.dart`: Demographics persistence and age calculations.
  - `test/presentation/screens/settings_screen_test.dart`: Form validation, controller event handling, and provider overrides.

## Out of Scope

- Detailed heart rate zone boundary customization and threshold pace entry (handled in Settings).
- Resting heart rate calibration (defaults to 60 bpm, adjustable in Settings).
- Shoe quiver onboarding and foam recovery tracking (governed by ADR 0006, handled in Equipment/Settings).
- Menstrual cycle tracking opt-in and cycle start date entry (governed by ADR 0005, handled in Settings).
- Strava OAuth integration (governed by ADR 0008, handled in Settings under Integrations).
- Cloud snapshot backups via Google Account / Firebase (governed by ADR 0010).
- Offline database backup archive import/export (governed by ADR 0011).

## Further Notes

- Adheres strictly to ADR 0009 ("Lightweight First-Launch Onboarding Flow").
- Uses domain vocabulary from `GLOSSARY.md` (`Local Profile / Guest Mode`, `Single Source of Truth (SSOT) Local Store`, `Activity`, `Training Load (TSS)`, `Fitness (CTL)`, `Fatigue (ATL)`, `Form (TSB)`).
- Designed for rapid completion: time-to-first-use remains under 30 seconds to prevent user drop-off.
- Completely offline: no network connectivity or cloud APIs are queried during onboarding.

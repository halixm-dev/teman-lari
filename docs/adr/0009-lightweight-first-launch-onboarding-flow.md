# 0009: Lightweight First-Launch Onboarding Flow

We decided to introduce a streamlined, two-step onboarding sequence for first-time app launches to orient new users and collect essential demographic baselines without cognitive or setup fatigue.

1. **Two-Step Onboarding Structure:**
   - *Step 1 (Welcome & Value Orientation):* Highlighting offline-first tracking, personalized training load analytics, and adaptive plan generation.
   - *Step 2 (Basic Demographic Setup):* Captures athlete name and birth date / age to establish baseline maximum heart rate estimates ($208 - 0.7 \times \text{age}$) and personal profile labels.

2. **Deferred Advanced Configuration:**
   - Detailed training zones, resting heart rate adjustments, shoe quivers, menstrual cycle tracking, and cloud/Strava integrations are omitted from the initial setup and accessed via Settings, ensuring time-to-first-use remains under 30 seconds.

3. **Persistent Routing State:**
   - The onboarding completion state is recorded locally in `SharedPreferences` (`has_completed_onboarding: true`). Subsequent launches bypass onboarding directly to `MainNavigationScreen`.

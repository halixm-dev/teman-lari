# 03: Demographic Setup, Tanaka Max HR Estimation & State Persistence (Step 2)

**What to build:** The complete Step 2 demographic setup flow capturing essential athlete baseline data and establishing physiological parameters in under 30 seconds. Athletes enter their preferred name and birth date or age with input validation (rejecting future dates or unrealistic ages). The view dynamically calculates and previews baseline Maximum Heart Rate using the Tanaka formula ($\text{HR}_{\max} = \text{round}(208 - 0.7 \times \text{age})$), accompanied by a note explaining that detailed zones and resting HR can be customized later in Settings. Athletes can navigate back to Step 1, tap "Skip" to continue in default guest mode, or tap "Complete Setup" to commit their demographic baselines and complete onboarding, reactively updating the dashboard greeting ("Hello, [Name]!") and physiological calculations.

**Blocked by:** 02: Welcome and Value Orientation (Step 1)

**Status:** resolved

- [x] Step 2 form provides input fields for Athlete Name and Date of Birth with a user-friendly date picker
- [x] Input validation rejects dates in the future or dates resulting in impossible age bounds (e.g. age < 5 or > 120)
- [x] Dynamic preview card calculates and displays estimated Maximum Heart Rate in real time via the Tanaka formula ($208 - 0.7 \times \text{age}$)
- [x] Informational caption clarifies that resting heart rate and custom zones are deferred to Settings to keep setup fast
- [x] "Back" action returns to Step 1 without losing entered data
- [x] "Skip" action persists `has_completed_onboarding: true`, keeps default guest profile, and navigates to the dashboard
- [x] "Complete Setup" action persists `athlete_name`, `date_of_birth`, calculated `max_hr`, and `has_completed_onboarding: true` before navigating to the dashboard
- [x] Dashboard header dynamically greets the athlete with their entered name ("Hello, [Name]!")
- [x] Settings screen demographic inputs reflect the saved athlete name and calculated maximum heart rate
- [x] Automated tests verify Tanaka formula computation, date validation, complete setup persistence, skip fallback, and reactive dashboard greeting

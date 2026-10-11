# 0005: Endocrine and Menstrual Cycle-Phase Periodization

We decided to introduce an opt-in, privacy-first menstrual cycle periodization model into Teman Lari to adapt training stimulus and recovery to female endocrine biology, rather than assuming a static androgenic physiological baseline.

1. **Domain Disambiguation:** 
   - The existing training mesocycle enum (`beginner`, `intermediate`, `advanced`) is renamed from `CyclePhase` to `MesocyclePhase` to avoid domain ambiguity.
   - A distinct `MenstrualPhase` enum is introduced (`earlyFollicular`, `midLateFollicular`, `ovulatory`, `midLateLuteal`).

2. **Physiological Training Adaptations:**
   - *Mid/Late Follicular (Estrogen dominant, low progesterone):* Prioritizes high-intensity quality sessions (VO2max, threshold intervals) and maximal neuromuscular strength.
   - *Ovulatory Surge:* Flags soft-tissue and ligament laxity awareness (focus on joint stability over high-impact plyometrics).
   - *Mid/Late Luteal (Progesterone dominant):* Softens anaerobic interval targets, expands recovery spacing between hard workouts, increases low-intensity Zone 1 volume bias, and raises `FuelingStrategy` targets (+150–200 mg/hr sodium and 25–30g post-run recovery protein) to counter progesterone-induced catabolism and elevated core body temperature.

3. **Privacy, Onboarding & Health Ingestion:**
   - Prompts the user during initial onboarding with an opt-in toggle.
   - All cycle dates and phase logs are stored 100% on-device in local encrypted storage (`PreferencesStorage`) and never transmitted to external servers. When disabled, planning defaults to standard neutral periodization.
   - Cycle tracking syncs with OS Health APIs (Apple HealthKit / Health Connect) when available, falling back seamlessly to an on-device dynamic day-count model (`lastPeriodStartDate` + configurable cycle length) with a one-tap "Period Started Today" re-anchor button.

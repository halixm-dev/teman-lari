# 0004: Concurrent Strength Periodization

We decided to integrate resistance training as a first-class, periodized companion system directly within Teman Lari's running engine, rather than treating strength as an uncoordinated secondary activity or uncoupled video library.

To mitigate the concurrent training interference effect (competing AMPK and mTOR intracellular signaling pathways and eccentric muscle damage):
1. **Intra-Day Pairing & "Hard Days Hard":** Heavy resistance sessions are scheduled on the same days as quality interval/tempo runs ("hard days hard") with a mandatory $\ge 6$-hour recovery separation (Quality Run AM $\to$ Lift PM). This preserves dedicated rest and recovery days. Heavy lower-body lifting is strictly forbidden within 24 hours prior to quality interval/tempo workouts or long runs.
2. **Phase-Synchronized Periodization:** Strength volume and intensity dynamically synchronize with the running mesocycle:
   - *Base Phase:* Hypertrophy, tissue capacity, and connective tissue durability.
   - *Build Phase:* High-intensity, low-volume neuromuscular maximal strength (tendon stiffness and running economy).
   - *Deload / Race Taper:* Automatic 50% volume cut, eliminating heavy eccentric lower-body lifts in favor of mobility and runner prehab.
3. **Domain Representation:** An immutable `StrengthWorkout? companionStrength` property is attached to `TrainingDay`, configured via `strengthDaysPerWeek` (0–3, default 2) and equipment preferences (gym barbells vs home dumbbells/bodyweight) across 3 runner-specific archetypes: Neuromuscular Max Strength, Runner Prehab & Durability, and Mobility/Recovery.

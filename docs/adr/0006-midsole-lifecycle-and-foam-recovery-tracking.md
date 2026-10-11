# 0006: Midsole Mechanical Lifecycle and Foam Recovery Tracking

We decided to replace passive, static shoe mileage counters with a dynamic midsole mechanical tracking system that accounts for foam rebound recovery windows and non-linear super-foam degradation.

1. **Strava Gear Ingestion & Domain Enrichment:**
   - Existing shoes are ingested from the Strava Athlete API (`gear_id`) and enriched locally in Teman Lari with functional category (`dailyTrainer`, `maxCushionRecovery`, `tempoWorkout`, `raceDayPlated`) and foam chemistry (`supercriticalPebaTpu` vs `traditionalEva`).
   - Shoe assignment occurs post-run during completed activity ingestion/logging, matching user preference rather than algorithmic forward prescription.

2. **Dynamic 24–48h Foam Rebound Tracking:**
   - Midsole foams experience acute cell compression during prolonged runs, requiring time to restore optimal shock attenuation.
   - The engine tracks hours elapsed since last run per shoe. If the runner logs consecutive sessions in the same compressed pair within its rebound window (24h standard, 48h following runs $>15$ km or $>90$ min), the app surfaces a foam fatigue warning advising a rotation to an uncompressed pair to protect soft tissues.

3. **Compound-Specific Non-Linear Lifecycle:**
   - Rather than a flat generic 650–800 km odometer, retirement and performance thresholds adapt to foam chemistry:
     - *PEBA Super-Foams:* 350–450 km total lifecycle, with an early "Performance Degradation" alert at 300 km (signaling loss of optimal energy return for peak racing).
     - *Traditional EVA / TPU:* 600–800 km lifecycle, with a cushioning loss alert at 550 km.
     - Custom user target overrides supported per shoe.

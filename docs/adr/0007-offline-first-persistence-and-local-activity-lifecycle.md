# 0007: Offline-First Persistence and Local Activity Lifecycle

We decided to eliminate cache expiration and elevate the local Hive database to the permanent Single Source of Truth (SSOT) for all activity data, training plans, and physiological metrics, decoupling the app from continuous network connectivity.

1. **Permanent Local SSOT (Zero-TTL Persistence):**
   - The 1-hour time-to-live expiration on cached activities and heart rate streams is eliminated. Local records persist indefinitely and serve all UI screens, analytics isolates, and plan generation engines directly from disk.

2. **Dual Offline Activity Ingestion:**
   - *In-App Workout Auto-Save:* Completed sessions tracked via `RunSessionScreen` (GPS and pedometer) are automatically synthesized into `Activity` domain entities with local timestamp-based unique IDs (negative integers) and committed to Hive immediately upon session completion.
   - *Manual Run Entry:* A manual run entry interface allows athletes to log runs completed without mobile GPS tracking (specifying date, distance, duration, perceived exertion, and assigned shoe).

3. **Autonomous On-Device Analytics:**
   - All physiological computations—including Acute Training Load (ATL), Chronic Training Load (CTL), Training Stress Balance (TSB), and heart rate zone distribution—execute completely on-device without outbound network calls.

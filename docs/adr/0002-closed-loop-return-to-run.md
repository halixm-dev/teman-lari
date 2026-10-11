# 0002: Closed-Loop Return-to-Run Rehabilitation

We decided to introduce a closed-loop, subjective pain feedback system into Teman Lari's `ReturnContext` and `ReturnPlanStrategy` to replace open-loop, purely calendar-based return ramps with clinically grounded tissue-load monitoring.

Athletes log subjective tissue irritability via a dual-window Visual Analog Scale (VAS 0–10) check-in: immediately post-run and the morning after. The engine enforces a 3-tier reactive state model:
1. **Pass (VAS $\le$ 3/10 and morning baseline cleared):** Progresses the volume ramp normally.
2. **Warning (VAS 3.1–5/10 or lingering morning stiffness):** Holds current weekly stage and mandates 48 hours of recovery before repeating the session.
3. **Flare-up (VAS $>$ 5/10 or acute sharp pain):** Regresses the plan by 1 stage, applies an immediate 30% volume reduction, and enforces 48–72 hours of non-impact cross-training.

Athletes can configure their preferred re-entry workout modality (graded walk/run intervals vs. continuous easy runs) in their preferences. Graduation from rehabilitation requires explicit user confirmation via an in-app readiness prompt once scheduled ramp weeks are completed.

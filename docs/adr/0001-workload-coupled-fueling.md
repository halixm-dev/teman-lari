# 0001: Workload-Coupled Fueling Model

We decided to couple endurance fueling and hydration guidance directly to scheduled workouts in `TrainingDay` via an immutable `FuelingStrategy` domain entity, rather than treating nutrition as an external consideration or relying on separate third-party trackers. 

Fueling targets are dynamically computed across a 3-Phase Window (Pre-Run priming, Intra-Run fueling/hydration, and Post-Run recovery) using planned workout duration (`targetMinutes`) and workout intensity (`WorkoutType`). Easy aerobic runs under 60 minutes are gated to hydration-only, while quality sessions ($\ge 45$ min) and long runs ($\ge 60$ min) receive scaled carbohydrate ($30\text{--}90\,\text{g/hr}$), fluid, and electrolyte recommendations, alongside progressive "Gut Training" periodization for marathon-distance builds.

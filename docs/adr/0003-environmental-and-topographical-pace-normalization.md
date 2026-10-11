# 0003: Real-Time Environmental and Topographical Pace Normalization

We decided to normalize running pace prescriptions and historical load calculations for environmental conditions (heat, humidity, and dew point) and terrain topography (slope/grade), rather than assuming flat-terrain and temperate conditions.

Topographical normalization applies Minetti's metabolic cost polynomial to calculate Grade Adjusted Pace (GAP) for post-run telemetry (improving threshold pace and TSS estimation accuracy from hilly runs) and advisory workout pacing on hilly routes. 

Thermal normalization uses the Temperature + Dew Point Sum index ($^\circ\text{C}$ or $^\circ\text{F}$) to de-rate prescribed target pace bands by 1% to 10%+ during high heat and humidity. A pluggable `WeatherRepository` seam fetches local forecasts via a free service (e.g., Open-Meteo), supports manual slider overrides, and gracefully falls back to neutral conditions when offline. In the UI, workouts prominently display the adjusted pace with a pill showing the offset, base pace, and the physiological rationale (preserving the intended cardiovascular training zone).

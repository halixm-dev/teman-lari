# 02: Welcome and Value Orientation (Step 1)

**What to build:** The complete Step 1 onboarding experience that greets new athletes and presents Teman Lari's core value propositions without cognitive fatigue. The view features branded typography, energetic styling, and clear visual cards highlighting the app's three pillars: Offline-First Tracking (zero-TTL SSOT local database), Autonomous On-Device Analytics (ATL/CTL/TSB calculated on phone), and Adaptive Plan Generation (periodized multi-week plans tailored to runner workload). An intuitive forward action ("Get Started") smoothly advances the athlete to demographic setup.

**Blocked by:** 01: First-Launch Routing and Onboarding Shell

**Status:** resolved

- [x] Step 1 view renders welcoming hero typography, brand styling (`AppColors.brandOrange`), and dark mode support
- [x] Step 1 view clearly presents three core value cards: Offline-First Tracking, Autonomous On-Device Analytics, and Adaptive Plan Generation
- [x] Responsive layout centers content and enforces max-width constraints on tablet and desktop screens
- [x] Clear call-to-action button ("Get Started" / "Continue") advances the onboarding sequence to Step 2
- [x] Visual indicators (step indicator / dots) reflect progress on Step 1 of 2
- [x] Automated widget tests verify all three value proposition cards are rendered and tapping "Get Started" transitions to Step 2

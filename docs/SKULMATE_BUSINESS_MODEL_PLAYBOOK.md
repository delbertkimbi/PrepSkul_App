# SkulMate Business Model Playbook

## What Is Implemented Now

- Per-generation **cost + credits estimate** is returned by `/api/skulmate/generate`.
- Per-user usage is logged in `skulmate_usage_events` (migration `072_skulmate_usage_events.sql`).
- Batch estimator endpoint is available at `/api/skulmate/cost-estimate` for "X games" planning.

This means we can now estimate:
- cost per game
- credits per game
- user/month cost and margin

---

## Recommended Credit Logic

Keep credits simple for users while reflecting backend cost:

- **1 credit**: text/PDF game (normal length)
- **2 credits**: image OCR game
- **+1 credit**: very long notes or very large generated set

Internal estimator already returns this as `estimatedCredits`.

---

## Suggested Pricing Tiers (Cameroon-first)

Use subscription + top-up hybrid:

- **Free**: 3 games/day (text/PDF), image OCR optional but limited
- **Starter**: 600 credits/month
- **Pro**: 2500 credits/month
- **Top-ups**: 200 / 500 / 1500 credits packs

Why this model:
- low friction onboarding via free tier
- predictable monthly spend for regular learners
- flexible top-ups for heavy image/OCR users

---

## How To Compute Cost for X Games

Use API:

- `POST /api/skulmate/cost-estimate`
- body example:

```json
{
  "games": 1000,
  "imageRatio": 0.35,
  "avgTextChars": 4500,
  "avgItemsPerGame": 12
}
```

Returns:
- per-game estimated USD + credits
- total estimated USD + credits
- suggested packaging defaults

---

## Industry Reference (Benchmark Direction)

Approximate public benchmarks (region/store dependent):

- Quizlet paid tier around annual + monthly bundles (roughly mass-market mid-range)
- Duolingo Super uses strong annual discount vs monthly
- Photomath Plus uses feature gating + subscription + promos

Takeaway for SkulMate:
- annual/monthly pricing ladder works
- free tier should be usable but not enough for power users
- keep OCR and premium generation in paid/credit buckets

---

## Rollout Plan

1. Apply migration `072_skulmate_usage_events.sql`.
2. Deploy `PrepSkul_Web` changes.
3. Monitor `skulmate_usage_monthly` for 1-2 weeks.
4. Lock final tier prices after real usage distribution (text vs image ratio).
5. Enforce credit deductions once confidence is high.

# SkulMate Pricing Decision Memo

## Objective

Define practical launch pricing for SkulMate based on estimated backend usage/cost, then map that to a sustainable credit model.

This memo is meant for decision-making (not just technical notes).

---

## Inputs Used

- Cost model: `PrepSkul_Web/lib/skulmate/costing.ts`
- Usage analysis: `prepskul_app/docs/SKULMATE_USAGE_AND_PRICING_ANALYSIS.md`
- Existing credit schema: `prepskul_app/supabase/migrations/038_user_credits_system.sql`
- New metering table: `prepskul_app/supabase/migrations/072_skulmate_usage_events.sql`

---

## Unit Economics (Current Estimates)

From estimator scenarios:

- Text/PDF typical game: **$0.0018**
- Image typical game: **$0.0024**
- Hard image game: **$0.0039**
- Worst-case image game: **$0.0066**

Mixed workload (35% image / 65% text):

- Average cost/game: **$0.0020**
- Average credits/game: **1.35**

Implication:
- 1,000 games cost about **$2.05**
- 10,000 games cost about **$20.45**

---

## Credit Model (Recommended)

Keep it simple for users:

- `1 credit`: normal text/PDF game
- `2 credits`: image OCR game
- `3-4 credits`: large/complex image game (long notes, many items)

This protects against OCR-heavy abuse without punishing normal users.

---

## Suggested User Pricing (XAF)

Cameroon-first, low-friction entry:

### Subscription

- **Starter**: 600 credits/month at **2,000 XAF**
- **Pro**: 2,500 credits/month at **5,000 XAF**

### Top-up packs

- 200 credits at **1,000 XAF**
- 500 credits at **2,000 XAF**
- 1,500 credits at **5,000 XAF**

### Free tier

- 3 games/day (with fair-use controls)

---

## Why These Numbers Work

1) They are easy to explain to users.
2) They map naturally to usage intensity.
3) They provide enough margin for:
- model fallbacks
- OCR retries
- support and infra overhead

Even with worst-case OCR spikes, these packages remain viable if credit enforcement is active.

---

## Risk Controls

To avoid cost blowups:

- enforce daily free-tier cap
- enforce credit deduction before/at generation completion
- apply max OCR retry cap per request
- monitor p90/p95 cost per game monthly using `skulmate_usage_events`

---

## 30-Day Launch Plan

Week 1:
- Deploy metering + OCR hardening
- Enable free tier + top-up only

Week 2:
- Inspect actual source mix (image vs text), p90 game cost
- tune credit weights if needed

Week 3:
- Enable Starter and Pro subscriptions

Week 4:
- Review conversion and churn
- adjust pack sizes/prices if needed

---

## Decision Recommendation

Launch now with:

- Free: 3/day
- Starter: 600 credits at 2,000 XAF
- Pro: 2,500 credits at 5,000 XAF
- Top-ups: 200/500/1,500 credits

Then reprice only after 2-4 weeks of real usage telemetry.

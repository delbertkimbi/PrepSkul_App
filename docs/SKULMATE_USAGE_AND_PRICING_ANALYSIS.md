# SkulMate Usage and Pricing Analysis

## Why This Document

This is the concrete analysis requested: how much SkulMate uses per game, what that means for cost at scale, and how to price sustainably.

Assumptions in this document come from the implemented estimator in `PrepSkul_Web/lib/skulmate/costing.ts`.

---

## 1) Cost Model Used

Per game estimated cost is:

- `entitiesUsd` (content analysis)
- `generationUsd` (game creation)
- `ocrUsd` (image OCR only)
- `safetyMarginUsd` = 25% of subtotal (retry/fallback buffer)

Then:

- `estimatedCostUsd = subtotal + safetyMarginUsd`
- `estimatedCredits`:
  - base `1`
  - `+1` if image source
  - `+1` if text > 12,000 chars
  - `+1` if items > 20

---

## 2) Per-Game Cost Scenarios

Calculated from the same formulas used in code.

| Scenario | Estimated USD/game | Estimated credits |
|---|---:|---:|
| Text (small) | 0.001243 | 1 |
| Text (typical) | 0.001835 | 1 |
| PDF (heavy structured) | 0.004312 | 1 |
| Image (typical, 2 OCR attempts) | 0.002436 | 2 |
| Image (hard, 4 OCR attempts) | 0.003890 | 2 |
| Image (worst, 6 OCR attempts + long + many items) | 0.006631 | 4 |

Interpretation:
- Typical text/PDF workloads are very cheap.
- Image-heavy worst-case costs are meaningfully higher but still manageable with credits.

---

## 3) Scale Cost for X Games

Example mixed workload:
- 35% image games
- 65% text games
- typical payload sizes

Derived average:
- `~$0.002045` per game
- `~1.35 credits` per game

### Volume projections

| Games | Estimated total cost (USD) | Estimated total credits |
|---:|---:|---:|
| 1,000 | 2.0454 | 1,350 |
| 10,000 | 20.4535 | 13,500 |

If traffic shifts toward harder image OCR, costs rise; this is why OCR should consume more credits.

---

## 4) Recommended Credit Economics

Use simple user-facing credits and protect margin:

- 1 credit: text/PDF standard game
- 2 credits: image game (OCR path)
- 3-4 credits: long/complex image game

This aligns with resource consumption and is already supported by estimator output.

---

## 5) Pricing Recommendation (Cameroon-first)

Use subscription + top-up hybrid:

1. Free
- 3 games/day
- prioritize text/PDF; throttle image OCR volume

2. Starter
- 600 credits/month

3. Pro
- 2500 credits/month

4. Top-up packs
- 200 / 500 / 1500 credits

Reasoning:
- predictable monthly plans for active students
- occasional users can buy packs
- OCR-heavy users pay fairly for higher compute usage

---

## 6) Benchmark Direction (How Others Charge)

Major edtech patterns (Quizlet, Duolingo, Photomath style):
- free core experience
- paid plan removes limits / unlocks premium AI features
- annual discount to improve retention and cash flow
- optional family or top-up model for flexibility

SkulMate should follow this:
- free but useful
- premium for volume + best OCR experience
- top-ups for spiky usage

---

## 7) What to Measure Before Final Price Lock

After 1-2 weeks in production, query:

- average cost/game by source type (image vs text)
- credit consumption per user segment
- p50 / p90 OCR attempts on image uploads
- conversion from free to paid at credit boundary

Example SQL (monthly user-level view is already created):

```sql
select *
from public.skulmate_usage_monthly
order by month desc, total_estimated_cost_usd desc;
```

And for source mix:

```sql
select
  date_trunc('month', created_at) as month,
  source_type,
  count(*) as events,
  avg(estimated_cost_usd) as avg_cost_usd,
  avg(estimated_credits) as avg_credits
from public.skulmate_usage_events
where event_type = 'generate_game'
group by 1,2
order by 1 desc, 2;
```

---

## 8) Final Recommendation

- Keep OCR hardening and fallback logic (already implemented).
- Launch with credit model now (1/2/3/4 credits by workload).
- Use actual `skulmate_usage_events` for a short calibration window.
- Lock public price points after real usage confirms p90 costs.

This gives you controlled cost, fair user pricing, and clear path to scale without surprises.

# skulMate Credits Usage & Prizing

## Where to Get the Migration

**File:** `prepskul_app/supabase/migrations/060_skulmate_session_source.sql`

**What it does:** Adds `individual_session_id` to `skulmate_games` and expands `source_type` to include `'session'`.

**How to apply:**
1. **Supabase Dashboard:** SQL Editor → paste contents of `060_skulmate_session_source.sql` → Run
2. **CLI:** `supabase db push` (if using Supabase CLI) or `supabase migration up`

---

## OpenRouter Credits for skulMate

skulMate uses **`SKULMATE_OPENROUTER_API_KEY`** for all AI features. Usage is separate from TichaAI.

### What Uses Credits

| Feature | Endpoint/File | Typical Cost |
|---------|---------------|--------------|
| **Game generation** | `/api/skulmate/generate` | ~\$0.01–0.05 per game |
| **Flashcard explain** | `/api/skulmate/explain` | ~\$0.005–0.02 per explain |
| **Entity extraction** | `/api/skulmate/extract-entities` | ~\$0.005–0.02 per extraction |
| **Session challenge** | `/api/skulmate/challenge/from-session` | ~\$0.01–0.05 per challenge |
| **Image OCR** (notes) | `lib/skulmate/extract.ts` | ~\$0.01–0.10 per image |

### Models Used

- **Game / explain / entity / challenge:** `openai/gpt-4o-mini`, `mistralai/mistral-7b-instruct`, `meta-llama/llama-3.2-3b-instruct`
- **Image OCR:** Vision models (e.g. Gemini, Qwen, Claude) via OpenRouter

### Approximate Costs (per action)

- **1 game generation:** ~\$0.02
- **1 flashcard explain:** ~\$0.01
- **1 image OCR:** ~\$0.02–0.05
- **100 games/month:** ~\$2–5
- **1000 games/month:** ~\$20–50

### How to View Usage

1. OpenRouter: https://openrouter.ai/activity  
2. Filter by `SKULMATE_OPENROUTER_API_KEY`  
3. See per-call usage and cost

---

## Prizing Options

### 1. Free Tier + Limits

- Example: 5 free games per day, then require subscription or credits
- Track usage in Supabase (e.g. `user_game_stats` or a new `skulmate_usage` table)

### 2. In-App Credits

- Use existing `user_credits` (from `038_user_credits_system.sql`)
- Deduct credits per game/explain (e.g. 1 credit = 1 game)
- “Buy credits” flow in the app

### 3. Subscription Tiers

- Basic: X games/month  
- Premium: Unlimited or higher limits  
- Link to Stripe/Fapshi for payment

### 4. Hybrid

- Free: Limited games (e.g. 3/day)  
- Paid: Unlimited or higher limits  
- Optional: One-time credit packs for occasional use

### 5. OpenRouter Cost → User Price

- Estimate cost per action (e.g. \$0.02 per game)
- Add margin (e.g. 2x → \$0.04 per game, or bundle into subscription)
- Expose as “credits” or “uses” to keep pricing simple

---

## Next Steps

1. Decide prizing model (free limits vs credits vs subscription)
2. Add usage tracking if not present (e.g. `skulmate_api_calls` or extend `user_game_stats`)
3. Add UI for limits/credits (e.g. “3 games left today”)
4. Implement payment flow (if monetizing)

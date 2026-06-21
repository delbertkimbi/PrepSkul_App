-- ======================================================
-- MIGRATION 095: SkulMate revision packages + free limit swap
-- Admin-editable credit packages; documents 4 / images 2 per day.
-- ======================================================

ALTER TABLE public.skulmate_pricing
  ADD COLUMN IF NOT EXISTS revision_packages JSONB NOT NULL DEFAULT '[
    {
      "id": "starter",
      "title": "Starter",
      "subtitle": "Good for consistent weekly revision",
      "credits": 600,
      "amount_xaf": 2000,
      "original_amount_xaf": 4000,
      "is_popular": false,
      "sort_order": 1,
      "cta": "Start Starter",
      "benefits": [
        "Generate games from your notes quickly",
        "Play saved games offline anytime",
        "Challenge friends and classmates"
      ]
    },
    {
      "id": "pro",
      "title": "Pro",
      "subtitle": "Best for exam periods and daily study",
      "credits": 2500,
      "amount_xaf": 5000,
      "original_amount_xaf": 10000,
      "is_popular": true,
      "sort_order": 2,
      "cta": "Go Pro",
      "benefits": [
        "Higher daily generation capacity",
        "Handles heavier image and document uploads",
        "Best value for serious daily learners"
      ]
    },
    {
      "id": "elite",
      "title": "Elite",
      "subtitle": "For families and power users",
      "credits": 5000,
      "amount_xaf": 9000,
      "original_amount_xaf": 18000,
      "is_popular": false,
      "sort_order": 3,
      "cta": "Choose Elite",
      "benefits": [
        "Highest headroom for intensive revision",
        "Great for weekly challenges with friends",
        "Maximum continuity for power users"
      ]
    }
  ]'::jsonb,
  ADD COLUMN IF NOT EXISTS promo_discount_percent NUMERIC(5, 2) NOT NULL DEFAULT 50
    CHECK (promo_discount_percent >= 0 AND promo_discount_percent <= 100);

ALTER TABLE public.skulmate_pricing
  ALTER COLUMN free_doc_text_games_per_day SET DEFAULT 4,
  ALTER COLUMN free_image_games_per_day SET DEFAULT 2;

UPDATE public.skulmate_pricing
SET
  free_doc_text_games_per_day = 4,
  free_image_games_per_day = 2
WHERE id = 1;

COMMENT ON COLUMN public.skulmate_pricing.revision_packages IS
'JSON array of SkulMate revision credit packages (prices, credits, promo amounts).';

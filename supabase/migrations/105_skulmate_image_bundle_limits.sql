-- Per-prompt image bundle limits (free vs paid tiers).
ALTER TABLE public.skulmate_pricing
  ADD COLUMN IF NOT EXISTS max_images_per_prompt_free INTEGER NOT NULL DEFAULT 3
    CHECK (max_images_per_prompt_free >= 1 AND max_images_per_prompt_free <= 20),
  ADD COLUMN IF NOT EXISTS max_images_per_prompt_paid INTEGER NOT NULL DEFAULT 5
    CHECK (max_images_per_prompt_paid >= 1 AND max_images_per_prompt_paid <= 20);

UPDATE public.skulmate_pricing
SET
  max_images_per_prompt_free = COALESCE(max_images_per_prompt_free, 3),
  max_images_per_prompt_paid = COALESCE(max_images_per_prompt_paid, 5)
WHERE id = 1;

COMMENT ON COLUMN public.skulmate_pricing.max_images_per_prompt_free IS
'Max photos per SkulMate image intake for free-tier users.';
COMMENT ON COLUMN public.skulmate_pricing.max_images_per_prompt_paid IS
'Max photos per SkulMate image intake for users with paid credits.';

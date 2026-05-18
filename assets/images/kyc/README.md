# KYC mascot illustrations (optional)

Add these PNGs to enable image heroes on **submitted** and **pending** verification screens. The app works without them (vector fallback cat).

| File | Use | Prompt |
|------|-----|--------|
| `kyc_submitted.png` | Step 4 + success state | Flat 2D cartoon PrepSkul friendly bear mascot holding a checkmark document envelope, relieved happy mood, deep blue `#1B2C4F` and soft sky blue accents, white background, minimal line art, no text, 4:3 |
| `kyc_pending.png` | Pending review screen | Flat 2D cartoon c with hourglass and calm waiting expression, document stack nearby, deep blue palette, white background, no text, 4:3 |

Style: match PrepSkul brand bear mascot; friendly, not childish; no readable text in the image.

**Format:** Save as real PNG (not JPEG renamed to `.png`). After adding files, run `flutter pub get` and **fully restart** the app — hot reload does not load new assets.

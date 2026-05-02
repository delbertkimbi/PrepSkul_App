# Plan: Agreements, KYC Notice, and Public Legal Pages

**Status:** To build  
**Scope:** Public legal pages (Next.js), KYC notice when parents/learners choose onsite or hybrid, agreement acceptance at booking (parents/learners) and at onboarding (tutors). Covers **payments** (no off-platform, dispute rules) and **platform abuse** (zero tolerance for tutor or parent).  
**Related:** [PLAN_PARENT_LEARNER_KYC_ONSITE.md](PLAN_PARENT_LEARNER_KYC_ONSITE.md) (actual KYC collection flow), [RESPONSE_TO_LEGAL_AND_OPERATIONAL_FEEDBACK.md](RESPONSE_TO_LEGAL_AND_OPERATIONAL_FEEDBACK.md), [ONSITE_SESSIONS_HOW_WE_MANAGE_FINAL_PITCH.md](ONSITE_SESSIONS_HOW_WE_MANAGE_FINAL_PITCH.md).

---

## 1. Next.js: Public legal pages and footer

- **Safeguarding Policy** – `PrepSkul_Web/app/[locale]/safeguarding/page.tsx`: parent/guardian presence for minors, visible-area sessions, no closed-door one-on-one with minor, no inappropriate contact, reporting/suspension, **zero tolerance for abuse by tutors or parents** (harassment, false disputes, threats).
- **Code of Conduct** – `PrepSkul_Web/app/[locale]/code-of-conduct/page.tsx`: professionalism, **no off-platform payments**, truthful info, no harassment/abuse, no false reports or dispute gaming, adherence to safeguarding.
- **Footer** – Add links to Safeguarding and Code of Conduct in `PrepSkul_Web/components/footer.tsx` (and translations if needed).
- **Terms (existing)** – Ensure payment rules and acceptable use (no abuse of disputes, no harassment) are covered; parents accept Terms at booking.

---

## 2. Parent/Learner onboarding: KYC notice

When user selects **In-Person** or **Hybrid** in the “Preferred Location” step:

- **parent_survey.dart** – In `_buildLearningLocation()`, show KYC notice below options when `_preferredLocation == 'In-Person' || _preferredLocation == 'Hybrid'`.
- **student_survey.dart** – Same in equivalent step.
- **add_child_profile_screen.dart** – Same if it has Preferred Location with In-Person/Hybrid.

**Copy:** “If you book a tutor for onsite sessions, you’ll be required to complete identity verification (KYC) when booking your first onsite session—after the tutor accepts your request and before payment.”

---

## 3. Booking flow: KYC notice and agreement acceptance

- **Location step:** When `_selectedLocation` is `onsite` or `hybrid`, show the same KYC notice below `LocationSelector` in `book_tutor_flow_screen.dart`.
- **Review step:** In `BookingReview`, add Agreements block: two checkboxes – “I agree to the Terms of Service” and “I agree to the Safeguarding Policy” (links open prepuskul.com/[locale]/terms and /safeguarding). Require both before “Send Request” is enabled. `BookTutorFlowScreen` holds state and passes callback; `_canProceed()` for last step requires both agreed.
- **Persistence:** Pass `agreedToTermsAt` and `agreedToSafeguardingAt` to `BookingService.createBookingRequest`; add columns `agreed_to_terms_at`, `agreed_to_safeguarding_at` to booking_requests (migration).

---

## 4. Tutor onboarding: Code of Conduct and Safeguarding

- In **tutor_onboarding_screen.dart**, add sixth item to `_finalAgreements`: key `'code_of_conduct_safeguarding'`.
- Text: “I have read and agree to the Code of Conduct and Safeguarding Policy.” with tappable links to prepuskul.com/en/code-of-conduct and /safeguarding.
- Persist in existing `final_agreements` JSONB (no schema change).

---

## 5. Payments and platform abuse (content)

- **Terms:** Payment rules (platform-only, when we release tutor pay, refund/cancellation, no abuse of disputes/chargebacks); acceptable use (no harassment, fraud, abuse of dispute/payment systems); breach → suspend/bar.
- **Safeguarding:** Zero tolerance line for abuse by tutors (no-show, harassment, misconduct) or parents (harassment of tutor, false “didn’t happen” claims, threats); we warn, suspend, or bar; link to “Report issue” and evidence-based resolution.
- **Code of Conduct:** No off-platform payments; no harassment/abuse; no false reports or dispute gaming; suspend/bar for breach.

---

## 6. Order of implementation

1. Next.js: Safeguarding + Code of Conduct pages + footer links (+ Terms review for payments/abuse).
2. Flutter – Surveys: KYC notice in parent_survey, student_survey, add_child.
3. Flutter – Booking: KYC notice on location step; agreement block in BookingReview; state and validation in BookTutorFlowScreen; BookingService + migration for agreement timestamps.
4. Flutter – Tutor: Sixth agreement (Code of Conduct + Safeguarding) with links in onboarding.

---

*Full plan with file paths and implementation notes: see Cursor plan “Agreements KYC and Public Legal Pages” or `.cursor/plans/`.*

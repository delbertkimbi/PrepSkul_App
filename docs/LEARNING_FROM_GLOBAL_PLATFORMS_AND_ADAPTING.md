# Learning from Global Platforms & Adapting for PrepSkul

**Context:** We run a home-visit tutoring marketplace in Cameroon and across Africa. We need to learn from scalable two-sided platforms (Airbnb, Uber, tutoring/care platforms) and adapt their trust, safety, and verification practices to **our level of risk**, **our unique context** (education, accessibility, many users without national ID), and **everyday users**—so we keep education accessible and interactive without copying blindly.

---

## 1. What we can learn (by platform)

### Airbnb (home stays – high trust, someone enters your home)

| What they do | What we can adapt |
|--------------|-------------------|
| **Both sides verified:** 100% of guests and primary hosts must complete identity verification (name, address, government ID, selfie; some regions use facial match to ID). | **Two-sided verification for onsite:** We already verify tutors (ID + certs). Add **one-time KYC for the person booking onsite** (first time), so we know who is hosting. |
| **Guests don’t see host’s ID; hosts don’t see guest’s ID.** Hosts only see: name, age band, “ID added,” profile photo. | **Same:** Tutors never see parent/learner documents. They only see a “Verified” or “Booking verified” badge. |
| **Verification required to book / get booked.** No verification → calendar blocked or can’t book. | **Require KYC before first onsite payment.** No verification → can’t complete payment for that first onsite booking. Online-only can stay as today. |
| **Badge:** “Identity verified” on profile. | **Badge:** “Booking verified” or “Identity verified” on the session/booking for the tutor’s peace of mind. |

**Risk level comparison:** Airbnb = stranger in your home, overnight. Our onsite = tutor in the home for a fixed session, no overnight. Our risk is real but different; we don’t need the same depth (e.g. selfie match) at day one. We can start with **document upload + admin review** and add selfie/automated match later if we scale.

---

### Uber (ride-hail – medium trust, driver and rider in a car)

| What they do | What we can adapt |
|---------------|-------------------|
| **Driver verification:** ID, licence, vehicle docs; ongoing checks. | **We already do:** Tutor ID + certificates at onboarding; we can stress this in the pitch. |
| **Rider verification:** Required when payment is “anonymous” (e.g. prepaid card, gift card) or when risk-flagged. Government ID + selfie; facial match to ID. Drivers see “Verified rider” badge, not the ID. | **Adapt:** For onsite, the “rider” is the household. Verify the **person who books/pays** (first time). No need for selfie match initially—document + admin review is enough. Tutor sees “Verified” badge. |
| **Real-time tracking:** Trip shared with trusted contacts; driver location during trip. | **We already do:** Location shared during active onsite session; check-in at venue; continuous location checks. Good parallel. |
| **Incident reporting:** Both sides can report; support and safety team follow up. | **We already do:** “Something wrong? Report issue” → safety incident → admin. Keep growing this. |

**Risk level:** Uber = closed car, short trip. We have a fixed location (the home) and a longer session. Our “tracking” (check-in + location during session) is the right level; we don’t need live GPS for the whole session like a ride.

---

### Wyzant / Preply (tutoring – in-person and online)

| What they do | What we can adapt |
|--------------|-------------------|
| **Wyzant:** No mandatory tutor background check; parents can *order* one (paid). Safety tips: meet in public, adult present for under 18, pay through platform. | **We go further for onsite:** We require tutor ID + certs at onboarding. We can add **parent/learner KYC for onsite (first time)** so it’s not only “tips” but a product rule. We already say “adult present or reachable” in the pitch. |
| **Preply:** Tutors must verify identity (passport or government ID) before they can withdraw earnings. | **We align:** Tutor verification at onboarding; we can make it explicit that “earnings are gated until we have verified ID and credentials.” |
| **In-person safety:** “Meet in public,” “adult present for minors.” | **We adapt:** For *home* visits we can’t require “public only,” but we *can* require verified household (KYC) + “adult present or reachable” + reporting channel. That’s our version of “in-person safety” for home. |

**Risk level:** Their in-person is often in public (library, café). Our onsite is in the home—higher accountability need. So we do *more* on verification and session proof (check-in, location, incidents) than a typical “meet in a café” tutoring platform.

---

### Care.com–style (care in the home)

- Caregivers and families both have profiles; background checks often paid by family or offered by platform.
- **Lesson:** For “someone in your home,” verifying both sides is industry practice. We’re right to add parent/learner KYC for onsite so we’re not only verifying the tutor.

---

## 2. Our risk level and unique context

| Dimension | Airbnb / Uber | Wyzant (in-person) | PrepSkul onsite |
|-----------|----------------|-------------------|------------------|
| **Where** | Host’s home / car | Often public | Learner’s home |
| **Who’s verified** | Both sides (ID, sometimes selfie) | Tutor often; family sometimes optional | Tutor today; add family for onsite (first time) |
| **Tracking** | Trip/location | Usually none | Check-in + location during session |
| **Payment link** | Strong (pay on platform) | Pay on platform | We already gate pay on proof + no dispute |

**Our unique context:**

- **Education and accessibility:** We want to **not exclude** students who don’t have a national ID (minors, or adults in regions where ID penetration is low). So we **accept parent/guardian ID** when the learner doesn’t have one, and we **accept multiple document types** (national ID, passport, voter card, driver’s licence, etc.) so everyday users can verify.
- **Cameroon and Africa:** Document mix and “whose ID” must reflect reality: many households have one adult with some form of ID (voter card, passport, national ID). We design for that.
- **Mobile-first, low friction:** We keep verification **one-time for onsite** and **only when needed** (first onsite booking before payment). We don’t ask for re-verification every booking or heavy selfie flows until we need to scale that.

---

## 3. What we truly need from them (and what we don’t)

**Take from them:**

- **Two-sided verification for “someone in the home”:** Verify both tutor and booking party for onsite (we add parent/learner KYC).
- **Other side never sees the document:** Tutor only sees “Verified” badge (like Airbnb host seeing “ID added,” not the ID).
- **Verification gated to the risky action:** For us, that’s “first onsite payment” (like Uber gating verification when you use anonymous payment).
- **Clear incident and reporting flow:** We already have this; we keep improving it.
- **Document diversity:** Like Africa-focused providers (Sumsub, IdentityPass, etc.): accept multiple doc types and, later, non-doc or NIN/BVN-style verification where available.

**Don’t copy blindly:**

- **We don’t need** full facial-match-to-ID at launch; admin review of uploaded ID is enough to start.
- **We don’t require** verification for online-only sessions; risk is lower, and we want to keep signup and booking simple.
- **We don’t block** users who don’t have a national ID; we allow parent/guardian ID and multiple document types so we stay inclusive.

---

## 4. Adapting for everyday users (Cameroon and Africa)

**Principle:** Safety and accountability should be **built in**, but the product must stay **accessible** and **understandable** for everyday users—parents, guardians, and learners who may be first-time platform users or have limited formal ID.

**Concrete adaptations:**

1. **“Whose ID?”**
   - Explicit option: **My ID** (parent/guardian) or **Parent/guardian ID** (e.g. learner booking, uploading the adult’s ID).
   - Copy: “Many students don’t have ID yet—you can upload the responsible adult’s ID (front and back).”

2. **Which documents**
   - Accept: National ID, passport, voter card, driver’s licence (and, if needed, “Other” with admin review).
   - Show a short list in the app so users know what they can use (e.g. “National ID, Passport, Voter card, or Driver’s licence”).

3. **When we ask**
   - Only when they’re about to **pay for their first onsite session** (or at first onsite booking attempt). No verification for online-only; no repeat after first time.

4. **Language and flow**
   - Short, clear reason: “So we know who’s hosting the tutor. One-time for onsite. Your tutor will only see that you’re verified, not your document.”
   - One screen: document type → upload front → upload back (if needed) → submit. No long forms.

5. **Admin review first**
   - Start with human review (admin approves/rejects). Later we can add automated checks or a provider (e.g. Cameroon/Africa-friendly) to speed up and scale.

6. **Future: non-doc and local schemes**
   - As we grow, we can plug in **non-document verification** (e.g. phone/OTP + database match) or **local IDs** (e.g. voter DB, NIN, BVN where available) so more users can verify without a physical ID in hand.

---

## 5. One-page “what we learned and what we do”

| From | We learned | What we do at PrepSkul |
|------|------------|-------------------------|
| **Airbnb** | Verify both sides when someone enters a home; other side doesn’t see the ID. | Tutor verified at onboarding; parent/learner KYC for first onsite booking; tutor sees “Verified” badge only. |
| **Uber** | Verify when risk is higher (e.g. anonymous pay); badge for the other side. | We require KYC before first onsite payment; tutor sees “Booking verified.” |
| **Wyzant / Preply** | Tutor verification; in-person safety tips (adult present, pay on platform). | Tutor ID + certs; for home we add household KYC + “adult present or reachable” + incident reporting. |
| **Africa / inclusion** | Many users don’t have national ID; use multiple doc types and “whose ID.” | Accept national ID, passport, voter card, licence; allow parent/guardian ID when learner has none. |
| **Our context** | Education must stay accessible; safety must be real. | Onsite-only, first-time KYC; flexible docs and “parent/guardian ID”; no verification for online-only. |

---

## 6. Making education accessible and interactive (Cameroon and Africa)

- **Accessible:** We don’t lock out households that lack a national ID or where the learner is a minor. We verify the **responsible adult** and accept **multiple document types** so more families can complete onboarding and book onsite.
- **Interactive:** We keep the product simple (one-time KYC, clear copy, mobile-first) so parents and learners can focus on learning, not on complex compliance.
- **Safe and accountable:** We learn from global platforms but **adapt** to our risk (home visit, education) and our context (document availability, who books, who has ID). That’s how we grow trust and still grow access.

---

*Use this doc next to PLAN_PARENT_LEARNER_KYC_ONSITE.md and ONSITE_ACCOUNTABILITY_AND_SAFETY_PITCH.md to build and pitch a system that is both safe and inclusive.*

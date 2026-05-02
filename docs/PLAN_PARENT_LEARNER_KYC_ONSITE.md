# Plan: Parent/Learner KYC (Know Your Customer) for Onsite Sessions (First Time)

**Status:** To build  
**Scope:** Onsite sessions only, first time per account (or per household)  
**Goal:** Verify the identity of the person booking before they pay for their first onsite session, so we know who is hosting the tutor. Keeps accountability two-sided and supports the pitch: “We verify both sides for onsite.”

---

## 1. Why build it

- **Accountability both ways:** Tutors are already verified (ID + certificates). Verifying the booking party for onsite reduces “anonymous host” risk and helps if there’s theft, harassment, or a safety incident.
- **Pitch/investor story:** “We verify both sides for onsite: tutor at onboarding, and the person booking before their first onsite payment.”
- **Evidence:** If something goes wrong, we have identity on file for the household.

**Trade-off:** Some friction at first onsite booking. Limiting to **onsite only** and **first time only** keeps friction low.

---

## 2. Who must verify

- The **person who owns the booking and pays** (usually the parent/guardian, sometimes the learner if they book and pay).
- **One verification per account** (or per household, depending on product choice). After that, no repeat for later onsite bookings.

---

## 3. Flexible ID: learners and contexts without national ID

**Problem:** In Cameroon and across Africa, many learners (especially minors) do not have a national ID. Some adults may have other documents first (voter card, passport, etc.).

**Rule:** We need to verify **the person responsible for the booking and the household**—not necessarily the learner.

**Options to support:**

| Who is booking / paying | Whose ID we accept | Notes |
|-------------------------|--------------------|--------|
| Parent books and pays   | **Parent/guardian ID** | Default: parent uploads their own ID (front + back). |
| Learner is 18+ and books/pays | **Learner’s own ID** | If they have one. |
| Learner is minor / no ID | **Parent or guardian ID** | e.g. “Upload your parent’s or guardian’s ID (front and back).” One responsible adult per household. |
| Adult in household is not the parent in app | **Guardian ID** | Allow “Guardian” or “Responsible adult” and accept their ID so we still have one verified adult for the home. |

**In the product:**

- At the verification step, ask: **“Whose ID are you uploading?”** with options such as:
  - **My ID** (if I’m the parent/guardian)
  - **Parent/guardian ID** (if the learner is booking and will upload the adult’s ID)
- If “Parent/guardian ID,” we can optionally ask relationship (e.g. parent, guardian, other) and store it for support only.
- **One verification per account (or household):** Once any one of these is verified, we mark the account (or linked household) as “Identity verified” and don’t ask again for future onsite bookings.

---

## 4. Document types to accept (inclusive for Cameroon and Africa)

Not everyone has a national ID. Accept **multiple document types** so we don’t exclude everyday users.

**Suggested list (pick what fits your market and compliance):**

- **National ID** (front + back where applicable)
- **Passport** (photo page; back if needed)
- **Voter card / voter ID** (where available and accepted locally, e.g. Cameroon)
- **Driver’s licence** (front + back if two-sided)
- **Residence permit** (if relevant)
- **Other government-issued ID** (define per country; e.g. student ID is usually not enough for “identity” but could be a future fallback with clear disclaimer)

**In the product:**

- Dropdown or selector: **“Type of document”** → National ID, Passport, Voter card, Driver’s licence, Other.
- Then: **Upload front** (and **Upload back** for two-sided docs). For passport, “Photo page” can be the single required image initially.
- Store document type with the upload so admins know what they’re reviewing.

**Later (optional):** Integrate with a provider (e.g. Sumsub, IdentityPass, or local partners) that support **non-document verification** or **alternative docs** in Africa (e.g. NIN, BVN, voter DB) to improve pass rates and reduce reliance on physical ID only.

---

## 5. Who verifies

- **Platform (admin), not the tutor.** Admin (or an automated provider) reviews the upload and marks the account as “Identity verified.”
- **Tutor** does **not** see the actual documents. Tutor can see a **“Verified”** or **“Booking verified”** badge on the session/booking so they know the household was verified.
- This keeps verification and liability with the platform and avoids tutors doing KYC.

---

## 6. When in the flow

**Recommended:** When the **session is approved** (tutor accepted the request), **before the parent/learner can pay**:

1. User goes to pay for the approved onsite session.
2. If this is their **first onsite booking** and they are **not yet verified**, show: **“Verify your identity to complete this onsite booking”** (one-time for onsite).
3. User selects document type, uploads front (and back if needed), and optionally selects “My ID” vs “Parent/guardian ID” with short explanation.
4. Submit → admin (or provider) verifies → on approval, mark account as “Identity verified” and **unlock payment** for this booking.
5. Future onsite bookings for this account skip the step.

**Alternative:** Trigger the same step at “first ever onsite booking attempt” (e.g. when they request an onsite session), so verification is done before approval; then after tutor approves, they can pay without another block.

---

## 7. Data and storage

- Store: **account_id** (or user_id of the person who completed verification), **document_type**, **front_url** (and **back_url** if applicable), **whose_id** (self / parent / guardian), **verified_at**, **verified_by** (admin or system), **status** (pending / verified / rejected).
- Reuse existing **documents** (or similar) storage bucket; add a clear path and RLS so only the user and admins can access.
- **Privacy:** Same as tutor docs—encrypted, access logged, not shared with the other side (tutor only sees “Verified” badge).

---

## 8. Build checklist (high level)

- [ ] **Backend / DB:** Table or fields for “parent/learner identity verification” (per account or per user): document_type, front_url, back_url, whose_id, status, verified_at, verified_by.
- [ ] **Storage:** Bucket/path for KYC uploads; RLS so user and admin only.
- [ ] **App (parent/learner):** When first onsite booking is approved and user goes to pay, check if verified; if not, show KYC step (document type, front/back upload, whose ID). On submit, save and set status = pending; then allow payment only after admin sets verified (or after provider callback).
- [ ] **Admin:** List of pending verifications; view uploads; approve or reject with optional note; on approve, set account as “Identity verified” and (if needed) trigger “payment unlocked” for the waiting booking.
- [ ] **Tutor app:** Show “Booking verified” or “Identity verified” badge on the relevant session/booking card (no document access).
- [ ] **Copy:** Short explanation for users (“We verify who’s hosting for onsite sessions. One-time only. You can use your ID or your parent/guardian’s ID.”) and for “Parent/guardian ID” option (“Many students don’t have ID yet—upload the responsible adult’s ID.”).
- [ ] **Document types:** Implement at least National ID, Passport, Voter card (if applicable), Driver’s licence; add “Other” with admin review if needed.

---

## 9. Success criteria

- First-time onsite bookers cannot pay until they complete KYC (or we have a verified account).
- We support “my ID” and “parent/guardian ID” so learners without ID are not blocked.
- We accept multiple document types so users without national ID can still verify.
- Tutors see a “Verified” badge only; they never see documents.
- Admins can clear the queue and approve/reject with an audit trail.

---

*This plan extends the Onsite Safety and Admin Monitoring approach and the pitch in ONSITE_ACCOUNTABILITY_AND_SAFETY_PITCH.md.*

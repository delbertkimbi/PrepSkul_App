# How We Ensure Accountability, Security & Trackability of Onsite Sessions

**Use this when investors or pitch judges ask: *"How do you ensure accountability and security for onsite sessions? How do you reduce risk of abuse?"***

---

## The one-line answer

> **"We treat onsite like a safety surface, not just logistics. Every session is verifiable: tutor check-in at the venue, continuous location checks during the session, family confirmation and feedback, and a clear audit trail. Disputes and anomalies are flagged automatically and surfaced to our team so we can act before they become trust issues."**

---

## 1. Accountability (who did what, when)

**What we say:**

- **Tutor is the primary proof point.** Only the tutor can start and end the session. For onsite, they must **check in at the venue** (GPS within ~100 m). We record check-in time, optional selfie, and punctuality (on time / late).
- **Family has a voice.** After the session, parent or learner answers **"Did this session take place as scheduled?"** (Yes / Partially / No) with optional notes. They can also **optionally confirm start and end** in the app. So we get dual signals: tutor proof + family confirmation or dispute.
- **Payment is gated on proof and no dispute.** We don’t release tutor pay until: (1) tutor has checked in, (2) session is completed, and (3) either the family said "Yes" or no dispute was raised within 7 days. If they say "No" or "Partially," we flag it for review and hold payment until we resolve it.
- **Everything is timestamped and queryable.** We have a **session timeline** (booking → start → check-in → check-out → feedback → incidents) and a **risk score** per session so we can explain exactly what happened and why we did or didn’t pay.

**Sound bite:** *"Accountability is built in: tutor check-in proves presence, family feedback confirms or disputes it, and payment only releases when the evidence supports it."*

---

## 2. Security (physical and emotional safety)

**What we say:**

- **Location is shared only when it matters.** During an active onsite session, the family can see that the tutor is at the right place. We’re transparent: we tell the tutor *"Location is shared with the parent for safety while this session is active."* No hidden tracking.
- **Anyone in the session can report an issue.** Tutor, parent, or learner can tap **"Something wrong? Report issue"** (e.g. *"Felt unsafe," "Tutor no-show," "Location issue"*). That creates a **safety incident** and immediately notifies our admin team. We don’t wait for a survey—we get real-time signals.
- **Admins see the full picture.** Our team gets push alerts for late check-in, location deviation during the session, safety incidents, and disputes. They have a **Safety dashboard** and **session detail** with check-in/out, deviations, feedback, and incidents so they can triage and act.
- **Incidents are tracked to resolution.** Every safety incident has severity, type, and resolution notes. We can show that we don’t hide issues—we surface them, assign risk, and resolve them.

**Sound bite:** *"Security is designed in: limited, transparent location sharing, one-tap reporting, and real-time admin alerts so we can respond quickly to anything that doesn’t feel right."*

---

## 2b. Documents we collect from tutors

**What we say:**

- **Before a tutor can take sessions, we collect and verify identity and qualifications.** Tutors upload during onboarding: **profile photo**, **national ID (front and back)**, and **certificates** (degree, training, or last official certificate depending on their education). These are stored securely and reviewed as part of tutor approval.
- **We use these for accountability and safety.** If there’s a dispute, an incident, or a report, we have a verified identity and a record of what we approved. We can show investors and families that we don’t let unvetted strangers into homes—we have ID and credentials on file.
- **We can strengthen this over time.** We can add explicit “document verified” flags, re-verification cycles, or integration with identity providers. The foundation (collect, store, review at approval) is already there.

**Sound bite:** *"Every tutor has verified ID and credentials on file before they can take sessions. We review them at approval and use them for accountability and safety if we ever need to investigate or escalate."*

---

## 3. Trackability (audit trail and evidence)

**What we say:**

- **One timeline per session.** We merge booking, start/end, check-in/check-out, location deviations, safety incidents, and feedback into a single **session timeline**. So for any session we can show: *"Tutor checked in at X, we logged two location checks during the session, family said the session took place, no incidents."*
- **Risk score per session.** We compute a simple **risk score** (0–100) from: family dispute, late check-in, location deviation, safety incidents, low ratings. High-risk sessions are highlighted in the admin Safety view so we prioritize review.
- **Payment eligibility is rule-based.** Our system uses a single definition of *"eligible for payment"*: tutor checked in, session completed, no open dispute (or 7 days passed with no feedback). Both our app and our backend use the same rule, so we avoid paying out when we shouldn’t and we can explain every decision.

**Sound bite:** *"Every onsite session has a full audit trail and a risk score. We can show an investor or a parent exactly what happened and why we paid or held payment."*

---

## 4. Risk reduction (how we reduce bad behavior and create accountability)

**What we say:**

- **Fake check-in is hard.** You have to be at the venue (GPS) to check in. We’re not relying on a single tap; we verify location. During the session we do **background location checks** (e.g. every 5 minutes). If the tutor leaves the area, we log a deviation and can alert admins. So *"I checked in and left"* doesn’t go unnoticed.
- **Family can’t silently stiff the tutor.** If they say the session didn’t happen, we don’t auto-refund or auto-cancel pay. We **flag for review**. Admins see tutor check-in time, any deviations, and the family’s notes. So we reduce both tutor no-show and false "it didn’t happen" claims by using evidence, not just one side’s word.
- **We don’t rely on scale-to-fail.** We’re not planning to hire a huge ops team to watch every session. We use **automated rules** (risk score, eligibility, alerts) so the first line of defense is the product. Humans step in for edge cases and disputes.
- **Safety incidents create a record.** When someone reports "Felt unsafe" or "Tutor no-show," that’s stored with severity and type. We can track repeat issues by tutor or by family and act (e.g. warnings, suspension, support). So abuse is visible and actionable.

**Sound bite:** *"We reduce risk through structured safeguards and documented accountability: verifying location, logging deviations, gating payment on evidence, and flagging disputes and incidents so our team can intervene—without scaling a call center. We don’t claim to eliminate all risk."*

---

## 5. Handling the hardest cases: child safety & tutor safety

**The scenarios:** A tutor could be alone with a child in the home (e.g. elderly or working parent not physically present), or a tutor could be harassed or abused by a parent or another adult in the household. We take both directions of risk seriously.

### Child safety (tutor alone with a child)

**What we say:**

- **We encourage an adult to be present or reachable.** In our product and onboarding we state that, for minors, we recommend at least one responsible adult in the home or immediately reachable during the session. We don’t pretend that eliminates risk, but it sets a norm and reduces opportunity.
- **The learner and parent can report at any time.** The **"Something wrong? Report issue"** flow is available to the **learner** and the **parent**, not just the tutor. Options include *"Felt unsafe"* and *"Other"* with free text. Every report creates a **safety incident** and notifies our team so we can follow up quickly.
- **We have an audit trail.** Check-in time, location during the session, and any incidents are recorded. If something is reported later, we have a timeline and evidence to support investigation and decisions (including suspension, reporting to authorities if required, and supporting the family).
- **We can evolve policy and product.** We can make it explicit in booking or reminders that *"Sessions with minors should have an adult present or reachable"*, and we can add incident types or guidance that make it easier for learners or parents to report discomfort or abuse. We design so these policies can be strengthened as we grow.

**Sound bite:** *"We encourage an adult to be present or reachable for sessions with minors, we give the learner and parent a one-tap way to report anything that doesn’t feel right, and we keep a full record so we can act and support families and authorities when needed."*

### Tutor safety (harassment or abuse by parents / others in the home)

**What we say:**

- **Tutors can report without penalty.** A tutor can report *"Felt unsafe"* or use *"Other"* to describe harassment, inappropriate behavior, or discomfort. That creates a **safety incident** and alerts our team. We treat tutor reports as seriously as parent or learner reports.
- **We don’t force anyone back into an unsafe situation.** If a tutor reports harassment or abuse, we do not require them to return to that household. We can pause or end the booking relationship, offer support, and handle the family side separately (e.g. warning, suspension, barring). Our incident flow supports resolution notes and follow-up so we can act consistently.
- **Incidents are tied to sessions and people.** We store who reported, severity, and type. That lets us see patterns (e.g. repeated issues with one family or one tutor) and take action. Tutors know there is a channel and that we use it.
- **We can extend product and policy.** We can add incident types or categories that explicitly capture harassment or inappropriate behavior by parents/guardians, and we can make it clear in tutor-facing copy that reporting will not disadvantage them and that we may reassign or suspend the booking.

**Sound bite:** *"Tutors can report feeling unsafe or harassed with one tap; we don’t force them back into that home, we track incidents by session and by party, and we act on patterns so tutors know we take their safety seriously."*

### Honest framing for investors or judges

- **We don’t claim to eliminate all risk.** Home-based tutoring will always carry some residual risk. What we do is: **reduce opportunity** (norms and guidance), **give everyone a voice** (reporting for tutor, parent, and learner), **create evidence** (timeline, incidents, risk score), and **support escalation** (admin triage, suspension, and cooperation with authorities when appropriate).
- **We design for both directions of harm.** It’s not only "tutor might harm child"—it’s also "parent or adult in the home might harm or harass the tutor." Our safety and incident system is built so either side can report and get a response, and we can act on both.

---

## 6. Direct Q&A (how to answer "How do you...?")

| **Question** | **Answer** |
|-------------|------------|
| **How do you ensure accountability for onsite sessions?** | Tutor must check in at the venue (GPS). Only the tutor can start/end the session. Family can confirm or dispute via "Did this session take place?" and optional start/end confirmation. Payment only releases when we have check-in, completion, and no dispute (or 7 days with no feedback). |
| **How do you ensure security during onsite sessions?** | Location is shared with the family only during the active session, and we’re transparent about it. Anyone in the session can report an issue with one tap; that creates a safety incident and notifies our team. We have a Safety dashboard and alerts for late check-in, location deviation, and incidents. |
| **How do you track what actually happened?** | Every session has a single timeline: booking, start/end, check-in/out, location checks, incidents, feedback. We also compute a risk score per session. So we have a full audit trail and can show what happened and why we paid or held payment. |
| **How do you reduce risk of abuse (tutor or parent)?** | We reduce risk through structured safeguards: ID and credential verification, location verification and continuous checks make fake check-in and "check-in then leave" harder. Disputes don’t auto-refund—they’re flagged for review with full evidence. Safety incidents are stored and can be used to spot repeat issues. Payment rules are consistent and automated. We don’t claim to eliminate all risk. |
| **What if a parent says the session didn’t happen but the tutor says it did?** | We don’t take one side’s word. We look at tutor check-in time, any location deviations during the session, and the parent’s notes. Payment is held until we resolve. That protects both sides and gives us a clear, evidence-based process. |
| **Can you scale this without hiring hundreds of people?** | Yes. The first line of defense is product: automated check-in, location checks, risk scoring, and payment eligibility. We only escalate to humans when there’s a dispute, an incident, or a high-risk flag. So we scale with data and rules, not with a huge ops team. |
| **What if a tutor is alone with a child and something happens? (E.g. elderly parent not home.)** | We encourage an adult to be present or reachable for sessions with minors. The learner and parent can report any concern with one tap ("Felt unsafe," etc.); that creates a safety incident and alerts our team. We keep a full timeline and incident record so we can investigate, support the family, and cooperate with authorities if needed. We can strengthen guidance and policy as we grow. |
| **What if a tutor is sexually harassed or abused by a parent?** | Tutors can report "Felt unsafe" or use "Other" to describe harassment; that creates a safety incident and notifies our team. We do not require the tutor to return to that household. We can pause or end the booking, support the tutor, and handle the family (warning, suspension, barring). Incidents are stored so we can see patterns and act. We take tutor safety as seriously as learner safety. |
| **What documents do you collect from tutors?** | We collect profile photo, national ID (front and back), and relevant certificates (degree, training, or last official certificate) during onboarding. These are reviewed as part of tutor approval and kept on file for accountability and safety. |
| **Do you verify the identity of parents or families who book onsite?** | We can require identity verification (e.g. ID upload) for the person booking when they first book an onsite session—before payment. That way we know who is hosting the tutor in their home. See product note below on parent/learner KYC. |

---

## 7. Closing line for a pitch

> **"For every onsite session we answer three things: Was the tutor really there? Did the session happen as agreed? And is there any safety concern? We do that with verified check-in, continuous location checks, family feedback, and real-time alerts—so we can scale safely and show investors and families exactly how we keep people accountable and safe."**

---

---

## Product note: Parent/learner KYC for onsite (first time)

**Idea:** When a parent or learner books an **onsite** session, require them to complete **identity verification (KYC)**—e.g. upload **front and back of ID**—**when the session is approved** (or just before they pay), so we know who is hosting the tutor in their home. **Only for onsite, and only the first time** (per account or per household).

### Does it help?

**Yes, if you want:**
- **Accountability both ways:** Tutors are verified; having the booking party verified for onsite reduces “anonymous host” risk and helps if there’s theft, harassment, or a safety incident.
- **Investor/pitch story:** “We verify both sides for onsite: tutor ID and credentials at onboarding, and the person booking must verify identity before their first onsite session and payment.”
- **Evidence:** If something goes wrong, you have identity on file for the household, not just the tutor.

**Trade-off:** Some friction at first onsite booking. Limiting it to **onsite only** and **first time only** keeps friction low.

### Who should “approve” or verify the documents?

**Recommendation: the platform (admin), not the tutor.**

- **Platform/admin:** Review the ID upload (or use an automated identity provider) and mark the account as “Identity verified.” Tutors never see the actual documents.
- **Tutor:** Can see a badge like “Booking verified” or “Identity verified” on the session/booking so they know the household was verified, without handling sensitive IDs or doing compliance themselves.
- **Why not tutor approves?** Tutors aren’t KYC experts; it’s odd to make them judge IDs. It can also feel uncomfortable or create liability. Verification is a platform responsibility.

### When in the flow?

- **Option A:** When the **session is approved** (e.g. tutor accepted the request), before the parent can pay, we prompt: “Verify your identity to complete this onsite booking” → upload front/back → submit → admin (or provider) verifies → then payment is unlocked.
- **Option B:** At **first onsite booking attempt** (before any onsite session is confirmed), require KYC once; after that, no repeat for that account.

Both work; Option A ties verification to a concrete session and payment step.

### Summary

| What | Recommendation |
|------|----------------|
| **Do it?** | Yes, if you want stronger accountability and a clear “we verify both sides for onsite” story. |
| **Scope** | Onsite only; first time only (per account or per household). |
| **When** | When session is approved, before payment (or at first onsite booking). |
| **Who verifies** | Platform/admin (or automated provider). Tutor sees “Verified” badge only, does not approve documents. |
| **What to collect** | ID front + back. **Flexible whose ID:** learner’s if they have one, otherwise **parent/guardian ID**. **Multiple doc types:** national ID, passport, voter card, driver’s licence (inclusive for Cameroon/Africa). Optional selfie later if using a provider. |

**Build plan:** See **PLAN_PARENT_LEARNER_KYC_ONSITE.md**. **Learning from others:** See **LEARNING_FROM_GLOBAL_PLATFORMS_AND_ADAPTING.md**.

---

*Reference: Onsite Safety and Admin Monitoring plan, Refine Onsite Session Management plan, and implemented flows (safety incidents, session_took_place, confirmations, risk views, admin Safety dashboard).*

# How We Manage Onsite Sessions — Final Pitch & Team Reference

**Purpose:** Single reference for how PrepSkul manages onsite tutoring sessions: accountability, security, trackability, and risk reduction through structured safeguards. Use this for **investor and judge pitches**, **team alignment**, and **partner conversations**.  
**Audience:** Investors, pitch judges, partners, and **the whole PrepSkul team** (product, ops, support, growth).  
**Confidentiality:** When sharing with investors or partners, use an NDA or confidentiality expectation where appropriate. See **Legal & operational context** below for legal, insurance, and policy positioning.

---

## One-page summary (share this first)

### The one-line answer

> **"We treat onsite like a safety surface, not just logistics. Every session is verifiable: tutor check-in at the venue, continuous location checks during the session, family confirmation and feedback, and a clear audit trail. Disputes and anomalies are flagged automatically and surfaced to our team so we can act before they become trust issues."**

### How we manage onsite in four pillars

| Pillar | What we do |
|--------|------------|
| **1. Accountability** | Tutor must check in at the venue (GPS). Only tutor can start/end the session. Family answers "Did this session take place?" (Yes/Partially/No) and can optionally confirm start/end. **Payment only releases** when tutor checked in, session completed, and no dispute (or 7 days with no feedback). |
| **2. Security** | Location shared with family only during the active session (transparent). **"Something wrong? Report issue"** for tutor, parent, or learner → safety incident + admin alert. Admins have a Safety dashboard and session detail with timeline, incidents, and risk score. |
| **3. Trackability** | **One timeline per session** (booking → start/end → check-in/out → deviations → incidents → feedback). **Risk score (0–100)** per session. **Payment eligibility** is rule-based and auditable. 
| **4. Risk reduction** | We **reduce risk** through structured safeguards and documented accountability: GPS check-in + continuous location checks (deviations logged and can trigger alerts). Disputes go to review with full evidence, not auto-refund. Safety incidents stored by severity/type; we can act on patterns (warnings, suspension). We do not claim to eliminate all risk. |

### Who we verify

- **Tutors:** Before they can take sessions we collect and verify **profile photo**, **national ID (front and back)**, and **certificates** (degree, training, or last official certificate). Reviewed at approval; kept on file.
- **Families (onsite, first time):** We can require **identity verification (KYC)** for the person booking before they pay for their **first** onsite session—so we know who is hosting the tutor. Accept **parent/guardian ID** when the learner doesn’t have one; accept **multiple document types** (national ID, passport, voter card, driver’s licence) so we stay inclusive in Cameroon and across Africa. Platform verifies; tutor only sees a "Verified" badge.

### Hardest cases (child safety & tutor safety)

- **Tutor alone with a child:** We encourage an adult to be present or reachable for sessions with minors. Learner and parent can report any concern with one tap; we keep a full timeline and incident record and can cooperate with authorities. We don’t claim to eliminate all risk—we reduce opportunity, give everyone a voice, and create evidence.
- **Tutor harassed by parent:** Tutors can report "Felt unsafe" or "Other"; we don’t force them back into that household. We can pause or end the booking, support the tutor, and handle the family (warning, suspension, barring). Incidents are tied to sessions and people so we can see patterns.

### Closing line for a pitch

> **"For every onsite session we answer three things: Was the tutor really there? Did the session happen as agreed? And is there any safety concern? We do that with verified check-in, continuous location checks, family feedback, and real-time alerts—so we can scale safely and show investors and families exactly how we keep people accountable and safe."**

---

## Full narrative (for deep dives and Q&A)

### 1. Accountability (who did what, when)

- **Tutor is the primary proof point.** Only the tutor can start and end the session. For onsite, they must **check in at the venue** (GPS within ~100 m). We record check-in time, optional selfie, and punctuality (on time / late).
- **Family has a voice.** After the session, parent or learner answers **"Did this session take place as scheduled?"** (Yes / Partially / No) with optional notes. They can also **optionally confirm start and end** in the app. Dual signals: tutor proof + family confirmation or dispute.
- **Payment is gated on proof and no dispute.** We don’t release tutor pay until: (1) tutor has checked in, (2) session is completed, and (3) either the family said "Yes" or no dispute was raised within 7 days. If they say "No" or "Partially," we flag for review and hold payment until we resolve it.
- **Everything is timestamped and queryable.** Session timeline and risk score per session so we can explain what happened and why we did or didn’t pay.

### 2. Security (physical and emotional safety)

- **Location shared only when it matters.** During an active onsite session, the family can see that the tutor is at the right place. We tell the tutor clearly: "Location is shared with the parent for safety while this session is active."
- **Anyone in the session can report an issue.** Tutor, parent, or learner can tap **"Something wrong? Report issue"** (e.g. "Felt unsafe," "Tutor no-show," "Location issue"). That creates a **safety incident** and immediately notifies our admin team.
- **Admins see the full picture.** Push alerts for late check-in, location deviation, safety incidents, and disputes. Safety dashboard and session detail with check-in/out, deviations, feedback, and incidents. Incidents are tracked to resolution (severity, type, resolution notes).

### 3. Documents we collect from tutors

- **Before a tutor can take sessions:** profile photo, national ID (front and back), and certificates (degree, training, or last official certificate depending on education). Stored securely; reviewed as part of tutor approval.
- **Use:** Accountability and safety—if there’s a dispute or incident, we have verified identity and a record of what we approved. We can strengthen with "document verified" flags or identity providers over time.

### 4. Trackability (audit trail and evidence)

- **One timeline per session:** booking, start/end, check-in/out, location deviations, safety incidents, feedback.
- **Risk score (0–100)** per session from: family dispute, late check-in, location deviation, safety incidents, low ratings. High-risk sessions highlighted in admin Safety view.
- **Payment eligibility** is rule-based: tutor checked in, session completed, no open dispute (or 7 days passed with no feedback). Same rule in app and backend—auditable and explainable.

### 5. Risk reduction (we don’t claim to prevent all abuse)

- **Fake check-in is hard:** GPS at venue required; continuous location checks during the session (e.g. every 5 min). If the tutor leaves the area, we log a deviation and can alert admins.
- **Family can’t silently stiff the tutor:** Disputes are flagged for review with full evidence (check-in time, deviations, notes). We reduce both tutor no-show and false "it didn’t happen" claims by using evidence, not one side’s word.
- **Safety incidents create a record.** Severity and type stored; we can track repeat issues by tutor or family and act (warnings, suspension, support). First line of defense is product (rules and alerts); humans step in for edge cases and disputes. We **reduce risk** through structured safeguards and documented accountability—we do not claim to eliminate all risk.

### 6. Legal & operational context (four pillars beyond tech)

We are a **marketplace** connecting independent tutors and families—we are **not** the employer of tutors. Our safety architecture supports that: we set rules, verification, and tools; we don’t guarantee tutor conduct. For real-world risk we add four pillars alongside the tech above:

| Pillar | Today | Roadmap / intent |
|--------|--------|-------------------|
| **Vetting & onboarding** | ID + credential verification; profile photo. | Signed **code of conduct**; short **safeguarding training** (acknowledge before first onsite). **Background checks:** we verify identity and credentials today; we are [evaluating / adding] criminal background checks for tutors working with minors as we scale—answer honestly in due diligence. |
| **Safeguarding policy** | In-app guidance (e.g. adult present or reachable for minors). | **Written policy** (signed or accepted): parent/guardian present or reachable for minors; sessions in visible areas; no closed-door one-on-one with a minor; no inappropriate physical contact. Referenced in Terms. |
| **Legal protection** | — | **Terms of Service** (marketplace, independent contractors, acceptable use). **Independent contractor agreement** with tutors. **Indemnity**, **limitation of liability**, **incident process**. **Zero tolerance** and **blacklist** policies in writing. |
| **Insurance** | State what we have (if any). | Intent to secure **professional indemnity** (or similar) as we scale. |

**NDAs:** When sharing this pitch or detailed safety/ops with investors or partners, use an NDA or confidentiality agreement where appropriate. In contractor/tutor agreements, include confidentiality so our processes and playbooks aren’t shared inappropriately.

### 7. Parent/learner KYC for onsite (first time)

- **What:** Identity verification (KYC) for the person booking before they pay for their **first** onsite session. Only for onsite; first time per account (or household).
- **Whose ID:** Learner’s if they have one; otherwise **parent/guardian ID** (many students don’t have national ID). Multiple document types: national ID, passport, voter card, driver’s licence (inclusive for Cameroon/Africa).
- **Who verifies:** Platform/admin (or provider). Tutor never sees documents—only a "Verified" or "Booking verified" badge.
- **When:** When the session is approved, before payment (or at first onsite booking attempt). Build plan: **PLAN_PARENT_LEARNER_KYC_ONSITE.md**.

---

## Direct Q&A (how to answer "How do you...?")

| Question | Answer |
|----------|--------|
| How do you ensure accountability for onsite sessions? | Tutor must check in at the venue (GPS). Only tutor can start/end the session. Family can confirm or dispute via "Did this session take place?" and optional start/end confirmation. Payment only releases when we have check-in, completion, and no dispute (or 7 days with no feedback). |
| How do you ensure security during onsite sessions? | Location is shared with the family only during the active session; we’re transparent. Anyone can report an issue with one tap → safety incident → admin alert. We have a Safety dashboard and alerts for late check-in, location deviation, and incidents. |
| How do you track what actually happened? | Every session has a single timeline (booking, start/end, check-in/out, location checks, incidents, feedback) and a risk score. Full audit trail; we can show what happened and why we paid or held payment. |
| How do you reduce risk of abuse (tutor or parent)? | We **reduce risk** through **structured safeguards** and **documented accountability**: tutor ID and credential verification, location verification and continuous checks, disputes flagged for review with full evidence, safety incidents stored for patterns. Payment rules are consistent and automated so we don’t pay when evidence doesn’t support it. We don’t claim to eliminate all risk. |
| Do you do background checks on tutors? | We verify tutor **identity** and **academic credentials** today. We are [evaluating / adding] criminal background checks for tutors working with minors as we scale—we answer this honestly in due diligence. |
| What is your safeguarding policy? | We have in-app guidance (e.g. adult present or reachable for minors). We are adding a **written safeguarding policy** (parent presence, visible-area sessions, no closed-door one-on-one with a minor, no inappropriate contact) that tutors and families accept, referenced in our Terms. |
| What insurance do you carry? | [State what we have today, e.g. “We do not yet carry professional indemnity.”] We intend to secure appropriate insurance (e.g. professional indemnity) as we scale. |
| What is your escalation protocol? | Anyone can report “Something wrong?” → safety incident → admin alert. We have a Safety dashboard and incident list; we resolve with notes and can warn, suspend, or bar. We don’t force tutors back into unsafe households. We are formalising zero tolerance and blacklist policies in writing. |
| What if a parent says the session didn’t happen but the tutor says it did? | We don’t take one side’s word. We look at tutor check-in time, any location deviations, and the parent’s notes. Payment is held until we resolve. That protects both sides. |
| Can you scale without hiring hundreds of people? | Yes. First line of defense is product: automated check-in, location checks, risk scoring, payment eligibility. We escalate to humans only for disputes, incidents, or high-risk flags. |
| What if a tutor is alone with a child and something happens? | We encourage an adult present or reachable for minors. Learner and parent can report with one tap; we keep a full timeline and incident record and can investigate and cooperate with authorities. We can strengthen guidance as we grow. |
| What if a tutor is sexually harassed or abused by a parent? | Tutors can report "Felt unsafe" or "Other"; we don’t require them to return to that household. We can pause or end the booking, support the tutor, and handle the family (warning, suspension, barring). We take tutor safety as seriously as learner safety. |
| What documents do you collect from tutors? | Profile photo, national ID (front and back), and relevant certificates (degree, training, or last official certificate) during onboarding. Reviewed at approval; kept on file for accountability and safety. |
| Do you verify the identity of parents or families who book onsite? | We can require identity verification (KYC) for the person booking when they first book an onsite session—before payment. We accept parent/guardian ID and multiple document types so we stay inclusive. |

---

## For the team (how this translates to our work)

- **Product:** Onsite flows (check-in, location sharing, "Did this session take place?", optional confirm start/end, Report issue, and—when we build it—first-time KYC before first onsite payment) are the core. Safety dashboard, session detail, and incidents list in admin are the control plane. Keep copy clear and inclusive (e.g. parent/guardian ID, multiple doc types).
- **Ops / Admin:** Use the **Safety dashboard** and **Incidents** list to triage. Resolve safety incidents with notes; use session detail (timeline, risk score, check-in/out, deviations, feedback) to decide on disputes and payment. Follow the dispute runbook when `session_took_place` is no/partially (see **prepskul_app/docs/ADMIN_DISPUTE_RUNBOOK.md**).
- **Support:** When families or tutors ask "how does safety work?" or "what if something goes wrong?", use the one-pager and Q&A above. Point them to "Something wrong? Report issue" and reassure that we don’t force tutors back into unsafe households and we hold payment until disputes are resolved.
- **Growth / Partnerships:** This doc is the single source of truth for how we manage onsite. Share the one-page summary and closing line in pitches; use the full narrative and Q&A for due diligence or deeper conversations.

---

## Related documents

| Document | Use |
|----------|-----|
| **RESPONSE_TO_LEGAL_AND_OPERATIONAL_FEEDBACK.md** | How we responded to feedback on legal/operational risk: three layers, four pillars, NDAs, marketplace positioning, honest answers (e.g. background checks). |
| **PLAN_PARENT_LEARNER_KYC_ONSITE.md** | Build plan for parent/learner KYC (flow, flexible ID, document types, checklist). |
| **LEARNING_FROM_GLOBAL_PLATFORMS_AND_ADAPTING.md** | How we learn from Airbnb, Uber, tutoring platforms and adapt for Cameroon/Africa and everyday users. |
| **prepskul_app/docs/ADMIN_DISPUTE_RUNBOOK.md** | Internal runbook when `session_took_place` is no/partially: how to review and resolve. |

---

*This is the final pitch document on how we manage onsite sessions. Share it with the team and use it for investors, judges, and partners. Last updated to reflect legal & operational context, four pillars, risk-reduction language, investor Q&A, and NDA note.*

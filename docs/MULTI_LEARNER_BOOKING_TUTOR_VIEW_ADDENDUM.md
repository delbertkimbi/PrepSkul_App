# Addendum: Tutor view and per-learner accept/decline (multi-learner booking)

**Add this as a new subsection (e.g. 2.4) in the multi-child booking plan, and renumber "Level compatibility" to 2.5.**

---

### Tutor view: one group card, per-learner accept/decline (multi-learner only)

- **Parent picks learner(s) when booking** – "Who is this for?" from "My children"; single or multiple selection. **Trial sessions remain subject-based** – Each trial is one learner, one subject, one time; no change to that model.

- **Same card, all learners** – For multi-learner bookings (same tutor, 2+ children), the tutor sees **one request card** (or one group request details screen) that contains the whole group. Inside that card/screen:
  - **List of learners** – Each learner is shown with: name, level (e.g. Form 5, Primary 3), **subject** for this trial (e.g. Maths, Physics), and proposed time (e.g. Session 1: Emma 3:00 PM, Session 2: James 4:00 PM).
  - **Visit respective learner details** – Tutor can open each learner's details (e.g. expand row or tap to see more: level, subject, goals/challenges if available from parent_learners or survey) in the same card/flow, without leaving the group.
  - **Accept/decline per learner, with reasons** – For each learner (each trial in the group), the tutor has: **Accept** | **Decline** (with optional reason). So the tutor can e.g. Accept Emma (Maths) and Decline James (Physics) with reason "I'm not taking Physics this term", or Accept both, or Decline both. Each trial session gets its own status: `approved` or `rejected` (with `rejection_reason`).

- **No all-or-nothing** – The tutor can work with just one (or more) of the learners; they are not forced to accept or reject the whole group at once. The same card is the place where they see all learners and take action per learner.

- **Payment** – Charge only for **accepted** sessions. Apply multi-learner discount to the count of accepted sessions (e.g. if parent requested 2 and tutor accepted 2 → discounted total; if tutor accepted 1 → one session, full price or define a "single from group" rule). Parent pays after tutor response, for accepted session(s) only.

---

**Clarifications already in the plan:**
- Parent chooses learner(s) when booking; trial sessions stay subject-based.
- One learner per session (one trial = one learner, one subject, one time).
- Tutor decides per learner: accept or decline with reason, all in the same group card/details view.

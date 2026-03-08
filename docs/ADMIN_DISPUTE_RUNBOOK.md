# Admin runbook: Session disputes (session_took_place)

When a parent or learner reports that the session did not take place as scheduled, use this runbook.

## When it applies

- **`session_feedback.session_took_place = 'no'`** — Family says the session did not take place (e.g. tutor no-show).
- **`session_feedback.session_took_place = 'partially'`** — Session only partly happened (e.g. tutor left early, only 20 minutes).

These are set in the feedback flow after an **onsite** session. Online sessions do not use this field.

## What to do

1. **List sessions for review**
   - In **Admin → Safety** you see a “Disputes” count (sessions with `session_took_place` no/partially).
   - In **Admin → Incidents** you see safety incidents; many disputes will also have an incident or appear in Safety-relevant sessions.

2. **Open the session**
   - Use **Admin → Safety** → “Safety-relevant sessions” and click **View** for the session.
   - Or **Admin → Incidents** → **View session** for a related incident.
   - Session detail URL: `/admin/sessions/[sessionId]` (individual_sessions only).

3. **Review**
   - **Safety summary**: Tutor check-in/check-out times, `check_in_verified`, and any location deviations.
   - **Family feedback**: `session_took_place` and `session_took_place_notes` (e.g. “Tutor didn’t show”, “Only 20 min”).
   - **Timeline**: Full event timeline for the session.
   - **Safety incidents**: Any reported incidents and whether they’re resolved.

4. **Decide**
   - If the tutor clearly checked in and stayed (verified check-in, no major deviations), and the dispute is questionable, you may resolve in the tutor’s favor and add resolution notes.
   - If the tutor did not check in or left early, consider holding or reversing payment and contacting both parties (see payment rules below).

5. **Payment**
   - Sessions with `session_took_place = 'no'` (and optionally `'partially'`) are **not eligible for payment** until the dispute is resolved (see `session_eligible_for_payment` and payment release logic).
   - After resolution, eligibility may change (e.g. admin override or dispute closed). Payment release is handled by the cron / QA flow using `is_session_eligible_for_payment(session_id)`.

## Quick reference

| Field / place        | Meaning |
|----------------------|--------|
| `session_feedback.session_took_place` | `yes` / `no` / `partially` (onsite only). |
| `session_feedback.session_took_place_notes` | Family’s explanation when no/partially. |
| Tutor check-in/out   | In session detail → Safety summary (from `session_attendance`). |
| `session_eligible_for_payment` | View: session is eligible for payment only if tutor checked in, completed, and no open dispute (or 7 days passed with no feedback). |

This keeps dispute handling consistent and auditable.

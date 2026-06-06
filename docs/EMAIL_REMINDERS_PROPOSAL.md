# Email reminders proposal (for approval)

PrepSkul should send automated emails only when they reduce missed actions and support trust. Below is a proposed catalog by audience. **Do not implement until product approves** which rows to ship and at what cadence.

## Tutors

| ID | Trigger | Purpose | Suggested timing |
|----|---------|---------|------------------|
| T1 | 24h before on-site session | Review venue address, travel time, enable GPS | Once per session |
| T2 | 1h before on-site session | Final reminder to depart / open app | Once per session |
| T3 | 15m after scheduled start, no verified check-in | Nudge to check in or contact support | Once per session |
| T4 | 30m after scheduled end, checked in but no checkout | Remind checkout + checkout selfie | Once per session |
| T5 | Payout request approved or rejected | Wallet transparency | On status change |
| T6 | Session completed, no tutor feedback after 24h | Complete feedback for records | Once per session |

## Parents / learners

| ID | Trigger | Purpose | Suggested timing |
|----|---------|---------|------------------|
| L1 | Payment confirmed + sessions generated | Receipt and “where to find sessions” | On payment success |
| L2 | 24h before on-site session | Confirm venue and who meets the tutor | Once per session |
| L3 | Session completed, no family feedback after 24h | Rate session / report issues | Once per session |
| L4 | Trial approved, payment pending | Complete payment to lock trial slot | Once until paid |

## Admins

| ID | Trigger | Purpose | Suggested timing |
|----|---------|---------|------------------|
| A1 | On-site checkout submitted (`attendance_admin_status = pending`) | Review queue item | Immediate or hourly digest |
| A2 | Family reports `session_took_place = no` or `partially` | Dispute / safety follow-up | Immediate |
| A3 | New tutor payout request | Process disbursement | Immediate or daily digest |
| A4 | Tutor checked in 15+ minutes late (onsite) | Quality monitoring | Immediate (optional) |

## Implementation notes (when approved)

- Reuse existing cron / notification infrastructure in PrepSkul_Web where possible.
- Deep-link emails to: tutor sessions tab, session detail check-in card, admin `/admin/session-attendance`, feedback flow.
- Idempotency: store `email_sent_at` per `(user_id, template_id, session_id)` to avoid duplicates.
- Respect user notification preferences if/when a global email opt-out exists.

## Suggested MVP (smallest high-value set)

1. **T3** – missed on-site check-in  
2. **T4** – missed checkout  
3. **A1** – admin attendance review  
4. **L3 / T6** – feedback reminders (24h after completed)  
5. **T5** – payout status  

Approve or edit this list before engineering schedules the email templates and cron jobs.

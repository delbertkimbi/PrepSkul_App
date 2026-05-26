# Notification system status

**Canonical docs (Web):**

- [NOTIFICATION_SYSTEM.md](../../PrepSkul_Web/docs/NOTIFICATION_SYSTEM.md) — architecture, meaningful activity, engagement orchestrator
- [CRON_JOB_REGISTRY.md](../../PrepSkul_Web/docs/CRON_JOB_REGISTRY.md) — cron-job.org jobs and heartbeats
- [CAMEROON_ENGAGEMENT_CALENDAR.md](../../PrepSkul_Web/docs/CAMEROON_ENGAGEMENT_CALENDAR.md) — special-day campaigns

**Flutter flow reference:** [NOTIFICATIONS_ACTIVITY_AND_FLOW.md](./NOTIFICATIONS_ACTIVITY_AND_FLOW.md)

## Recent fixes

- Session completed / cancelled / no-show → `NotificationHelperService` (push + email via `/api/notifications/send`)
- Schedule session/payment/review reminders use admin Supabase client on Web
- `schedule-review-reminder` API route added
- Payment confirmed dedupe when Fapshi webhook already notified
- Engagement crons use activity-aware orchestrator (max one engagement push per inactive WAT day)

# Retention notifications checklist (Duolingo-style)

Session/booking pushes use **FCM (server)**. SkulMate daily streak uses **local scheduled notifications** on the device **plus** optional **FCM** from cron.

## On your Android device (after app update)

1. **Rebuild & reinstall** the app (`flutter run` or release build) — local scheduling fixes require a new binary.
2. **Settings → Apps → PrepSkul → Notifications** — all channels ON.
3. **Settings → Apps → PrepSkul → Alarms & reminders** (Android 12+) — allow if shown.
4. **Battery** — disable aggressive optimization for PrepSkul (OEM “sleep” modes cancel local alarms).
5. Open the app once after install so streak reminder is scheduled (default **6:00 PM local**).
6. In logs, look for: `Scheduled skulMate streak reminder at … (local)`.

## In-app preferences

**Profile → Notification preferences**

| Toggle | Affects |
|--------|---------|
| Push notifications | FCM (sessions, engagement server push) |
| Learning tips & reminders | Server engagement (`engagement_push_enabled`) |

SkulMate **local** streak reminder is on by default (`skulmate_streak_reminder_enabled` in SharedPreferences).

## Server configuration (PrepSkul Web + cron-job.org)

Required for **server-side** daily engagement (FCM backup + in-app):

| Cron endpoint | Suggested schedule | Purpose |
|---------------|-------------------|---------|
| `GET /api/cron/daily-challenge-reminder` | Daily ~5–6 PM WAT | SkulMate streak FCM |
| `GET /api/cron/daily-inactivity` | Daily ~6 PM WAT | “Come back” nudge if no activity |
| `GET /api/cron/process-scheduled-notifications` | Every 2–5 min | Session reminders |

All require header: `Authorization: Bearer <CRON_SECRET>` (same as `CRON_SECRET` in deployment env).

Verify in Supabase **`cron_job_heartbeats`** — `job_name` = `daily-challenge-reminder` with recent `last_success_at`.

### Env vars (www.prepskul.com / Vercel)

- `CRON_SECRET` — matches cron-job.org
- `FIREBASE_SERVICE_ACCOUNT_KEY` — JSON for FCM (sessions already prove this works)
- `NEXT_PUBLIC_APP_URL` — must be set so engagement cron can call `/api/notifications/send`
- `ENABLE_DAILY_MATCHED_TUTORS=true` — optional tutor digest

## Database checks (Supabase)

```sql
-- FCM token for your user (server push)
SELECT token, platform, is_active, updated_at
FROM fcm_tokens WHERE user_id = '<your-user-id>';

-- SkulMate stats row (required for server streak cron)
SELECT * FROM user_game_stats WHERE user_id = '<your-user-id>';

-- Engagement prefs
SELECT push_enabled, engagement_push_enabled, quiet_hours_start, quiet_hours_end
FROM notification_preferences WHERE user_id = '<your-user-id>';
```

## Why session push works but daily might not

| Channel | Delivery | You had |
|---------|----------|---------|
| Session / booking | FCM from server | ✅ Working |
| SkulMate streak | **Local alarm** on phone | Was broken (init race, cancel-all bug, timezone) — fixed in app |
| SkulMate / engagement | FCM from cron | Needs cron + row in `user_game_stats`; skips if already played SkulMate **today** |

**Opening the app daily** still blocks `daily-inactivity` (by design). It no longer blocks `daily-challenge-reminder` if you only opened the app but did not play SkulMate.

## Quick test

1. Do **not** play SkulMate today.
2. Set device time to 5:58 PM (or change reminder time in SkulMate settings if exposed).
3. Force-close the app.
4. Wait for notification at 6:00 PM.

Or trigger server cron manually:

```bash
curl -H "Authorization: Bearer $CRON_SECRET" \
  "https://www.prepskul.com/api/cron/daily-challenge-reminder"
```

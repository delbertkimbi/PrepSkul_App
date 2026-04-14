# SkulMate Daily Leaderboard Endpoint Skeleton (External Cron)

Use this as implementation reference for your backend service.

## Endpoint

`POST /api/cron/skulmate/daily-leaderboard-notify`

## Request

```json
{
  "runDate": "2026-04-14",
  "triggerSource": "external-cron",
  "dryRun": false
}
```

Headers:

- `Authorization: Bearer <CRON_SECRET>`
- `Idempotency-Key: skulmate_daily_leaderboard:2026-04-14:external-cron`

## TypeScript-style Pseudocode

```ts
type RunStatus = "running" | "completed" | "partial" | "failed";

export async function postDailyLeaderboardNotify(req, res) {
  assertCronAuth(req.headers.authorization);

  const runDate = validateIsoDate(req.body.runDate); // UTC date
  const triggerSource = req.body.triggerSource ?? "external-cron";
  const dryRun = Boolean(req.body.dryRun);
  const idemKey = req.headers["idempotency-key"] as string | undefined;

  // Optional API idempotency layer.
  if (idemKey) {
    const cached = await db.api_idempotency_keys.findOne({ key: idemKey });
    if (cached) return res.status(cached.response_code ?? 200).json(cached.response_body);
  }

  let runId: string;
  try {
    // Upsert run row (deterministic by run_date + trigger_source).
    const run = await db.tx(async (tx) => {
      const existing = await tx.skulmate_notification_runs.findByDateSource(runDate, triggerSource);
      if (existing) return existing;
      return tx.skulmate_notification_runs.insert({
        run_date: runDate,
        trigger_source: triggerSource,
        status: "running",
        metadata: {},
      });
    });
    runId = run.id;

    const top = await queryDailyTopSnapshot(runDate); // deterministic tie-break
    const recipients = await querySkulmateRecipients(); // all players

    const payloadFactory = (userId: string) => ({
      type: "skulmate_daily_leaderboard",
      title: "Daily game chart update ⚡",
      message:
        top.user_id === userId
          ? `You are topping today's game chart with ${top.total_xp} XP. Keep the streak going!`
          : `${top.user_name} is topping today's game chart with ${top.total_xp} XP.`,
      actionUrl: "/skulmate/leaderboard",
      actionText: "View leaderboard",
      metadata: {
        run_date: runDate,
        period: "daily",
        top_user_id: top.user_id,
        top_user_name: top.user_name,
        top_xp: top.total_xp,
      },
    });

    // Insert delivery rows idempotently by event_key
    const eventType = "skulmate_daily_leaderboard";
    for (const userId of recipients) {
      const eventKey = `${eventType}:${runDate}:${userId}`;
      const payload = payloadFactory(userId);
      await db.skulmate_notification_deliveries.insertOnConflictDoNothing({
        run_id: runId,
        run_date: runDate,
        user_id: userId,
        event_type: eventType,
        event_key: eventKey,
        payload,
      });
    }

    if (!dryRun) {
      // Work queue style preferred; inline loop for skeleton.
      const pending = await db.skulmate_notification_deliveries.findPendingByRun(runId);
      for (const row of pending) {
        try {
          await db.tx(async (tx) => {
            // 1) in-app
            const notif = await tx.notifications.insert({
              user_id: row.user_id,
              type: row.payload.type,
              title: row.payload.title,
              message: row.payload.message,
              action_url: row.payload.actionUrl,
              action_text: row.payload.actionText,
              metadata: row.payload.metadata,
            });

            // 2) push
            const pushResult = await sendPushToUser(row.user_id, row.payload);

            await tx.skulmate_notification_deliveries.update(row.id, {
              in_app_status: "sent",
              in_app_notification_id: notif.id,
              push_status: pushResult.ok ? "sent" : "failed",
              push_provider_id: pushResult.providerId ?? null,
              attempt_count: row.attempt_count + 1,
              last_error: pushResult.ok ? null : pushResult.errorMessage,
            });
          });
        } catch (e) {
          await db.skulmate_notification_deliveries.markFailed(row.id, String(e));
        }
      }
    }

    // Finalize run status from aggregate
    const agg = await db.skulmate_notification_deliveries.aggregateByRun(runId);
    const status: RunStatus = agg.failed_count > 0 ? (agg.sent_count > 0 ? "partial" : "failed") : "completed";
    await db.skulmate_notification_runs.finish(runId, status, {
      top_user_id: top.user_id,
      top_user_name: top.user_name,
      top_xp: top.total_xp,
      recipient_count: agg.total_count,
      in_app_sent: agg.in_app_sent_count,
      push_sent: agg.push_sent_count,
      failed: agg.failed_count,
      dry_run: dryRun,
    });

    const response = {
      runId,
      runDate,
      status,
      recipientCount: agg.total_count,
      inAppSent: agg.in_app_sent_count,
      pushSent: agg.push_sent_count,
      failed: agg.failed_count,
      dryRun,
    };

    if (idemKey) {
      await db.api_idempotency_keys.upsert({
        key: idemKey,
        endpoint: "/api/cron/skulmate/daily-leaderboard-notify",
        response_code: 200,
        response_body: response,
        expires_at: addDays(new Date(), 7),
      });
    }

    return res.status(200).json(response);
  } catch (e) {
    if (runId) {
      await db.skulmate_notification_runs.finish(runId, "failed", { error: String(e) });
    }
    const errorBody = { error: "Daily leaderboard run failed", details: String(e) };
    if (idemKey) {
      await db.api_idempotency_keys.upsert({
        key: idemKey,
        endpoint: "/api/cron/skulmate/daily-leaderboard-notify",
        response_code: 500,
        response_body: errorBody,
        expires_at: addDays(new Date(), 1),
      });
    }
    return res.status(500).json(errorBody);
  }
}
```

## SQL snippets used by endpoint

### Deterministic top snapshot (daily)

```sql
select user_id, user_name, total_xp, games_played, rank
from skulmate_leaderboards
where period = 'daily'
  and period_start::date = $1::date
order by total_xp desc, games_played desc, rank asc, user_id asc
limit 1;
```

### Recipient set (example)

```sql
select distinct user_id
from (
  select user_id from skulmate_games where is_deleted = false
  union
  select user_id from skulmate_game_sessions
) u;
```

## External Cron Example (curl)

```bash
curl -X POST "https://api.yourdomain.com/api/cron/skulmate/daily-leaderboard-notify" \
  -H "Authorization: Bearer $CRON_SECRET" \
  -H "Idempotency-Key: skulmate_daily_leaderboard:2026-04-14:external-cron" \
  -H "Content-Type: application/json" \
  -d '{
    "runDate":"2026-04-14",
    "triggerSource":"external-cron",
    "dryRun":false
  }'
```


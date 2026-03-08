# skulMate Notifications & Re-engagement Design

This document outlines the notification strategy for skulMate to keep users engaged, protect streaks, and surface social/friend activity.

---

## 1. Daily Streak Reminder (High Priority)

**Goal:** Encourage users to play at least one game per day to maintain their streak.

| Trigger | When | Title | Message | Channel |
|---------|------|-------|---------|---------|
| Streak reminder | Daily, configurable time (e.g. 6 PM) | 🔥 Don't lose your streak! | You've got a {N} day streak. Play one game to keep it going! | Local notification |
| Streak at risk | Same day, 2 hours before midnight (if not played) | ⏰ Streak ends soon | Play now to keep your {N} day streak! | Local notification |

**Implementation:**
- **Local notifications** via `flutter_local_notifications` (zoned scheduling)
- User can opt in/out and set reminder time in SkulMate settings
- Check `GameStatsService.getStats()` for `lastPlayedDate` and `currentStreak`
- If `lastPlayedDate` is today → skip reminder

**Data needed:** `lastPlayedDate` from `GameStats` / `user_game_stats`

---

## 2. Friend Activity Notifications

**Goal:** Surface social activity to bring users back.

| Trigger | Recipient | Title | Message | Channel |
|---------|-----------|-------|---------|---------|
| Friend sent request | Recipient | 👋 New friend request | {Name} wants to be your friend | In-app, Push, Email |
| Friend accepted request | Requester | ✅ {Name} accepted | {Name} accepted your friend request | In-app, Push |
| Friend played a game | Recipient (friend) | 🎮 {Name} just played | {Name} played a game and earned XP | In-app, Push |
| Friend beat your score | Recipient | 🏆 Challenge! | {Name} beat your score on {Game} | In-app, Push |

**Implementation:**
- **In-app:** Insert into `notifications` table (existing flow)
- **Push:** Send via FCM from Next.js API or Supabase Edge Function
- **Friend played:** Requires backend to detect `skulmate_game_sessions` insert and notify friends
- **Friend beat score:** Compare leaderboard / game stats after session completion

**Database:** `skulmate_friendships` for friend list; `skulmate_game_sessions` for activity

---

## 3. Challenge Notifications

**Goal:** Engage users when friends challenge them.

| Trigger | Recipient | Title | Message | Channel |
|---------|-----------|-------|---------|---------|
| New challenge | Challengee | ⚔️ Challenge from {Name} | {Name} challenged you to beat their score on {Game}! | In-app, Push, Email |
| Challenge accepted | Challenger | ✅ {Name} accepted | {Name} accepted your challenge. Play now! | In-app, Push |
| Challenge completed | Both | 🎉 Challenge complete | You {won/lost} against {Name}! | In-app, Push |

**Implementation:**
- On `skulmate_challenges` insert → notify challengee
- On status → `accepted` → notify challenger
- On status → `completed` → notify both with winner

---

## 4. Daily Re-engagement (Come Back)

**Goal:** Bring back users who haven't played in 1–3 days.

| Trigger | When | Title | Message | Channel |
|---------|------|-------|---------|---------|
| Missed 1 day | Next day, morning | 📚 Ready to learn? | Your games are waiting. Play one to stay on track! | Push |
| Missed 2+ days | 2 days, afternoon | 🎯 We miss you! | Come back and play – your streak is waiting to be restarted | Push |

**Implementation:**
- **Backend job** (Supabase Edge Function cron or Next.js API cron)
- Query users where `last_played` (from `user_game_stats`) is 1–2 days ago
- Send FCM to those users (batch, rate-limited)
- Requires FCM tokens in `fcm_tokens` table

---

## 5. Implementation Phases

### Phase 1: Local Streak Reminder (Client-side)
- [ ] Add SkulMate settings: "Daily streak reminder" toggle + time picker
- [ ] Use `flutter_local_notifications` to schedule daily notification at chosen time
- [ ] On app open: check if played today; cancel today's reminder if yes
- [ ] Reschedule for next day after showing

### Phase 2: Friend & Challenge In-App Notifications
- [ ] Insert into `notifications` on friend request, accept, challenge create/accept/complete
- [ ] Ensure SkulMate screens subscribe to relevant notification types
- [ ] Add notification tap handler → navigate to Friends or Challenges

### Phase 3: Push for Friend/Challenge
- [ ] API/Edge Function to send FCM when friend request, challenge created
- [ ] Reuse existing `PushNotificationService` + FCM token storage

### Phase 4: Daily Re-engagement Job
- [ ] Cron job to find inactive users (1–2 days)
- [ ] Batch send FCM via Firebase Admin SDK
- [ ] Respect user preference (opt-out for marketing/re-engagement)

---

## 6. User Preferences

Store in `profiles` or a new `skulmate_notification_prefs` table:

| Preference | Default | Description |
|------------|---------|-------------|
| `streak_reminder_enabled` | true | Daily streak reminder |
| `streak_reminder_time` | "18:00" | Time (user's local) |
| `friend_activity_push` | true | Push when friends play / request |
| `challenge_push` | true | Push for new challenges |
| `reengagement_push` | true | "We miss you" after 1–2 days inactive |

---

## 7. Technical Notes

- **Local notifications:** `flutter_local_notifications` supports `zonedSchedule` for daily reminders
- **FCM:** Existing `PushNotificationService` handles token + permission
- **Backend:** Next.js API or Supabase Edge Functions for server-triggered push
- **Database triggers:** Can use Supabase triggers to insert `notifications` on `skulmate_friendships` / `skulmate_challenges` changes

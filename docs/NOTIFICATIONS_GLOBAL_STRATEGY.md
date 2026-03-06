## Notifications – Global Strategy & Caps (Students, Parents, Tutors)

**Goal:** Make every notification feel necessary and useful, not noisy.  
**Scope:** All channels (in‑app, email, push) across all roles (student, parent, tutor, admin).

---

### 1. Core principles

- **Utility first**: Every notification must answer “What should I do with this right now?”  
- **Respect attention**: Hard caps per day; no “keep the metric green” spam.  
- **Role‑specific**: Different messages for students, parents, and tutors, even when the trigger is the same.  
- **Channel layering**:
  - In‑app: always safe; primary audit trail.  
  - Email: for receipts, summaries, and anything users may search later.  
  - Push: reserved for time‑sensitive or high‑value items only.
- **No emojis in copy**: Keep language clear, simple, and professional.

---

### 2. Daily and weekly caps

These are **soft caps** (enforced in code where possible; otherwise by design discipline):

- **Per user (all roles)**:
  - **Push**:  
    - Max **1 engagement / marketing push per day** (e.g. streak reminder, SkulMate nudge, “come back” message).  
    - Max **3 engagement pushes per week**.  
    - Transactional pushes (session starting, payment confirmed, critical safety) are allowed on top, but should still be meaningful.
  - **Email**:
    - No more than **1 non‑transactional email per week** (e.g. newsletter, tips), excluding receipts and legal messages.
- **Priority rules when multiple candidates exist on the same day**:
  1. Safety / account security (very rare).  
  2. Time‑sensitive session events (today’s or tomorrow’s booking).  
  3. Money‑related (payment due, payout status).  
  4. Learning / engagement (SkulMate, streaks, recommendations).  
  5. Marketing / announcements (last priority).

---

### 3. Role‑based strategy

#### 3.1 Students

- **Core value**: Consistent learning and exam readiness.
- **Primary triggers**:
  - Upcoming sessions and feedback requests.  
  - SkulMate games, streaks, and daily challenges.  
  - Tutor recommendations when they browse but don’t book.
- **Push focus**:
  - Session reminders (today/tomorrow).  
  - 1 daily learning nudge at most (SkulMate, “resume practice”, “complete feedback”) when they have not used the app that day.

#### 3.2 Parents

- **Core value**: Visibility and follow‑through for their child.  
- **Primary triggers**:
  - Booking status, payments, missed sessions, and safety incidents.  
  - Gentle nudges to confirm sessions, complete KYC (onsite), or review tutors.
- **Push focus**:
  - Critical booking/payment/safety events.  
  - At most one **planning or check‑in** reminder per day (e.g. “review upcoming sessions this week”).

#### 3.3 Tutors

- **Core value**: Reliable income and manageable schedule.  
- **Primary triggers**:
  - New booking / trial requests, schedule changes, payment and payout events.  
  - Profile/safeguarding updates and important policies.
- **Push focus**:
  - Requests and sessions they must respond to.  
  - At most one “growth” nudge per day (e.g. “update availability” or “respond to pending requests”).

---

### 4. Message style guidelines (all roles)

- **Tone**: Calm, clear, and straightforward.  
- **Structure**:
  - Title: short, 3–6 words, no emojis.  
  - Body: 1–2 concise sentences; first sentence says what happened, second suggests the next action.  
  - Action: always provide an action URL when the user can do something (view booking, start game, update profile).
- **Examples (push/email body)**:
  - Student: “Your session with [Tutor] starts in 30 minutes. Open PrepSkul to review the topic and join on time.”  
  - Parent: “Your booking with [Tutor] was approved. Complete payment now to confirm the first session.”  
  - Tutor: “You have a new request from [Student/Parent]. Review the details and accept or suggest another time.”

---

### 5. Interaction with existing notification system

- **Automatic vs manual**: Keep using `NotificationHelperService` for automatic events and the admin notifications panel for manual messages, but tag all notifications with:
  - `role_targets` (student/parent/tutor/admin).  
  - `category` (safety, session, payment, earnings, learning, marketing).  
  - `priority` (low, normal, high, critical).
- **Enforcing caps** (implementation notes):
  - Before sending a push, check a simple **“notifications_sent_today”** counter per user and category; skip or downgrade to in‑app only when caps are reached.  
  - Scheduled jobs (e.g. daily inactivity, Monday 8pm, monthly messages) should all call a single helper that applies these caps and style rules.

---

### 6. How this guides concrete features

- **Daily inactivity push**:
  - Only send if the user has not opened the app that day **and** has not already received another engagement push.  
  - Tailor the copy per role (student/parent/tutor) using the style rules above.
- **Weekly Monday 8pm and monthly messages**:
  - Treat them as **engagement** category, never exceeding weekly caps.  
  - If a higher‑priority push (e.g. urgent session reminder) is already scheduled that day, skip or reschedule the broadcast for that user.
- **SkulMate notifications**:
  - Slot under “learning” category and respect general engagement caps so they do not conflict with other engagement nudges.


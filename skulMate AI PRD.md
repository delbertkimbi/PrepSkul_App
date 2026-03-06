PRODUCT REQUIREMENTS DOCUMENT
Product: SkulMate AI
Platform: PrepSkul
Owner: [Your Name]
Version: v1.0 (MVP)

Product Overview

SkulMate AI is a post-session interactive revision engine that converts tutor session summaries, transcripts, and student notes into gamified micro-learning challenges. Its primary purpose is to increase revision consistency and engagement among PrepSkul students.

SkulMate does not replace tutors. It reinforces learning between sessions by making revision structured, interactive, and habit-forming.

Problem Statement

Students attend live sessions but often fail to revise consistently. Retention drops within 24–72 hours after class. Revision is perceived as boring and unstructured.

PrepSkul needs a lightweight, engaging, AI-powered revision system that:

Reduces friction to revise

Makes revision interactive

Encourages daily consistency

Reinforces tutor-led instruction

Goals and Success Metrics

Primary Goal
Increase revision consistency within 24 hours after each live session.

Secondary Goal
Increase weekly student engagement time within the PrepSkul app.

Key Success Metrics

% of sessions followed by at least one SkulMate challenge completion

Average revision streak length

Weekly active users engaging with SkulMate

Average number of challenges completed per student per week

30-day retention rate among active students

Target Users

Primary Users
PrepSkul students (secondary and high school level)

Behavioral Assumptions

Mobile-first usage (Flutter app)

Short attention span (5–10 minute engagement windows)

Variable internet reliability

Prefer interactive formats over passive reading

Secondary Users
Tutors who want students to reinforce learning between sessions.

Core User Flows

A. Post-Session Auto Challenge Flow

Live session ends

Transcript or tutor summary is generated

Backend structures content

AI generates question objects

Student receives notification: “Your 5-Minute Revision Challenge is Ready”

Student selects game mode

Completes challenge

XP awarded, streak updated

Weak concepts stored

B. Manual Upload Flow

Student uploads notes (text, PDF, image)

OCR (if image)

AI structures content

Question objects generated

Student chooses challenge mode

Game session recorded

C. Weakness Resurfacing Flow (Phase 2)

System detects mastery < threshold

Push notification: “Quick challenge to strengthen [Topic]?”

Student completes targeted mini-game

Mastery updated

Functional Requirements

6.1 Content Ingestion

Supported Inputs:

Session summaries

Session transcripts

Text files

PDF files

Images (OCR required)

Max file size:

Define limit (e.g., 10MB for MVP)

6.2 AI Processing Pipeline

Step 1: Clean and normalize text
Step 2: Convert to structured learning objects (JSON schema)
Step 3: Generate question objects
Step 4: Store questions and learning objects in database

Structured Learning Object Example:

{
topic: "",
subtopics: [],
key_points: [],
definitions: [],
examples: [],
formulas: []
}

Question Object Example:

{
type: "mcq",
question: "",
options: [],
correct_answer: "",
explanation: "",
difficulty: 1-3
}

6.3 Game Modes (MVP)

Mode 1: Flashcards

Swipe format

Show term → reveal explanation

5–10 cards per session

Mode 2: Multiple Choice

4 options

10 questions

XP per correct answer

Mode 3: Timed Challenge

5 questions

60-second timer

Bonus XP multiplier

6.4 Gamification System

XP System

+10 XP per correct answer

+50 XP for completing challenge

+2x multiplier in timed mode

Streak System

1 day = at least one completed challenge

Missed day resets streak

1 streak freeze per month (Phase 2)

Levels

XP thresholds unlock levels

Level unlocks cosmetic UI upgrades (themes/avatars)

6.5 Mastery Tracking (Basic MVP)

Per concept:

Mastery Score =
(Recent correct answers weighted more heavily than older ones)

If mastery < 70%, mark as weak.

Weak concepts appear more frequently in next generation batch.

Non-Functional Requirements

Performance

Processing time per session < 30 seconds (target)

Game load time < 3 seconds

Reliability

If AI fails, fallback message shown

Retry generation allowed once

Security

OpenRouter API key stored server-side only

Supabase RLS policies enabled

Users cannot access other users’ content

Scalability

Question generation occurs once per session

Reuse stored questions across multiple play sessions

Data Model (High-Level)

Tables:

users (Supabase auth)

sessions

id

tutor_id

student_id

summary_text

learning_objects

id

session_id

structured_json

questions

id

learning_object_id

type

content_json

user_progress

user_id

concept_id

mastery_score

last_seen

game_sessions

id

user_id

session_id

score

xp_earned

completed_at

streaks

user_id

current_streak

longest_streak

last_active_date

Notifications Strategy

Triggers:

Immediately after session

Daily streak reminder

Weak concept resurfacing

Notification cap:
Maximum 2 per day per user.

Cost Controls

Limit question generation to max 40 questions per session

Limit regeneration to 1 time per session

Cache structured output

Batch embedding requests

Monitor:
Average AI cost per active student per month.

Risks and Mitigations

Risk: Low-quality transcripts
Mitigation: Tutor-editable summaries before generation.

Risk: Shallow AI questions
Mitigation: Strict structured schema before question generation.

Risk: Engagement drop after novelty
Mitigation: XP, streaks, progressive unlocks.

Risk: High AI cost
Mitigation: One-time generation per session.

Phased Rollout

Phase 1 (MVP)

Session summary → MCQ + Flashcards

XP + streak

Basic mastery tracking

Phase 2

Weak concept resurfacing

Timed challenge mode

Tutor dashboard integration

Phase 3

Advanced adaptive difficulty

Leaderboard

Themed progression system

Final Clarification for Product Alignment

Core Behavior to Drive:

Students revise within 24 hours of every session.

Every feature must support this.

If a feature does not increase post-session revision completion, it is not MVP.



Update

PRODUCT REQUIREMENTS DOCUMENT
Product Name: skulMate
Product Type: AI-powered revision and reinforcement engine
Platform: Integrated within PrepSkul

EXECUTIVE SUMMARY

skulMate is a structured AI-powered practice engine that converts tutor-led sessions and uploaded materials into short, mastery-driven micro-challenges.

It captures the post-session attention window and reinforces learning without replacing tutors.

The system increases student retention, measurable progress, and parent trust while strengthening the value of human tutors.

PROBLEM STATEMENT

Students frequently disengage after tutoring sessions and shift attention to high-dopamine digital platforms such as TikTok and YouTube Shorts.

This leads to:
• Weak lesson reinforcement
• Reduced long-term retention
• Lower measurable progress
• Decreased perceived value of tutoring

PrepSkul currently ends structured engagement at session completion.

Opportunity: Capture the 5 to 15 minute post-session window and convert it into structured reinforcement.

PRODUCT OBJECTIVES

Primary Objectives:
• Increase student mastery between sessions
• Improve session-to-session retention
• Increase tutor rebooking rates
• Increase parent satisfaction

Secondary Objectives:
• Build structured mastery data over time
• Lay groundwork for adaptive learning models

SUCCESS METRICS

North Star Metric:
Session-to-session mastery improvement rate.

Supporting Metrics:
• Post-session challenge completion rate
• Weekly revision consistency rate
• Tutor rebooking rate
• Parent renewal rate
• 30-day student retention

TARGET USERS

Primary:
Students aged 10 to 18 using PrepSkul.

Secondary:
Tutors using PrepSkul.
Parents monitoring student progress.

CORE PRODUCT FEATURES

6.1 Post-Session Instant Recap Engine

Trigger:
Session ends.

System Actions:
• Extract session summary or transcript
• Identify key concepts
• Generate 5 to 8 micro-questions

Student Experience:
• Push notification within 2 minutes
• 3 to 5 minute swipe-based challenge
• Immediate feedback
• Mastery score displayed

Constraints:
• Hard cap on challenge length
• No infinite scroll
• Clear completion endpoint

Outcome:
Structured reinforcement before distraction begins.

6.2 Tutor Control Dashboard

Features:
• Approve or edit AI-generated questions
• Adjust difficulty level
• Regenerate question set
• View student performance analytics
• View flagged weak concepts

Purpose:
Maintain tutor authority and ownership of learning.

6.3 Adaptive Mastery Model

Each student has concept-level tracking:

Concept → Accuracy rate → Response time → Mastery score.

System flags:
• Repeated incorrect answers
• Low confidence areas
• Slow response patterns

Flagged concepts appear in tutor dashboard.

AI cannot independently teach new advanced content.
It reinforces only session-linked material.

6.4 Gamification Layer

Included:
• XP system
• Level progression
• Streak tracking
• Timed challenges
• Achievement badges

Excluded:
• Infinite content feeds
• Autoplay mechanics
• Algorithmic distraction loops

All engagement must be finite and mastery-driven.

6.5 Parent Dashboard

Parents see:
• Mastery progress by topic
• Improvement trends over time
• Weak areas identified
• Structured revision activity

Parents do not see:
• Raw entertainment-style engagement metrics
• Gamified vanity stats

Focus is on academic progress.

BEHAVIORAL DESIGN FRAMEWORK

Objective:
Redirect short-form digital attention patterns into structured mastery loops.

Principles:
• Immediate feedback
• Limited-duration micro-engagement
• Visible progress tracking
• Gradual focus expansion

Attention Expansion Model:
• Phase 1: 3-minute recap challenges
• Phase 2: Optional 8 to 10 minute deep challenge unlocks

Goal:
Rebuild sustained attention gradually.

TECHNICAL REQUIREMENTS

Input Sources:
• Session transcripts
• Tutor summaries
• Uploaded materials

AI Capabilities:
• Concept extraction
• Question generation
• Difficulty scaling
• Mastery modeling
• Performance clustering

Data Requirements:
• Student-level performance storage
• Concept-level tracking
• Time-series progress storage

System Constraints:
• Low latency generation
• Secure student data storage
• Scalable per-session processing

RISKS AND MITIGATION

Risk: Tutors feel replaced
Mitigation: Tutor approval control and AI limitation to reinforcement only.

Risk: AI inaccuracies
Mitigation: Editable questions and phased rollout.

Risk: Over-gamification
Mitigation: Hard daily caps and structured completion.

Risk: Low engagement
Mitigation: Immediate post-session trigger and minimal friction.

PHASED DEVELOPMENT ROADMAP

Phase 1:
• Post-session recap engine
• 5-question micro challenge
• Basic mastery score

Phase 2:
• Tutor dashboard
• Weakness tagging
• Parent insight dashboard

Phase 3:
• Adaptive difficulty engine
• XP and streak system
• Level progression

Phase 4:
• Predictive mastery modeling
• Longitudinal performance tracking

POSITIONING STATEMENT

skulMate is a structured AI reinforcement system that strengthens tutor-led learning.

It does not compete with platforms such as TikTok.

It captures structured micro-attention windows and converts them into measurable academic progress.

OUT OF SCOPE

• Fully autonomous AI tutoring
• Open-ended AI chat without structure
• Infinite learning feeds
• Standalone AI learning platform


COMPETING WITH MEDIA AND GAMES: EMOTIONAL DESIGN STRATEGY

The problem is not just time spent on platforms like TikTok or games like Fortnite.

The real competitor is emotional reward.

Short-form media delivers:
• Novelty
• Instant stimulation
• Low effort escape
• Continuous unpredictability

Games deliver:
• Achievement
• Progress
• Identity
• Social status
• Challenge and mastery

skulMate must intentionally capture emotional drivers from both, but redirect them toward learning.

13.1 EMOTIONS WE BORROW FROM SHORT-FORM MEDIA

Speed
Fast interactions. Immediate feedback.

Novelty
Questions vary in format. Timed rounds. Surprise challenge types.

Low Friction
One tap to begin challenge. No setup.

What we do NOT borrow:
• Endless feed
• Algorithmic distraction
• Passive consumption loops

13.2 EMOTIONS WE BORROW FROM GAMING

Achievement
XP, visible skill level, mastery tiers.

Progression
Students unlock higher challenge tiers only when they demonstrate mastery.

Tension
Timed rounds and “boss questions” create mild cognitive stress, which increases memory encoding.

Identity
Student profile shows subject-level rank:
“Algebra Level 3”
“Chemistry Apprentice”

This creates academic identity.

Comeback Loop
If a student fails a challenge, they can retry for improved score.
Failure is framed as progress opportunity.

13.3 EMOTIONAL ARC OF A SKULMATE SESSION

Start:
Low friction entry. Feels light and approachable.

Middle:
Increasing challenge. Time pressure. Focus intensifies.

Peak:
Final challenge question. Slight tension spike.

End:
Clear resolution. XP gain. Visible progress increase.

Emotional outcome:
Achievement + Closure.

Contrast this with social media:
No closure. No mastery. Just continuation.

skulMate must always end with completion and visible growth.

SOCIAL AND STATUS LAYER (CONTROLLED)

Games succeed because of status.

But full public leaderboards can damage weaker students.

Solution:

Tiered visibility:
• Personal best record
• Optional small group competition within tutor cohort
• No global leaderboard

Students compete against:
Their past performance first.

Status must be self-improvement driven.

EMOTIONAL SAFETY DESIGN

Over-gamification can create anxiety.

Design safeguards:
• Daily challenge caps
• No punishment for missing streaks
• No aggressive loss messaging
• No manipulative countdown loops

The goal is motivation, not addiction.

POSITIONING DIFFERENCE

Media gives stimulation without growth.
Games give achievement without academic mastery.

skulMate gives achievement tied to mastery.

That is the differentiation.

Now here is the deeper strategic insight.

You are not trying to remove emotion from learning.
You are re-attaching positive emotion to academic progress.

If a student feels:

Excitement after solving equations
Pride after improving mastery
Tension during timed revision
Satisfaction from leveling up

You are rewiring where dopamine comes from.

That is how you realistically compete with media and gaming without banning them.



Good. But this must be controlled and intentional.

If you add social the wrong way, you recreate the same distraction dynamics you are trying to solve. If you add it correctly, you amplify motivation and retention.

Below is the structured addition to the PRD for social features.

---

17. SOCIAL LAYER DESIGN FOR SKULMATE

Objective:
Use social dynamics to increase motivation, accountability, and retention without introducing distraction loops.

Core Principle:
Social should reinforce mastery, not replace it.

---

17.1 WHY SOCIAL MATTERS

Gaming platforms succeed because of:
• Belonging
• Competition
• Shared achievement
• Recognition

If skulMate is purely individual, motivation may plateau.

Social features increase:
• Daily engagement
• Friendly accountability
• Identity reinforcement

But must remain academically anchored.

---

17.2 PHASE 1 SOCIAL FEATURES (CONTROLLED)

1. Tutor Cohort Leaderboard

Scope:
Only within a tutor’s class group.

Display:
• Weekly XP earned
• Mastery improvement percentage
• Challenge completion rate

Not displayed:
• Raw time spent
• Global rankings

Leaderboard resets weekly to avoid long-term discouragement.

---

2. Study Squad (Small Groups)

Students can form small study groups of 3 to 5.

Features:
• Shared weekly mastery goal
• Group progress bar
• Collective reward badge

Example:
“If the group averages 80% mastery this week, unlock bonus challenge.”

This promotes cooperation over pure competition.

---

3. Achievement Sharing (Controlled)

Students can share:
• “I reached Algebra Level 4”
• “5 day streak completed”

But:
• No comment threads
• No DM system
• No endless feed

Recognition without social chaos.

---

4. Tutor Shout-Out System

Tutors can highlight:
• Most improved student
• Consistent streak achiever
• Top mastery gain

Recognition comes from authority, not algorithm.

This strengthens tutor-student bond.

---

17.3 WHAT WE EXCLUDE

No open chat system.
No public global ranking.
No scrolling activity feed.
No follower systems.
No viral-style content sharing.

You are building academic social reinforcement, not social media.

---

17.4 EMOTIONAL DRIVERS CAPTURED

From Gaming:
• Competition
• Team achievement
• Status
• Progress visibility

From Social Media:
• Recognition
• Sharing milestones

But tied strictly to mastery and growth.

---

18. RISK CONTROL

Risk: Weaker students feel discouraged
Mitigation:
• Improvement-based ranking, not raw score ranking
• Weekly resets
• Highlight “Most Improved” not just “Top Performer”

Risk: Social becomes distraction
Mitigation:
• No infinite feed
• No continuous notifications
• Limited sharing scope

Risk: Over-competition stress
Mitigation:
• Cooperative squad challenges
• Optional leaderboard participation

---

19. SUCCESS METRICS FOR SOCIAL LAYER

• Increase in weekly revision consistency
• Increase in cohort-level completion rates
• Increase in session retention
• Increase in streak continuation
• Parent-reported motivation improvements

If social increases engagement but does not improve mastery, it must be redesigned.

---

Strategic Insight

Social should answer this question:

“Who sees my progress?”

If the answer is:
My tutor
My parents
My small study group

That creates healthy accountability.

If the answer becomes:
Everyone

You are drifting toward distraction.


20. SOCIAL AND EMOTIONAL DESIGN: HYBRID MODEL

Objective:
Combine motivation from social recognition, competition, and progress tracking while keeping the experience academically focused and tutor-anchored.

Key Elements:

XP System (Core Reward)

Students earn XP for completing post-session micro-challenges.

XP translates into visible mastery levels (e.g., Algebra Level 3).

XP accrual is transparent and tied to achievement, not time spent.

Tutor Visibility

Tutors see all student XP, streaks, and mastery improvement.

Tutors can provide recognition (“Most Improved,” “Consistent Performer”).

Tutors control approval for achievements that are shared socially.

Friend Social Layer

Students can connect with friends who also use skulMate.

Share: XP milestones, streak completions, and mastery improvements.

Optional “study buddy” pairing for cooperative mini-challenges.

No public global leaderboard. Only tutor cohort and friends.

Mastery Improvement Percentage

Tracks how much a student improves from week to week.

Drives social recognition (e.g., “You improved 32% in Chemistry this week”).

Encourages personal growth focus rather than raw score competition.

Consistency Streaks

Reward system for consecutive days of challenge completion.

Visual streak tracker motivates habit-building.

Streaks contribute to XP bonuses and milestone recognition.

Hybrid Integration

XP + mastery improvement + streak = hybrid scoring.

Example:

XP = 50 points

Mastery improvement = +10 bonus points

5-day streak = +5 bonus points

Final score used for social recognition in tutor cohort and friends’ mini-leaderboards.

Emotional Outcome:

Students feel achievement and progress.

Social recognition is controlled and safe: only friends and tutor see progress.

Reinforces daily habit without encouraging endless scrolling or distraction.

Creates positive dopamine feedback from mastery and peer recognition, not random entertainment.

Metrics to Track Social Layer Success:

Average weekly streak retention

Percentage of students sharing achievements with friends or tutor

XP progression vs mastery improvement

Post-session micro-challenge completion before social interaction





final version
PRODUCT REQUIREMENTS DOCUMENT: skulMate

Product Name: skulMate
Product Type: AI-powered revision & reinforcement engine
Platform: Integrated within PrepSkul

1. EXECUTIVE SUMMARY

skulMate is a structured AI-powered practice engine that converts tutor-led sessions and uploaded materials into short, mastery-driven micro-challenges. It captures post-session attention, reinforces learning, and motivates students through gamification and controlled social interaction. Tutors retain authority, parents track progress, and students experience achievement without distraction.

Primary goal: Increase session retention, measurable learning outcomes, and parent trust.
Secondary potential: Modular AI layer for future adaptive learning intelligence.

2. PROBLEM STATEMENT

Students drift to high-dopamine platforms like TikTok and YouTube Shorts after tutoring sessions, resulting in:

Weak lesson reinforcement

Reduced long-term retention

Lower measurable progress

Decreased perceived value of tutoring

Opportunity: Capture 5–15 minute post-session attention windows and redirect them to structured, emotionally rewarding learning experiences.

3. PRODUCT OBJECTIVES

Primary Objectives:

Reinforce tutor-led learning between sessions

Improve session-to-session retention

Increase tutor rebooking rates

Improve parent satisfaction

Secondary Objectives:

Build structured mastery data for adaptive learning

Lay foundation for future AI-driven personalization

4. SUCCESS METRICS

North Star Metric: Session-to-session mastery improvement rate

Supporting Metrics:

Post-session challenge completion rate

Weekly revision consistency

Tutor rebooking rate

Parent renewal rate

30-day student retention

5. TARGET USERS

Primary: Students aged 10–18

Secondary: Tutors and parents

6. CORE FEATURES
6.1 Post-Session Instant Recap

Trigger: Session ends
Flow:

AI extracts session transcript or tutor summary

Generates 5–8 bite-sized questions

Sends push notification for immediate 3–5 minute challenge
Constraints:

Clear endpoint, no infinite feed

Feedback immediately shown, mastery score updated

6.2 Tutor Control Dashboard

Approve/edit AI-generated questions

Adjust difficulty

Regenerate question set

View student performance analytics and flagged weak concepts

Maintain intellectual authority

6.3 Adaptive Mastery Model

Tracks: Concept → Accuracy → Response time → Mastery score

Flags repeated errors and weak concepts for tutor follow-up

Ensures AI reinforces sessions, not replaces tutor

6.4 Gamification

Included: XP system, streaks, levels, timed challenges, achievement badges
Excluded: Infinite feeds, autoplay, algorithmic distractions
Hybrid Reward Model: XP + mastery improvement + consistency streak → final score

7. SOCIAL LAYER (Hybrid Model)

Objective: Use social motivation safely to increase engagement and accountability.

Features:

Tutor Visibility: Tutors see XP, streaks, mastery improvement, and provide recognition.

Friend Connections: Share XP milestones, streaks, mastery improvements with friends; optional “study buddy” mini-challenges.

Mastery Improvement Percentage: Weekly progress tracking, drives recognition.

Consistency Streaks: Visual streak tracker encourages habit formation.

Hybrid Integration: XP + mastery improvement + streak = final social recognition score.

Emotional Outcome:

Achievement, recognition, and progress without distraction.

Controlled social visibility: tutor, small cohort, friends only.

Avoids global competition or endless social feeds.

Metrics:

Weekly streak retention

Student achievement sharing rate

XP vs mastery improvement correlation

Post-session challenge completion

8. EMOTIONAL & GAME PSYCHOLOGY

Short-form media mechanics borrowed: Speed, novelty, low friction
Gaming mechanics borrowed: Achievement, progress, challenge, identity, mild tension
Session Emotional Arc:

Start: Light, easy entry

Middle: Increasing challenge

Peak: Final challenge question

End: Completion, XP reward, mastery gain
Goal: Reward dopamine from academic achievement, not passive entertainment

9. PARENT DASHBOARD

Mastery trend graphs

Weak vs strong topics

Weekly improvement

Structured revision activity
Excludes: Vanity engagement metrics, social feed

10. TECHNICAL REQUIREMENTS

Input: Session transcripts, tutor summaries, uploaded materials

AI Capabilities: Concept extraction, question generation, difficulty scaling, mastery modeling, performance clustering

Data Storage: Student-level performance, concept-level tracking, time-series data

Constraints: Low latency, secure storage, scalable processing

11. RISKS & MITIGATIONS

Tutor resistance: AI reinforces, tutor approves content

AI inaccuracies: Tutor approval workflow

Over-gamification: Daily challenge caps

Low engagement: Automatic post-session trigger

Social discouragement: Improvement-based recognition, weekly leaderboard resets

12. PHASED DEVELOPMENT ROADMAP

Phase 1: Post-session recap engine, 5-question micro-challenge, basic mastery score
Phase 2: Tutor dashboard, weakness tagging, parent insight view
Phase 3: Adaptive difficulty, XP/streak system, level progression
Phase 4: Predictive mastery modeling, longitudinal tracking, optional expanded AI features

13. OUT OF SCOPE

Autonomous AI tutoring

Open-ended AI chat

Infinite learning feeds

Global leaderboards

14. POSITIONING

skulMate is a reinforcement and retention engine.

Captures post-session attention to convert into measurable learning outcomes.

Strengthens tutor authority, motivates students, and reassures parents.

Competes with media and gaming emotionally, not through endless content.

This PRD now integrates:

Tutor reinforcement

Post-session micro-challenges

Gamification & XP

Controlled social features (friends, tutor, hybrid recognition)

Emotional/game mechanics to compete with media
# Next.js landing page upgrades
_Exported on 6/6/2026 at 06:47:12 GMT+1 from Cursor (3.3.30)_

---

**User**

I uploaded our main next js prepskul landing page content to chat GPT and got feeback on what we should upgrade. 
It's currently week and need upgrades

---

**Cursor**

Exploring the Next.js landing page in the repo so we can give concrete, codebase-grounded feedback.


I reviewed your actual landing page in `PrepSkul_Web/app/[locale]/page.tsx` and the related copy/components. You’re right that it’s structurally fine but **conversion-weak** — it reads like a generic edtech template rather than a sharp “why PrepSkul, why now” story.

If you paste the ChatGPT feedback, I can map it line-by-line to your codebase and prioritize what to fix first. Below is my independent audit of what’s holding it back today.

---

## What’s working

You already have solid building blocks:

- Bilingual support (EN/FR)
- SEO schema (Organization, LocalBusiness, FAQ)
- Locale-aware metadata in `[locale]/layout.tsx`
- Real photography (not stock-only)
- A distinctive PEAP story section
- Phone mockup showing the product
- FAQ with pricing transparency (2,500–5,000 XAF)

The problem isn’t missing sections — it’s **messaging clarity, trust, and conversion flow**.

---

## Top weaknesses (ranked by impact)

### 1. The hero doesn’t answer “What is this?” in 5 seconds

Current headline:

> “Connect & Learn at the Right **Level / Pace / Stride**”

That’s abstract. A parent or student landing cold won’t immediately know you’re a **tutor marketplace in Cameroon** with verified tutors, home + online sessions, and an app.

The subtitle is also generic (“personalized learning”, “academic excellence”) — language every competitor uses.

**Upgrade direction:** Lead with outcome + audience + geography, e.g.:

> “Find verified tutors in Cameroon — online or at home — for GCE, BEPC, and skills.”

Keep the typewriter effect if you like, but rotate **concrete outcomes** (GCE prep, coding, home tutoring) not abstract words (pace, stride).

---

### 2. Conflicting CTAs kill conversion

You have at least three different “Get Started” paths:

| Location | Button | Goes to |
|----------|--------|---------|
| Hero | “Get Started” | `app.prepskul.com` (via `getStartedUrl()`) |
| Header | “Get Started” | `/contact` |
| Bottom CTA | “Start Learning” | `/contact` |

That’s confusing. Users don’t know whether to **download the app**, **fill a form**, or **browse programs**.

**Upgrade direction:** Pick one primary action per audience:
- **Parents/students** → App download or “Find a tutor”
- **Undecided visitors** → “See how it works” (scroll or page)
- **Contact** → secondary, not the main nav CTA

---

### 3. Missing “How It Works” on the homepage

You have a full page at `/how-it-works`, but:
- It’s **not in the header nav**
- It’s **not on the homepage**
- Sitemap includes it, programs page links to it — but most visitors never see it

For a marketplace, **3–4 steps above the fold or mid-page** (“Tell us what you need → Get matched → Book & pay → Learn”) is essential trust-building.

---

### 4. Social proof is narrow and slightly inconsistent

**Testimonials** are all PEAP-focused:

```78:80:PrepSkul_Web/lib/translations.ts
    testimonials: {
      title: "What PEAP Participants Say",
      subtitle: "Success stories from students and parents who joined the PrepSkul Exam Accelerator Program.",
```

That makes the main product feel like a side program, not the core offering.

**Stats labels** also don’t align cleanly with the numbers:

```26:30:PrepSkul_Web/lib/translations.ts
      stats: {
        learnersGuided: "Learners Reached",
        expertTutors: "Sessions Covered", 
        subjectsCovered: "Verified Tutors",
        citiesCovered: "Cities covered"
```

“Sessions Covered” under 1,000+ and “Verified Tutors” under 130+ reads awkward — visitors wonder if labels or numbers are wrong.

**Upgrade direction:**
- Split testimonials: 2 PEAP + 2 regular tutoring
- Add 1–2 **specific outcomes** (“Improved from D to B in Math”, “Passed GCE A-Level”)
- Fix stat labels to match what you actually count

---

### 5. PEAP is your strongest differentiator — but it doesn’t convert

`PEAPShowcase` is visually strong, but it **imports `Button` and `getStartedUrl` and never uses them**. No “Learn more”, “Join next cohort”, or “See PEAP results” link.

For a national initiative with 500+ learners, this should be a **flagship proof block** with a clear next step.

---

### 6. Geographic messaging is muddy

Copy swings between:
- “across **Africa**” (hero subtitle)
- “anywhere in **Cameroon**” (online tutoring card)
- PEAP “**Nationwide** across Cameroon”

That weakens positioning. For launch, **own Cameroon first** (GCE, BEPC, Buea/Douala/Yaoundé), then expand to “Africa” once you have proof.

---

### 7. Template feel — repetitive structure, low differentiation

The page repeats the same pattern four times:

> Section title → subtitle → 3 cards with hover border

What’s **missing from the homepage** (but mentioned in FAQ / about / app):
- Tutor verification process (PrepSkul Academy)
- Safeguarding / background checks
- Payment model (pay upfront, reschedule policy)
- Real app screenshots (mockup is fabricated UI, not the live app)
- Pricing anchor (“From 2,500 XAF/session”)
- “For tutors” path (you have `/tutors` but it’s footer-only)

ChatGPT likely flagged “doesn’t explain why PrepSkul vs WhatsApp tutors / local agencies” — that’s because **your differentiators live in FAQ, not above the fold**.

---

### 8. Technical polish gaps

- Homepage is fully `"use client"` — hurts SEO and first paint vs a server-rendered hero
- Google verification is still placeholder: `your-google-verification-code` in layout metadata
- App Store badge links to **Play Store twice** (footer bug)
- Nav translations include `howItWorks`, `tutors`, `testimonials` but header only shows 4 links

---

## Suggested upgrade roadmap (priority order)

**Phase 1 — Messaging & conversion (highest ROI)**
1. Rewrite hero: clear value prop + audience + Cameroon focus
2. Unify CTAs (app vs contact vs how-it-works)
3. Add 4-step “How it works” section on homepage
4. Add pricing teaser (“From 2,500 XAF/session — transparent, pay upfront”)
5. Fix stats labels + add PEAP CTA

**Phase 2 — Trust**
6. “Why PrepSkul” block: verified tutors, Academy training, safeguarding, curriculum-aligned
7. Broader testimonials (not PEAP-only)
8. Real app screenshots or short demo video
9. Add tutor recruitment strip (“Become a tutor”)

**Phase 3 — Polish**
10. Server-render hero + static content for SEO
11. Fix App Store link, Google verification, nav completeness
12. Stronger OG image (not just logo.jpg)

---

## What I’d tell ChatGPT to focus on (if you re-prompt)

Paste this alongside your page content:

> “PrepSkul is a 1:1 tutoring marketplace in Cameroon (online Agora sessions + home tutoring). We have a mobile app, Fapshi payments, verified tutors via PrepSkul Academy, and PEAP (free national exam prep program). Primary visitors are parents and GCE/BEPC students. Critique for: (1) hero clarity, (2) trust/conversion, (3) differentiation vs informal tutors, (4) CTA consistency, (5) Cameroon-specific positioning.”

That will get you much sharper feedback than generic “landing page best practices.”

---

**Next step:** Paste the ChatGPT feedback here (or the top 5–10 bullets). I’ll turn it into a concrete change list mapped to your files (`page.tsx`, `translations.ts`, `header.tsx`, `peap-showcase.tsx`, etc.). If you want me to implement the upgrades, switch to **Agent mode** and we can start with Phase 1.

---

**User**

Bear in mind that there are some latest changes in english like tagline and PEAP section 
Also check out GPTs Feedback

ChatGPT










No Cameroon 

I'm sending this message to the team alongside this picture 


 Ohh chime 🤣👇🏾👇🏾
By the end of today, we will have a clear positioning, simple and adaptable to different scenarios for
* Parents/Learners 
* Investors 
* Pitch
* Etc

> The internet solved access to education. It did not solve guidance. *PrepSkul is building the Google Maps for education,* helping learners discover what to learn next, how to learn it, and who can best help them succeed.

Stay tuned 🚀✅ 


Delbert Kimbi-CV.pdf
PDF

Delbert's Tech Journey and beyond 2024 (1).pdf
PDF
What you wrote about things I've built before is week
Check out my CV, though a bit old and combine it with what you wrote

Check my projects
Tradam, iWitness, wanDay etc across hackathons and so on

Liverage on all i have share with you and all we've built, numbers, etc



For the most impressive thing other than this startup
Also mention how I am a Coordinator and learning support for the MTN Skills Academy workshop and guided over 5000 young Cameroonians across 3 workshops towards gaining real world skils around tech fields and business. 
Be specific on my impact at Deltech Hub s far in the past 2 years

You're right.

The draft I gave would be acceptable, but it would massively underrepresent your profile.

After looking through your CV and tech journey document, the story isn't:

"I built a GPA app."

The story is:

"I've spent the last 3 years repeatedly building products, winning competitions, organizing communities, teaching technology, and helping thousands of people enter tech."

That is a very different founder profile. 

 


For YC, we want signal.

Most Impressive Thing Other Than This Startup
I would write:

I founded DelTech Hub, a technology and entrepreneurship community that has impacted more than 2,500 young innovators across Cameroon through bootcamps, hackathons, workshops, mentorship programs, and startup-building initiatives. I also served as a coordinator and learning support facilitator for MTN Skills Academy programs, helping guide more than 5,000 young Cameroonians through practical learning experiences in technology, entrepreneurship, and career development. While still a university student, I built and led these programs, organized hackathons, trained learners, mentored founders, and helped young people launch projects and careers in tech.

This is much stronger than talking about hackathons.

Why?

Because YC values people who can create leverage through people.

Things You've Built Before
This should showcase a pattern.

I've been building software products since my first year at university.

One of my first products was GPA Guide, a mobile application for university students that helps them track GPA, set academic goals, generate AI-powered study plans, and collaborate through study groups. The app was deployed on the Google Play Store and used by students at the University of Buea.

Since then, I've built multiple products through startups, hackathons, and community initiatives.

PrepSkul is an EdTech platform helping African learners learn at the right level through personalized tutoring, adaptive learning, and AI-assisted learning experiences.

iWitness is a browser extension that helps users browse more safely by analyzing privacy policies, website trustworthiness, harmful content, and online risks in real time.

Connectify won 1st place at the DEV WAR Hackathon and helped connect startups with potential investors. Tradam placed 3rd at CityHack Douala and became a national finalist with a barter-based digital commerce platform. Acuva was developed during the CITS National Hackathon as a data analytics platform for business decision-making, while Pablow focused on promoting and marketing Cameroonian music.
Alongside building products, I've organized bootcamps, hackathons, developer training programs, and technical workshops through DelTech Hub and other initiatives.

Competitions / Awards
Let's make this factual and specific.

Youth Impact Award 2025 (Technology Category)

Emerging Leader of the Year 2025

1st Place, DEV WAR Hackathon (Connectify)

1st Place, 237 Tech Hackathon (iWitness)

3rd Place, CityHack Douala (Tradam) and National Finalist

Finalist, CITS National Hackathon (Acuva)

Top 5, CIMFEST Hackathon (Pablow)

What YC Will Actually Like
Your strongest signal is not:

Flutter

AI

GPA Guide

It's that you're a repeat builder.

By age 21, you've:

Built multiple products

Won multiple hackathons

Built a startup

Built a community

Organized events

Trained thousands

Mentored people

Generated revenue

That's the pattern we want to make obvious throughout the application.

The profile should make a YC partner think:

"This founder has been creating things continuously for years. PrepSkul is just the latest thing he's building."

That's much stronger than looking like someone who started their first company six months ago.


Screenshot 2026-06-01 at 08.59.09.png
Screenshot 2026-06-01 at 09.01.54.png
Screenshot 2026-06-01 at 09.02.16.png
Screenshot 2026-06-01 at 09.02.40.png
YC did not really pull out all my work experience on LinkedIn

My eduction is abit light

Why do i see tradam instead od my or PrepSkul and how can i change it?

Instead of the tagline that says AI and entrepreneurship for young innovators, what should we say?

The current tagline feels like a training program.

But the design itself feels bigger:

ambitious

founder-focused

startup energy

future builders

So the tagline should communicate transformation and execution, not just topics.

Best options:

Building Africa’s Next Generation of Builders ✅

Where Young Innovators Build Real Ideas ✅

From Ideas to Real Products ✅

Helping Young Innovators Build the Future ✅

Turning Ideas Into Startups ✅

Learn. Build. Launch. ✅

Build What Matters ✅

For Young Builders Ready to Start ✅

Helping Young Innovators Go From Idea to Launch ✅

The Launchpad for Young African Builders ✅

My top 3 for this specific visual:

Building Africa’s Next Generation of Builders

From Ideas to Real Products

Learn. Build. Launch.

The strongest strategically is probably:

Building Africa’s Next Generation of Builders

Because it aligns with:

PrepSkul

DelTech Hub

YC-style ambition

entrepreneurship

AI

product building

ecosystem building

It sounds like a movement, not a workshop.


What is we want a supporting text below
AI and entrepreneurship for young innovators, while keeping the text?

Yes, that works better structurally.

You keep the strong identity:

Summer Build Camp

Then the supporting line explains it.

I’d structure it like this:

Option 1 (Strongest)
Building Africa’s Next Generation of Builders
AI and entrepreneurship for young innovators

Option 2
Learn. Build. Launch.
AI and entrepreneurship for young innovators

Option 3
From Ideas to Real Products
AI and entrepreneurship for young innovators

Option 4
The Launchpad for Young African Builders
AI and entrepreneurship for young innovators

Option 5
Helping Young Innovators Build the Future
AI and entrepreneurship for young innovators

For your ecosystem and long-term positioning, I’d personally choose:

Building Africa’s Next Generation of Builders
AI and entrepreneurship for young innovators

because it feels:

bigger than a camp

aligned with DelTech Hub

aligned with PrepSkul

aligned with your YC/founder narrative

community-driven

venture-scale minded

It sounds like something that could evolve into a long-term movement, not just a seasonal program.


No the AI and entrepreneurship for young innovators is the main text i want a supporting

Got it.

So:

Main text
AI and entrepreneurship for young innovators

Then you need a smaller supporting line beneath it.

Strong supporting text options:

Learn future-ready skills. Build real products.

From learning to launching real ideas.

Helping young builders turn ideas into reality.

Practical skills for the next generation of innovators.

A hands-on experience in building, creativity, and innovation.

Where young innovators learn to build and launch.

Equipping young Africans to build the future with technology.

Learn AI, build products, and solve real problems.

Turning curiosity into real-world innovation.

Helping students become builders, not just consumers.

Best fit for your positioning:

Helping students become builders, not just consumers.

Why?

Because it:

sounds deeper

aligns with your ecosystem vision

connects AI + entrepreneurship naturally

feels movement-oriented

sounds modern and founder-minded

So the hierarchy becomes:

AI and entrepreneurship for young innovators
Helping students become builders, not just consumers.


3fd4ab6b-b134-43ec-892b-8cf8b34f7b53.png
449abfa2-fb3f-494d-870a-11437c2cae8d.png

Pasted text(3).txt
Document

Pasted text (2).txt
Document
This is like our current website landing page
Abit week

Yes. It is weak.

Not because the UI is bad. The UI is actually decent for your current stage.

The weakness is strategic positioning.

Right now the landing page says:

"Find tutors."

But your actual insight is much bigger:

"Learners don't know what they need to learn next."

Those are two completely different companies.

Your current landing page looks like:

tutoring marketplace

educational services website

coaching platform

It does NOT yet look like:

learning guidance infrastructure

AI-powered educational navigation

personalized learning system

And that is the disconnect.

The Core Problem
Your homepage currently communicates:

"We provide tutors."

But your YC narrative communicates:

"We help learners navigate education."

The second is far stronger.

Current Hero Section Problem
Current:

Connect & Learn at the Right Level

This is okay.

But the subtext and visuals still make it feel like:

tutoring company.

The "Find Your Tutor" UI reinforces marketplace positioning.

What It Should Feel Like
When someone lands on PrepSkul, they should immediately feel:

"This platform understands where I am academically and guides me forward."

Not:

"This is another tutoring website."

The Strongest Shift
You need to shift from:

Current Positioning
tutors

sessions

home tutoring

online tutoring

to:

Guidance Positioning
learning path

skill gaps

academic level

personalized roadmap

progress guidance

next concept

AI recommendations

learning journey

Your Biggest Untapped Asset
Ironically, the strongest thing on your homepage right now is actually this:

Exam Accelerator Program

Why?

Because it demonstrates:

trust

scale

mission

movement

learning outcomes

accessibility

educational impact

It feels larger than "find a tutor."

What The Homepage Should Eventually Say
Instead of:

Connect & Learn at the Right Level

Something closer to:

Learn at the Right Level. Progress With Guidance.

or:

The Guidance Layer for Education in Africa

or:

Helping Learners Discover What To Learn Next

or:

Personalized Learning Guidance for African Students

The Real Homepage Structure
HERO SECTION
Headline
Learn at the Right Level

Subheadline
PrepSkul helps learners understand where they are academically, what they need to learn next, and how to improve through AI-powered guidance and personalized tutoring.

CTA
Start Learning

Assess My Learning Level

THEN SHOW THE PROBLEM
Not just stats.

Something like:

Most learners are taught according to age and curriculum.
PrepSkul helps learners learn according to their actual ability.

That alone differentiates you.

THEN SHOW GUIDANCE FLOW
1. Understand Your Level
Assessment + AI diagnostics

2. Get a Personalized Learning Path
Recommendations + weaknesses

3. Learn With the Right Support
Tutors + adaptive exercises + reinforcement

THEN SHOW TUTORS
Tutors become:

part of the system

instead of:

the product itself

This is VERY important.

Right Now Your Website Says
"Uber for tutoring."

Your YC Narrative Says
"Google Maps for learning."

The second is far bigger.

Another Important Observation
The design is actually cleaner than many early African startups.

Your biggest limitation is NOT frontend quality.

It's messaging hierarchy.

You already have:

bilingual support

clear sections

social proof

testimonials

tutor supply

real product

live infrastructure

That's ahead of many startups at your stage.

But the story the interface tells is still too small for the company you're trying to become. 





---

**Cursor**

Checking the latest English copy and PEAP section against ChatGPT's positioning feedback.


I re-checked the repo against ChatGPT’s feedback and your new “Google Maps for education” direction. Here’s a synthesized take — including where ChatGPT is right, where to be careful, and how to adapt messaging by audience.

**Note:** In the current repo, the English hero is still `"Connect & Learn at the Right"` and PEAP copy is hardcoded in `peap-showcase.tsx` (not in `translations.ts`). If you’ve drafted new tagline/PEAP text locally, it isn’t committed yet — paste it and I can review the exact wording.

---

## ChatGPT is right about the core problem

The diagnosis is accurate: **your UI is decent; your story is too small.**

There’s a split in your own codebase:

| Layer | What it says |
|-------|----------------|
| **Homepage hero** | “Find experienced tutors… personalized learning” |
| **Phone mockup** | “Find Your Tutor” |
| **FAQ #1** | “Guided learning ecosystem… custom roadmaps… learning to every learner’s level” |
| **About page** | “Guidance Builds Greatness” — movement, not marketplace |
| **Team Slack message** | “Google Maps for education” — discover what to learn next, how, and with whom |

Right now a visitor sees **Uber for tutoring**. Your YC/pitch narrative says **navigation layer for learning**. Those are different companies — and that’s why the page feels weak despite good design.

ChatGPT’s line is the one to keep:

> *The internet solved access to education. It did not solve guidance.*

That’s stronger than any tutor-marketplace headline.

---

## What’s actually live vs. aspirational (important)

Before you rewrite everything as “AI-powered learning navigation,” be honest about product reality:

**Live today (v1):**
- Tutor matching via onboarding survey (goals, challenges, subjects, budget)
- Book → pay (Fapshi) → online/home sessions
- PEAP as proof of scale and mission
- Tutor verification via PrepSkul Academy

**Partially built / off at launch:**
- SkulMate (post-session AI revision) — exists but `enableSkulMate = false`
- Full “assess my level → auto roadmap → AI diagnostics” — mentioned in FAQ, not yet the hero product experience

So the landing page should sell **guidance as the vision**, but prove it with **what works today**: human tutors + structured matching + PEAP outcomes + (optionally) “AI reinforcement coming” if SkulMate is near launch.

Don’t promise “Google Maps” UI on day one unless the app actually shows a learning path. Promise the **problem you solve** and **how you solve it now**.

---

## Recommended positioning hierarchy

Use a **主 + 副** structure (main line + supporting line), like you did for DelTech Hub:

### Main (PrepSkul — all audiences)
**Option A (closest to your Slack message):**
> **Learn at the right level — with guidance, not guesswork.**

**Option B (more investor/pitch):**
> **The guidance layer for education in Africa.**

**Option C (parent-friendly, less metaphor):**
> **Helping learners discover what to learn next — and who can help them get there.**

### Supporting (scenario-specific)

| Audience | Supporting line |
|----------|-----------------|
| **Parents / learners** | PrepSkul understands where your child is academically, matches them with a verified tutor, and supports progress session by session — online or at home. |
| **Investors / YC** | We’re building the navigation layer for learning: diagnosis → personalized path → human + AI reinforcement. Tutoring is the first wedge; PEAP proved demand at national scale. |
| **Pitch deck** | Access to education is solved. Guidance isn’t. PrepSkul connects learners to the right next step, the right support, and measurable progress. |

**On “No Cameroon”:** For **investor/global** copy, lead with **Africa** or **learners everywhere access is broken**. For **conversion** (parents booking tutors), keep **Cameroon-specific** proof: GCE, BEPC, Fapshi, cities, PEAP nationwide. Geo should match the CTA, not disappear entirely.

---

## Homepage restructure (aligned with ChatGPT + your product)

Keep your existing sections; **reorder the story**:

```
1. HERO — Guidance positioning (not "find tutors")
2. PROBLEM — "Taught by age/curriculum, not by actual ability"
3. HOW IT WORKS — 3 steps (this is missing today!)
4. PROOF — PEAP + stats (move PEAP UP, not buried mid-page)
5. LEARNING OPTIONS — tutors as delivery channel, not the product
6. PROGRAMS — academic + skills
7. TESTIMONIALS — mix PEAP + regular tutoring
8. FAQ + CTA
```

### 1. Hero (replace current)

**Current** (`translations.ts`):
```20:24:PrepSkul_Web/lib/translations.ts
        title: "Connect & Learn at the Right",
        titleWords: ["Level", "Pace", "Stride"],
        subtitle: "Find experienced, qualified tutors across Africa for personalized learning...
```

**Suggested direction:**
- **Headline:** `Learn at the Right Level`
- **Subhead:** `PrepSkul helps learners understand where they are, what to focus on next, and how to improve — through personalized guidance and trusted tutors.`
- **Primary CTA:** `Start Learning` → app
- **Secondary CTA:** `See How It Works` → scroll or `/how-it-works`

Replace the phone mockup’s **“Find Your Tutor”** (`mobile.findTutor.title`) with something like **“Your Learning Journey”** showing steps/path, not a tutor card — that single UI change fixes half the positioning mismatch.

### 2. New “Problem” block (ChatGPT’s best addition)

> **Most learners are taught by age and curriculum.**  
> **PrepSkul helps them learn by actual ability, gaps, and goals.**

One section. No cards. High contrast. This is your differentiation in one breath.

### 3. “How it works” (must be on homepage)

You already have `/how-it-works` but it’s **not in the nav** and **not on the homepage**. ChatGPT’s 3-step flow maps well to what you actually do:

1. **Understand your needs** — survey, goals, challenges (real: `student_survey.dart`)
2. **Get matched with the right support** — verified tutor + tailored plan (real: matching + booking)
3. **Learn and progress** — sessions, tracking, reinforcement (real today: sessions; future: SkulMate)

Tutors become **step 3’s engine**, not the headline.

### 4. PEAP — your strongest asset (ChatGPT nailed this)

PEAP currently reads well (“National Impact Initiative”, 500+ learners, March 2026) but:
- It sits **below** generic tutoring cards
- It has **no CTA** (Button imported, never used)
- Testimonials are **100% PEAP** — so the page tells two conflicting stories

**Fix:**
- Move PEAP **above** “Flexible Learning Options” or immediately after stats
- Reframe PEAP as **proof of the guidance model at scale**, not a separate program:
  > *“When 500+ exam candidates needed structured revision nationwide, PrepSkul delivered — free. That’s the guidance model we’re building for every learner.”*
- Add CTA: `Explore PEAP Results` or `Join the Next Cohort`

---

## What to change in copy (quick wins)

| Element | Issue | Fix |
|---------|-------|-----|
| Stats labels | “Sessions Covered” under 1000+, “Verified Tutors” under 130+ | Align labels with numbers or rename |
| Testimonials title | “What PEAP Participants Say” | Split: general PrepSkul + PEAP highlight |
| Header CTA | Goes to `/contact` | Same as hero → app or unified funnel |
| Bottom CTA | “Start Learning” → contact | → app |
| Hero subtitle | “across Africa” while cards say “Cameroon” | Pick primary geo per section |
| FAQ answer #1 | Strongest positioning line on the site | **Lift to hero subhead** — it’s buried |

That FAQ answer is literally your positioning:
> *“…understanding their learning challenges and developing custom roadmaps…”*

That should be above the fold, not FAQ item #1.

---

## Separate from the landing page (but connected)

ChatGPT mixed three things — keep them distinct:

### 1. PrepSkul landing page
Guidance + tutoring wedge + PEAP proof. Not your hackathon history.

### 2. YC / founder profile
DelTech Hub (2,500+ innovators), MTN Skills Academy (5,000+ guided), repeat builder pattern — **application and LinkedIn**, not homepage hero. ChatGPT’s rewrite there is much stronger than “I built a GPA app.”

### 3. DelTech Hub / Summer Build Camp tagline
That’s a **different brand**. Your chosen structure works:
- **Main:** `AI and entrepreneurship for young innovators`
- **Supporting:** `Helping students become builders, not just consumers.`

Don’t force PrepSkul and DelTech into one tagline — link them narratively: *“PrepSkul is the product; DelTech is the community that produces builders.”*

### LinkedIn showing Tradam instead of PrepSkul
That’s profile configuration, not code:
- **Experience:** Pin PrepSkul as primary, mark “Current”
- **Featured:** Add PrepSkul, PEAP, DelTech Hub
- **Headline:** Lead with PrepSkul + one-line positioning, not hackathon project names
- **Projects section:** Reorder so PrepSkul is first; Tradam as “past project”

---

## Scenario cheat sheet (for your team message today)

**Parents/Learners (website):**
> PrepSkul helps your child learn at the right level — we understand their needs, match a verified tutor, and support progress online or at home. From 2,500 XAF/session.

**Investors:**
> PrepSkul is building the guidance layer for education in Africa. We’ve already run a free nationwide exam program (500+ learners), operate a live tutoring marketplace, and are adding AI-powered reinforcement (SkulMate). Tutoring is the wedge; navigation is the platform.

**Pitch (one-liner):**
> The internet solved access to education. PrepSkul solves guidance — helping learners discover what to learn next, how to learn it, and who can help them succeed.

**YC “most impressive thing”:**
> DelTech Hub (2,500+ innovators) + MTN Skills Academy coordinator (5,000+ young Cameroonians) — leverage through people, not just products.

---

## Bottom line

ChatGPT’s feedback is **strategically correct**. The landing page isn’t weak because of Tailwind or layout — it’s weak because:

1. Hero + mockup scream **marketplace**
2. Your best copy lives in **FAQ and About**, not above the fold
3. **PEAP** is your proof of a bigger mission but is treated as a sidebar
4. **CTAs conflict** (app vs contact)
5. New **“Google Maps for education”** narrative isn’t reflected in `translations.ts` or `peap-showcase.tsx` yet

**Priority order for the team today:**
1. Agree on one positioning line (guidance, not tutors)
2. Rewrite hero + mockup label
3. Add problem statement + 3-step flow on homepage
4. Elevate PEAP as proof block
5. Unify CTAs
6. Keep Cameroon proof for conversion; use Africa framing for pitch/investors

If you paste your **draft new English tagline and PEAP text**, or switch to Agent mode, I can map exact strings to `translations.ts`, `peap-showcase.tsx`, and `phone-mockup` line by line.

---

**User**

Cursor is much closer to reality.

This is the kind of critique you get from someone thinking:

positioning
conversion
user psychology
startup differentiation
actual GTM

not just UI aesthetics.

And the biggest thing it correctly identified is:

Your homepage currently explains features before identity.

That is exactly the problem.

About The Typewriter

Your instinct is correct.

The typewriter effect is not the issue.

The words are.

Current:

level
pace
stride

These sound:

abstract
educational
vague
corporate

A parent in Cameroon does not wake up saying:

"My child needs better learning pace optimization."

They say:

"My child is struggling."
"We need a good tutor."
"He doesn't understand math."
"She needs help for GCE."
"We need guidance."

So the rotating words should communicate:

outcomes
direction
specificity
transformation
Better Typewriter Variations

Instead of:

Connect & Learn at the Right Level

Try:

Option 1 (Strongest)

Learn at the Right
Level. Pace. Path.

Why this works:

"Path" introduces guidance/navigation
still simple
still emotional
sounds intelligent
future scalable

This is probably the best balance.

Option 2

Learn with the Right
Tutor. Guidance. Support.

More conversion-focused.
Less visionary.
Better for parents.

Option 3

Learn at the Right
Level. Time. Direction.

"Direction" is VERY powerful.
Feels like guidance infrastructure.

Option 4

Learn with the Right
Help. Structure. Guidance.

Very parent-friendly.

Option 5 (Most YC-style)

Learn with the Right
Guidance.

Simple.
Strong.
Memorable.

My Recommendation

For your current stage:

Hero Headline

Learn at the Right
Level. Pace. Path.

Subheadline

PrepSkul helps learners understand what to learn next, connect with the right tutors, and improve through personalized guidance and adaptive learning.

This is MUCH stronger because:

still educational
still clean
but now introduces:
progression
navigation
guidance
personalization
Another Major Issue

Your current hero image says:

Find Your Tutor

But your narrative says:

Find Your Learning Path

These are different.

Your future mockups should eventually show:

skill gaps
progress
learning roadmap
recommendations
milestones
adaptive guidance

not just:

tutor card
book session

Because visually, your product currently still looks like:

Airbnb for tutors.

not:

AI-guided learning infrastructure.

Cursor Also Correctly Identified This

PEAP is your strongest differentiator.

100%.

That section feels:

mission-driven
national
scalable
impactful
defensible

It feels bigger than tutoring.

Which means:
PEAP should not feel like a side initiative.

It should feel like:

evidence that PrepSkul can coordinate learning at scale.

That matters.

Another Massive Strategic Insight

This from Cursor was VERY important:

Cameroon-specific positioning.

YES.

Right now you're trying to sound:

pan-African
global
big

too early.

Own:

GCE
Cameroon
BEPC
Concours
Upper Sixth
Form Five
Buea/Douala/Yaoundé

FIRST.

Why?

Because:

specificity builds trust
trust builds conversion
conversion builds traction
traction builds expansion

YC prefers:

dominant in one painful niche

over:

vaguely continental.

What PrepSkul Actually Is Right Now

Not:

AI education platform.

Not:

learning infrastructure.

Not yet.

Right now PrepSkul is:

A trusted guidance-driven tutoring and learning support system for Cameroonian learners.

THAT is believable.

The infrastructure narrative is:

the direction you're heading.

And that's okay.

Great startups evolve into their vision.

They don't pretend they've already reached it.



Let's plan the fixes and final decisssions from all we've discussed
The fonts, espetially tagline adn others are not responsive, the site does not have the premiunm feel required...

We'll be moving section by section, from landing to about, to programs to contact

---

**Cursor**

Reviewing each page and typography setup so we can produce a concrete section-by-section plan with final decisions.


Here is a consolidated **implementation plan** — final decisions locked, section-by-section, with typography/premium fixes baked in. Treat this as the team spec before you touch code.

---

# PrepSkul Website Upgrade Plan

## Part 0 — Lock these decisions first (team sign-off)

### What PrepSkul is **today** (public-facing truth)
> **A trusted, guidance-driven tutoring and learning support system for Cameroonian learners** — online or at home, with verified tutors and structured support for GCE, BEPC, and skills.

### Where you're **heading** (pitch/investor/About only)
> The internet solved access. PrepSkul is building the **guidance layer** — helping learners discover what to learn next, how, and with whom.

**Rule:** Homepage sells **today's product believably**. About + pitch deck carry the **vision**.

### Geography rule
| Context | Geo |
|---------|-----|
| Homepage, Programs, Contact, PEAP | **Cameroon-first** (GCE, BEPC, Buea, Douala, Yaoundé, Form Five, Upper Sixth) |
| About mission, YC, investor deck | Africa / broader — secondary |

### Hero copy — **FINAL**
| Element | English |
|---------|---------|
| **Headline (static)** | `Learn at the Right` |
| **Typewriter words** | `Level` · `Pace` · `Path` |
| **Subheadline** | `PrepSkul helps learners in Cameroon understand what to focus on next, connect with verified tutors, and improve through personalized guidance — online or at home.` |
| **Primary CTA** | `Start Learning` → app (`getStartedUrl()`) |
| **Secondary CTA** | `See How It Works` → scroll to `#how-it-works` |

**Do not use** "adaptive learning" or "AI-powered" in hero until SkulMate is live — say **personalized guidance** (true via survey + tutor matching).

### CTA hierarchy — **FINAL (site-wide)**
| Button | Destination | Where |
|--------|-------------|-------|
| Start Learning / Get Started | App or Play Store | Hero, bottom CTA |
| See How It Works | `#how-it-works` or `/how-it-works` | Hero, nav |
| Talk to Us / Get Matched | `/contact` | Secondary only |
| Header primary | **Same as hero** (not contact) | Fix `header.tsx` |

### Stats labels — **FINAL**
| Number | Label |
|--------|-------|
| 600+ | Learners Reached |
| 1,000+ | Sessions Completed |
| 130+ | Verified Tutors |
| 7+ | Cities in Cameroon |

### PEAP framing — **FINAL**
Not a sidebar program. It's **proof PrepSkul coordinates learning at national scale**.

One-line bridge:
> *When 500+ exam candidates needed structured revision nationwide, PrepSkul delivered — free. That's the guidance model we build for every learner.*

---

## Part 1 — Cross-cutting foundations (do once, before sections)

These fix the **premium feel** and **responsive typography** issues you flagged. Apply across all pages.

### 1A. Typography scale (create shared classes in `globals.css`)

**Problem today:** Hero jumps `text-5xl → text-7xl` with no `clamp()`. Typewriter has `minWidth: 80px` — words like "Direction" or "Guidance" will clip or jump layout. Contact hero is smaller than landing — feels inconsistent.

**Fix — adopt a fluid type system:**

```css
/* Conceptual — implement in globals.css */
.text-display    → clamp(2.25rem, 5vw + 1rem, 4.5rem)   /* hero h1 */
.text-display-sm → clamp(2rem, 4vw + 0.5rem, 3.5rem)    /* page heroes */
.text-section    → clamp(1.75rem, 3vw + 0.5rem, 2.5rem)  /* h2 */
.text-lead       → clamp(1rem, 1.5vw + 0.5rem, 1.25rem)  /* subheads */
```

**Rules:**
- Hero h1: `text-display font-bold tracking-tight leading-[1.05]`
- Subheads: `text-lead text-muted-foreground max-w-xl` (not `max-w-3xl` on hero — tighter reads more premium)
- Section h2: `text-section font-bold`
- Body in cards: stay `text-sm` — don't shrink hero to fit cards

### 1B. Typewriter component fixes (`typewriter.tsx`)

- Set `minWidth` dynamically per longest word (or use `ch` units: ~8ch for "Guidance")
- Add `aria-live="polite"` for accessibility
- Ensure rotating word uses same font size/weight as static headline (no layout shift)
- Consider **stopping rotation on mobile** if it causes jank — show static "Path" on small screens

### 1C. Phone mockup — phased approach

| Phase | Change | Effort |
|-------|--------|--------|
| **Now (Phase 1)** | Rename card header from "Find Your Tutor" → **"Your Learning Journey"**; show 3 mini-steps (Needs → Match → Progress) instead of tutor booking card | Medium |
| **Later (Phase 2)** | Replace with real app screenshot or designed "learning path" UI (gaps, milestones) | High |

Phase 1 alone fixes the Airbnb-for-tutors visual problem without waiting on design assets.

Also fix in `globals.css`: phone `scale(0.6)` is too aggressive on tablet — use responsive scale:
- mobile: `scale(0.55)` or hide mockup, show simplified graphic
- md: `scale(0.65)`
- lg: `scale(0.75)`

### 1D. Premium feel checklist (apply per section)

- **More whitespace** — increase section padding from `py-12` → `py-16 sm:py-20 lg:py-24` on key sections
- **Fewer borders** — replace `border-2` cards with `shadow-sm hover:shadow-md` + subtle `ring-1 ring-border/50`
- **One accent moment per section** — not every card hover turns primary
- **Consistent max-width** — content blocks: `max-w-6xl`; text blocks: `max-w-2xl` centered
- **Section labels** — small uppercase tracking badge above h2 (e.g. `HOW IT WORKS`) — instant premium hierarchy
- **Move PEAP + problem statement copy into `translations.ts`** — PEAP is hardcoded English today; breaks FR parity

### 1E. Nav update (`header.tsx` + footer)

Add to desktop + mobile nav:
- How It Works → `/${locale}/how-it-works`
- Optional: Tutors → `/${locale}/tutors`

Keep nav to **5 items max** — Home, Programs, How It Works, About, Contact.

### 1F. Files touched globally
- `PrepSkul_Web/app/globals.css`
- `PrepSkul_Web/lib/translations.ts` (EN first, FR after EN is approved)
- `PrepSkul_Web/components/header.tsx`
- `PrepSkul_Web/components/footer.tsx` (fix App Store link → real URL or remove)
- `PrepSkul_Web/components/typewriter.tsx`
- `PrepSkul_Web/components/phone-mockup.tsx`

---

## Part 2 — Landing page (section by section)

**New section order** in `app/[locale]/page.tsx`:

```
Hero → Problem → Stats → How It Works → PEAP → Learning Options → Programs → Testimonials → FAQ → CTA
```

---

### Section 1: Hero

**Identity before features.** One job: parent/student knows what PrepSkul is in 5 seconds.

| Item | Action |
|------|--------|
| Copy | Apply final headline + subhead + typewriter words |
| CTAs | Primary → app; Secondary → `#how-it-works` |
| Typography | Replace `text-7xl` with `text-display` |
| Mockup | Phase 1 journey UI (not tutor card) |
| Trust strip | Add one line under CTAs: `Verified tutors · GCE & BEPC prep · From 2,500 XAF/session` |
| Mobile | Left-align text on all breakpoints (remove `justify-center` on sm for hero buttons) |

**New translation keys:**
```ts
home.hero.title: "Learn at the Right"
home.hero.titleWords: ["Level", "Pace", "Path"]
home.hero.subtitle: [Cameroon subhead above]
home.hero.trustStrip: "Verified tutors · GCE & BEPC prep · From 2,500 XAF/session"
home.hero.howItWorks: "See How It Works"
```

---

### Section 2: Problem statement (NEW)

**ChatGPT + Cursor consensus — highest-impact new block.**

```
[ small label: THE PROBLEM ]

Most learners are taught by age and curriculum.
PrepSkul helps them learn by ability, gaps, and goals.
```

- Dark or muted background (`bg-primary/5` or soft gray)
- No cards. Two lines. Large type.
- This is your differentiation — don't bury it

**Translation keys:** `home.problem.line1`, `home.problem.line2`

---

### Section 3: Stats

| Item | Action |
|------|--------|
| Labels | Fix to final table above |
| Context | Add micro-line above stats: `Trusted across Cameroon` |
| Typography | Counters stay bold; labels `text-xs sm:text-sm` |

---

### Section 4: How It Works (NEW on homepage)

Extract/simplify from existing `/how-it-works/page.tsx`. Three steps:

| Step | Title | Body |
|------|-------|------|
| 1 | Tell us what you need | Share your subjects, exam (GCE, BEPC), goals, and schedule |
| 2 | Get matched with the right tutor | Verified educators trained through PrepSkul Academy |
| 3 | Learn and track progress | Online or home sessions with structured support between lessons |

- Add `id="how-it-works"` for anchor links
- Link to full page: "Learn more about the process →"
- Tutors are **step 2's delivery mechanism**, not the headline

**Component:** new `components/how-it-works-section.tsx` (reused on homepage; full page can import same steps)

---

### Section 5: PEAP (elevated + reframed)

| Item | Action |
|------|--------|
| Position | Move **above** Learning Options |
| Reframe | Lead with proof, not program description |
| Copy | Move all strings to `translations.ts` |
| CTA | Add button: `See PEAP Impact` or `Learn About PEAP` |
| Stats | Keep 500+, Nationwide, 2 Weeks, 100% Free |
| Closing line | Use bridge copy from Part 0 |

**Suggested PEAP header reframe:**
- Badge: `Proven at National Scale`
- H2: `PrepSkul Exam Accelerator Program (PEAP)`
- Sub: keep GCE 2025/2026 specificity — Cameroon parents trust this

---

### Section 6: Learning Options

| Item | Action |
|------|--------|
| Reframe title | `How You Learn` (not "Flexible Learning Options") |
| Reframe subtitle | Tutors deliver guidance **your way** — online, home, or group |
| Cards | Add subtle CTA per card: `Learn more →` linking to programs anchors |
| Copy | Ensure all three say **Cameroon**, not "Africa" |

---

### Section 7: Programs preview

Keep two-card layout but tighten copy toward **outcomes**:

- Academic: lead with **GCE O/A, BEPC, Baccalauréat**
- Skills: lead with **coding, digital literacy, life skills**

Both CTAs → `/${locale}/programs` (not duplicate "View Programs" twice with same label)

---

### Section 8: Testimonials

| Item | Action |
|------|--------|
| Title | `What Learners & Parents Say` (not PEAP-only) |
| Subtitle | Mix general tutoring + exam prep |
| Content | Keep 2 PEAP + 2 general (Marie Fotso parent quote is perfect) |
| Optional | Add exam type tags: `GCE A-Level`, `Form 5`, `Coding` |

---

### Section 9: FAQ

| Item | Action |
|------|--------|
| FAQ #1 answer | Already strong — ensure hero subhead echoes it |
| Add question | `How is PrepSkul different from finding a tutor on WhatsApp?` |
| Answer angle | Verification, safeguarding, structured matching, payment protection, PrepSkul Academy |

---

### Section 10: Bottom CTA

| Item | Action |
|------|--------|
| Title | `Ready to learn at the right level?` |
| Subtitle | Cameroon-specific, mention cities |
| Button | `Start Learning` → app (not contact) |
| Secondary | `Talk to our team` → contact |

---

## Part 3 — About page

**Job:** Tell the **why** and **founder credibility** without repeating the homepage feature list.

### Current issues
- Hero says "Guidance Builds Greatness" — good internally, vague externally
- Story mentions "Cameroon and Africa" — tighten to Cameroon first
- Values grid is 6 generic cards — feels template
- CTA goes to contact, not app

### Proposed structure

| Section | Change |
|---------|--------|
| **Hero** | `We believe guidance builds great learners` + sub: Cameroon movement, not tutoring agency |
| **Story** | Rewrite para 1 around the insight: *access exists, guidance doesn't* — this is your Slack message |
| **Proof block (NEW)** | PEAP stats + DelTech/MTN only if you want founder credibility here — **optional**, keep light |
| **Mission** | Keep primary block — strong visual break |
| **Values** | Reduce to **4** (Growth, Trust, Accessibility, Excellence) — cut redundancy |
| **CTA** | Primary → app; Secondary → tutors |

**About hero subhead (draft):**
> PrepSkul started in Cameroon with a simple belief: every learner deserves to know where they stand, what to focus on next, and who can help them get there.

---

## Part 4 — Programs page

**Job:** Convert intent — parent knows their child needs **Math + GCE** and finds it fast.

### Current issues
- Hero is generic ("Our Programs")
- Heavy framer-motion — fine, but content is feature-first
- Exam prep section exists but isn't hero-level — **GCE/BEPC should lead**

### Proposed structure

| Section | Change |
|---------|--------|
| **Hero** | `Programs built for Cameroonian learners` + sub listing GCE, BEPC, Baccalauréat, skills |
| **Exam prep** | **Move to top** (before academic grid) — highest intent traffic |
| **Academic** | Keep subject cards; add exam tags on each |
| **Skills** | Keep; tie to "future-ready" not generic |
| **What's included** | Rename features: "Personalized Plans" → **"Guidance from day one"** |
| **CTA** | Primary → app; Secondary → how-it-works |

**Programs hero (draft):**
> **Headline:** Programs for every learner in Cameroon  
> **Sub:** From GCE and BEPC exam prep to coding and life skills — with verified tutors and structured guidance.

---

## Part 5 — Contact page

**Job:** Capture leads who won't download the app yet — parents especially.

### Current issues
- Hero copy is a wall of text
- Form is functional but feels administrative
- No pricing anchor, no WhatsApp-first option above fold
- Typography smaller than rest of site

### Proposed structure

| Section | Change |
|---------|--------|
| **Hero** | Short: `Let's find the right support for you` + 2 lines max |
| **Dual path (NEW)** | Two cards above form: **Download the app** vs **Fill the form** — let user self-select |
| **Form** | Add field: `City` (Buea, Douala, Yaoundé, Other) — GTM data + trust |
| **Form** | Add `Class/Form` for students (Form 3, Form 5, Upper Sixth) |
| **Pricing note** | Small text: `Sessions from 2,500 XAF · Transparent pricing before you start` |
| **WhatsApp** | Prominent: `Prefer WhatsApp? Message us directly` with link |
| **Typography** | Match `text-display-sm` on hero h1 |

**Contact hero (draft):**
> **Headline:** Get matched with the right support  
> **Sub:** Tell us what you need — we'll connect you with a verified PrepSkul tutor within 24 hours.

---

## Part 6 — Implementation phases & order

### Sprint 1 — Identity + conversion (Landing only)
**Goal:** Homepage tells the right story and converts.

1. Lock copy in `translations.ts` (EN)
2. Typography scale + typewriter fix
3. Hero rewrite + CTA unification (header too)
4. Problem statement section
5. How it works section
6. PEAP move + reframe + CTA
7. Stats label fix
8. Phone mockup Phase 1 (journey UI)
9. Testimonials title + mix
10. Bottom CTA fix

**Ship EN first. FR follows once EN is approved.**

### Sprint 2 — Premium polish (Landing)
1. Section spacing + card shadow system
2. Phone mockup responsive scale
3. Trust strip, section badges
4. Server-render static hero content (SEO — optional but valuable)

### Sprint 3 — About + Programs
1. About copy rewrite + values trim
2. Programs reorder (exam prep first) + hero
3. Cross-link CTAs consistently

### Sprint 4 — Contact + FR
1. Contact dual-path + form fields
2. French translations for all new keys
3. OG image update (not just logo.jpg)

---

## Part 7 — Open decisions (resolve in today's team sync)

| # | Question | Recommendation |
|---|----------|----------------|
| 1 | Typewriter on mobile — rotate or static "Path"? | Static "Path" on `< sm` |
| 2 | PEAP CTA — link where? | Dedicated `/peap` page later; for now anchor scroll or contact with `?program=peap` |
| 3 | Include DelTech/MTN on About? | Light mention only — 1 sentence + stats; full story stays YC/LinkedIn |
| 4 | "Adaptive learning" in copy? | No until SkulMate ships; use "personalized guidance" |
| 5 | App vs contact as primary site-wide? | **App primary**, contact for hand-holding parents |
| 6 | FR timing? | After EN Sprint 1 is live and reviewed |

---

## Part 8 — Copy doc to share with team (paste-ready)

**One-liner (WhatsApp/social):**
> PrepSkul helps Cameroonian learners learn at the right level — with personalized guidance and verified tutors, online or at home.

**Pitch one-liner (investors):**
> The internet solved access to education. PrepSkul is building the guidance layer — starting with tutoring in Cameroon, proven at national scale through PEAP.

**Hero (website):**
> **Learn at the Right** Level · Pace · Path  
> PrepSkul helps learners in Cameroon understand what to focus on next, connect with verified tutors, and improve through personalized guidance — online or at home.

---

When you're ready to execute, switch to **Agent mode** and say **"Start Sprint 1 — Landing hero + problem + how it works"**. We'll go section by section exactly as planned, starting with `translations.ts` and `page.tsx` so copy and layout stay in sync.

If anything in Part 7 should go a different way, lock those calls in the sync first — everything else is ready to build.

---

**User**

No em dashes like this  — 
We need a bright deepblue and yellow design feel
Ask me for any narative you want to pu out there before you do if you are not sure, don't just take decissions
I prefare we postion as Cameroon and Across Africa or pay less attention to Country becuase we are scaling...

Let's not make it look small or unprefessional...

Let's plan and excute

Also solve this problem @/Users/user/.cursor/projects/Users-user-Desktop-PrepSkul/terminals/6.txt:7-63 

---

**Cursor**

Fixing the pnpm workspace issue first, then reviewing the design system and landing page so we can plan and execute with your constraints (no em dashes, deep blue + yellow, Africa-scale positioning).


pnpm is fixed. Implementing design tokens and Sprint 1 landing page updates.


Implementing design system and landing page Sprint 1 in parallel.


Done. Here is what was fixed and shipped for **Sprint 1 (Landing page)**.

---

## pnpm fix

`pnpm-workspace.yaml` was missing a `packages` field, so pnpm treated the project as a broken workspace.

**Fix:** Added `packages: ['.']` to `pnpm-workspace.yaml`.

You can now run:
```bash
cd PrepSkul_Web && pnpm dev
```
Dev server is running at **http://localhost:3000**.

---

## Sprint 1: Landing page (executed)

### Design system
- **Deep blue primary** + **bright yellow accent** across theme tokens
- Fluid typography: `.text-display`, `.text-section`, `.text-lead`
- `.section-label` (yellow uppercase badges)
- `.premium-card` (shadow/ring instead of heavy borders)
- Responsive phone mockup scaling (larger on desktop)

### Positioning (your direction)
- Hero: **"Learn at the Right"** + typewriter **Level · Pace · Path**
- Geo: **"learners across Africa"** (not Cameroon-only)
- Guidance narrative, not "find a tutor" marketplace
- No em dashes anywhere in new copy

### New / reordered sections
1. **Hero** (guidance copy, trust strip, unified CTAs)
2. **Problem statement** (deep blue block)
3. **Stats** (fixed labels)
4. **How It Works** (new component, `#how-it-works` anchor)
5. **PEAP** (moved up, reframed as national proof, CTA added)
6. Learning options → Programs → Testimonials → FAQ → CTA

### Components updated
- `header.tsx`: How It Works in nav, Get Started → app
- `phone-mockup.tsx`: "Your Learning Journey" steps (not tutor card)
- `peap-showcase.tsx`: i18n, yellow accents, bridge copy
- `typewriter.tsx`: responsive width, yellow cursor

### Bottom CTA
- Primary: **Start Learning** → app (yellow button on blue)
- Secondary: **Talk to our team** → contact

---

## What's next (Sprint 2–4)

| Sprint | Pages | Status |
|--------|-------|--------|
| **2** | About | Pending your review of landing |
| **3** | Programs | Pending |
| **4** | Contact | Pending |

---

## Before Sprint 2, please confirm or adjust

1. **Hero subhead** – currently: *"PrepSkul helps learners across Africa understand what to focus on next..."*  
   Want more/less Africa emphasis?

2. **PEAP** – still mentions Cameroon specifically (it's factual for that program). OK to keep?

3. **Pricing in trust strip** – *"Sessions from 2,500 XAF"* – keep or remove?

4. **Yellow intensity** – current accent is bright gold. Want it bolder or softer?

Open **http://localhost:3000/en** and review the landing page. When you're happy (or after tweaks), say **"Start Sprint 2: About"** and we'll continue section by section.

---

**User**

Bro please remove the yellow aspects papa, go back to the previous colors, it just made the site not nice, white and deeepblue and strategic yellow usage at different minor areas like in images, etc...
You can give me prompts for the Ho it works  images, so that we don't use icons


This page is much stronger than the homepage structurally.

But strategically, it still sounds like:

educational service categories

instead of:

guided learning outcomes.

Right now it feels like:

course catalog
tuition center
tutoring agency

The opportunity is to make it feel like:

learning journeys designed around goals.

Biggest Issue

The page organization is:

Academic Tutoring
Skill Development
Exam Preparation

This is logical.

But emotionally weak.

Parents and students don't buy:

categories.

They buy:

passing exams
confidence
future opportunities
guidance
skill growth
academic recovery
Biggest Upgrade

Rename:

Our Programs

to something like:

Option 1 (Strongest)

Learning Paths for Every Goal

Option 2

Choose Your Learning Journey

Option 3

Personalized Paths to Success

Option 4

Guided Learning Paths

Hero Section Rewrite

Current:

From academic excellence to skill mastery...

Generic.

Better:

Version 1

Whether you're preparing for GCE, improving weak subjects, or learning future-ready skills, PrepSkul helps you learn with the right guidance and support.

Version 2

Every learner is different. PrepSkul combines personalized tutoring, structured learning support, and flexible learning options to help learners progress at the right level.

Rename The Sections

Current:

Academic Tutoring

Weak because:

commodity
generic
sounds like every tutoring site

Better:

Academic Growth Path

or

Academic Excellence Path

Current:

Skill Development

Better:

Future Skills Path

or

Digital Skills Path

Current:

Exam Preparation

This is already strong because it is outcome-based.

Maybe:

Exam Success Path
Most Important Strategic Shift

Right now your cards describe:

subjects.

Instead, they should describe:

learner outcomes.

Example Transformation
CURRENT

Mathematics
Algebra, Geometry, Calculus...

Weak.

BETTER
Improve in Mathematics

Personalized support for learners struggling with math concepts, exam preparation, problem-solving, and confidence building from primary to university level.

Now it feels:

personalized
human
guided
outcome-driven
Another Massive Missed Opportunity

You barely mention:

right-level learning
personalized guidance
skill gaps
adaptive support

Those are your differentiators.

Every section should subtly reinforce:

learners progress differently.

Example Better Intro

Instead of:

From academic excellence to skill mastery...

Try:

PrepSkul helps learners follow personalized learning paths based on their goals, strengths, and current level, whether they need academic support, exam preparation, or future-ready digital skills.

This immediately reinforces:

personalization
progression
guidance
pathways
The “95% Success Rate” Section

Dangerous.

YC-style thinking:
If you cannot rigorously prove it:

don't use exact percentages.

Especially in education.

Better:

Replace With

Hundreds of learners have used PrepSkul for tutoring, exam preparation, and skill development across Cameroon.

or

Learners across Cameroon use PrepSkul to improve academically, prepare for exams, and develop practical skills for the future.

Trust > exaggerated claims.

"What's Included" Section

This section is actually GOOD.

But:

"Qualified Tutors"

should become:

Verified Tutors

because trust matters more.

"Personalized Plans"

VERY GOOD.
Lean into this more.

Add:

Right-Level Learning Support

This is your moat.

Final Strategic Insight

Right now your Programs page still answers:

"What subjects do you offer?"

But your company vision is trying to answer:

"How do learners progress effectively?"

Those are fundamentally different companies.

You don't need to fully become the second yet.

But every page should slowly transition users from:

tutoring marketplace

towards:

personalized learning guidance system.

---

**Cursor**

Reverting the yellow theme to deep blue + white, then restructuring the Programs page around guided learning outcomes. Checking the codebase for yellow usage and the Programs page structure.


Reverting colors to deep blue + white, updating the landing page accents, restructuring the Programs page, and adding How It Works image support plus generation prompts.


Done. Here is what changed:

## 1. Colors reverted (no site-wide yellow)

- Theme accent is back to **deep blue** (same as before the yellow experiment).
- Landing, PEAP, phone mockup, typewriter, and CTA use **primary blue + white** only.
- Yellow is not used in UI chrome anymore. You can still use it **inside photos** when you generate assets.

## 2. Programs page rebuilt (guidance / outcomes)

| Before | After |
|--------|--------|
| Our Programs | **Learning Paths for Every Goal** |
| Academic Tutoring | **Academic Growth Path** |
| Skill Development | **Future Skills Path** |
| Exam Preparation | **Exam Success Path** (moved **first**) |
| 95% success rate | **Trust statement** (no unproven %) |
| Subject catalog cards | **Outcome cards** (e.g. "Improve in Mathematics") |
| 4 included items | **5 items** including **Right-Level Learning Support** |
| Qualified Tutors | **Verified Tutors** |

New flow: Hero → intro band → Exam path → Academic path → Skills path → What's included → CTA (app + how it works).

## 3. How It Works: photos instead of icons

- Steps now use **photo cards** with step numbers on the image.
- Fallback photos are active until you add custom files.
- Full prompts saved in: `PrepSkul_Web/docs/HOW_IT_WORKS_IMAGE_PROMPTS.md`

**Image prompts (save to `public/images/how-it-works/`):**

**`step-1-share-needs.jpg`**  
Professional photograph of a young African secondary school student and a parent with a friendly tutor, discussing learning goals on a notebook and tablet. Warm study setting, hopeful expressions, soft natural light, EdTech marketing style, deep navy and white tones, no text overlay.

**`step-2-matched-tutor.jpg`**  
Professional photograph of a confident young African tutor welcoming a student one-on-one, laptop and textbooks visible, modern study space, trustworthy education brand photo, navy blue and white environment, no text overlay.

**`step-3-track-progress.jpg`**  
Professional photograph of a motivated African student studying with confidence, reviewing notes or a laptop, tutor softly in background, sense of progress and achievement, premium EdTech quality, no text overlay.

After you add those three files, set `USE_CUSTOM_IMAGES = true` in `components/how-it-works-section.tsx`.

---

Refresh:
- Landing: `http://localhost:3000/en`
- Programs: `http://localhost:3000/en/programs`

If you want tweaks to Programs copy (hero version 1 vs 2, or path naming), say which lines to change and we can adjust before About / Contact.

---

**User**

Just so bold an not Nice man
What is this? Please remove the picuture of the flyer, let's have a nicely strucutured image stacking showing inline sessions of students learning in groups, i'll upload and other image

Now the colors just look dump and not cool, just so plane, and note exciting,

This landing page should not be too different from the previous
can we make things work man

---

**Cursor**

Reviewing the landing page and PEAP section to restore visual energy closer to the previous design, remove the flyer, and add a structured image stack for group learning photos.


Here is what I changed to get the landing page closer to the **previous look** while keeping the stronger copy.

## Fixed

### PEAP section
- **Removed the flyer** (`program1.jpg`) completely.
- Added a **3-layer photo stack** (group class + online session + live session) with depth and rotation.
- Softer section styling: gray gradient background, smaller logo, lighter quote box (not a heavy navy slab).
- Your meet screenshot is already used as the middle layer at `public/images/peap/peap-session-online.png`.

**When you upload your own photos**, drop them here:
- `public/images/peap/peap-stack-back.jpg`
- `public/images/peap/peap-stack-mid.jpg`
- `public/images/peap/peap-stack-front.jpg`

Then set `USE_UPLOADED_STACK = true` in `components/peap-image-stack.tsx`. Details are in `docs/PEAP_IMAGE_STACK.md`.

### Hero (back to previous feel)
- Gray gradient background (`from-gray-50 to-white`) and decorative circles restored.
- Original headline sizes (`text-5xl` / `6xl` / `7xl`), not the oversized display type.
- **Phone mockup restored** to the familiar layout: Find Your Tutor card, Online/Home/Groups pills, tutor preview (not the big “Learning Journey” block).
- Secondary button back to **View Programs** (like before).
- Blue glow behind the phone restored.

### Less “bold / plain”
- Removed the full-width **dark navy problem banner**; it is now a soft gray band with normal text.
- Learning option and program cards use **`border-2` + hover shadow** again (like the old site).
- Stats section matches the previous border layout.

### Colors
- Back to **white + deep blue** only (no site-wide yellow).
- Small **amber** star on the tutor rating in the phone (same as before).

---

## Important: hard refresh

Your screenshot still shows **old copy** (“Connect & Learn…”, old nav). The code now has **“Learn at the Right”** and updated buttons. Do a hard refresh:

**Mac:** `Cmd + Shift + R`  
Or open an incognito window at `http://localhost:3000/en`

---

## Next step for you

Upload 2–3 **group / online learning** photos to the `peap-stack-*` paths above and tell me when they are in place; I will flip the stack to use only your images.

If anything still feels off after refresh, say which section (hero, PEAP, or how-it-works) and we can tune that section only.

---

**User**

Work on the contact's page UI bro

---

**Cursor**

Reviewing the contact page and aligning its UI with the updated landing page style.


Redesigning the contact page to match the site: clearer layout, dual paths (app vs form), and updated copy.


Rewriting the contact page with a two-column layout, dual paths, and role/path card selectors.


The contact page is redesigned to align with the landing and programs pages. Here is what changed:

### Layout and hero
- Gray gradient hero with shorter, goal-focused copy (EN + FR)
- Two top cards: **Start in the app** (links to `getStartedUrl()`) and **Request a callback** (with pricing note)

### Two-column main section
- **Left sidebar** (sticky on desktop): WhatsApp CTA, clickable phone, location, link to programs
- **Right panel**: wider form card with `border-2` styling

### Form UX
- **Role** and **learning path** are card pickers (not only dropdowns)
- Path labels match programs: Academic Growth, Exam Success, Future Skills
- Subject/skill chips use selected-state borders
- Success state uses translations (no hardcoded English)
- `?program=exam|academic|skills` pre-selects a path from the URL

### Copy (i18n)
- New keys: `paths`, `sidebar`, `form.subtitle`, `form.errors`, expanded `form.success`
- French updated to match

Open `/en/contact` or `/fr/contact` on your dev server to review. If you want tweaks (e.g. PEAP as a fourth path, or scroll-to-form when clicking “Request a callback”), say what you prefer.

---

**User**

Use the workd Academic support, 
Your 2500 XAF makes us look cheap man we have to be premium
Remove it....
Connect and learn at the right ... was cool thought just that the way the text is postioned in smalle and learge screens is not cool, maybe the size?

This supporiting description is so so vague man
Not YC standards

please the sites context should be YC standards aligning to African context

Work on ths book card, to be more seamless

The PEAP sectio has alot of work man, i don't just feal the intro


Don't forget to change naratives in both languages for alll text changes

Ask me anything you are unsure

---

**Cursor**

Upgrading copy, hero typography, the tutor book card, and the PEAP section across EN/FR. Exploring the current implementation.


Applying premium copy, hero typography fixes, seamless book card, and PEAP intro across EN/FR.


Here is what changed across **EN and FR**:

### Hero (positioning + typography)
- Headline back to **“Connect & Learn at the”** + typewriter **Level / Pace / Path** (FR: **“Connectez-vous et apprenez au bon”** + Niveau / Rythme / Parcours).
- Responsive sizes so mobile does not chop words awkwardly; typewriter stays **inline** with `whitespace-nowrap` and a flexible min-width.
- Subhead is sharper and uses **academic support**: built for Africa, verified tutors, structured guidance.
- Trust strip: **no 2,500 XAF** → `Verified tutors · Academic support · Guidance that fits you`.

### Premium positioning (no “cheap” cues)
- Removed **2,500 XAF** from trust strip, contact pricing card, and FAQ answers (both languages).
- FAQ pricing now: tailored plans, discussed clearly before commit.
- Footer, CTA, programs, contact, and About accessibility copy updated to match.

### Phone “book” card
- Softer, integrated card: gradient background, light ring instead of heavy border, rating beside name, subtler chips, **“Book support”** CTA, header card says **Academic support**.

### PEAP section
- Stronger intro layout: left narrative + right stat grid.
- New punch line: *“Not more content. The right sequence…”*
- Rewritten subtitle, story, bridge, and CTA; stats fully i18n (including values).

### Naming
- **Academic Support Path** on programs, contact, and related copy (was Academic Growth).

Hard refresh the site (`Cmd+Shift+R`) to see it.

**One thing to confirm:** PEAP intro still says **“Cameroon’s largest free GCE revision sprint”** because PEAP is nationally Cameroon-focused. If you want that framed as **Africa-scale vision** while keeping PEAP factual, say how you want that line to read and I will adjust EN + FR.

---

**User**

Connect and learn at the right....

I don't know where this will be helptfull, from supporting text, etc
Take note that parents will be visiting the page, not just portential investors or organizations


For decades, the solution to education has been more access.

More schools. More teachers. More books. More courses. More educational content.

Today, a learner can access YouTube, Google, ChatGPT, online courses, private tutors, and thousands of learning resources from a mobile phone.

Yet learning outcomes remain poor.

More than 70% of children in Cameroon cannot read and understand an age-appropriate text by age 10, and learning poverty continues to affect over 100 million learners across Africa. These learning gaps compound over time, leading to poor academic performance, reduced employability, and limited economic opportunities later in life.

The internet solved access to education.
It did not solve guidance.

PrepSkul is building the guidance layer for education in Africa, the Google Maps for learning. We help learners understand where they are academically, identify learning gaps, access the right support, and learn at the right level rather than simply following the same curriculum path.

We combine AI-powered learning experiences, adaptive assessments, and qualified tutors to deliver personalized learning journeys that improve outcomes for learners.


---

**Cursor**

Aligning the hero with "Connect & Learn at the Right [Level/Pace/Path]" and rewriting supporting copy for parents—clear guidance framing without investor jargon.


Fixing the hero to include "Right" and rewriting copy for parents, incorporating the access-vs-guidance narrative.


Here is what changed based on your narrative and the parent-first audience.

### Hero fix (“at the Right”)
The headline was missing **Right**, so it read awkwardly as “Learn at the **Path**”. It is now:

- **Line 1:** Connect & Learn  
- **Line 2:** at the Right **Level / Pace / Path** (typewriter)

French: **Connectez-vous & apprenez** / **au bon Niveau / Rythme / Parcours**

### Parent-first supporting copy
- **Subtitle:** speaks to parents (“your child”, access vs progress, what to focus on next).
- **Support line:** “Built for parents and students across Africa…”
- **CTA:** “Get Academic Support” (not investor-style language).
- **Trust strip:** “For parents and students · Verified tutors · Progress you can see”

### Where your story lives (not buried in the hero)
A new **“Why guidance matters”** section on the homepage uses your framing in plain language parents can scan:

1. More access (schools, YouTube, ChatGPT, tutors)  
2. The Cameroon / Africa learning gap stat  
3. **“The internet solved access. It did not solve guidance.”**  
4. PrepSkul as the **guidance layer** (right level, gaps, verified tutors)  
5. **Map metaphor** for parents: where your child is, what’s next, who helps  
6. Adaptive tools + tutors (without sounding like a pitch deck)  
7. Closing line for parents: clarity, fit, visible progress  

The **Google Maps for learning** idea is expressed as a parent-friendly map line, not jargon in the hero. The full investor phrase can sit on **About** later if you want.

### Also updated (EN + FR)
- How It Works steps (parents + students)  
- Bottom CTA (“Give your child support that fits”)

Hard refresh and check mobile: you should see **Connect & Learn** on one line and **at the Right Level** (etc.) on the next.

**Quick check for you:** Should the map line say **“your child”** only, or also speak to **older students browsing alone** (e.g. “your child or you”)? I can tune that in one pass.

---

**User**

Is it a text book, go back to the previous narative

---

**Cursor**

Reverting the guidance section to the shorter, punchier narrative and removing the textbook-style wall of text.


Repo already has the short problem block; fixing the hero ("at the Right") and keeping parent-friendly copy concise—not the long textbook section.


You're right — that block read like a textbook. It's back to the **short two-line narrative**:

- *"Most learners are taught by age and curriculum."*
- *"PrepSkul helps them learn by ability, gaps, and goals."*

(Same in French.)

The long access/guidance story (stats, Google Maps framing, etc.) is **not** on the homepage anymore. That belongs on **About** when you're ready, written for parents in a tighter format—not eight stacked paragraphs.

**Hero** is also fixed again:
- **Connect & Learn**  
- **at the Right** Level / Pace / Path  

Subtitle is one concise line for parents, not a wall of text.

Hard refresh (`Cmd+Shift+R`). If you still see the long section, the dev server may be on stale code—restart `pnpm dev` once.

---

**User**

All we've done is not cool man stash every and pull from main, lets learn from our mistakes, plan and start again.

---

**Cursor**

Stashing local changes and syncing with `main` so we can start fresh.


Everything is stashed and synced to **main**. Here is where things stand:

### Done

| Repo | Action | Branch | Stash (recover later) |
|------|--------|--------|-------------------------|
| **PrepSkul_Web** | Stashed all changes (incl. untracked) → `main` → pulled | `main` @ `e0abbec` | `stash@{0}` on delbert |
| **prepskul_app** | Stashed all changes → `main` → pulled | `main` | `stash@{0}` on delbert |
| **PrepSkul** (root) | Stashed → `main` → pulled | `main` | `stash@{0}` |

Your landing/contact/translations work is **not lost**. It is in the PrepSkul_Web stash:

```bash
cd PrepSkul_Web && git stash list
# git stash show -p stash@{0}   # preview
# git stash pop                 # only if you want it back
```

Root repo may show `PrepSkul_Web` and `prepskul_app` as modified because those submodules are now on **latest main**, which can differ from the commit pins in the parent repo. That is normal and safe to ignore for web work.

---

### What we learned (keep this for round 2)

1. **One audience per section** — Parents on the homepage; long “access vs guidance” essays belong on **About**, not a text wall on home.
2. **Hero = one idea** — `Connect & Learn at the Right [Level|Pace|Path]` plus **one** supporting line, not hero + essay + trust strip all saying the same thing.
3. **Premium ≠ price tags** — No `2,500 XAF` on marketing; use “plans discussed clearly” if needed.
4. **Ship in small PRs** — Hero copy → problem band → contact → PEAP → programs (not everything at once).
5. **Typography** — Two-line headline (`Connect & Learn` / `at the Right Level`) beats a single line that breaks badly on mobile.

---

### Suggested restart plan (when you are ready)

1. **Branch** off `PrepSkul_Web` `main`: e.g. `feature/landing-v2`
2. **Sprint A** — Hero only (EN/FR, typewriter, parent subtitle, no pricing)
3. **Sprint B** — Short problem band (2 lines, keep it)
4. **Sprint C** — Contact page UI
5. **Sprint D** — PEAP + phone mockup polish
6. **Sprint E** — About page with the full guidance narrative (for parents + partners)

Say when you want to start **Sprint A** and we can do it step by step on clean `main`.

---

**User**

<system_notification>
The following task has finished. If you were already aware, ignore this notification and do not restate prior responses.

<task>
kind: shell
status: success
task_id: 229134
title: Stash root repo changes and pull main
output_path: /Users/user/.cursor/projects/Users-user-Desktop-PrepSkul/terminals/229134.txt
</task>
</system_notification>
<user_query>Briefly inform the user about the task result and perform any follow-up actions (if needed). If there's no follow-ups needed, don't explicitly say that.</user_query>

---

**Cursor**

**Reset complete.** All local work is stashed and both repos are on **`main`** with the latest pull:

- **PrepSkul_Web** — clean on `main` (web changes in `stash@{0}`)
- **prepskul_app** — clean on `main` (app changes in `stash@{0}`)
- **PrepSkul** (root) — on `main`; submodules may show as modified because they’re on newer commits than the parent pin

To recover old web work later: `cd PrepSkul_Web && git stash pop`

When you want to restart the landing work, we can branch from this clean `main` and take it sprint by sprint.

---

**User**

@/Users/user/.cursor/projects/Users-user-Desktop-PrepSkul/terminals/11.txt:7-445 hmm

---

**Cursor**

Accidental notes were pasted into a Dart file and there's a typo in another. Fixing both so the app compiles.


Two accidental breakages were blocking the build:

1. **`session_profile_service.dart`** — Notes about the pay/onsite verification flow were pasted at the top of the file, corrupting the `import`. Restored the proper `intl` import.
2. **`agora_video_session_screen.dart`** — Typo: `toLowerCas e()` → `toLowerCase()`.

Run `flutter run` again; it should compile now.

The verification flow you described (onsite/hybrid → minimalist screen if not verified) is **not implemented yet** — that text was only notes in the file. Say if you want that built next.

---

**User**

Seessions hav ebeen approved and even paid for, but they still show under tutor request

---

**Cursor**

Investigating how tutor requests are filtered after approval and payment.


Paid approved requests are still counted as "active" until their scheduled date passes. Excluding them from the Requests list once payment is complete and fixing the filter counts.


**Root cause:** Paid, approved bookings were still treated as active Requests until their scheduled date passed (or 30 days). That’s why you saw **PAID** cards with **View Session** still under Requests, and why **Approved (6)** didn’t match **All (3)** — counts used different rules.

**Fix:**
- **Approved + paid** (or matched/scheduled + paid) → removed from Requests; they belong under **Sessions** (still visible under **Past** for history).
- **Approved, not yet paid** → stays on Requests (waiting on payment).
- Filter counts (**Pending**, **Approved**, etc.) now only count **active** requests, so tabs stay consistent.

Hot restart the app and pull to refresh on Requests — those paid items should be gone from All/Approved. They’ll show under **Sessions**, or **Past** if you need history.

---

**User**

@/Users/user/.cursor/projects/Users-user-Desktop-PrepSkul/terminals/11.txt:7-1014 

---

**Cursor**

Analyzing the session logs and checking how remote video inactivity and disconnects are handled in code.


Here is what that session log shows:

### What worked
- Tutor joined channel `session_2d90c49d-...` (UID `103960876`), token OK.
- Learner joined (UID `158699401`).
- Remote video decoded at **360×480** and audio decoded — the call **did connect**.
- Cloud recording started (200).
- Session timer started (60 min).

### Warnings (mostly expected on Web)
| Log | Meaning |
|-----|--------|
| `createDataStream returned invalid id: 0` | Known **Agora Web** limit — in-channel data stream (emoji reactions, some screen-share sync) will not work. Camera state still goes via **Realtime** (`camera_on` messages in log). |
| `setRemoteDefaultVideoStreamType not supported` | Harmless on Web. |
| Quality `720p → 480p` | Network dipped; app adapted bitrate. |
| `presence/ping Failed to fetch` | Local Chrome could not reach `prepskul.com/api/mobile/presence/ping` (CORS/network in dev). Does not block the call. |

### Why “Remote video inactive” for 47s / 77s / 107s
Recovery ran 2× then gave up. From the same log:
- Learner joined with **camera/mic muted**, then turned camera on.
- Later: `remoteVideoStateReasonRemoteMuted` and **remote camera OFF**.
- So this is often **camera off / not publishing frames**, not a broken connection. Recovery cannot fix an intentional mute.

At **04:56:08** you (tutor) also **turned your camera off** (`publishCameraTrack=false`).

### Disconnect at the end
```
User offline: 158699401, reason: userOfflineDropped
GRACE started 15s
```
Learner’s connection **dropped** (tab closed, network blip, or sleep). The app correctly waits **15s** for reconnect before treating them as gone.

---

**Bottom line:** The session stack is working; this run looks like **learner camera off + network drop**, not a failed join.

If you are seeing a **specific UI bug** (black screen while both cameras on, or disconnect too fast), say which side (tutor/learner) and what you saw on screen — we can tune recovery so it does not fire when the remote user has camera intentionally off.

---

**User**

            screen  share is not visible and the UI is not really cool                                                                                                                                                                                                                                                                       

---

**Cursor**

Investigating screen-share rendering and the session UI layout.


Implementing fixes: defaulting web to fullscreen share, rebinding the preview after capture starts, and preventing the local camera watchdog from overwriting the screen surface.


I fixed the screen share visibility issue and tightened up the share UI. Here’s what was going wrong and what changed.

### Root cause
On Flutter web, Agora only binds **one** local video surface. When screen share started, the app switched to a side-by-side layout with a companion camera rail, and the local preview watchdog could still re-bind the **camera** canvas — overwriting the screen share and leaving a blank main stage.

### Fixes applied

1. **Fullscreen share on web** — Default layout is now `stageOnly` (no left sidebar eating space or fighting the canvas).

2. **Re-bind screen preview** — After capture starts, the app re-binds the screen canvas once the stage widget is mounted (`rebindLocalScreenSharePreview` in `agora_service.dart`).

3. **Guard local camera watchdog** — Preview recovery no longer runs while screen share is active, so it can’t steal the canvas.

4. **Suppress noisy recovery banner** — “Peer heartbeat is delayed” no longer shows during active screen share (it’s unrelated to the share stream).

5. **UI polish during share**
   - Header pill: “Your screen” / “Learner’s screen”
   - Floating participant chips (avatars + camera-off indicators) instead of a dead sidebar
   - Full-width stage without the empty left rail

### Files changed
- `prepskul_app/lib/features/sessions/screens/agora_video_session_screen.dart`
- `prepskul_app/lib/features/sessions/services/agora_service.dart`
- `prepskul_app/lib/features/sessions/widgets/agora_video_view.dart`

Restart the web session, start screen share again, and you should see your shared content fill the main stage. If it’s still blank after picking a window, tell me whether you’re on tutor or learner side and which browser you’re using.


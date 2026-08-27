# Learning content: style, structure, and how it gets authored

This is the contract between three things that keep drifting apart: what the
engines generate, what a parent is told, and what a model is asked for when we
want new content. All three now read from one place — `domain/curriculum.dart`
— and `test/primar/curriculum_test.dart` fails if any of them starts lying.

---

## 1. The unit of everything is a level, and a level is not a grade

Ten levels per subject. A level describes **what a child can do**, not how old
they are and not what class they are registered in.

That distinction is the entire product. Cameroon's problem is not that children
are absent from school — it is that a P4 classroom contains children reading
fluently and children who cannot name a letter, and the lesson is pitched at
neither. A system that assigns content by grade reproduces that. A system that
assigns content by demonstrated ability does not.

**Rules that follow from this, and are enforced by tests:**

- No outcome may contain the words *grade*, *Class 3*, *Form 1*, *Primary 4*,
  or *year group*.
- No outcome may be phrased as a deficit. Every row says what a child **can**
  do. `cannot`, `behind`, `struggling`, `weak`, `slow` are banned strings.
- Bands shown to parents (`first steps` … `ready for more`) are deliberately
  vague. A parent should be able to see movement without being handed a
  comparison to the child down the road.

## 2. How a child is placed

Four sources, weakest to strongest. **Nothing here gates content — all of it
only chooses which question is asked first.**

| Source | Weight | Where |
|---|---|---|
| Days actually at school this year | 1.7 levels of swing | `Screener.estimate` |
| Age | 0.5 levels per year — 3.0 across the offered range | `Screener.estimate` |
| What the parent has watched the child do | 4.4 levels of swing | `Screener.estimate` |
| **The warm-up: three questions the child answers** | overrules all three | `Screener.startFromProbe` |

The parent's answers pick which three levels the warm-up asks at. The child's
answers pick where the session starts, by the basal rule every early-grade
assessment uses: *start at the hardest thing they actually got right*, or one
below the easiest thing shown if they got none.

Then the staircase overrules the warm-up too. `screener_test.dart` proves it:
a child started nine rungs too high is working at their real level by the last
third of the session.

**A test asserts age moves the start less than direct observation does.** If
someone ever tunes the weights the wrong way, that test fails.

## 3. The progressions, and why they are in that order

Every ordering here is the one the evidence supports, not the one a syllabus
lists.

### Letters (`literacy.dart`)

```
tell letters apart  →  attach a sound  →  hear that sound in a word
                    →  build a word from sounds  →  read a word
      L1–2                L3–5               L6–7          L8            L9–10
```

- **Shape before sound.** b/d confusion is a visual-spatial problem before it is
  a phonics one — the same letter reflected. Teaching the sound first means
  teaching a sound onto a shape the child cannot yet hold.
- **Reading a word does not appear until L9.** Everything before it is what
  makes reading a word possible. A product that starts at "read this word"
  is testing, not teaching.
- **Every word shown to be read must be picturable.** Absolute rule. Four bare
  written words is a shape-matching task, not reading — reading is decoding
  *and* meaning, and meaning needs a picture for a child who cannot yet read.
  `WordPicture.drawable` is the whole permitted vocabulary; the generator is
  restricted to it.

### Numbers (`numeracy.dart`)

```
count a group  →  numeral↔quantity both ways  →  compare  →  match a whole set
   →  add  →  take away  →  find the missing part
```

- **Cardinality before arithmetic.** Addition does not appear until L5. A child
  who has not linked "5" to five things is doing symbol manipulation.
- **Comparison before addition.** More/less as a judgement is earlier and
  cheaper than combining.
- **Missing addend last.** The unknown sitting in the middle of a sentence is
  genuinely harder than at the end, and it is where `operandEcho` errors cluster.

### Shapes (`items.dart`)

```
put together  →  put together with curves  →  more parts
   →  tell near-misses apart  →  take apart  →  both directions, complex
```

- **Composition before decomposition, always.** Taking apart is the harder
  direction and every curriculum that leads with it loses children.
- Difficulty climbs by making **distractors closer**, not by making shapes
  merely busier. A one-stroke difference at L10 is a harder discrimination
  than a six-stroke shape with an obviously wrong distractor.

Shapes is not really a third subject. It is the visual reasoning that letters
and numbers both sit on, which is why all three run on one staircase.

## 4. Content style

**Voice.** Every screen is read aloud, from the first one, because a parent may
not read either. Lines are short — they are heard, often in a second language.
Each onboarding page speaks *its own question*; a single welcome line for five
screens is no better than silence.

**Nothing is written that must be read.** A child cannot be given an instruction
in writing. The prompt is spoken; the answer is tapped, dragged, spelled or
spoken back.

**Pictures over words in every option a parent chooses between.** And the rule
those pictures are drawn to: *the thing that tells two options apart has to be
the biggest thing in the picture.* The first cut of the onboarding icons failed
this — three school options differing only by how many 5px dots were filled —
and all three read as the same icon at real size.

**A miss teaches.** Never "wrong", never a buzzer. The answer is named *and*
explained, then the same item comes back unscored. "I do, we do, you do", with
the last step actually present.

**Running out of time is not failing.** The countdown ending means a child has
been left alone too long, and the right response to that is help.

**Two choices at the bottom, four at the top.** Four options put the guessing
floor at 25%, which left the weakest children near 39% correct with nowhere
further down — the content floor sat above the population this exists for.

## 5. The authoring contract

Content is **generated by a model and banked to disk**, never generated at
runtime. This is the Cursor/Lovable pattern: the model authors an artefact, the
artefact runs deterministically and offline. A child in Buea with no signal must
get the same session as a child with fibre.

When a model is asked for content, it is handed the curriculum row, not a level
number. `outcomeFor(subject, level)` gives four fields, and every one of them
belongs in the prompt:

```
level     7
can       "adds and takes away within twelve"
taught    "subtraction as taking away, alongside addition"
evidence  "both operations, unsignalled, so the symbol has to be read"
watchFor  "adding when the sign says take away"
```

A prompt built as *"write a level 7 numeracy question"* gets whatever the model
imagines a level 7 is. A prompt built as *"this child can add two groups up to
twelve and is just meeting subtraction; the mistake they keep making is adding
when the sign says take away"* gets something usable.

### What the server enforces regardless

`/api/primar/explain` filters every generated line against a banned list before
it ever reaches a device — `wrong`, `incorrect`, `mistake`, `fail`, `stupid`,
`try harder`, `should know`, `easy`, `slow`, `behind`, `struggl`, and their
French equivalents. A model that produces deficit language does not get to say
it to a child, whatever the prompt asked for.

`/api/primar/voice` serves a **closed phrase catalogue**. Every line the app can
ever speak is enumerated, synthesised once, and cached on the device forever.
There is no free-text TTS path, which is what makes the voice work offline.

### Adding a new level or subject

1. Add the row to `curriculum.dart` first, in outcome terms.
2. Add the generator forms to the subject's level table.
3. `curriculum_test.dart` will fail until the two agree — it checks that a level
   promising a match board actually generates one, that a level promising
   spelling actually spells, and that every level generates something.
4. Add any new spoken line to **both** `VoiceLines.fixed` and the server's
   `PHRASES` map. A line in one and not the other goes silent offline.

## 6. Known gaps

- **French does not run the read-a-word rung.** French and English phonics are
  different systems, not translations. There is no French picture set, and the
  two available shortcuts — bare French words, or English pictures with French
  audio — are both worse than a missing rung. Needs a Francophone teacher's
  review of a word list before it goes near a child.
- **The shapes ceiling is level 10 and there is nothing above it.** A child
  comfortable there has outgrown the subject.
- **Nothing here has been validated with real children.** Every progression
  above is drawn from published early-grade practice (TaRL, EGRA/EGMA,
  systematic synthetic phonics) and from simulation. The ordering is defensible;
  the calibration of *which* level is *which* is not yet evidence-based.

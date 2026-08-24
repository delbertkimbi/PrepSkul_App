/// Finding out where a child actually is.
///
/// ## Age is not a level, and must never be treated as one
///
/// The whole reason this product exists is that age and grade stopped
/// predicting ability. A Cameroonian nine-year-old in P4 may be reading
/// fluently or may not know a single letter, and the second child is the one
/// this is built for. Anything that hands a nine-year-old level-5 content
/// *because they are nine* has reproduced the exact failure — teaching to the
/// nominal grade — that leaves them behind in school.
///
/// So the rule this file enforces:
///
/// **Nothing here gates content. Everything here only chooses which question
/// gets asked first.** The staircase in `mastery.dart` moves on evidence and
/// will overrule any starting point within a handful of questions. A wrong
/// start costs a child one or two easy questions. A gate would cost them the
/// year.
///
/// ## Why ask anything at all, then
///
/// Because the first ninety seconds decide whether a child stays. Starting a
/// child who cannot read at "which word says *bus*" and starting a fluent
/// reader at "point to the letter A" are both ways of losing them — one to
/// humiliation, one to boredom. A starting point that is roughly right buys
/// the staircase time to get precisely right.
///
/// ## The three sources, weakest to strongest
///
/// 1. **Age** — the weakest signal, and weighted accordingly. Kept only
///    because it is free and, absent everything else, better than nothing.
/// 2. **Parent report** — schooling, and what the parent has seen the child
///    do. This is what ASER and Uwezo household surveys have used at national
///    scale for twenty years, and it beats age comfortably.
/// 3. **The probe** — three questions the child answers, spanning a wide
///    range. This is the only direct evidence, and it is allowed to overrule
///    both of the others outright.
///
/// The estimate from 1 and 2 exists purely to choose *which three* questions
/// the probe asks. It never reaches the child as content.
library;

import 'subjects.dart';

/// How much school the child has actually had this year.
///
/// Not "what grade are they in". Enrolment and attendance are different things
/// in the population this serves, and attendance is the one that predicts.
enum Schooling {
  none,
  patchy,
  daily;

  /// Levels, relative to the base. Missing school is the single largest
  /// downward signal a parent can give us.
  double get weight => switch (this) {
        Schooling.none => -1.2,
        Schooling.patchy => -0.4,
        Schooling.daily => 0.5,
      };
}

/// What the parent has actually watched the child do.
///
/// Phrased as observable acts, never as ability. "Do they know their letters"
/// invites a parent to guess and to flatter; "have you seen them read a word
/// on a packet" is a thing that either happened or did not.
enum SeenDoing {
  notYet,
  starting,
  someOfIt,
  confident;

  double get weight => switch (this) {
        SeenDoing.notYet => -2.1,
        SeenDoing.starting => -0.7,
        SeenDoing.someOfIt => 0.9,
        SeenDoing.confident => 2.3,
      };

  /// The question is asked in the subject's own terms, because "can they do
  /// some of it" means nothing on its own.
  ///
  /// It is also the last thing a parent answers before handing the phone over,
  /// and it carries more weight in the placement than anything else they say —
  /// so it was the worst page in the flow to have left in English. A parent who
  /// picked Français got five French questions and then this one, and a parent
  /// who cannot read it either guesses or stops.
  String prompt(Subject subject, [String locale = 'en']) =>
      locale == 'fr' ? _fr(subject) : _en(subject);

  String _en(Subject subject) => switch (subject) {
        Subject.reading => switch (this) {
            SeenDoing.notYet => 'Letters are still just shapes to them',
            SeenDoing.starting => 'They know a few letters',
            SeenDoing.someOfIt => 'They know most letters and their sounds',
            SeenDoing.confident => 'They can read short words like "bus"',
          },
        Subject.numeracy => switch (this) {
            SeenDoing.notYet => 'They do not count objects yet',
            SeenDoing.starting => 'They can count to about ten',
            SeenDoing.someOfIt => 'They count past twenty and compare amounts',
            SeenDoing.confident => 'They add and take away small numbers',
          },
        Subject.shapes => switch (this) {
            SeenDoing.notYet => 'They do not match shapes yet',
            SeenDoing.starting => 'They can find two shapes that are the same',
            SeenDoing.someOfIt => 'They can see how two shapes fit together',
            SeenDoing.confident => 'They can work out the missing piece',
          },
      };

  /// The same four observations, kept as plain and concrete in French as in
  /// English — a thing the parent either watched happen or did not.
  String _fr(Subject subject) => switch (subject) {
        Subject.reading => switch (this) {
            SeenDoing.notYet => 'Les lettres ne sont encore que des dessins',
            SeenDoing.starting => 'Il connaît quelques lettres',
            SeenDoing.someOfIt => 'Il connaît la plupart des lettres et leurs sons',
            SeenDoing.confident => 'Il lit de petits mots comme « bus »',
          },
        Subject.numeracy => switch (this) {
            SeenDoing.notYet => 'Il ne compte pas encore les objets',
            SeenDoing.starting => 'Il compte jusqu’à dix environ',
            SeenDoing.someOfIt => 'Il compte au-delà de vingt et compare les quantités',
            SeenDoing.confident => 'Il ajoute et retire de petits nombres',
          },
        Subject.shapes => switch (this) {
            SeenDoing.notYet => 'Il n’associe pas encore les formes',
            SeenDoing.starting => 'Il trouve deux formes identiques',
            SeenDoing.someOfIt => 'Il voit comment deux formes s’assemblent',
            SeenDoing.confident => 'Il devine la pièce qui manque',
          },
      };
}

/// Everything the onboarding collected. Every field is optional on purpose —
/// a parent who skips a page still gets a working session, just a slightly
/// looser first question.
class ScreenerAnswers {
  const ScreenerAnswers({
    this.age,
    this.schooling,
    this.seenDoing,
    this.subject = Subject.numeracy,
    this.name = '',
    this.locale = 'en',
    this.voiceId = 'guide',
  });

  final int? age;
  final Schooling? schooling;
  final SeenDoing? seenDoing;
  final Subject subject;
  final String name;

  /// The language the child is learning to read in. Chosen on the first page,
  /// because everything after it — the voice, the alphabet, the word list and
  /// the mastery node — depends on it.
  final String locale;

  /// Who does the teaching. See [TeachingVoice] — this is a product decision,
  /// not a settings toggle.
  final String voiceId;

  ScreenerAnswers copyWith({
    int? age,
    Schooling? schooling,
    SeenDoing? seenDoing,
    Subject? subject,
    String? name,
    String? locale,
    String? voiceId,
  }) {
    return ScreenerAnswers(
      age: age ?? this.age,
      schooling: schooling ?? this.schooling,
      seenDoing: seenDoing ?? this.seenDoing,
      subject: subject ?? this.subject,
      name: name ?? this.name,
      locale: locale ?? this.locale,
      voiceId: voiceId ?? this.voiceId,
    );
  }

  /// How much of the questionnaire we actually have. Used to decide how wide
  /// the probe should cast — with no information at all, it has to look
  /// further in both directions.
  int get signalCount =>
      (age != null ? 1 : 0) + (schooling != null ? 1 : 0) + (seenDoing != null ? 1 : 0);
}

/// A starting point, and how much we trust it.
class Estimate {
  const Estimate({required this.level, required this.spread, required this.basis});

  /// Where the probe will centre its questions. 1–10.
  final int level;

  /// How far either side the probe reaches. Wider when we know less.
  final int spread;

  /// Plain sentence for the parent about what this is and is not.
  final String basis;

  /// The three levels the probe will ask at, low to high, deduplicated and
  /// clamped into the real range.
  List<int> get probeLevels {
    final raw = {
      (level - spread).clamp(1, 10),
      level.clamp(1, 10),
      (level + spread).clamp(1, 10),
    }.toList()
      ..sort();
    return raw;
  }
}

/// Weighted estimate from what the parent told us.
///
/// The weights are deliberately modest. This is choosing between "start near
/// the bottom", "start in the middle" and "start high" — it is not a score,
/// and the arithmetic should not pretend to a precision it does not have.
class Screener {
  Screener._();

  /// The centre of the scale. A child we know nothing about starts here, which
  /// is also where the probe has the most room to move in both directions.
  static const double _base = 4.0;

  /// Age is worth about half a level a year, which is less than either of the
  /// other two signals contributes on its own. That ordering is the point.
  static const double _perYear = 0.5;

  /// Ages the onboarding offers, plus [olderThanListed] for everyone above.
  ///
  /// The list is deliberately wide at both ends. It stopped at eleven, which
  /// quietly assumed no older child would need this — false in the population
  /// this serves, where fifteen-year-olds who cannot read a sentence are
  /// ordinary. It started at five, which excluded the years when counting
  /// three things and telling two letters apart are exactly the right work.
  static const List<int> ages = [3, 4, 5, 6, 7, 8, 9, 10, 11, 12];

  /// The last option: "thirteen or older". Stored as a real number so the
  /// arithmetic stays simple, but see [_ageTerm] for why it changes nothing —
  /// every age from twelve upward is worth exactly what eleven is worth.
  static const int olderThanListed = 13;

  /// What an age is worth, which is less the older the child gets.
  ///
  /// Half a level a year holds while a child is roughly on track. It stops
  /// holding above about eleven: past that point, a child who still needs this
  /// is a child for whom age stopped predicting anything years ago, and
  /// continuing to add half a level a year would start a fifteen-year-old
  /// non-reader four rungs above a nine-year-old one for no reason but the
  /// year they were born.
  ///
  /// So the contribution is capped at the eleven-year-old value. Older children
  /// are offered the picker — they are welcome here — and then placed on what
  /// they and their parent actually report.
  static double _ageTerm(int? age) {
    if (age == null) return 0;
    return (age.clamp(3, 11) - 7) * _perYear;
  }

  static Estimate estimate(ScreenerAnswers a) {
    var level = _base;

    level += _ageTerm(a.age);
    level += a.schooling?.weight ?? 0;
    level += a.seenDoing?.weight ?? 0;

    // Err low, always. Starting one rung beneath a child costs them a question
    // they find easy. Starting one rung above costs them the belief that they
    // can do this, and that is the thing we are actually trying to build.
    level -= 0.8;

    final centre = level.round().clamp(1, 10);

    // Less information, wider probe. With all three answers we are looking to
    // confirm; with none we are genuinely searching.
    final spread = switch (a.signalCount) {
      3 => 2,
      2 => 3,
      _ => 4,
    };

    return Estimate(level: centre, spread: spread, basis: _basis(a));
  }

  static String _basis(ScreenerAnswers a) {
    final name = a.name.trim().isEmpty ? 'your child' : a.name.trim();
    if (a.signalCount == 0) {
      return 'We will start $name in the middle and let the questions find their level.';
    }
    return 'We will start $name where your answers point, then let what they '
        'actually do decide the rest.';
  }

  /// Where to begin the real session, once the child has answered the probe.
  ///
  /// The rule is the basal one every early-grade assessment uses: a child
  /// starts at the hardest thing they actually got right. Not one above it —
  /// getting a question right is evidence you can work there, not evidence you
  /// have outgrown it, and the staircase will climb within two questions if
  /// they have.
  ///
  /// A child who got none of the three right starts one rung below the easiest
  /// thing they were shown. There is no lower verdict than that here: the
  /// content floor is level 1, and a child who cannot do level 1 needs a
  /// person, not a lower number.
  static int startFromProbe(List<ProbeResult> results, Estimate estimate) {
    if (results.isEmpty) return estimate.level;

    final correct = results.where((r) => r.correct).map((r) => r.level);
    if (correct.isEmpty) {
      final lowest = results.map((r) => r.level).reduce((a, b) => a < b ? a : b);
      return (lowest - 1).clamp(1, 10);
    }
    return correct.reduce((a, b) => a > b ? a : b).clamp(1, 10);
  }

  /// What the parent is told after the probe.
  ///
  /// Describes what happened, never what the child is. "Started here" is a
  /// fact; "is at this level" is a label, and labels are what this product is
  /// trying to take away from these families.
  static String probeSummary(List<ProbeResult> results, String name) {
    final who = name.trim().isEmpty ? 'Your child' : name.trim();
    final got = results.where((r) => r.correct).length;
    if (got == 0) {
      return '$who is starting from the beginning, which is exactly where we '
          'can help most.';
    }
    if (got == results.length) {
      return '$who answered all the warm-ups, so we are starting them higher.';
    }
    return '$who answered $got of the ${results.length} warm-ups. We are '
        'starting from the hardest one they got.';
  }
}

/// One answered probe question.
class ProbeResult {
  const ProbeResult({required this.level, required this.correct});

  final int level;
  final bool correct;
}

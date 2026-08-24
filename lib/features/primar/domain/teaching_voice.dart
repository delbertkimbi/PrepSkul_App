/// Who does the teaching.
///
/// ## Why this is a real product decision and not a settings toggle
///
/// A child learning from a voice they recognise is in a different emotional
/// situation from a child learning from a stranger. The design intent is that a
/// parent can be present in their child's learning when they are not in the
/// room — and that is not a skin on a text-to-speech engine, it is the point.
///
/// ## What is actually available, and what is not
///
/// The synthesis model in use reports `supports_voice_cloning = false`, so
/// cloning a parent's voice is **not possible on the current provider**. Saying
/// otherwise on an onboarding screen would be a promise the app cannot keep.
///
/// So this ships in two honest halves:
///
///  * **Guide and teacher voices work today.** They are real African-English
///    neural voices, not an American default with a label on it, and they cost
///    the same as any other.
///  * **A parent's voice is recorded, not cloned.** The parent records a short
///    set of phrases in their own voice — praise, encouragement, a nudge to try
///    again — and the engine plays *those actual recordings* at the moments
///    they fit. Nothing is synthesised, so nothing sounds nearly-right, and the
///    consent question never arises: it is their voice, on their phone,
///    recorded by them, deletable by them.
///
/// The recorded route is not a lesser version of cloning. A real parent saying
/// "I know you can do this" beats a synthetic approximation of them saying it,
/// and it is available now rather than after a provider migration.
library;

/// Where a voice comes from.
enum VoiceKind {
  /// The app's own companion.
  guide,

  /// A recorded human teacher voice.
  teacher,

  /// The child's own parent, recorded by them on this phone.
  parent,
}

class TeachingVoice {
  const TeachingVoice({
    required this.id,
    required this.label,
    required this.blurb,
    required this.kind,
    this.synthName,
    this.locale = 'en',
  });

  final String id;
  final String label;
  final String blurb;
  final VoiceKind kind;

  /// The provider's voice name, for voices that are synthesised.
  ///
  /// Null for [VoiceKind.parent], because a parent's voice is not synthesised
  /// at all — it is played back from what they recorded.
  final String? synthName;

  final String locale;

  /// Whether choosing this needs the parent to record something first.
  bool get needsRecording => kind == VoiceKind.parent;
}

/// The voices offered at onboarding.
///
/// The African-English options are here because they exist and are good, not as
/// a gesture. Probing the provider found genuine Nigerian and Kenyan neural
/// voices at the same price as any other, and Nigerian English is far nearer an
/// Anglophone Cameroonian child's ear than the American default that most
/// products ship without thinking about it.
///
/// There is no Cameroonian locale and no African French voice at all, which is
/// worth knowing rather than papering over: a Francophone child currently
/// learns from a Parisian voice because nothing closer is available.
const List<TeachingVoice> teachingVoices = [
  TeachingVoice(
    id: 'guide',
    label: 'Skul Mate',
    blurb: 'Our friendly guide',
    kind: VoiceKind.guide,
    synthName: 'en-NG-EzinneNeural',
  ),
  TeachingVoice(
    id: 'teacher.ezinne',
    label: 'Teacher Ezinne',
    blurb: 'Warm and patient',
    kind: VoiceKind.teacher,
    synthName: 'en-NG-EzinneNeural',
  ),
  TeachingVoice(
    id: 'teacher.abeo',
    label: 'Teacher Abeo',
    blurb: 'Calm and steady',
    kind: VoiceKind.teacher,
    synthName: 'en-NG-AbeoNeural',
  ),
  TeachingVoice(
    id: 'teacher.asilia',
    label: 'Teacher Asilia',
    blurb: 'Bright and encouraging',
    kind: VoiceKind.teacher,
    synthName: 'en-KE-AsiliaNeural',
  ),
  TeachingVoice(
    id: 'parent',
    label: "A parent's voice",
    blurb: 'Record your own praise and encouragement',
    kind: VoiceKind.parent,
  ),
];

const List<TeachingVoice> teachingVoicesFr = [
  TeachingVoice(
    id: 'guide',
    label: 'Skul Mate',
    blurb: 'Notre guide',
    kind: VoiceKind.guide,
    synthName: 'fr-FR-DeniseNeural',
    locale: 'fr',
  ),
  TeachingVoice(
    id: 'teacher.denise',
    label: 'Maîtresse Denise',
    blurb: 'Douce et patiente',
    kind: VoiceKind.teacher,
    synthName: 'fr-FR-DeniseNeural',
    locale: 'fr',
  ),
  TeachingVoice(
    id: 'parent',
    label: "La voix d'un parent",
    blurb: 'Enregistrez vos encouragements',
    kind: VoiceKind.parent,
    locale: 'fr',
  ),
];

List<TeachingVoice> voicesFor(String locale) =>
    locale == 'fr' ? teachingVoicesFr : teachingVoices;

TeachingVoice voiceById(String id, String locale) => voicesFor(locale).firstWhere(
      (v) => v.id == id,
      orElse: () => voicesFor(locale).first,
    );

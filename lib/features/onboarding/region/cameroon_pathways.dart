import 'region_packs.dart';

// Navigation taxonomy, not a claim that syllabus content has been verified.
// Sources and rollout limits: docs/CURRICULUM_FOUNDATION.md.
const cameroonPathways = [
  RegionOption(
    id: 'general',
    label: Bilingual(en: '📚 Grammar / general', fr: '📚 Enseignement général'),
  ),
  RegionOption(
    id: 'technical',
    label: Bilingual(
      en: '🛠️ Technical / industrial',
      fr: '🛠️ Technique / industriel',
    ),
  ),
  RegionOption(
    id: 'commercial',
    label: Bilingual(en: '💼 Commercial / business', fr: '💼 Commercial'),
  ),
];
const cameroonStreams = [
  RegionOption(
    id: 'arts',
    label: Bilingual(en: '🎨 Arts', fr: '🎨 Lettres'),
  ),
  RegionOption(
    id: 'science',
    label: Bilingual(en: '🔬 Science', fr: '🔬 Sciences'),
  ),
  RegionOption(
    id: 'mixed',
    label: Bilingual(
      en: '📚 Mixed / not specialised yet',
      fr: '📚 Mixte / pas encore spécialisé',
    ),
  ),
];

bool needsCameroonPathway(String country, String? system, String? level) =>
    country == 'cm' &&
    system == 'cm-anglophone' &&
    (level?.startsWith('form') == true || level == 'l6' || level == 'u6');

List<RegionOption> pathwaySubjects(
  List<RegionOption> base,
  String? pathway, {
  String? stream,
}) {
  if (pathway == 'general' && (stream == 'arts' || stream == 'science')) {
    // Suggestions, not a restriction on the learner's registered combination.
    final preferred = stream == 'science'
        ? ['maths', 'physics', 'chemistry', 'biology', 'cs']
        : [
            'english',
            'literature',
            'history',
            'geography',
            'economics',
            'french',
          ];
    return [
      ...base.where((item) => preferred.contains(item.id)),
      ...base.where((item) => !preferred.contains(item.id)),
    ];
  }
  if (pathway != 'commercial' && pathway != 'technical') return base;
  return [
    ...base.where((s) => ['maths', 'english', 'french', 'cs'].contains(s.id)),
    if (pathway == 'commercial') ...const [
      RegionOption(
        id: 'accounting',
        label: Bilingual(en: 'Accounting', fr: 'Comptabilité'),
      ),
      RegionOption(
        id: 'commerce',
        label: Bilingual(en: 'Commerce', fr: 'Commerce'),
      ),
      RegionOption(
        id: 'economics',
        label: Bilingual(en: 'Economics', fr: 'Économie'),
      ),
      RegionOption(
        id: 'business-maths',
        label: Bilingual(
          en: 'Business mathematics',
          fr: 'Mathématiques commerciales',
        ),
      ),
    ],
    if (pathway == 'technical') ...const [
      RegionOption(
        id: 'electrical',
        label: Bilingual(en: 'Electrical technology', fr: 'Électrotechnique'),
      ),
      RegionOption(
        id: 'mechanical',
        label: Bilingual(en: 'Mechanical technology', fr: 'Mécanique'),
      ),
      RegionOption(
        id: 'building',
        label: Bilingual(en: 'Building construction', fr: 'Construction'),
      ),
      RegionOption(
        id: 'technical-drawing',
        label: Bilingual(en: 'Technical drawing', fr: 'Dessin technique'),
      ),
    ],
    const RegionOption(
      id: 'other',
      label: Bilingual(
        en: 'My subject / specialty',
        fr: 'Ma matière / spécialité',
      ),
    ),
  ];
}

List<RegionOption> pathwayExams(
  String? pathway,
  String? level,
  List<RegionOption> fallback,
) {
  if (pathway == 'technical' || pathway == 'commercial') {
    return const [
      RegionOption(
        id: 'tvee-il',
        label: Bilingual(
          en: 'TVEE Intermediate Level',
          fr: 'TVEE niveau intermédiaire',
        ),
      ),
      RegionOption(
        id: 'tvee-al',
        label: Bilingual(en: 'TVEE Advanced Level', fr: 'TVEE niveau avancé'),
      ),
      RegionOption(
        id: 'other',
        label: Bilingual(
          en: 'Another exam / not sure yet',
          fr: 'Autre examen / pas encore sûr',
        ),
      ),
    ];
  }
  return fallback;
}

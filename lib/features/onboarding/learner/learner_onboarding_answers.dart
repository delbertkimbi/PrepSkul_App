class LearnerOnboardingAnswers {
  const LearnerOnboardingAnswers({
    this.locale = 'en',
    this.accountRole = 'learner',
    this.name = '',
    this.countryId = 'cm',
    this.countryOther,
    this.cityId,
    this.cityOther,
    this.systemId,
    this.levelId,
    this.subjectId,
    this.subjectOther,
    this.examId,
    this.examWhenId,
    this.learningGoalId,
    this.tutorModeId,
    this.channelId = 'mix',
    this.paceId = 'balanced',
    this.examFeelId,
    this.interestIds = const [],
    this.superChoice,
    this.voiceOut = true,
  });

  final String locale;
  final String accountRole;
  final String name;
  final String countryId;
  final String? countryOther;
  final String? cityId;
  final String? cityOther;
  final String? systemId;
  final String? levelId;
  final String? subjectId;
  final String? subjectOther;
  final String? examId;
  final String? examWhenId;
  final String? learningGoalId;
  final String? tutorModeId;
  final String channelId;
  final String paceId;
  final String? examFeelId;
  final List<String> interestIds;
  final String? superChoice;
  final bool voiceOut;

  Map<String, dynamic> toJson() => {
    'locale': locale,
    'accountRole': accountRole,
    'name': name,
    'countryId': countryId,
    'countryOther': countryOther,
    'cityId': cityId,
    'cityOther': cityOther,
    'systemId': systemId,
    'levelId': levelId,
    'subjectId': subjectId,
    'subjectOther': subjectOther,
    'examId': examId,
    'examWhenId': examWhenId,
    'learningGoalId': learningGoalId,
    'tutorModeId': tutorModeId,
    'channelId': channelId,
    'paceId': paceId,
    'examFeelId': examFeelId,
    'interestIds': interestIds,
    'superChoice': superChoice,
    'voiceOut': voiceOut,
  };

  factory LearnerOnboardingAnswers.fromJson(Map<String, dynamic> json) {
    return LearnerOnboardingAnswers(
      locale: json['locale'] as String? ?? 'en',
      accountRole: json['accountRole'] as String? ?? 'learner',
      name: json['name'] as String? ?? '',
      countryId: json['countryId'] as String? ?? 'cm',
      countryOther: json['countryOther'] as String?,
      cityId: json['cityId'] as String?,
      cityOther: json['cityOther'] as String?,
      systemId: json['systemId'] as String?,
      levelId: json['levelId'] as String?,
      subjectId: json['subjectId'] as String?,
      subjectOther: json['subjectOther'] as String?,
      examId: json['examId'] as String?,
      examWhenId: json['examWhenId'] as String?,
      learningGoalId: json['learningGoalId'] as String?,
      tutorModeId: json['tutorModeId'] as String?,
      channelId: json['channelId'] as String? ?? 'mix',
      paceId: json['paceId'] as String? ?? 'balanced',
      examFeelId: json['examFeelId'] as String?,
      interestIds: (json['interestIds'] as List<dynamic>? ?? const [])
          .whereType<String>()
          .toList(),
      superChoice: json['superChoice'] as String?,
      voiceOut: json['voiceOut'] as bool? ?? true,
    );
  }

  LearnerOnboardingAnswers copyWith({
    String? locale,
    String? accountRole,
    String? name,
    String? countryId,
    String? countryOther,
    String? cityId,
    String? cityOther,
    String? systemId,
    String? levelId,
    String? subjectId,
    String? subjectOther,
    String? examId,
    String? examWhenId,
    String? learningGoalId,
    String? tutorModeId,
    String? channelId,
    String? paceId,
    String? examFeelId,
    List<String>? interestIds,
    String? superChoice,
    bool? voiceOut,
    bool clearCity = false,
    bool clearCountryOther = false,
    bool clearCityOther = false,
    bool clearSystem = false,
    bool clearLevel = false,
    bool clearExam = false,
    bool clearSubjectOther = false,
  }) {
    return LearnerOnboardingAnswers(
      locale: locale ?? this.locale,
      accountRole: accountRole ?? this.accountRole,
      name: name ?? this.name,
      countryId: countryId ?? this.countryId,
      countryOther: clearCountryOther
          ? null
          : (countryOther ?? this.countryOther),
      cityId: clearCity ? null : (cityId ?? this.cityId),
      cityOther: clearCityOther ? null : (cityOther ?? this.cityOther),
      systemId: clearSystem ? null : (systemId ?? this.systemId),
      levelId: clearLevel ? null : (levelId ?? this.levelId),
      subjectId: subjectId ?? this.subjectId,
      subjectOther: clearSubjectOther
          ? null
          : (subjectOther ?? this.subjectOther),
      examId: clearExam ? null : (examId ?? this.examId),
      examWhenId: examWhenId ?? this.examWhenId,
      learningGoalId: learningGoalId ?? this.learningGoalId,
      tutorModeId: tutorModeId ?? this.tutorModeId,
      channelId: channelId ?? this.channelId,
      paceId: paceId ?? this.paceId,
      examFeelId: examFeelId ?? this.examFeelId,
      interestIds: interestIds ?? this.interestIds,
      superChoice: superChoice ?? this.superChoice,
      voiceOut: voiceOut ?? this.voiceOut,
    );
  }
}

class LearnerOnboardingAnswers {
  const LearnerOnboardingAnswers({
    this.locale = 'en',
    this.accountRole = 'learner',
    this.name = '',
    this.countryId = 'cm',
    this.cityId,
    this.systemId,
    this.levelId,
    this.subjectId,
    this.examId,
    this.examWhenId,
    this.channelId = 'mix',
    this.paceId = 'balanced',
    this.examFeelId,
    this.interestIds = const [],
    this.superChoice,
  });

  final String locale;
  final String accountRole;
  final String name;
  final String countryId;
  final String? cityId;
  final String? systemId;
  final String? levelId;
  final String? subjectId;
  final String? examId;
  final String? examWhenId;
  final String channelId;
  final String paceId;
  final String? examFeelId;
  final List<String> interestIds;
  final String? superChoice;

  LearnerOnboardingAnswers copyWith({
    String? locale,
    String? accountRole,
    String? name,
    String? countryId,
    String? cityId,
    String? systemId,
    String? levelId,
    String? subjectId,
    String? examId,
    String? examWhenId,
    String? channelId,
    String? paceId,
    String? examFeelId,
    List<String>? interestIds,
    String? superChoice,
    bool clearCity = false,
    bool clearSystem = false,
    bool clearLevel = false,
    bool clearExam = false,
  }) {
    return LearnerOnboardingAnswers(
      locale: locale ?? this.locale,
      accountRole: accountRole ?? this.accountRole,
      name: name ?? this.name,
      countryId: countryId ?? this.countryId,
      cityId: clearCity ? null : (cityId ?? this.cityId),
      systemId: clearSystem ? null : (systemId ?? this.systemId),
      levelId: clearLevel ? null : (levelId ?? this.levelId),
      subjectId: subjectId ?? this.subjectId,
      examId: clearExam ? null : (examId ?? this.examId),
      examWhenId: examWhenId ?? this.examWhenId,
      channelId: channelId ?? this.channelId,
      paceId: paceId ?? this.paceId,
      examFeelId: examFeelId ?? this.examFeelId,
      interestIds: interestIds ?? this.interestIds,
      superChoice: superChoice ?? this.superChoice,
    );
  }
}

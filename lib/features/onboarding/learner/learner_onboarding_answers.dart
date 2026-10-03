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

  Map<String, dynamic> toJson() => {
        'locale': locale,
        'accountRole': accountRole,
        'name': name,
        'countryId': countryId,
        'cityId': cityId,
        'systemId': systemId,
        'levelId': levelId,
        'subjectId': subjectId,
        'examId': examId,
        'examWhenId': examWhenId,
        'channelId': channelId,
        'paceId': paceId,
        'examFeelId': examFeelId,
        'interestIds': interestIds,
        'superChoice': superChoice,
      };

  factory LearnerOnboardingAnswers.fromJson(Map<String, dynamic> json) {
    return LearnerOnboardingAnswers(
      locale: json['locale'] as String? ?? 'en',
      accountRole: json['accountRole'] as String? ?? 'learner',
      name: json['name'] as String? ?? '',
      countryId: json['countryId'] as String? ?? 'cm',
      cityId: json['cityId'] as String?,
      systemId: json['systemId'] as String?,
      levelId: json['levelId'] as String?,
      subjectId: json['subjectId'] as String?,
      examId: json['examId'] as String?,
      examWhenId: json['examWhenId'] as String?,
      channelId: json['channelId'] as String? ?? 'mix',
      paceId: json['paceId'] as String? ?? 'balanced',
      examFeelId: json['examFeelId'] as String?,
      interestIds: (json['interestIds'] as List<dynamic>? ?? const [])
          .whereType<String>()
          .toList(),
      superChoice: json['superChoice'] as String?,
    );
  }

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

/// Model to track profile completion status
class ProfileCompletionStatus {
  final int totalSteps;
  final int completedSteps;
  final double percentage;
  final List<ProfileSection> sections;
  final bool isComplete;

  ProfileCompletionStatus({
    required this.totalSteps,
    required this.completedSteps,
    required this.percentage,
    required this.sections,
  }) : isComplete = completedSteps == totalSteps;

  factory ProfileCompletionStatus.fromSections(List<ProfileSection> sections) {
    final totalSteps = sections.length;
    final completedSteps = sections.where((s) => s.isComplete).length;
    final percentage = totalSteps > 0
        ? (completedSteps / totalSteps) * 100.0
        : 0.0;

    return ProfileCompletionStatus(
      totalSteps: totalSteps,
      completedSteps: completedSteps,
      percentage: percentage,
      sections: sections,
    );
  }
}

/// Individual section in the profile
class ProfileSection {
  final String id;
  final String title;
  final String description;
  final bool isComplete;
  final List<ProfileField> fields;
  final bool isRequired;

  ProfileSection({
    required this.id,
    required this.title,
    required this.description,
    required this.isComplete,
    required this.fields,
    this.isRequired = true,
  });

  /// Get missing fields in this section
  List<ProfileField> get missingFields =>
      fields.where((f) => f.isRequired && !f.isComplete).toList();
}

/// Individual field in a section
class ProfileField {
  final String name;
  final String label;
  final bool isComplete;
  final bool isRequired;

  ProfileField({
    required this.name,
    required this.label,
    required this.isComplete,
    this.isRequired = true,
  });
}

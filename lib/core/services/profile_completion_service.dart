import 'package:prepskul/core/models/profile_completion.dart';

/// Service to calculate and track profile completion
class ProfileCompletionService {
  /// Calculate tutor profile completion status
  static ProfileCompletionStatus calculateTutorCompletion(
    Map<String, dynamic> tutorData,
  ) {
    final sections = <ProfileSection>[
      _checkPersonalInfo(tutorData),
      _checkAcademicBackground(tutorData),
      _checkExperience(tutorData),
      _checkTutoringDetails(tutorData),
      _checkAvailability(tutorData),
      _checkPayment(tutorData),
      _checkVerification(tutorData),
    ];

    return ProfileCompletionStatus.fromSections(sections);
  }

  /// Personal Information Section
  static ProfileSection _checkPersonalInfo(Map<String, dynamic> data) {
    final fields = [
      ProfileField(
        name: 'profile_photo',
        label: 'Profile Photo',
        isComplete:
            data['profile_photo_url'] != null &&
            (data['profile_photo_url'] as String).isNotEmpty,
        isRequired: true,
      ),
      ProfileField(
        name: 'city',
        label: 'City',
        isComplete: data['city'] != null && (data['city'] as String).isNotEmpty,
        isRequired: true,
      ),
      ProfileField(
        name: 'quarter',
        label: 'Quarter',
        isComplete:
            data['quarter'] != null && (data['quarter'] as String).isNotEmpty,
        isRequired: true,
      ),
      ProfileField(
        name: 'bio',
        label: 'About Me',
        isComplete: data['bio'] != null && (data['bio'] as String).isNotEmpty,
        isRequired: true,
      ),
    ];

    return ProfileSection(
      id: 'personal_info',
      title: 'Personal Information',
      description: 'Profile photo, location, and bio',
      isComplete: fields.every((f) => !f.isRequired || f.isComplete),
      fields: fields,
    );
  }

  /// Academic Background Section
  static ProfileSection _checkAcademicBackground(Map<String, dynamic> data) {
    final fields = [
      ProfileField(
        name: 'highest_education',
        label: 'Highest Education Level',
        isComplete:
            data['highest_education'] != null &&
            (data['highest_education'] as String).isNotEmpty,
        isRequired: true,
      ),
      ProfileField(
        name: 'institution',
        label: 'Institution Name',
        isComplete:
            data['institution'] != null &&
            (data['institution'] as String).isNotEmpty,
        isRequired: true,
      ),
      ProfileField(
        name: 'field_of_study',
        label: 'Field of Study',
        isComplete:
            data['field_of_study'] != null &&
            (data['field_of_study'] as String).isNotEmpty,
        isRequired: true,
      ),
      ProfileField(
        name: 'certifications',
        label: 'Certificates',
        isComplete:
            data['certifications'] != null &&
            (data['certifications'] as List).isNotEmpty,
        isRequired: false, // Optional
      ),
    ];

    return ProfileSection(
      id: 'academic_background',
      title: 'Academic Background',
      description: 'Education and certifications',
      isComplete: fields.every((f) => !f.isRequired || f.isComplete),
      fields: fields,
    );
  }

  /// Experience Section
  static ProfileSection _checkExperience(Map<String, dynamic> data) {
    final hasExperience = data['has_teaching_experience'] == true;
    final fields = [
      ProfileField(
        name: 'has_teaching_experience',
        label: 'Teaching Experience',
        isComplete: data['has_teaching_experience'] != null,
        isRequired: true,
      ),
      if (hasExperience) ...[
        ProfileField(
          name: 'teaching_duration',
          label: 'Duration of Experience',
          isComplete:
              data['teaching_duration'] != null &&
              (data['teaching_duration'] as String).isNotEmpty,
          isRequired: true,
        ),
        ProfileField(
          name: 'previous_roles',
          label: 'Previous Teaching Roles',
          isComplete:
              data['previous_roles'] != null &&
              (data['previous_roles'] as List).isNotEmpty,
          isRequired: true,
        ),
      ],
      ProfileField(
        name: 'motivation',
        label: 'Why You Want to Tutor',
        isComplete:
            data['motivation'] != null &&
            (data['motivation'] as String).isNotEmpty,
        isRequired: true,
      ),
    ];

    return ProfileSection(
      id: 'experience',
      title: 'Teaching Experience',
      description: 'Your teaching background',
      isComplete: fields.every((f) => !f.isRequired || f.isComplete),
      fields: fields,
    );
  }

  /// Tutoring Details Section
  static ProfileSection _checkTutoringDetails(Map<String, dynamic> data) {
    final fields = [
      ProfileField(
        name: 'tutoring_areas',
        label: 'Tutoring Areas',
        isComplete:
            data['tutoring_areas'] != null &&
            (data['tutoring_areas'] as List).isNotEmpty,
        isRequired: true,
      ),
      ProfileField(
        name: 'learner_levels',
        label: 'Learner Levels',
        isComplete:
            data['learner_levels'] != null &&
            (data['learner_levels'] as List).isNotEmpty,
        isRequired: true,
      ),
      ProfileField(
        name: 'specializations',
        label: 'Specializations',
        isComplete:
            data['specializations'] != null &&
            (data['specializations'] as List).isNotEmpty,
        isRequired: true,
      ),
      ProfileField(
        name: 'personal_statement',
        label: 'Personal Statement',
        isComplete:
            data['personal_statement'] != null &&
            (data['personal_statement'] as String).isNotEmpty,
        isRequired: true,
      ),
    ];

    return ProfileSection(
      id: 'tutoring_details',
      title: 'Tutoring Details',
      description: 'What you teach and who you teach',
      isComplete: fields.every((f) => !f.isRequired || f.isComplete),
      fields: fields,
    );
  }

  /// Availability Section
  static ProfileSection _checkAvailability(Map<String, dynamic> data) {
    final fields = [
      ProfileField(
        name: 'hours_per_week',
        label: 'Hours Per Week',
        isComplete:
            data['hours_per_week'] != null &&
            (data['hours_per_week'] as String).isNotEmpty,
        isRequired: true,
      ),
      ProfileField(
        name: 'availability',
        label: 'Weekly Availability',
        isComplete:
            data['availability'] != null &&
            (data['availability'] as Map).isNotEmpty,
        isRequired: true,
      ),
    ];

    return ProfileSection(
      id: 'availability',
      title: 'Availability',
      description: 'Your schedule and hours',
      isComplete: fields.every((f) => !f.isRequired || f.isComplete),
      fields: fields,
    );
  }

  /// Payment Section
  static ProfileSection _checkPayment(Map<String, dynamic> data) {
    final fields = [
      ProfileField(
        name: 'payment_method',
        label: 'Payment Method',
        isComplete:
            data['payment_method'] != null &&
            (data['payment_method'] as String).isNotEmpty,
        isRequired: true,
      ),
      ProfileField(
        name: 'hourly_rate',
        label: 'Hourly Rate',
        isComplete: data['hourly_rate'] != null && data['hourly_rate'] is num,
        isRequired: true,
      ),
      ProfileField(
        name: 'payment_details',
        label: 'Payment Details',
        isComplete:
            data['payment_details'] != null &&
            (data['payment_details'] as Map).isNotEmpty,
        isRequired: true,
      ),
      ProfileField(
        name: 'payment_agreement',
        label: 'Payment Policy Agreement',
        isComplete: data['payment_agreement'] == true,
        isRequired: true,
      ),
    ];

    return ProfileSection(
      id: 'payment',
      title: 'Payment Information',
      description: 'Rate and payment details',
      isComplete: fields.every((f) => !f.isRequired || f.isComplete),
      fields: fields,
    );
  }

  /// Verification Section
  static ProfileSection _checkVerification(Map<String, dynamic> data) {
    final fields = [
      ProfileField(
        name: 'id_card_front',
        label: 'ID Card (Front)',
        isComplete:
            data['id_card_front_url'] != null &&
            (data['id_card_front_url'] as String).isNotEmpty,
        isRequired: true,
      ),
      ProfileField(
        name: 'id_card_back',
        label: 'ID Card (Back)',
        isComplete:
            data['id_card_back_url'] != null &&
            (data['id_card_back_url'] as String).isNotEmpty,
        isRequired: true,
      ),
      ProfileField(
        name: 'video_link',
        label: 'Introduction Video',
        isComplete:
            data['video_link'] != null &&
            (data['video_link'] as String).isNotEmpty,
        isRequired: false, // Can be completed later
      ),
      ProfileField(
        name: 'verification_agreement',
        label: 'Verification Agreement',
        isComplete: data['verification_agreement'] == true,
        isRequired: true,
      ),
    ];

    return ProfileSection(
      id: 'verification',
      title: 'Verification',
      description: 'ID verification and video',
      isComplete: fields.every((f) => !f.isRequired || f.isComplete),
      fields: fields,
    );
  }
}


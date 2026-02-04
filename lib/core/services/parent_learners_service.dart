import 'package:prepskul/core/services/log_service.dart';
import 'package:prepskul/core/services/supabase_service.dart';

/// Service for parent's linked learners (children) used in "My children" and "Who is this for?" at booking.
class ParentLearnersService {
  static final _supabase = SupabaseService.client;

  /// List all learners for a parent, ordered by display_order then created_at.
  static Future<List<Map<String, dynamic>>> getLearners(String parentId) async {
    try {
      final response = await _supabase
          .from('parent_learners')
          .select()
          .eq('parent_id', parentId)
          .order('display_order', ascending: true)
          .order('created_at', ascending: true);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      LogService.error('Error fetching parent learners: $e');
      return [];
    }
  }

  /// Add a learner (child) for a parent with full profile data.
  static Future<Map<String, dynamic>?> addLearner({
    required String parentId,
    required String name,
    String? educationLevel,
    String? classLevel,
    int displayOrder = 0,
    // Extended profile fields
    DateTime? dateOfBirth,
    String? gender,
    String? relationshipToChild,
    String? learningPath,
    String? stream,
    List<String>? subjects,
    String? universityCourses,
    String? skillCategory,
    List<String>? skills,
    String? examType,
    String? specificExam,
    List<String>? examSubjects,
    String? confidenceLevel,
    List<String>? learningGoals,
    List<String>? challenges,
    String? tutorGenderPreference,
    String? tutorQualificationPreference,
    String? preferredLocation,
    List<String>? preferredSchedule,
  }) async {
    try {
      final data = <String, dynamic>{
        'parent_id': parentId,
        'name': name,
        'education_level': educationLevel,
        'class_level': classLevel,
        'display_order': displayOrder,
        'updated_at': DateTime.now().toIso8601String(),
      };
      
      // Add extended fields if provided
      if (dateOfBirth != null) data['date_of_birth'] = dateOfBirth.toIso8601String();
      if (gender != null) data['gender'] = gender;
      if (relationshipToChild != null) data['relationship_to_child'] = relationshipToChild;
      if (learningPath != null) data['learning_path'] = learningPath;
      if (stream != null) data['stream'] = stream;
      if (subjects != null && subjects.isNotEmpty) data['subjects'] = subjects;
      if (universityCourses != null && universityCourses.isNotEmpty) data['university_courses'] = universityCourses;
      if (skillCategory != null) data['skill_category'] = skillCategory;
      if (skills != null && skills.isNotEmpty) data['skills'] = skills;
      if (examType != null) data['exam_type'] = examType;
      if (specificExam != null) data['specific_exam'] = specificExam;
      if (examSubjects != null && examSubjects.isNotEmpty) data['exam_subjects'] = examSubjects;
      if (confidenceLevel != null) data['confidence_level'] = confidenceLevel;
      if (learningGoals != null && learningGoals.isNotEmpty) data['learning_goals'] = learningGoals;
      if (challenges != null && challenges.isNotEmpty) data['challenges'] = challenges;
      if (tutorGenderPreference != null) data['tutor_gender_preference'] = tutorGenderPreference;
      if (tutorQualificationPreference != null) data['tutor_qualification_preference'] = tutorQualificationPreference;
      if (preferredLocation != null) data['preferred_location'] = preferredLocation;
      if (preferredSchedule != null && preferredSchedule.isNotEmpty) data['preferred_schedule'] = preferredSchedule;
      
      final response = await _supabase
          .from('parent_learners')
          .insert(data)
          .select()
          .maybeSingle();
      if (response != null) {
        LogService.success('Parent learner added with full profile: $name');
        return response as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      LogService.error('Error adding parent learner: $e');
      rethrow;
    }
  }

  /// Update a learner with full profile data.
  static Future<bool> updateLearner({
    required String learnerId,
    required String parentId,
    String? name,
    String? educationLevel,
    String? classLevel,
    int? displayOrder,
    // Extended profile fields
    DateTime? dateOfBirth,
    String? gender,
    String? relationshipToChild,
    String? learningPath,
    String? stream,
    List<String>? subjects,
    String? universityCourses,
    String? skillCategory,
    List<String>? skills,
    String? examType,
    String? specificExam,
    List<String>? examSubjects,
    String? confidenceLevel,
    List<String>? learningGoals,
    List<String>? challenges,
    String? tutorGenderPreference,
    String? tutorQualificationPreference,
    String? preferredLocation,
    List<String>? preferredSchedule,
  }) async {
    try {
      final updates = <String, dynamic>{
        'updated_at': DateTime.now().toIso8601String(),
      };
      if (name != null) updates['name'] = name;
      if (educationLevel != null) updates['education_level'] = educationLevel;
      if (classLevel != null) updates['class_level'] = classLevel;
      if (displayOrder != null) updates['display_order'] = displayOrder;
      
      // Add extended fields if provided
      if (dateOfBirth != null) updates['date_of_birth'] = dateOfBirth.toIso8601String();
      if (gender != null) updates['gender'] = gender;
      if (relationshipToChild != null) updates['relationship_to_child'] = relationshipToChild;
      if (learningPath != null) updates['learning_path'] = learningPath;
      if (stream != null) updates['stream'] = stream;
      if (subjects != null) updates['subjects'] = subjects.isNotEmpty ? subjects : null;
      if (universityCourses != null) updates['university_courses'] = universityCourses.isNotEmpty ? universityCourses : null;
      if (skillCategory != null) updates['skill_category'] = skillCategory;
      if (skills != null) updates['skills'] = skills.isNotEmpty ? skills : null;
      if (examType != null) updates['exam_type'] = examType;
      if (specificExam != null) updates['specific_exam'] = specificExam;
      if (examSubjects != null) updates['exam_subjects'] = examSubjects.isNotEmpty ? examSubjects : null;
      if (confidenceLevel != null) updates['confidence_level'] = confidenceLevel;
      if (learningGoals != null) updates['learning_goals'] = learningGoals.isNotEmpty ? learningGoals : null;
      if (challenges != null) updates['challenges'] = challenges.isNotEmpty ? challenges : null;
      if (tutorGenderPreference != null) updates['tutor_gender_preference'] = tutorGenderPreference;
      if (tutorQualificationPreference != null) updates['tutor_qualification_preference'] = tutorQualificationPreference;
      if (preferredLocation != null) updates['preferred_location'] = preferredLocation;
      if (preferredSchedule != null) updates['preferred_schedule'] = preferredSchedule.isNotEmpty ? preferredSchedule : null;

      await _supabase
          .from('parent_learners')
          .update(updates)
          .eq('id', learnerId)
          .eq('parent_id', parentId);
      LogService.success('Parent learner updated with full profile: $learnerId');
      return true;
    } catch (e) {
      LogService.error('Error updating parent learner: $e');
      rethrow;
    }
  }

  /// Delete a learner.
  static Future<bool> deleteLearner({
    required String learnerId,
    required String parentId,
  }) async {
    try {
      await _supabase
          .from('parent_learners')
          .delete()
          .eq('id', learnerId)
          .eq('parent_id', parentId);
      LogService.success('Parent learner deleted: $learnerId');
      return true;
    } catch (e) {
      LogService.error('Error deleting parent learner: $e');
      rethrow;
    }
  }

  /// Sync first child from parent_profiles to parent_learners (for onboarding completion).
  /// This ensures the child entered during onboarding appears in "My children".
  /// Returns true if a child was synced, false if none existed or already synced.
  static Future<bool> syncFirstChildFromProfile(String parentId) async {
    try {
      // Check if parent already has learners
      final existingLearners = await getLearners(parentId);
      if (existingLearners.isNotEmpty) {
        LogService.info('Parent already has learners, skipping sync');
        return false;
      }

      // Fetch parent profile to get child info
      final parentProfile = await _supabase
          .from('parent_profiles')
          .select('child_name, child_date_of_birth, child_gender, relationship_to_child, education_level, class_level, learning_path, stream, subjects, skill_category, skills, exam_type, specific_exam, exam_subjects, child_confidence_level, learning_goals, challenges, tutor_gender_preference, tutor_qualification_preference, preferred_location, preferred_schedule')
          .eq('user_id', parentId)
          .maybeSingle();

      if (parentProfile == null) {
        LogService.info('No parent profile found for sync');
        return false;
      }

      final childName = parentProfile['child_name'] as String?;
      if (childName == null || childName.trim().isEmpty) {
        LogService.info('No child name in parent profile');
        return false;
      }

      // Check if this child already exists (by name match)
      final nameMatches = existingLearners.where(
        (l) => (l['name'] as String? ?? '').trim().toLowerCase() == childName.trim().toLowerCase(),
      );
      if (nameMatches.isNotEmpty) {
        LogService.info('Child already exists in parent_learners');
        return false;
      }

      // Create learner record from parent profile with all available fields
      await addLearner(
        parentId: parentId,
        name: childName.trim(),
        educationLevel: parentProfile['education_level'] as String?,
        classLevel: parentProfile['class_level'] as String?,
        dateOfBirth: parentProfile['child_date_of_birth'] != null 
            ? DateTime.parse(parentProfile['child_date_of_birth'] as String)
            : null,
        gender: parentProfile['child_gender'] as String?,
        relationshipToChild: parentProfile['relationship_to_child'] as String?,
        learningPath: parentProfile['learning_path'] as String?,
        stream: parentProfile['stream'] as String?,
        subjects: parentProfile['subjects'] != null 
            ? List<String>.from(parentProfile['subjects'] as List)
            : null,
        skillCategory: parentProfile['skill_category'] as String?,
        skills: parentProfile['skills'] != null
            ? List<String>.from(parentProfile['skills'] as List)
            : null,
        examType: parentProfile['exam_type'] as String?,
        specificExam: parentProfile['specific_exam'] as String?,
        examSubjects: parentProfile['exam_subjects'] != null
            ? List<String>.from(parentProfile['exam_subjects'] as List)
            : null,
        confidenceLevel: parentProfile['child_confidence_level'] as String?,
        learningGoals: parentProfile['learning_goals'] != null
            ? List<String>.from(parentProfile['learning_goals'] as List)
            : null,
        challenges: parentProfile['challenges'] != null
            ? List<String>.from(parentProfile['challenges'] as List)
            : null,
        tutorGenderPreference: parentProfile['tutor_gender_preference'] as String?,
        tutorQualificationPreference: parentProfile['tutor_qualification_preference'] as String?,
        preferredLocation: parentProfile['preferred_location'] as String?,
        preferredSchedule: parentProfile['preferred_schedule'] != null
            ? List<String>.from(parentProfile['preferred_schedule'] as List)
            : null,
        displayOrder: 0,
      );

      LogService.success('Synced first child from parent profile: $childName');
      return true;
    } catch (e) {
      LogService.error('Error syncing first child from profile: $e');
      return false;
    }
  }
}

import 'package:prepskul/core/services/supabase_service.dart';
import 'package:prepskul/core/services/tutor_service.dart';

class MatchScore {
  final double totalScore;
  final double percentage;
  final Map<String, double> breakdown;
  MatchScore({required this.totalScore, required this.breakdown, required this.percentage});
}

class MatchedTutor {
  final Map<String, dynamic> tutor;
  final MatchScore matchScore;
  MatchedTutor({required this.tutor, required this.matchScore});
}

class TutorMatchingService {
  static Future<List<MatchedTutor>> matchTutorsForUser({
    required String userId,
    required String userType,
    Map<String, dynamic>? filters,
  }) async {
    // Stub implementation - will be implemented later
    final tutors = await TutorService.fetchTutors();
    return tutors.map((tutor) => MatchedTutor(
      tutor: tutor,
      matchScore: MatchScore(
        totalScore: 0.5,
        percentage: 50.0,
        breakdown: {},
      ),
    )).toList();
  }
}

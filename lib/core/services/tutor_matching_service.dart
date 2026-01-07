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
    // Fetch tutors with basic filters applied (subject/rating/price)
    final subjectFilter = (filters?['subject'] as String?)?.toLowerCase();
    final minRate = filters?['minRate'] as int?;
    final maxRate = filters?['maxRate'] as int?;
    final minRating = (filters?['minRating'] as double?) ?? 0.0;

    final tutors = await TutorService.fetchTutors(
      subject: subjectFilter,
      minRate: minRate,
      maxRate: maxRate,
      minRating: minRating,
    );

    if (tutors.isEmpty) return [];

    // Load user location (city/quarter) from profiles table for location-based matching
    String? userCity;
    String? userQuarter;
    try {
      final profile = await SupabaseService.client
          .from('profiles')
          .select('city, quarter')
          .eq('id', userId)
          .maybeSingle();

      if (profile != null) {
        userCity = profile['city']?.toString();
        userQuarter = profile['quarter']?.toString();
      }
    } catch (_) {
      // If profile lookup fails, we simply won't use location in scoring
    }

    const double subjectWeight = 0.5;
    const double locationWeight = 0.2;
    const double ratingWeight = 0.3;
    const double maxScore = subjectWeight + locationWeight + ratingWeight;

    final matches = tutors.map((tutor) {
      // Subjects / specializations from tutor
      final subjects = (tutor['subjects'] as List?)
              ?.map((s) => s.toString().toLowerCase())
              .toList() ??
          <String>[];
      final specializations = (tutor['specializations'] as List?)
              ?.map((s) => s.toString().toLowerCase())
              .toList() ??
          <String>[];
      final allSubjects = {...subjects, ...specializations};

      final bool subjectMatch = subjectFilter == null || subjectFilter.isEmpty
          ? allSubjects.isNotEmpty
          : allSubjects.contains(subjectFilter);

      // Location match: city or quarter alignment with user
      final tutorCity = tutor['city']?.toString().toLowerCase();
      final tutorQuarter = tutor['quarter']?.toString().toLowerCase();
      bool locationMatch = false;
      if (userCity != null && userCity.isNotEmpty && tutorCity != null) {
        locationMatch = tutorCity.toLowerCase() == userCity.toLowerCase();
      }
      if (!locationMatch &&
          userQuarter != null &&
          userQuarter.isNotEmpty &&
          tutorQuarter != null) {
        locationMatch =
            tutorQuarter.toLowerCase() == userQuarter.toLowerCase();
      }

      // Rating score (0–1 based on 0–5 stars)
      final rating = (tutor['rating'] as num?)?.toDouble() ?? 0.0;
      final ratingScore = (rating / 5.0).clamp(0.0, 1.0);

      double totalScore = 0.0;
      final breakdown = <String, double>{};

      if (subjectMatch) {
        totalScore += subjectWeight;
        breakdown['subject'] = subjectWeight;
      } else {
        breakdown['subject'] = 0.0;
      }

      if (locationMatch) {
        totalScore += locationWeight;
        breakdown['location'] = locationWeight;
      } else {
        breakdown['location'] = 0.0;
      }

      final ratingComponent = ratingWeight * ratingScore;
      totalScore += ratingComponent;
      breakdown['rating'] = ratingComponent;

      final percentage = (totalScore / maxScore) * 100.0;

      return MatchedTutor(
        tutor: tutor,
        matchScore: MatchScore(
          totalScore: totalScore,
          percentage: percentage,
          breakdown: breakdown,
        ),
      );
    }).toList();

    // Keep only tutors who match by subject or location
    final filteredMatches = matches.where((m) {
      final subjectScore = m.matchScore.breakdown['subject'] ?? 0.0;
      final locationScore = m.matchScore.breakdown['location'] ?? 0.0;
      return subjectScore > 0 || locationScore > 0;
    }).toList();

    // Sort: primary by match score, secondary by rating (top-rated first)
    filteredMatches.sort((a, b) {
      final scoreDiff = b.matchScore.totalScore.compareTo(a.matchScore.totalScore);
      if (scoreDiff != 0) return scoreDiff;
      final ratingA = (a.tutor['rating'] as num?)?.toDouble() ?? 0.0;
      final ratingB = (b.tutor['rating'] as num?)?.toDouble() ?? 0.0;
      return ratingB.compareTo(ratingA);
    });

    return filteredMatches;
  }
}

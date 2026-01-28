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

    // Load user location (city/quarter) and budget from profiles/learner_profiles for matching
    String? userCity;
    String? userQuarter;
    int? userMinBudget;
    int? userMaxBudget;
    bool hasSurveyData = false;
    
    try {
      // Check profiles table for location
      final profile = await SupabaseService.client
          .from('profiles')
          .select('city, quarter')
          .eq('id', userId)
          .maybeSingle();

      if (profile != null) {
        userCity = profile['city']?.toString();
        userQuarter = profile['quarter']?.toString();
        if ((userCity != null && userCity.isNotEmpty) || 
            (userQuarter != null && userQuarter.isNotEmpty)) {
          hasSurveyData = true;
        }
      }
      
      // Check learner_profiles for budget (if user is a student)
      if (userType == 'student' || userType == 'learner') {
        try {
          final learnerProfile = await SupabaseService.client
              .from('learner_profiles')
              .select('min_budget, max_budget')
              .eq('user_id', userId)
              .maybeSingle();
          
          if (learnerProfile != null) {
            userMinBudget = learnerProfile['min_budget'] as int?;
            userMaxBudget = learnerProfile['max_budget'] as int?;
            if (userMinBudget != null || userMaxBudget != null) {
              hasSurveyData = true;
            }
          }
        } catch (_) {
          // Budget lookup failed, continue without it
        }
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

      // Price range match (if user has budget preferences)
      bool priceMatch = false;
      if (hasSurveyData && (userMinBudget != null || userMaxBudget != null)) {
        final tutorRate = (tutor['hourly_rate'] as num?)?.toInt() ?? 0;
        if (userMinBudget != null && userMaxBudget != null) {
          priceMatch = tutorRate >= userMinBudget && tutorRate <= userMaxBudget;
        } else if (userMinBudget != null) {
          priceMatch = tutorRate >= userMinBudget;
        } else if (userMaxBudget != null) {
          priceMatch = tutorRate <= userMaxBudget;
        }
      }

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
      breakdown['priceMatch'] = priceMatch ? 1.0 : 0.0;

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

    // Don't filter by subject/location - show all tutors, sorted properly
    final filteredMatches = matches;

    // Sort according to requirements:
    // 1. Primary: Rating (highest first)
    // 2. Secondary: Location match (if user has survey data)
    // 3. Tertiary: Price range match (if user has budget)
    // 4. Quaternary: Gender (female priority) - TODO: Add gender field to profiles/tutor_profiles
    filteredMatches.sort((a, b) {
      // Primary: Rating (highest first)
      final ratingA = (a.tutor['rating'] as num?)?.toDouble() ?? 0.0;
      final ratingB = (b.tutor['rating'] as num?)?.toDouble() ?? 0.0;
      final ratingDiff = ratingB.compareTo(ratingA);
      if (ratingDiff != 0) return ratingDiff;
      
      // Secondary: Location match (if user has survey data)
      if (hasSurveyData) {
        final locationMatchA = a.matchScore.breakdown['location'] ?? 0.0;
        final locationMatchB = b.matchScore.breakdown['location'] ?? 0.0;
        final locationDiff = locationMatchB.compareTo(locationMatchA);
        if (locationDiff != 0) return locationDiff;
      }
      
      // Tertiary: Price range match (if user has budget)
      if (hasSurveyData && (userMinBudget != null || userMaxBudget != null)) {
        final priceMatchA = a.matchScore.breakdown['priceMatch'] ?? 0.0;
        final priceMatchB = b.matchScore.breakdown['priceMatch'] ?? 0.0;
        final priceDiff = priceMatchB.compareTo(priceMatchA);
        if (priceDiff != 0) return priceDiff;
      }
      
      // Quaternary: Gender (female priority) - TODO: Implement when gender field is available
      // For now, return 0 (no change in order)
      // When gender is available:
      // final genderA = a.tutor['gender']?.toString().toLowerCase();
      // final genderB = b.tutor['gender']?.toString().toLowerCase();
      // if (genderA == 'female' && genderB != 'female') return -1;
      // if (genderA != 'female' && genderB == 'female') return 1;
      
      return 0;
    });

    return filteredMatches;
  }
}

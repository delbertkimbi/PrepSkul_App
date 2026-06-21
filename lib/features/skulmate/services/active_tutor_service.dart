import 'package:prepskul/core/services/log_service.dart';
import 'package:prepskul/core/services/supabase_service.dart';

/// Whether the learner already has active tutor relationships (avoid "find a tutor" noise).
class ActiveTutorService {
  ActiveTutorService._();

  static Future<ActiveTutorStatus> check() async {
    final userId = SupabaseService.client.auth.currentUser?.id;
    if (userId == null) {
      return const ActiveTutorStatus(hasActiveTutor: false, tutorNames: []);
    }

    try {
      final names = <String>{};

      final recurring = await SupabaseService.client
          .from('recurring_sessions')
          .select('tutor_name, status')
          .eq('learner_id', userId)
          .eq('status', 'active')
          .limit(10);
      for (final row in recurring) {
        final name = row['tutor_name']?.toString();
        if (name != null && name.isNotEmpty) names.add(name);
      }

      final bookings = await SupabaseService.client
          .from('booking_requests')
          .select('tutor_name, status')
          .eq('student_id', userId)
          .inFilter('status', ['pending', 'approved'])
          .limit(10);
      for (final row in bookings) {
        final name = row['tutor_name']?.toString();
        if (name != null && name.isNotEmpty) names.add(name);
      }

      final trials = await SupabaseService.client
          .from('trial_sessions')
          .select('tutor_id, status, profiles:tutor_id(full_name)')
          .eq('requester_id', userId)
          .inFilter('status', ['pending', 'approved', 'scheduled'])
          .limit(10);
      for (final row in trials) {
        final profile = row['profiles'];
        if (profile is Map && profile['full_name'] != null) {
          names.add(profile['full_name'].toString());
        }
      }

      final tutorList = names.toList();
      return ActiveTutorStatus(
        hasActiveTutor: tutorList.isNotEmpty,
        tutorNames: tutorList,
      );
    } catch (e) {
      LogService.debug('ActiveTutorService.check: $e');
      return const ActiveTutorStatus(hasActiveTutor: false, tutorNames: []);
    }
  }
}

class ActiveTutorStatus {
  final bool hasActiveTutor;
  final List<String> tutorNames;

  const ActiveTutorStatus({
    required this.hasActiveTutor,
    required this.tutorNames,
  });

  String primaryTutorName() =>
      tutorNames.isNotEmpty ? tutorNames.first : '';
}

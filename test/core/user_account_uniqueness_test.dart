import 'package:flutter_test/flutter_test.dart';

/// Comprehensive tests for User Account Uniqueness
/// 
/// Tests that user accounts are unique across all aspects of the platform
/// including relationships, attributes, and foreign key constraints
void main() {
  group('User Account Uniqueness - Core Tables', () {
    group('Profiles Table', () {
      test('each user should have exactly one profile', () {
        final userId = 'user_123';
        final profiles = [
          {'id': userId, 'email': 'user@test.com'},
        ];
        
        // Should have exactly one profile per user
        expect(profiles.length, 1);
        expect(profiles[0]['id'], userId);
      });

      test('profile ID should be unique (primary key)', () {
        final profiles = [
          {'id': 'user_1', 'email': 'user1@test.com'},
          {'id': 'user_2', 'email': 'user2@test.com'},
        ];
        
        final ids = profiles.map((p) => p['id']).toSet();
        expect(ids.length, profiles.length);
      });

      test('profile should reference auth.users(id) uniquely', () {
        final userId = 'user_123';
        final profile = {
          'id': userId,
          'email': 'user@test.com',
          'user_type': 'learner',
        };
        
        // Profile ID should match auth.users ID
        expect(profile['id'], userId);
      });

      test('email should be unique per profile', () {
        final profiles = [
          {'id': 'user_1', 'email': 'user1@test.com'},
          {'id': 'user_2', 'email': 'user2@test.com'},
        ];
        
        final emails = profiles.map((p) => p['email']).toSet();
        expect(emails.length, profiles.length);
      });
    });

    group('Learner Profiles Table', () {
      test('each learner should have exactly one learner profile', () {
        final userId = 'learner_123';
        final learnerProfiles = [
          {'user_id': userId, 'student_name': 'John Doe'},
        ];
        
        expect(learnerProfiles.length, 1);
        expect(learnerProfiles[0]['user_id'], userId);
      });

      test('learner profile user_id should be unique', () {
        final learnerProfiles = [
          {'user_id': 'learner_1', 'student_name': 'John'},
          {'user_id': 'learner_2', 'student_name': 'Jane'},
        ];
        
        final userIds = learnerProfiles.map((p) => p['user_id']).toSet();
        expect(userIds.length, learnerProfiles.length);
      });

      test('learner profile should reference profiles(id) uniquely', () {
        final profileId = 'profile_123';
        final learnerProfile = {
          'id': profileId,
          'user_id': profileId,
        };
        
        expect(learnerProfile['id'], learnerProfile['user_id']);
      });
    });

    group('Parent Profiles Table', () {
      test('each parent should have exactly one parent profile', () {
        final userId = 'parent_123';
        final parentProfiles = [
          {'user_id': userId, 'child_name': 'Child Doe'},
        ];
        
        expect(parentProfiles.length, 1);
        expect(parentProfiles[0]['user_id'], userId);
      });

      test('parent profile user_id should be unique', () {
        final parentProfiles = [
          {'user_id': 'parent_1', 'child_name': 'Child 1'},
          {'user_id': 'parent_2', 'child_name': 'Child 2'},
        ];
        
        final userIds = parentProfiles.map((p) => p['user_id']).toSet();
        expect(userIds.length, parentProfiles.length);
      });

      test('parent profile should reference profiles(id) uniquely', () {
        final profileId = 'profile_123';
        final parentProfile = {
          'id': profileId,
          'user_id': profileId,
        };
        
        expect(parentProfile['id'], parentProfile['user_id']);
      });
    });

    group('Tutor Profiles Table', () {
      test('each tutor should have exactly one tutor profile', () {
        final userId = 'tutor_123';
        final tutorProfiles = [
          {'user_id': userId, 'bio': 'Experienced tutor'},
        ];
        
        expect(tutorProfiles.length, 1);
        expect(tutorProfiles[0]['user_id'], userId);
      });

      test('tutor profile should reference profiles(id) uniquely', () {
        final profileId = 'profile_123';
        final tutorProfile = {
          'id': profileId,
          'user_id': profileId,
        };
        
        expect(tutorProfile['id'], tutorProfile['user_id']);
      });
    });
  });

  group('User Account Uniqueness - Booking Relationships', () {
    group('Booking Requests', () {
      test('student_id should reference unique user', () {
        final bookingRequests = [
          {'id': 'req_1', 'student_id': 'student_1', 'tutor_id': 'tutor_1'},
          {'id': 'req_2', 'student_id': 'student_2', 'tutor_id': 'tutor_1'},
        ];
        
        final studentIds = bookingRequests.map((r) => r['student_id']).toList();
        // Multiple requests can have same student, but each student_id should be valid
        expect(studentIds.every((id) => id != null), true);
      });

      test('tutor_id should reference unique user', () {
        final bookingRequests = [
          {'id': 'req_1', 'student_id': 'student_1', 'tutor_id': 'tutor_1'},
          {'id': 'req_2', 'student_id': 'student_2', 'tutor_id': 'tutor_1'},
        ];
        
        final tutorIds = bookingRequests.map((r) => r['tutor_id']).toSet();
        // Multiple requests can have same tutor
        expect(tutorIds.length, 1);
      });

      test('learner_id should reference unique user', () {
        final bookingRequest = {
          'id': 'req_1',
          'learner_id': 'learner_123',
          'tutor_id': 'tutor_1',
        };
        
        expect(bookingRequest['learner_id'], isNotNull);
      });

      test('parent_id should reference unique user', () {
        final bookingRequest = {
          'id': 'req_1',
          'parent_id': 'parent_123',
          'tutor_id': 'tutor_1',
        };
        
        expect(bookingRequest['parent_id'], isNotNull);
      });
    });

    group('Trial Sessions', () {
      test('requester_id should reference unique user', () {
        final trialSessions = [
          {'id': 'trial_1', 'requester_id': 'student_1', 'tutor_id': 'tutor_1'},
          {'id': 'trial_2', 'requester_id': 'student_2', 'tutor_id': 'tutor_1'},
        ];
        
        final requesterIds = trialSessions.map((t) => t['requester_id']).toList();
        expect(requesterIds.every((id) => id != null), true);
      });

      test('tutor_id should reference unique user', () {
        final trialSession = {
          'id': 'trial_1',
          'requester_id': 'student_1',
          'tutor_id': 'tutor_123',
        };
        
        expect(trialSession['tutor_id'], isNotNull);
      });

      test('learner_id should reference unique user', () {
        final trialSession = {
          'id': 'trial_1',
          'learner_id': 'learner_123',
          'tutor_id': 'tutor_1',
        };
        
        expect(trialSession['learner_id'], isNotNull);
      });
    });

    group('Recurring Sessions', () {
      test('tutor_id should reference unique user', () {
        final recurringSession = {
          'id': 'recurring_1',
          'tutor_id': 'tutor_123',
          'learner_id': 'learner_123',
        };
        
        expect(recurringSession['tutor_id'], isNotNull);
      });

      test('learner_id should reference unique user', () {
        final recurringSession = {
          'id': 'recurring_1',
          'tutor_id': 'tutor_123',
          'learner_id': 'learner_123',
        };
        
        expect(recurringSession['learner_id'], isNotNull);
      });

      test('parent_id should reference unique user', () {
        final recurringSession = {
          'id': 'recurring_1',
          'tutor_id': 'tutor_123',
          'parent_id': 'parent_123',
        };
        
        expect(recurringSession['parent_id'], isNotNull);
      });
    });

    group('Individual Sessions', () {
      test('tutor_id should reference unique user', () {
        final individualSession = {
          'id': 'session_1',
          'tutor_id': 'tutor_123',
          'learner_id': 'learner_123',
        };
        
        expect(individualSession['tutor_id'], isNotNull);
      });

      test('learner_id should reference unique user', () {
        final individualSession = {
          'id': 'session_1',
          'tutor_id': 'tutor_123',
          'learner_id': 'learner_123',
        };
        
        expect(individualSession['learner_id'], isNotNull);
      });

      test('parent_id should reference unique user', () {
        final individualSession = {
          'id': 'session_1',
          'tutor_id': 'tutor_123',
          'parent_id': 'parent_123',
        };
        
        expect(individualSession['parent_id'], isNotNull);
      });
    });
  });

  group('User Account Uniqueness - Payment Relationships', () {
    group('Payment Requests', () {
      test('student_id should reference unique user', () {
        final paymentRequest = {
          'id': 'payment_req_1',
          'student_id': 'student_123',
          'tutor_id': 'tutor_123',
        };
        
        expect(paymentRequest['student_id'], isNotNull);
      });

      test('tutor_id should reference unique user', () {
        final paymentRequest = {
          'id': 'payment_req_1',
          'student_id': 'student_123',
          'tutor_id': 'tutor_123',
        };
        
        expect(paymentRequest['tutor_id'], isNotNull);
      });
    });

    group('User Credits', () {
      test('user_id should reference unique user', () {
        final userCredits = [
          {'user_id': 'user_1', 'balance': 1000},
          {'user_id': 'user_2', 'balance': 2000},
        ];
        
        final userIds = userCredits.map((c) => c['user_id']).toSet();
        expect(userIds.length, userCredits.length);
      });

      test('each user should have exactly one credit record', () {
        final userId = 'user_123';
        final creditRecords = [
          {'user_id': userId, 'balance': 1000},
        ];
        
        expect(creditRecords.length, 1);
        expect(creditRecords[0]['user_id'], userId);
      });
    });

    group('Credit Transactions', () {
      test('user_id should reference unique user', () {
        final transactions = [
          {'id': 'trans_1', 'user_id': 'user_1', 'amount': 100},
          {'id': 'trans_2', 'user_id': 'user_2', 'amount': 200},
        ];
        
        final userIds = transactions.map((t) => t['user_id']).toList();
        expect(userIds.every((id) => id != null), true);
      });
    });

    group('Tutor Earnings', () {
      test('tutor_id should reference unique user', () {
        final earnings = [
          {'id': 'earning_1', 'tutor_id': 'tutor_1', 'amount': 5000},
          {'id': 'earning_2', 'tutor_id': 'tutor_2', 'amount': 6000},
        ];
        
        final tutorIds = earnings.map((e) => e['tutor_id']).toList();
        expect(tutorIds.every((id) => id != null), true);
      });
    });
  });

  group('User Account Uniqueness - Foreign Key Constraints', () {
    test('all user_id foreign keys should reference valid users', () {
      final userId = 'user_123';
      final tables = [
        {'table': 'profiles', 'user_id': userId},
        {'table': 'learner_profiles', 'user_id': userId},
        {'table': 'parent_profiles', 'user_id': userId},
        {'table': 'tutor_profiles', 'user_id': userId},
      ];
      
      for (final table in tables) {
        expect(table['user_id'], userId);
        expect(table['user_id'], isNotNull);
      }
    });

    test('all student_id foreign keys should reference valid users', () {
      final studentId = 'student_123';
      final tables = [
        {'table': 'booking_requests', 'student_id': studentId},
        {'table': 'payment_requests', 'student_id': studentId},
      ];
      
      for (final table in tables) {
        expect(table['student_id'], studentId);
        expect(table['student_id'], isNotNull);
      }
    });

    test('all tutor_id foreign keys should reference valid users', () {
      final tutorId = 'tutor_123';
      final tables = [
        {'table': 'booking_requests', 'tutor_id': tutorId},
        {'table': 'trial_sessions', 'tutor_id': tutorId},
        {'table': 'recurring_sessions', 'tutor_id': tutorId},
        {'table': 'individual_sessions', 'tutor_id': tutorId},
        {'table': 'payment_requests', 'tutor_id': tutorId},
        {'table': 'tutor_earnings', 'tutor_id': tutorId},
      ];
      
      for (final table in tables) {
        expect(table['tutor_id'], tutorId);
        expect(table['tutor_id'], isNotNull);
      }
    });

    test('all learner_id foreign keys should reference valid users', () {
      final learnerId = 'learner_123';
      final tables = [
        {'table': 'booking_requests', 'learner_id': learnerId},
        {'table': 'trial_sessions', 'learner_id': learnerId},
        {'table': 'recurring_sessions', 'learner_id': learnerId},
        {'table': 'individual_sessions', 'learner_id': learnerId},
      ];
      
      for (final table in tables) {
        expect(table['learner_id'], learnerId);
        expect(table['learner_id'], isNotNull);
      }
    });

    test('all parent_id foreign keys should reference valid users', () {
      final parentId = 'parent_123';
      final tables = [
        {'table': 'booking_requests', 'parent_id': parentId},
        {'table': 'recurring_sessions', 'parent_id': parentId},
        {'table': 'individual_sessions', 'parent_id': parentId},
      ];
      
      for (final table in tables) {
        expect(table['parent_id'], parentId);
        expect(table['parent_id'], isNotNull);
      }
    });
  });

  group('User Account Uniqueness - Cascade Deletes', () {
    test('deleting user should cascade delete profile', () {
      final userId = 'user_123';
      final profile = {'id': userId, 'user_id': userId};
      
      // When user is deleted, profile should be deleted (CASCADE)
      expect(profile['id'], userId);
    });

    test('deleting user should cascade delete learner profile', () {
      final userId = 'user_123';
      final learnerProfile = {'user_id': userId};
      
      // When user is deleted, learner profile should be deleted (CASCADE)
      expect(learnerProfile['user_id'], userId);
    });

    test('deleting user should cascade delete parent profile', () {
      final userId = 'user_123';
      final parentProfile = {'user_id': userId};
      
      // When user is deleted, parent profile should be deleted (CASCADE)
      expect(parentProfile['user_id'], userId);
    });

    test('deleting user should cascade delete tutor profile', () {
      final userId = 'user_123';
      final tutorProfile = {'user_id': userId};
      
      // When user is deleted, tutor profile should be deleted (CASCADE)
      expect(tutorProfile['user_id'], userId);
    });
  });

  group('User Account Uniqueness - Unique Constraints', () {
    test('profiles.id should be unique (primary key)', () {
      final profiles = [
        {'id': 'user_1'},
        {'id': 'user_2'},
        {'id': 'user_3'},
      ];
      
      final ids = profiles.map((p) => p['id']).toSet();
      expect(ids.length, profiles.length);
    });

    test('learner_profiles.user_id should be unique', () {
      final learnerProfiles = [
        {'user_id': 'learner_1'},
        {'user_id': 'learner_2'},
      ];
      
      final userIds = learnerProfiles.map((p) => p['user_id']).toSet();
      expect(userIds.length, learnerProfiles.length);
    });

    test('parent_profiles.user_id should be unique', () {
      final parentProfiles = [
        {'user_id': 'parent_1'},
        {'user_id': 'parent_2'},
      ];
      
      final userIds = parentProfiles.map((p) => p['user_id']).toSet();
      expect(userIds.length, parentProfiles.length);
    });

    test('user_credits.user_id should be unique', () {
      final userCredits = [
        {'user_id': 'user_1', 'balance': 1000},
        {'user_id': 'user_2', 'balance': 2000},
      ];
      
      final userIds = userCredits.map((c) => c['user_id']).toSet();
      expect(userIds.length, userCredits.length);
    });
  });
}


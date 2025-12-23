// /// Route Guards
// ///
// /// Validates user permissions before navigation
// import 'package:shared_preferences/shared_preferences.dart';
// import 'package:prepskul/core/services/auth_service.dart';
// import 'package:prepskul/core/services/supabase_service.dart';

// class RouteGuard {
//   /// Check if user can navigate to a specific route
//   static Future<RouteGuardResult> canNavigateTo(String route) async {
//     try {
//       // Check authentication status first
//       final isAuthenticated = await AuthService.isLoggedIn();
//       final hasSupabaseSession = SupabaseService.isAuthenticated;
//       final userIsAuthenticated = isAuthenticated || hasSupabaseSession;

//       // Auth rou tes (login, signup, etc.)
//       final authRoutes = [
//         '/auth-method-selection',
//         '/login',
//         '/beautiful-login',
//         '/beautiful-signup',
//         '/email-signup',
//         '/email-login',
//         '/forgot-password',
//         '/reset-password',
//         '/otp-verification',
//       ];

//       // If user is authenticated and tries to access auth routes, check onboarding/survey first
//       if (userIsAuthenticated && authRoutes.contains(route)) {
//         print(
//           '🚫 [GUARD] Authenticated user tried to access auth route, checking onboarding/survey status',
//         );
//         try {
//           // For authenticated users with Supabase session, check if they have a profile
//           // If they have a profile, skip onboarding check (they've signed in before)
//           bool shouldCheckOnboarding = true;
          
//           if (hasSupabaseSession) {
//             try {
//               final user = SupabaseService.currentUser;
//               if (user != null) {
//                 final profile = await SupabaseService.client
//                     .from('profiles')
//                     .select('id')
//                     .eq('id', user.id)
//                     .maybeSingle();
                
//                 // If user has a profile, they've signed in before - skip onboarding
//                 if (profile != null) {
//                   shouldCheckOnboarding = false;
//                   print('✅ [GUARD] Authenticated user with profile - skipping onboarding check');
//                 }
//               }
//             } catch (e) {
//               print('⚠️ [GUARD] Error checking profile: $e - will check onboarding');
//               // On error, fall back to onboarding check
//             }
//           }
          
//           // Only check onboarding if user doesn't have a profile (new user)
//           if (shouldCheckOnboarding) {
//             final prefs = await SharedPreferences.getInstance();
//             final hasCompletedOnboarding =
//                 prefs.getBool('onboarding_completed') ?? false;

//             if (!hasCompletedOnboarding) {
//               print(
//                 '🚫 [GUARD] Onboarding not completed, redirecting to onboarding',
//               );
//               return RouteGuardResult.redirect('/onboarding');
//             }
//           }
//           // Check survey completion
//           final hasCompletedSurvey = await AuthService.isSurveyCompleted();
//           final userRole = await AuthService.getUserRole();

//           if (!hasCompletedSurvey && userRole != null) {
//             print(
//               '🚫 [GUARD] Survey not completed, redirecting to profile setup',
//             );
//             return RouteGuardResult.redirect(
//               '/profile-setup',
//               arguments: {'userRole': userRole},
//             );
//           }

//           // Both onboarding and survey completed, redirect to dashboard
//           if (userRole == 'tutor') {
//             return RouteGuardResult.redirect('/tutor-nav');
//           } else if (userRole == 'parent') {
//             return RouteGuardResult.redirect('/parent-nav');
//           } else {
//             return RouteGuardResult.redirect('/student-nav');
//           }
//         } catch (e) {
//           print('⚠️ [GUARD] Error checking onboarding/survey: $e');
//           // On error, redirect to onboarding to be safe
//           return RouteGuardResult.redirect('/onboarding');
//         }
//       }

//       // Public routes that don't require authentication
//       final publicRoutes = [
//         '/onboarding',
//         ...authRoutes, // Auth routes are public only if not authenticated
//       ];

//       if (publicRoutes.contains(route) && !userIsAuthenticated) {
//         return RouteGuardResult.allowed();
//       }

//       // If not authenticated and trying to access protected route, redirect to auth
//       if (!userIsAuthenticated) {
//         print('🚫 [GUARD] Not authenticated, redirecting to auth');
//         return RouteGuardResult.redirect('/auth-method-selection');
//       }

//       // For authenticated users with Supabase session, check if they have a profile
//       // If they have a profile, skip onboarding check (they've signed in before)
//       // Only check onboarding for users without profiles (truly new users)
//       if (route != '/onboarding') {
//         bool shouldCheckOnboarding = true;
        
//         // If user has Supabase session, check if they have a profile
//         if (hasSupabaseSession) {
//           try {
//             final user = SupabaseService.currentUser;
//             if (user != null) {
//               final profile = await SupabaseService.client
//                   .from('profiles')
//                   .select('id')
//                   .eq('id', user.id)
//                   .maybeSingle();
              
//               // If user has a profile, they've signed in before - skip onboarding
//               if (profile != null) {
//                 shouldCheckOnboarding = false;
//                 print('✅ [GUARD] Authenticated user with profile - skipping onboarding check');
//               }
//             }
//           } catch (e) {
//             print('⚠️ [GUARD] Error checking profile: $e - will check onboarding');
//             // On error, fall back to onboarding check
//           }
//         }
        
//         // Only check onboarding if user doesn't have a profile (new user)
//         if (shouldCheckOnboarding) {
//           final prefs = await SharedPreferences.getInstance();
//           final hasCompletedOnboarding =
//               prefs.getBool('onboarding_completed') ?? false;

//           if (!hasCompletedOnboarding) {
//             print('🚫 [GUARD] Onboarding not completed, redirecting');
//             return RouteGuardResult.redirect('/onboarding');
//           }
//         }
//       }
//       }

//       // Check survey completion for dashboard routes
//       final dashboardRoutes = ['/tutor-nav', '/student-nav', '/parent-nav'];
//       if (dashboardRoutes.contains(route)) {
//         final hasCompletedSurvey = await AuthService.isSurveyCompleted();
//         final userRole = await AuthService.getUserRole();

//         if (!hasCompletedSurvey && userRole != null) {
//           print(
//             '🚫 [GUARD] Survey not completed, redirecting to profile setup',
//           );
//           return RouteGuardResult.redirect(
//             '/profile-setup',
//             arguments: {'userRole': userRole},
//           );
//         }
//       }

//       // Role-based route guards
//       if (route.startsWith('/tutor-nav') || route.contains('tutor')) {
//         final userRole = await AuthService.getUserRole();
//         if (userRole != 'tutor') {
//           print('🚫 [GUARD] Not a tutor, redirecting to student nav');
//           return RouteGuardResult.redirect('/student-nav');
//         }
//       }

//       // All checks passed
//       return RouteGuardResult.allowed();
//     } catch (e) {
//       print('❌ [GUARD] Error checking route guard: $e');
//       // On error, allow navigation but log it
//       return RouteGuardResult.allowed();
//     }
//   }

//   /// Check if user has completed onboarding
//   static Future<bool> hasCompletedOnboarding() async {
//     try {
//       final prefs = await SharedPreferences.getInstance();
//       return prefs.getBool('onboarding_completed') ?? false;
//     } catch (e) {
//       print('❌ [GUARD] Error checking onboarding: $e');
//       return false;
//     }
//   }

//   /// Check if user has completed survey
//   static Future<bool> hasCompletedSurvey() async {
//     try {
//       return await AuthService.isSurveyCompleted();
//     } catch (e) {
//       print('❌ [GUARD] Error checking survey: $e');
//       return false;
//     }
//   }

//   /// Check if user is authenticated
//   static Future<bool> isAuthenticated() async {
//     try {
//       return await AuthService.isLoggedIn() || SupabaseService.isAuthenticated;
//     } catch (e) {
//       print('❌ [GUARD] Error checking authentication: $e');
//       return false;
//     }
//   }

//   /// Get user role
//   static Future<String?> getUserRole() async {
//     try {
//       return await AuthService.getUserRole();
//     } catch (e) {
//       print('❌ [GUARD] Error getting user role: $e');
//       return null;
//     }
//   }
// }

// /// Result of route guard check
// class RouteGuardResult {
//   final bool allowed;
//   final String? redirectRoute;
//   final Map<String, dynamic>? arguments;

//   RouteGuardResult._({
//     required this.allowed,
//     this.redirectRoute,
//     this.arguments,
//   });

//   factory RouteGuardResult.allowed() {
//     return RouteGuardResult._(allowed: true);
//   }

//   factory RouteGuardResult.redirect(
//     String route, {
//     Map<String, dynamic>? arguments,
//   }) {
//     return RouteGuardResult._(
//       allowed: false,
//       redirectRoute: route,
//       arguments: arguments,
//     );
//   }
// }




import 'package:shared_preferences/shared_preferences.dart';
import 'package:prepskul/core/services/auth_service.dart';
import 'package:prepskul/core/services/supabase_service.dart';

/// Route Guards
///
/// Validates user permissions before navigation
class RouteGuard {
  /// Check if user can navigate to a specific route
  static Future<RouteGuardResult> canNavigateTo(String route) async {
    try {
      // Check authentication status first
      final isAuthenticated = await AuthService.isLoggedIn();
      final hasSupabaseSession = SupabaseService.isAuthenticated;
      final userIsAuthenticated = isAuthenticated || hasSupabaseSession;

      // Auth routes (login, signup, etc.)
      final authRoutes = [
        '/auth-method-selection',
        '/login',
        '/beautiful-login',
        '/beautiful-signup',
        '/email-signup',
        '/email-login',
        '/email-confirmation', // Allow email confirmation screen during verification
        '/forgot-password',
        '/reset-password',
        '/otp-verification',
      ];

      // If user is authenticated and tries to access auth routes, check onboarding/survey first
      if (userIsAuthenticated && authRoutes.contains(route)) {
        print(
          '🚫 [GUARD] Authenticated user tried to access auth route, checking onboarding/survey status',
        );
        try {
          // For authenticated users with Supabase session, check if they have a profile.
          // If they have a profile, skip onboarding (they've already signed in before).
          bool shouldCheckOnboarding = true;

          if (hasSupabaseSession) {
            try {
              final user = SupabaseService.currentUser;
              if (user != null) {
                final profile = await SupabaseService.client
                    .from('profiles')
                    .select('id')
                    .eq('id', user.id)
                    .maybeSingle();

                // If user has a profile, they've signed in before - skip onboarding
                if (profile != null) {
                  shouldCheckOnboarding = false;
                  print(
                    '✅ [GUARD] Authenticated user with profile - skipping onboarding check (auth routes)',
                  );
                }
              }
            } catch (e) {
              print(
                '⚠️ [GUARD] Error checking profile for auth route guard: $e - will check onboarding',
              );
              // On error, fall back to onboarding check
            }
          }

          // Only check onboarding if user doesn't have a profile (truly new user)
          if (shouldCheckOnboarding) {
            final prefs = await SharedPreferences.getInstance();
            final hasCompletedOnboarding =
                prefs.getBool('onboarding_completed') ?? false;

            if (!hasCompletedOnboarding) {
              print(
                '🚫 [GUARD] Onboarding not completed, redirecting to onboarding',
              );
              return RouteGuardResult.redirect('/onboarding');
            }
          }

          // Check survey completion
          final hasCompletedSurvey = await AuthService.isSurveyCompleted();
          final userRole = await AuthService.getUserRole();

          if (!hasCompletedSurvey && userRole != null) {
            print(
              '🚫 [GUARD] Survey not completed, redirecting to profile setup',
            );
            return RouteGuardResult.redirect(
              '/profile-setup',
              arguments: {'userRole': userRole},
            );
          }

          // Both onboarding and survey completed, redirect to dashboard
          if (userRole == 'tutor') {
            return RouteGuardResult.redirect('/tutor-nav');
          } else if (userRole == 'parent') {
            return RouteGuardResult.redirect('/parent-nav');
          } else {
            return RouteGuardResult.redirect('/student-nav');
          }
        } catch (e) {
          print('⚠️ [GUARD] Error checking onboarding/survey: $e');
          // On error, redirect to onboarding to be safe
          return RouteGuardResult.redirect('/onboarding');
        }
      }

      // Public routes that don't require authentication
      final publicRoutes = [
        '/onboarding',
        ...authRoutes, // Auth routes are public only if not authenticated
      ];

      if (publicRoutes.contains(route) && !userIsAuthenticated) {
        return RouteGuardResult.allowed();
      }

      // If not authenticated and trying to access protected route, redirect to auth
      if (!userIsAuthenticated) {
        print('🚫 [GUARD] Not authenticated, redirecting to auth');
        return RouteGuardResult.redirect('/auth-method-selection');
      }

      // For authenticated users with Supabase session on ANY non-onboarding route,
      // check if they have a profile. If they do, skip onboarding check.
      if (route != '/onboarding') {
        bool shouldCheckOnboarding = true;

        if (hasSupabaseSession) {
          try {
            final user = SupabaseService.currentUser;
            if (user != null) {
              final profile = await SupabaseService.client
                  .from('profiles')
                  .select('id')
                  .eq('id', user.id)
                  .maybeSingle();

              if (profile != null) {
                shouldCheckOnboarding = false;
                print(
                  '✅ [GUARD] Authenticated user with profile - skipping onboarding check (general)',
                );
              }
            }
          } catch (e) {
            print(
              '⚠️ [GUARD] Error checking profile (general guard): $e - will check onboarding',
            );
          }
        }

        if (shouldCheckOnboarding) {
          final prefs = await SharedPreferences.getInstance();
          final hasCompletedOnboarding =
              prefs.getBool('onboarding_completed') ?? false;

          if (!hasCompletedOnboarding) {
            print('🚫 [GUARD] Onboarding not completed, redirecting');
            return RouteGuardResult.redirect('/onboarding');
          }
        }
      }

      // Check survey completion for dashboard routes
      final dashboardRoutes = ['/tutor-nav', '/student-nav', '/parent-nav'];
      if (dashboardRoutes.contains(route)) {
        final hasCompletedSurvey = await AuthService.isSurveyCompleted();
        final userRole = await AuthService.getUserRole();

        if (!hasCompletedSurvey && userRole != null) {
          print(
            '🚫 [GUARD] Survey not completed, redirecting to profile setup',
          );
          return RouteGuardResult.redirect(
            '/profile-setup',
            arguments: {'userRole': userRole},
          );
        }
      }

      // Role-based route guards
      if (route.startsWith('/tutor-nav') || route.contains('tutor')) {
        final userRole = await AuthService.getUserRole();
        if (userRole != 'tutor') {
          print('🚫 [GUARD] Not a tutor, redirecting to student nav');
          return RouteGuardResult.redirect('/student-nav');
        }
      }

      // All checks passed
      return RouteGuardResult.allowed();
    } catch (e) {
      print('❌ [GUARD] Error checking route guard: $e');
      // On error, allow navigation but log it
      return RouteGuardResult.allowed();
    }
  }

  /// Check if user has completed onboarding
  static Future<bool> hasCompletedOnboarding() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool('onboarding_completed') ?? false;
    } catch (e) {
      print('❌ [GUARD] Error checking onboarding: $e');
      return false;
    }
  }

  /// Check if user has completed survey
  static Future<bool> hasCompletedSurvey() async {
    try {
      return await AuthService.isSurveyCompleted();
    } catch (e) {
      print('❌ [GUARD] Error checking survey: $e');
      return false;
    }
  }

  /// Check if user is authenticated
  static Future<bool> isAuthenticated() async {
    try {
      return await AuthService.isLoggedIn() || SupabaseService.isAuthenticated;
    } catch (e) {
      print('❌ [GUARD] Error checking authentication: $e');
      return false;
    }
  }

  /// Get user role
  static Future<String?> getUserRole() async {
    try {
      return await AuthService.getUserRole();
    } catch (e) {
      print('❌ [GUARD] Error getting user role: $e');
      return null;
    }
  }
}

/// Result of route guard check
class RouteGuardResult {
  final bool allowed;
  final String? redirectRoute;
  final Map<String, dynamic>? arguments;

  RouteGuardResult._({
    required this.allowed,
    this.redirectRoute,
    this.arguments,
  });

  factory RouteGuardResult.allowed() {
    return RouteGuardResult._(allowed: true);
  }

  factory RouteGuardResult.redirect(
    String route, {
    Map<String, dynamic>? arguments,
  }) {
    return RouteGuardResult._(
      allowed: false,
      redirectRoute: route,
      arguments: arguments,
    );
  }
}
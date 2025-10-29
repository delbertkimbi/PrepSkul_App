import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../features/tutor/screens/tutor_home_screen.dart';
import '../../features/dashboard/screens/student_home_screen.dart';
import '../../features/booking/screens/tutor_pending_requests_screen.dart';
import '../../features/tutor/screens/tutor_students_screen.dart';
import '../../features/discovery/screens/find_tutors_screen.dart';
import '../../features/booking/screens/my_requests_screen.dart';
import '../../features/profile/screens/profile_screen.dart';
import '../theme/app_theme.dart';

class MainNavigation extends StatefulWidget {
  final String userRole;
  final int? initialTab;

  const MainNavigation({
    Key? key,
    required this.userRole,
    this.initialTab,
  }) : super(key: key);

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  late int _selectedIndex;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialTab ?? 0;
  }

  // Tutor screens (4 items)
  final List<Widget> _tutorScreens = [
    const TutorHomeScreen(), // Home Dashboard
    const TutorPendingRequestsScreen(), // Booking Requests
    const TutorStudentsScreen(), // Active Sessions
    const ProfileScreen(userType: 'tutor'), // Profile & Settings
  ];

  // Student/Parent screens (4 items)
  final List<Widget> _studentScreens = [
    const StudentHomeScreen(), // Home Dashboard
    const FindTutorsScreen(), // Find Tutors
    const MyRequestsScreen(), // My Booking Requests
    const ProfileScreen(userType: 'student'), // Profile & Settings
  ];

  // Tutor navigation items (4 items)
  final List<BottomNavigationBarItem> _tutorItems = [
    const BottomNavigationBarItem(
      icon: Icon(Icons.home_outlined),
      activeIcon: Icon(Icons.home),
      label: 'Home',
    ),
    const BottomNavigationBarItem(
      icon: Icon(Icons.mail_outline), // inbox icon for requests
      activeIcon: Icon(Icons.mail),
      label: 'Requests',
    ),
    const BottomNavigationBarItem(
      icon: Icon(Icons.school_outlined), // sessions icon
      activeIcon: Icon(Icons.school),
      label: 'Sessions',
    ),
    const BottomNavigationBarItem(
      icon: Icon(Icons.person_outline),
      activeIcon: Icon(Icons.person),
      label: 'Profile',
    ),
  ];

  // Student/Parent navigation items (4 items)
  final List<BottomNavigationBarItem> _studentItems = [
    const BottomNavigationBarItem(
      icon: Icon(Icons.home_outlined),
      activeIcon: Icon(Icons.home),
      label: 'Home',
    ),
    const BottomNavigationBarItem(
      icon: Icon(Icons.search),
      activeIcon: Icon(Icons.search),
      label: 'Find Tutors',
    ),
    const BottomNavigationBarItem(
      icon: Icon(Icons.receipt_long_outlined), // requests icon
      activeIcon: Icon(Icons.receipt_long),
      label: 'Requests',
    ),
    const BottomNavigationBarItem(
      icon: Icon(Icons.person_outline),
      activeIcon: Icon(Icons.person),
      label: 'Profile',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final isTutor = widget.userRole == 'tutor';
    final screens = isTutor ? _tutorScreens : _studentScreens;
    final items = isTutor ? _tutorItems : _studentItems;

    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: screens),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppTheme.primaryColor,
        unselectedItemColor: AppTheme.textMedium,
        selectedLabelStyle: GoogleFonts.poppins(
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: GoogleFonts.poppins(
          fontSize: 12,
          fontWeight: FontWeight.w400,
        ),
        items: items,
      ),
    );
  }
}




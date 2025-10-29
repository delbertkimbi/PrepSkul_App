import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../features/tutor/screens/tutor_home_screen.dart';
import '../../features/tutor/screens/tutor_requests_screen.dart';
import '../../features/tutor/screens/tutor_students_screen.dart';
import '../../features/discovery/screens/find_tutors_screen.dart';
import '../../features/sessions/screens/my_tutors_screen.dart';
import '../../features/profile/screens/profile_screen.dart';
import '../theme/app_theme.dart';

class MainNavigation extends StatefulWidget {
  final String userRole;

  const MainNavigation({Key? key, required this.userRole}) : super(key: key);

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _selectedIndex = 0;

  // Tutor screens
  final List<Widget> _tutorScreens = [
    const TutorHomeScreen(),
    const TutorRequestsScreen(),
    const TutorStudentsScreen(),
    const ProfileScreen(userType: 'tutor'),
  ];

  // Student/Parent screens
  final List<Widget> _studentScreens = [
    const FindTutorsScreen(),
    const MyTutorsScreen(),
    const ProfileScreen(userType: 'student'),
  ];

  // Tutor navigation items
  final List<BottomNavigationBarItem> _tutorItems = [
    const BottomNavigationBarItem(
      icon: Icon(Icons.home_outlined),
      activeIcon: Icon(Icons.home),
      label: 'Home',
    ),
    const BottomNavigationBarItem(
      icon: Icon(Icons.assignment_outlined),
      activeIcon: Icon(Icons.assignment),
      label: 'Requests',
    ),
    const BottomNavigationBarItem(
      icon: Icon(Icons.people_outline),
      activeIcon: Icon(Icons.people),
      label: 'Students',
    ),
    const BottomNavigationBarItem(
      icon: Icon(Icons.person_outline),
      activeIcon: Icon(Icons.person),
      label: 'Profile',
    ),
  ];

  // Student/Parent navigation items
  final List<BottomNavigationBarItem> _studentItems = [
    const BottomNavigationBarItem(
      icon: Icon(Icons.search),
      activeIcon: Icon(Icons.search),
      label: 'Find Tutors',
    ),
    const BottomNavigationBarItem(
      icon: Icon(Icons.people_outline),
      activeIcon: Icon(Icons.people),
      label: 'My Tutors',
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




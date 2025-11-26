import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:prepskul/core/theme/app_theme.dart';
import 'package:prepskul/core/widgets/app_logo_header.dart';
import 'package:prepskul/features/discovery/screens/tutor_detail_screen.dart';
import 'package:prepskul/features/booking/screens/request_tutor_flow_screen.dart';
import 'package:prepskul/core/services/tutor_service.dart';
import 'package:prepskul/core/services/pricing_service.dart';
import 'package:prepskul/core/services/survey_repository.dart';
import 'package:prepskul/core/services/auth_service.dart';
import 'package:prepskul/data/app_data.dart';
import 'package:prepskul/core/widgets/shimmer_loading.dart';

class FindTutorsScreen extends StatefulWidget {
  const FindTutorsScreen({Key? key}) : super(key: key);

  @override
  State<FindTutorsScreen> createState() => _FindTutorsScreenState();
}

class _FindTutorsScreenState extends State<FindTutorsScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _tutors = [];
  List<Map<String, dynamic>> _filteredTutors = [];
  bool _isLoading = true;
  String? _selectedSubject;
  String? _selectedPriceRange;
  double _minRating = 0.0;

  // Smart subject list based on user preferences
  List<String> _subjects = [];
  List<String> _userPreferredSubjects = []; // User's subjects from survey
  bool _subjectsLoaded = false;

  // Default fallback subjects
  final List<String> _defaultSubjects = [
    'Mathematics',
    'Physics',
    'Chemistry',
    'Biology',
    'English',
    'French',
    'History',
    'Geography',
    'Accounting',
    'Business Studies',
    'Python',
    'JavaScript',
  ];

  // Monthly price ranges (in XAF per month)
  // Based on typical monthly pricing: 2-3 sessions/week × 4 weeks
  // Example: 3k/session × 2 sessions/week × 4 weeks = 24k/month
  final List<Map<String, dynamic>> _priceRanges = [
    {'label': 'Under 20k/mo', 'min': 0, 'max': 20000},
    {'label': '20k - 30k/mo', 'min': 20000, 'max': 30000},
    {'label': '30k - 40k/mo', 'min': 30000, 'max': 40000},
    {'label': '40k - 50k/mo', 'min': 40000, 'max': 50000},
    {'label': 'Above 50k/mo', 'min': 50000, 'max': 200000},
  ];

  @override
  void initState() {
    super.initState();
    _loadUserSubjects(); // Load user's preferred subjects first
    _loadTutors();
    
    // Listen to search text changes and filter tutors
    _searchController.addListener(_filterTutors);
  }

  /// Load user's subjects from survey and build smart subject list
  Future<void> _loadUserSubjects() async {
    try {
      final userProfile = await AuthService.getUserProfile();
      if (userProfile == null) {
        // No user profile - use default subjects
        setState(() {
          _subjects = _defaultSubjects;
          _subjectsLoaded = true;
        });
        return;
      }

      final userType = userProfile['user_type']?.toString();
      if (userType != 'student' && userType != 'parent') {
        // Not a student/parent - use default subjects
        setState(() {
          _subjects = _defaultSubjects;
          _subjectsLoaded = true;
        });
        return;
      }

      // Load survey data
      Map<String, dynamic>? surveyData;
      if (userType == 'student') {
        surveyData = await SurveyRepository.getStudentSurvey(userProfile['id']);
      } else if (userType == 'parent') {
        surveyData = await SurveyRepository.getParentSurvey(userProfile['id']);
      }

      if (surveyData != null && mounted) {
        // Get user's preferred subjects from survey
        final userSubjects = List<String>.from(surveyData['subjects'] ?? []);
        
        // Get education level, system, and stream for dynamic subject loading
        final system = surveyData['system']?.toString() ?? 'anglophone';
        final stream = surveyData['stream']?.toString();
        final eduLevel = surveyData['education_level']?.toString();

        // Load available subjects based on user's niche
        List<String> availableSubjects = [];
        if (eduLevel != null) {
          String levelKey = _mapEducationLevelToKey(eduLevel);
          availableSubjects = AppData.getSubjectsForLevel(
            levelKey,
            system,
            stream: stream,
          );
        }

        // Combine user's subjects with available subjects
        // Priority: User's subjects first, then other available subjects, then default
        final Set<String> allSubjectsSet = {};
        
        // Add user's preferred subjects first (these will be highlighted)
        for (var subject in userSubjects) {
          allSubjectsSet.add(subject);
        }
        
        // Add available subjects based on education level/stream
        for (var subject in availableSubjects) {
          allSubjectsSet.add(subject);
        }
        
        // If still empty or very few, add default subjects
        if (allSubjectsSet.length < 5) {
          for (var subject in _defaultSubjects) {
            allSubjectsSet.add(subject);
          }
        }

        // Convert to list and sort: user's subjects first, then alphabetically
        final List<String> sortedSubjects = [];
        
        // Add user's preferred subjects first
        for (var subject in userSubjects) {
          if (allSubjectsSet.contains(subject) && !sortedSubjects.contains(subject)) {
            sortedSubjects.add(subject);
          }
        }
        
        // Add other available subjects (alphabetically)
        final otherSubjects = allSubjectsSet
            .where((s) => !userSubjects.contains(s))
            .toList()
          ..sort();
        sortedSubjects.addAll(otherSubjects);

        if (mounted) {
          setState(() {
            _userPreferredSubjects = userSubjects;
            _subjects = sortedSubjects.isNotEmpty ? sortedSubjects : _defaultSubjects;
            _subjectsLoaded = true;
          });
        }
      } else {
        // No survey data - use default subjects
        if (mounted) {
          setState(() {
            _subjects = _defaultSubjects;
            _subjectsLoaded = true;
          });
        }
      }
    } catch (e) {
      print('⚠️ Error loading user subjects: $e');
      // Fallback to default subjects
      if (mounted) {
        setState(() {
          _subjects = _defaultSubjects;
          _subjectsLoaded = true;
        });
      }
    }
  }

  /// Map education level from survey to AppData key format
  String _mapEducationLevelToKey(String eduLevel) {
    final level = eduLevel.toLowerCase();
    if (level.contains('primary')) return 'primary';
    if (level.contains('secondary') || level.contains('high school')) {
      if (level.contains('lower') || level.contains('form 1') || level.contains('form 2') || 
          level.contains('form 3') || level.contains('grade 7') || level.contains('grade 8') || 
          level.contains('grade 9')) {
        return 'lower_secondary';
      }
      if (level.contains('upper') || level.contains('form 4') || level.contains('form 5') || 
          level.contains('form 6') || level.contains('grade 10') || level.contains('grade 11') || 
          level.contains('grade 12')) {
        return 'upper_secondary';
      }
      return 'upper_secondary'; // Default to upper secondary
    }
    if (level.contains('university') || level.contains('college') || level.contains('undergraduate')) {
      return 'university';
    }
    return 'upper_secondary'; // Default fallback
  }

  Future<void> _loadTutors() async {
    setState(() => _isLoading = true);

    try {
      print('🔍 FindTutorsScreen: Starting to load tutors...');
      // ✅ USING TutorService - Easy to swap demo/real data!
      // Change TutorService.USE_DEMO_DATA to false when ready for Supabase
      final tutors = await TutorService.fetchTutors();
      print('🔍 FindTutorsScreen: Received ${tutors.length} tutors from TutorService');

      if (mounted) {
        setState(() {
          _tutors = tutors;
          _filteredTutors = _tutors;
          _isLoading = false;
        });
        print('🔍 FindTutorsScreen: Updated state with ${_tutors.length} tutors, ${_filteredTutors.length} filtered');
        
        // Show debug message if no tutors found
        if (tutors.isEmpty) {
          print('⚠️ FindTutorsScreen: No tutors found! Check TutorService logs for details.');
      }
      }
    } catch (e, stackTrace) {
      print('❌ FindTutorsScreen: Error loading tutors: $e');
      print('❌ Stack trace: $stackTrace');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading tutors: $e'),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  void _filterTutors() {
    setState(() {
      _filteredTutors = _tutors.where((tutor) {
        final searchQuery = _searchController.text.toLowerCase();
        if (searchQuery.isNotEmpty) {
          final name = (tutor['full_name'] ?? '').toString().toLowerCase();
          final subjects =
              (tutor['subjects'] as List?)?.join(' ').toLowerCase() ?? '';
          if (!name.contains(searchQuery) && !subjects.contains(searchQuery)) {
            return false;
          }
        }

        if (_selectedSubject != null) {
          final subjects = tutor['subjects'] as List?;
          if (subjects == null || !subjects.contains(_selectedSubject)) {
            return false;
          }
        }

        if (_selectedPriceRange != null) {
          final priceRange = _priceRanges.firstWhere(
            (range) => range['label'] == _selectedPriceRange,
          );
          // Calculate monthly price for this tutor
          final pricing = PricingService.calculateFromTutorData(tutor);
          final monthlyPrice = (pricing['perMonth'] ?? 0.0) as double;
          if (monthlyPrice < priceRange['min'] || monthlyPrice > priceRange['max']) {
            return false;
          }
        }

        final rating = (tutor['rating'] ?? 0.0).toDouble();
        if (rating < _minRating) {
          return false;
        }

        return true;
      }).toList();
    });
  }

  void _clearFilters() {
    setState(() {
      _searchController.clear();
      _selectedSubject = null;
      _selectedPriceRange = null;
      _minRating = 0.0;
    });
    _filterTutors(); // Apply cleared filters
  }

  // Check if any filter is active
  bool get _isFilterActive =>
      _searchController.text.isNotEmpty ||
      _selectedSubject != null ||
      _selectedPriceRange != null ||
      _minRating > 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        automaticallyImplyLeading: false, // Remove back button
        elevation: 0,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        title: const AppLogoHeader(),
        actions: [
          IconButton(
            icon: Icon(Icons.tune, color: Colors.black),
            onPressed: _showFilterBottomSheet,
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Section
          Container(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: Column(
              children: [
                // Search Bar
                Container(
                  height: 52,
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(26),
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (value) {
                      setState(() {});
                      _filterTutors();
                    },
                    style: GoogleFonts.poppins(
                      color: Colors.black,
                      fontSize: 15,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Search by name or subject',
                      hintStyle: GoogleFonts.poppins(
                        color: Colors.grey[500],
                        fontSize: 15,
                      ),
                      prefixIcon: Icon(
                        Icons.search,
                        color: Colors.grey[600],
                        size: 22,
                      ),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: Icon(
                                Icons.close,
                                color: Colors.grey[600],
                                size: 20,
                              ),
                              onPressed: () {
                                _searchController.clear();
                                setState(() {});
                                _filterTutors();
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 16,
                      ),
                    ),
                  ),
                ),

                // Active Filters
                if (_selectedSubject != null ||
                    _selectedPriceRange != null ||
                    _minRating > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                if (_selectedSubject != null)
                                  _buildFilterChip(_selectedSubject!, () {
                                    setState(() => _selectedSubject = null);
                                    _filterTutors();
                                  }),
                                if (_selectedPriceRange != null) ...[
                                  const SizedBox(width: 8),
                                  _buildFilterChip(_selectedPriceRange!, () {
                                    setState(() => _selectedPriceRange = null);
                                    _filterTutors();
                                  }),
                                ],
                                if (_minRating > 0) ...[
                                  const SizedBox(width: 8),
                                  _buildFilterChip(
                                    '${_minRating.toInt()}+ ⭐',
                                    () {
                                      setState(() => _minRating = 0.0);
                                      _filterTutors();
                                    },
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: _clearFilters,
                          child: Text(
                            'Clear',
                            style: GoogleFonts.poppins(
                              color: AppTheme.primaryColor,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),

          // Results Count - only show when filtering or searching
          if (_isFilterActive)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  Text(
                    'Found ${_filteredTutors.length} tutor${_filteredTutors.length != 1 ? 's' : ''}',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[700],
                    ),
                  ),
                ],
              ),
            ),

          // Tutors List
          Expanded(
            child: _isLoading
                ? ShimmerLoading.tutorList(
                    count: 5,
                  ) // ✨ Beautiful shimmer loading
                : _filteredTutors.isEmpty
                ? _buildEmptyState()
                : RefreshIndicator(
                    onRefresh: _loadTutors,
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                      itemCount: _filteredTutors.length,
                      itemBuilder: (context, index) {
                        return _buildTutorCard(_filteredTutors[index]);
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildRatingIndicator(int rating, String label) {
    // Show as selected if this exact rating value is closest to current minRating
    // Round to nearest integer for selection
    final currentRating = _minRating.round();
    final isSelected = currentRating == rating;
    return GestureDetector(
      onTap: () {
        setState(() {
          _minRating = rating.toDouble();
        });
        _filterTutors(); // Apply filter when rating indicator is tapped
      },
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryColor : Colors.grey[200],
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected ? AppTheme.primaryColor : Colors.grey[300]!,
            width: isSelected ? 2.5 : 2,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
              color: isSelected ? Colors.white : Colors.grey[600],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, VoidCallback onDelete) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppTheme.primaryColor,
            ),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: onDelete,
            child: Icon(Icons.close, size: 16, color: AppTheme.primaryColor),
          ),
        ],
      ),
    );
  }

  Widget _buildTutorCard(Map<String, dynamic> tutor) {
    final name = tutor['full_name'] ?? 'Unknown';
    final rating = (tutor['rating'] ?? 0.0).toDouble();
    final totalReviews = tutor['total_reviews'] ?? 0;
    final bio = tutor['bio'] ?? '';
    final completedSessions = tutor['completed_sessions'] ?? 0;
    
    // Remove "Hello!" from bio if it starts with it (for cards)
    String displayBio = bio;
    if (displayBio.toLowerCase().startsWith('hello!')) {
      displayBio = displayBio.substring(6).trim();
      // Remove "I am" if it follows
      if (displayBio.toLowerCase().startsWith('i am')) {
        displayBio = displayBio.substring(4).trim();
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor, // Use theme surface color for neumorphic
        borderRadius: BorderRadius.circular(16),
        // Neumorphic shadows: light top-left, dark bottom-right
        boxShadow: [
          BoxShadow(
            color: Colors.white.withOpacity(0.7),
            blurRadius: 10,
            offset: const Offset(-4, -4),
            spreadRadius: 0,
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(4, 4),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => TutorDetailScreen(tutor: tutor),
              ),
            );
          },
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Avatar (Larger & clickable)
                    GestureDetector(
                      onTap: () => _showProfileImage(context, tutor),
                      child: Container(
                        width: 70,
                        height: 70,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppTheme.primaryColor.withOpacity(0.1), // Background for fallback
                          border: Border.all(
                            color: AppTheme.primaryColor.withOpacity(0.3),
                            width: 2.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.08),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: ClipOval(
                          child: _buildAvatarImage(
                            tutor['avatar_url'] ?? tutor['profile_photo_url'],
                            name,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  name,
                                  style: GoogleFonts.poppins(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.black,
                                  ),
                                ),
                              ),
                              if (tutor['is_verified'] == true)
                                Icon(
                                  Icons.verified,
                                  size: 18,
                                  color: AppTheme.primaryColor,
                                ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                Icons.star,
                                size: 16,
                                color: Colors.amber[700],
                              ),
                              const SizedBox(width: 4),
                              Text(
                                rating > 0 ? rating.toStringAsFixed(1) : 'N/A',
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black,
                                ),
                              ),
                              if (rating > 0 && totalReviews > 0)
                              Text(
                                ' ($totalReviews)',
                                style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Subjects
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children:
                      (tutor['subjects'] as List?)
                          ?.take(3)
                          .map(
                            (subject) => Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.grey[100],
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                subject.toString(),
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.grey[700],
                                ),
                              ),
                            ),
                          )
                          .toList() ??
                      [],
                ),
                const SizedBox(height: 12),
                // Bio (personal statement, with "Hello!" removed for cards)
                if (displayBio.isNotEmpty)
                Text(
                    displayBio,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: Colors.grey[600],
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 12),
                // Bottom Info Row - Focus on value, not pricing
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Sessions completed (bold as requested)
                    Row(
                      children: [
                        Icon(
                          Icons.school_outlined,
                          size: 16,
                          color: Colors.grey[600],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '$completedSessions',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: Colors.grey[700],
                            fontWeight: FontWeight.w700, // Bold as requested
                          ),
                        ),
                        Text(
                          ' lessons',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    // Subtle monthly estimate (not emphasized)
                    _buildSubtleMonthlyEstimate(tutor),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSubtleMonthlyEstimate(Map<String, dynamic> tutor) {
    // Calculate monthly pricing but display it subtly
    final pricing = PricingService.calculateFromTutorData(tutor);
    final monthlyAmount = pricing['perMonth'] as double;
    final hasDiscount = pricing['hasDiscount'] as bool? ?? false;

    // On cards, show only discount price if available
    if (hasDiscount) {
      return Text(
        'From ${PricingService.formatPrice(monthlyAmount)}/mo',
        style: GoogleFonts.poppins(
          fontSize: 12,
          color: AppTheme.primaryColor,
          fontWeight: FontWeight.w700,
        ),
      );
    }

    return Text(
      'From ${PricingService.formatPrice(monthlyAmount)}/mo',
      style: GoogleFonts.poppins(
        fontSize: 12,
        color: Colors.grey[700],
        fontWeight: FontWeight.w700, // Bold as requested
      ),
    );
  }

  Widget _buildEmptyState() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 60),

          // Clear filters button
          TextButton(
            onPressed: _clearFilters,
            child: Text(
              'Clear all filters/search',
              style: GoogleFonts.poppins(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppTheme.primaryColor,
              ),
            ),
          ),
          const SizedBox(height: 32),

          // Request Tutor CTA
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.primaryColor.withOpacity(0.1),
                  AppTheme.primaryColor.withOpacity(0.05),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppTheme.primaryColor.withOpacity(0.3),
                width: 1.5,
              ),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.person_search_rounded,
                  size: 48,
                  color: AppTheme.primaryColor,
                ),
                const SizedBox(height: 16),
                Text(
                  'Can\'t find the right tutor?',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textDark,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Let us know what you\'re looking for and we\'ll find the perfect match for you',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: AppTheme.textMedium,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => RequestTutorFlowScreen(
                            prefillData: {
                              'subjects': _selectedSubject != null
                                  ? [_selectedSubject]
                                  : [],
                              'teaching_mode': null,
                              'location': null,
                            },
                          ),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.add_circle_outline, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Request a Tutor',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showFilterBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.75,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Filters',
                    style: GoogleFonts.poppins(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: Colors.black,
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      _clearFilters();
                      Navigator.pop(context);
                    },
                    child: Text(
                      'Clear all',
                      style: GoogleFonts.poppins(
                        color: AppTheme.primaryColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Divider(color: Colors.grey[200]),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                  children: [
                    Text(
                      'Subject',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.black,
                      ),
                        ),
                        if (_userPreferredSubjects.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Text(
                            '(⭐ = Your preferences)',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w400,
                              color: Colors.grey[600],
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Show loading indicator if subjects haven't loaded yet
                    _subjectsLoaded
                        ? Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _subjects.map((subject) {
                        final isSelected = _selectedSubject == subject;
                              final isUserPreferred = _userPreferredSubjects.contains(subject);
                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedSubject = isSelected ? null : subject;
                            });
                                  _filterTutors(); // Apply filter when subject changes
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppTheme.primaryColor
                                        : isUserPreferred
                                            ? AppTheme.primaryColor.withOpacity(0.1)
                                  : Colors.grey[100],
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isSelected
                                    ? AppTheme.primaryColor
                                          : isUserPreferred
                                              ? AppTheme.primaryColor.withOpacity(0.5)
                                    : Colors.grey[300]!,
                                      width: isUserPreferred && !isSelected ? 2 : 1,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (isUserPreferred && !isSelected) ...[
                                        Icon(
                                          Icons.star,
                                          size: 14,
                                          color: AppTheme.primaryColor,
                                        ),
                                        const SizedBox(width: 4),
                                      ],
                                      Text(
                              subject,
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                          fontWeight: isUserPreferred
                                              ? FontWeight.w600
                                              : FontWeight.w500,
                                color: isSelected
                                    ? Colors.white
                                              : isUserPreferred
                                                  ? AppTheme.primaryColor
                                    : Colors.grey[700],
                              ),
                                      ),
                                    ],
                            ),
                          ),
                        );
                      }).toList(),
                          )
                        : const Center(
                            child: Padding(
                              padding: EdgeInsets.all(20.0),
                              child: CircularProgressIndicator(),
                            ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Monthly Price Range',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _priceRanges.map((range) {
                        final label = range['label'] as String;
                        final isSelected = _selectedPriceRange == label;
                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedPriceRange = isSelected ? null : label;
                            });
                            _filterTutors(); // Apply filter when price range changes
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppTheme.primaryColor
                                  : Colors.grey[100],
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isSelected
                                    ? AppTheme.primaryColor
                                    : Colors.grey[300]!,
                              ),
                            ),
                            child: Text(
                              label,
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: isSelected
                                    ? Colors.white
                                    : Colors.grey[700],
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Minimum Rating',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Column(
                      children: [
                    Row(
                      children: [
                        Expanded(
                          child: Slider(
                            value: _minRating,
                            min: 0,
                            max: 5,
                            divisions: 5,
                                label: _minRating == 0 ? 'Any' : '${_minRating.toStringAsFixed(1)} ⭐',
                            activeColor: AppTheme.primaryColor,
                                inactiveColor: Colors.grey[300],
                            onChanged: (value) {
                              setState(() {
                                _minRating = value;
                              });
                              _filterTutors(); // Apply filter when rating changes
                            },
                          ),
                        ),
                            const SizedBox(width: 12),
                        Container(
                          width: 60,
                          alignment: Alignment.center,
                          child: Text(
                                _minRating == 0 ? 'Any' : '${_minRating.toStringAsFixed(1)}+',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.primaryColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                        const SizedBox(height: 8),
                        // Rating value indicators
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _buildRatingIndicator(0, 'Any'),
                            _buildRatingIndicator(1, '1'),
                            _buildRatingIndicator(2, '2'),
                            _buildRatingIndicator(3, '3'),
                            _buildRatingIndicator(4, '4'),
                            _buildRatingIndicator(5, '5'),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: SafeArea(
                child: ElevatedButton(
                  onPressed: () {
                    _filterTutors();
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    'Show ${_filteredTutors.length} tutor${_filteredTutors.length != 1 ? 's' : ''}',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatarImage(String? avatarUrl, String name, {bool isLarge = false}) {
    // Check if avatarUrl is a network URL or asset path
    final isNetworkUrl = avatarUrl != null &&
        (avatarUrl.startsWith('http://') ||
            avatarUrl.startsWith('https://') ||
            avatarUrl.startsWith('//'));
    
    if (avatarUrl != null && avatarUrl.isNotEmpty) {
      if (isNetworkUrl) {
        // Use CachedNetworkImage for better performance and caching
        return CachedNetworkImage(
          imageUrl: avatarUrl,
          fit: BoxFit.cover,
          placeholder: (context, url) => _buildAvatarPlaceholder(name, isLarge: isLarge),
          errorWidget: (context, url, error) {
            // Log error for debugging
            print('⚠️ Failed to load avatar image: $url, error: $error');
            return _buildAvatarPlaceholder(name, isLarge: isLarge);
          },
          fadeInDuration: const Duration(milliseconds: 300),
          fadeOutDuration: const Duration(milliseconds: 100),
          // Add timeout to prevent infinite loading
          httpHeaders: const {'Cache-Control': 'max-age=3600'},
        );
      } else {
        // Use Image.asset for local asset paths
        return Image.asset(
          avatarUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
            return _buildAvatarPlaceholder(name, isLarge: isLarge);
          },
        );
      }
    }
    
    // Fallback to placeholder
    return _buildAvatarPlaceholder(name, isLarge: isLarge);
  }

  Widget _buildAvatarPlaceholder(String name, {bool isLarge = false}) {
    if (isLarge) {
                      return Container(
                        height: 300,
                        color: AppTheme.primaryColor.withOpacity(0.1),
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                name.isNotEmpty ? name[0].toUpperCase() : 'T',
                                style: GoogleFonts.poppins(
                                  fontSize: 80,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.primaryColor,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                name,
                                style: GoogleFonts.poppins(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.grey[700],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
    }
    
    return Container(
      color: AppTheme.primaryColor.withOpacity(0.1),
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : 'T',
          style: GoogleFonts.poppins(
            fontSize: 28,
            fontWeight: FontWeight.w600,
            color: AppTheme.primaryColor,
          ),
        ),
      ),
    );
  }

  void _showProfileImage(BuildContext context, Map<String, dynamic> tutor) {
    final name = tutor['full_name'] ?? 'Tutor';
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Stack(
          children: [
            // Profile Image
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.7,
                  maxWidth: MediaQuery.of(context).size.width * 0.9,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: _buildAvatarImage(
                    tutor['avatar_url'],
                    name,
                    isLarge: true,
                  ),
                ),
              ),
            ),
            // Close button
            Positioned(
              top: 10,
              right: 10,
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close, color: Colors.white, size: 24),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.removeListener(_filterTutors);
    _searchController.dispose();
    super.dispose();
  }
}

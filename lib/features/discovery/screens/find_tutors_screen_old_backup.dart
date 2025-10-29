import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:prepskul/core/theme/app_theme.dart';
import 'package:prepskul/core/services/auth_service.dart';
import 'package:prepskul/core/services/survey_repository.dart';
import 'package:url_launcher/url_launcher.dart';

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

  // Available subjects for filtering
  final List<String> _subjects = [
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

  // Price ranges
  final List<Map<String, dynamic>> _priceRanges = [
    {'label': 'Under 20k', 'min': 0, 'max': 20000},
    {'label': '20k - 30k', 'min': 20000, 'max': 30000},
    {'label': '30k - 40k', 'min': 30000, 'max': 40000},
    {'label': 'Above 40k', 'min': 40000, 'max': 1000000},
  ];

  @override
  void initState() {
    super.initState();
    _loadTutors();
  }

  Future<void> _loadTutors() async {
    setState(() => _isLoading = true);

    try {
      // Load from JSON file
      final String response = await rootBundle.loadString(
        'assets/data/sample_tutors.json',
      );
      final data = json.decode(response);

      setState(() {
        _tutors = List<Map<String, dynamic>>.from(data['tutors']);
        _filteredTutors = _tutors;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading tutors: $e')));
      }
    }
  }

  void _filterTutors() {
    setState(() {
      _filteredTutors = _tutors.where((tutor) {
        // Search filter
        final searchQuery = _searchController.text.toLowerCase();
        if (searchQuery.isNotEmpty) {
          final name = (tutor['full_name'] ?? '').toString().toLowerCase();
          final subjects =
              (tutor['subjects'] as List?)?.join(' ').toLowerCase() ?? '';
          if (!name.contains(searchQuery) && !subjects.contains(searchQuery)) {
            return false;
          }
        }

        // Subject filter
        if (_selectedSubject != null) {
          final subjects = tutor['subjects'] as List?;
          if (subjects == null || !subjects.contains(_selectedSubject)) {
            return false;
          }
        }

        // Price filter
        if (_selectedPriceRange != null) {
          final priceRange = _priceRanges.firstWhere(
            (range) => range['label'] == _selectedPriceRange,
          );
          final rate = (tutor['hourly_rate'] ?? 0).toDouble();
          if (rate < priceRange['min'] || rate > priceRange['max']) {
            return false;
          }
        }

        // Rating filter
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
      _filteredTutors = _tutors;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.softBackground,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        title: Text(
          'Find Tutors',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: AppTheme.textDark,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.tune, color: AppTheme.primaryColor),
            onPressed: _showFilterBottomSheet,
            tooltip: 'Filters',
          ),
        ],
      ),
      body: Column(
        children: [
          // Professional Search Section
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Search Bar
                Container(
                  decoration: BoxDecoration(
                    color: AppTheme.softBackground,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.softBorder, width: 1),
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (value) {
                      setState(() {});
                      _filterTutors();
                    },
                    style: GoogleFonts.poppins(
                      color: AppTheme.textDark,
                      fontSize: 15,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Search tutors by name or subject',
                      hintStyle: GoogleFonts.poppins(
                        color: AppTheme.textLight,
                        fontSize: 15,
                      ),
                      prefixIcon: Icon(
                        Icons.search,
                        color: AppTheme.textLight,
                        size: 22,
                      ),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: Icon(
                                Icons.close,
                                color: AppTheme.textLight,
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
                        horizontal: 16,
                        vertical: 14,
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
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              if (_selectedSubject != null)
                                _buildFilterChip(_selectedSubject!, () {
                                  setState(() => _selectedSubject = null);
                                  _filterTutors();
                                }),
                              if (_selectedPriceRange != null)
                                _buildFilterChip(_selectedPriceRange!, () {
                                  setState(() => _selectedPriceRange = null);
                                  _filterTutors();
                                }),
                              if (_minRating > 0)
                                _buildFilterChip(
                                  '${_minRating.toInt()}+ stars',
                                  () {
                                    setState(() => _minRating = 0.0);
                                    _filterTutors();
                                  },
                                ),
                            ],
                          ),
                        ),
                        TextButton(
                          onPressed: _clearFilters,
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                          ),
                          child: Text(
                            'Clear',
                            style: GoogleFonts.poppins(
                              color: AppTheme.primaryColor,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),

          // Results Summary
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${_filteredTutors.length} tutor${_filteredTutors.length != 1 ? 's' : ''} available',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textDark,
                  ),
                ),
                if (!_isLoading && _filteredTutors.isNotEmpty)
                  Text(
                    'Sorted by rating',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: AppTheme.textLight,
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // Tutors List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredTutors.isEmpty
                ? _buildEmptyState()
                : RefreshIndicator(
                    onRefresh: _loadTutors,
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
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

  Widget _buildFilterChip(String label, VoidCallback onDelete) {
    return Chip(
      label: Text(
        label,
        style: GoogleFonts.poppins(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: AppTheme.primaryColor,
        ),
      ),
      deleteIcon: const Icon(Icons.close, size: 16),
      onDeleted: onDelete,
      backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: AppTheme.primaryColor.withOpacity(0.3)),
      ),
    );
  }

  Widget _buildTutorCard(Map<String, dynamic> tutor) {
    final name = tutor['full_name'] ?? 'Unknown';
    final rate = (tutor['hourly_rate'] ?? 0).toDouble();
    final rating = (tutor['rating'] ?? 0.0).toDouble();
    final totalReviews = tutor['total_reviews'] ?? 0;
    final bio = tutor['bio'] ?? '';
    final experience = tutor['experience'] ?? '';
    final studentCount = tutor['student_count'] ?? 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppTheme.softBorder, width: 1),
      ),
      child: InkWell(
        onTap: () => _showTutorDetails(tutor),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Avatar
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppTheme.primaryColor.withOpacity(0.3),
                        width: 2,
                      ),
                    ),
                    child: ClipOval(
                      child: Image.asset(
                        tutor['avatar_url'] ??
                            'assets/images/prepskul_profile.png',
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            color: AppTheme.primaryColor.withOpacity(0.1),
                            child: Center(
                              child: Text(
                                name[0].toUpperCase(),
                                style: GoogleFonts.poppins(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.primaryColor,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Name and Rating
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
                                  fontSize: 17,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textDark,
                                ),
                              ),
                            ),
                            if (tutor['is_verified'] == true)
                              Icon(
                                Icons.verified,
                                size: 20,
                                color: Colors.blue[600],
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
                              rating.toStringAsFixed(1),
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textDark,
                              ),
                            ),
                            Text(
                              ' ($totalReviews)',
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                color: AppTheme.textLight,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Icon(
                              Icons.people_outline,
                              size: 16,
                              color: AppTheme.textLight,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '$studentCount students',
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                color: AppTheme.textLight,
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
                        ?.take(4)
                        .map(
                          (subject) => Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: AppTheme.primaryColor.withOpacity(0.2),
                              ),
                            ),
                            child: Text(
                              subject.toString(),
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: AppTheme.primaryColor,
                              ),
                            ),
                          ),
                        )
                        .toList() ??
                    [],
              ),
              const SizedBox(height: 12),
              // Bio
              Text(
                bio,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: AppTheme.textLight,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 12),
              // Bottom Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.work_outline,
                        size: 16,
                        color: AppTheme.textLight,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        experience,
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: AppTheme.textLight,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${(rate / 1000).toStringAsFixed(0)}k',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                        Text(
                          ' XAF/hr',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showTutorDetails(Map<String, dynamic> tutor) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => TutorDetailsSheet(tutor: tutor),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 80,
              color: AppTheme.textLight.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'No tutors found',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppTheme.textDark,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Try adjusting your filters or request a tutor',
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: AppTheme.textLight,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _clearFilters,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'Clear Filters',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _requestTutorViaWhatsApp,
              icon: const Icon(Icons.chat, size: 20),
              label: Text(
                'Request Tutor via WhatsApp',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF25D366),
                side: const BorderSide(color: Color(0xFF25D366), width: 2),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _requestTutorViaWhatsApp() async {
    try {
      final userId = await AuthService.getUserId();
      final userName = await AuthService.getUserName();
      final userRole = await AuthService.getUserRole();

      if (userId == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please log in to request a tutor')),
          );
        }
        return;
      }

      Map<String, dynamic>? surveyData;
      if (userRole == 'student') {
        surveyData = await SurveyRepository.getStudentSurvey(userId);
      } else if (userRole == 'parent') {
        surveyData = await SurveyRepository.getParentSurvey(userId);
      }

      final message = _buildWhatsAppMessage(
        userName: userName ?? 'User',
        userRole: userRole ?? 'learner',
        surveyData: surveyData,
      );

      const whatsappNumber = '237653301997';
      final encodedMessage = Uri.encodeComponent(message);
      final whatsappUrl = Uri.parse(
        'https://wa.me/$whatsappNumber?text=$encodedMessage',
      );

      if (await canLaunchUrl(whatsappUrl)) {
        await launchUrl(whatsappUrl, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Could not open WhatsApp. Please make sure it\'s installed.',
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  String _buildWhatsAppMessage({
    required String userName,
    required String userRole,
    Map<String, dynamic>? surveyData,
  }) {
    final buffer = StringBuffer();

    buffer.writeln('🎓 *PrepSkul Tutor Request*\n');
    buffer.writeln('Hello! I\'m looking for a tutor.\n');

    buffer.writeln('👤 *Personal Information:*');
    buffer.writeln('• Name: $userName');
    buffer.writeln('• Role: ${userRole == 'student' ? 'Student' : 'Parent'}');

    if (surveyData != null) {
      if (surveyData['city'] != null || surveyData['quarter'] != null) {
        buffer.writeln('\n📍 *Location:*');
        if (surveyData['city'] != null) {
          buffer.writeln('• City: ${surveyData['city']}');
        }
        if (surveyData['quarter'] != null) {
          buffer.writeln('• Quarter: ${surveyData['quarter']}');
        }
      }

      buffer.writeln('\n📚 *Learning Details:*');
      if (surveyData['learning_path'] != null) {
        buffer.writeln('• Learning Path: ${surveyData['learning_path']}');
      }
      if (surveyData['education_level'] != null) {
        buffer.writeln('• Education Level: ${surveyData['education_level']}');
      }
      if (surveyData['class'] != null) {
        buffer.writeln('• Class: ${surveyData['class']}');
      }
      if (surveyData['stream'] != null) {
        buffer.writeln('• Stream: ${surveyData['stream']}');
      }

      if (surveyData['subjects'] != null &&
          (surveyData['subjects'] as List).isNotEmpty) {
        final subjects = (surveyData['subjects'] as List).join(', ');
        buffer.writeln('• Subjects: $subjects');
      }
      if (surveyData['skills'] != null &&
          (surveyData['skills'] as List).isNotEmpty) {
        final skills = (surveyData['skills'] as List).join(', ');
        buffer.writeln('• Skills: $skills');
      }

      if (surveyData['exam_type'] != null) {
        buffer.writeln('\n📝 *Exam Preparation:*');
        buffer.writeln('• Exam Type: ${surveyData['exam_type']}');
        if (surveyData['specific_exam'] != null) {
          buffer.writeln('• Specific Exam: ${surveyData['specific_exam']}');
        }
        if (surveyData['exam_subjects'] != null &&
            (surveyData['exam_subjects'] as List).isNotEmpty) {
          final examSubjects = (surveyData['exam_subjects'] as List).join(', ');
          buffer.writeln('• Exam Subjects: $examSubjects');
        }
      }

      if (surveyData['min_budget'] != null ||
          surveyData['max_budget'] != null) {
        buffer.writeln('\n💰 *Budget:*');
        buffer.writeln(
          '• Range: ${surveyData['min_budget'] ?? 0} - ${surveyData['max_budget'] ?? 0} XAF per session',
        );
      }

      buffer.writeln('\n⚙️ *Preferences:*');
      if (surveyData['tutor_gender_preference'] != null) {
        buffer.writeln(
          '• Tutor Gender: ${surveyData['tutor_gender_preference']}',
        );
      }
      if (surveyData['tutor_qualification'] != null) {
        buffer.writeln('• Qualification: ${surveyData['tutor_qualification']}');
      }
      if (surveyData['preferred_location'] != null) {
        buffer.writeln('• Location: ${surveyData['preferred_location']}');
      }
      if (surveyData['preferred_schedule'] != null) {
        buffer.writeln('• Schedule: ${surveyData['preferred_schedule']}');
      }

      if (surveyData['learning_goals'] != null &&
          (surveyData['learning_goals'] as List).isNotEmpty) {
        final goals = (surveyData['learning_goals'] as List).join(', ');
        buffer.writeln('\n🎯 *Learning Goals:*');
        buffer.writeln('• $goals');
      }

      if (surveyData['challenges'] != null &&
          (surveyData['challenges'] as List).isNotEmpty) {
        final challenges = (surveyData['challenges'] as List).join(', ');
        buffer.writeln('\n⚠️ *Challenges:*');
        buffer.writeln('• $challenges');
      }
    }

    if (_selectedSubject != null ||
        _selectedPriceRange != null ||
        _searchController.text.isNotEmpty) {
      buffer.writeln('\n🔍 *Current Search Filters:*');
      if (_searchController.text.isNotEmpty) {
        buffer.writeln('• Search: ${_searchController.text}');
      }
      if (_selectedSubject != null) {
        buffer.writeln('• Subject: $_selectedSubject');
      }
      if (_selectedPriceRange != null) {
        buffer.writeln('• Price Range: $_selectedPriceRange');
      }
      if (_minRating > 0) {
        buffer.writeln('• Minimum Rating: ${_minRating.toInt()}+ stars');
      }
    }

    buffer.writeln('\n---');
    buffer.writeln('Please help me find a suitable tutor. Thank you! 🙏');

    return buffer.toString();
  }

  void _showFilterBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
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
                    'Filter Tutors',
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textDark,
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      _clearFilters();
                      Navigator.pop(context);
                    },
                    child: Text(
                      'Clear All',
                      style: GoogleFonts.poppins(
                        color: AppTheme.primaryColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Subject',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textDark,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _subjects.map((subject) {
                        final isSelected = _selectedSubject == subject;
                        return FilterChip(
                          label: Text(subject),
                          selected: isSelected,
                          onSelected: (selected) {
                            setState(() {
                              _selectedSubject = selected ? subject : null;
                            });
                          },
                          selectedColor: AppTheme.primaryColor.withOpacity(0.2),
                          checkmarkColor: AppTheme.primaryColor,
                          labelStyle: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: isSelected
                                ? AppTheme.primaryColor
                                : AppTheme.textDark,
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Price Range',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textDark,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _priceRanges.map((range) {
                        final label = range['label'] as String;
                        final isSelected = _selectedPriceRange == label;
                        return FilterChip(
                          label: Text(label),
                          selected: isSelected,
                          onSelected: (selected) {
                            setState(() {
                              _selectedPriceRange = selected ? label : null;
                            });
                          },
                          selectedColor: AppTheme.primaryColor.withOpacity(0.2),
                          checkmarkColor: AppTheme.primaryColor,
                          labelStyle: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: isSelected
                                ? AppTheme.primaryColor
                                : AppTheme.textDark,
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
                        color: AppTheme.textDark,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Slider(
                            value: _minRating,
                            min: 0,
                            max: 5,
                            divisions: 5,
                            label: _minRating == 0
                                ? 'Any'
                                : '${_minRating.toInt()}+ stars',
                            activeColor: AppTheme.primaryColor,
                            onChanged: (value) {
                              setState(() => _minRating = value);
                            },
                          ),
                        ),
                        Text(
                          _minRating == 0 ? 'Any' : '${_minRating.toInt()}+',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.primaryColor,
                          ),
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
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () {
                    _filterTutors();
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    'Apply Filters',
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

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}

// Tutor Details Bottom Sheet
class TutorDetailsSheet extends StatelessWidget {
  final Map<String, dynamic> tutor;

  const TutorDetailsSheet({Key? key, required this.tutor}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final name = tutor['full_name'] ?? 'Unknown';
    final bio = tutor['bio'] ?? '';
    final education = tutor['education'] ?? '';
    final experience = tutor['experience'] ?? '';
    final rate = (tutor['hourly_rate'] ?? 0).toDouble();
    final rating = (tutor['rating'] ?? 0.0).toDouble();
    final totalReviews = tutor['total_reviews'] ?? 0;
    final studentCount = tutor['student_count'] ?? 0;
    final completedSessions = tutor['completed_sessions'] ?? 0;
    final teachingStyle = tutor['teaching_style'] ?? '';
    final successStories = tutor['success_stories'] ?? '';
    final city = tutor['city'] ?? '';
    final quarter = tutor['quarter'] ?? '';
    final videoIntro = tutor['video_intro'] ?? '';

    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
          ),
          child: Column(
            children: [
              // Handle
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Row(
                        children: [
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppTheme.primaryColor.withOpacity(0.3),
                                width: 3,
                              ),
                            ),
                            child: ClipOval(
                              child: Image.asset(
                                tutor['avatar_url'] ??
                                    'assets/images/prepskul_profile.png',
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    color: AppTheme.primaryColor.withOpacity(
                                      0.1,
                                    ),
                                    child: Center(
                                      child: Text(
                                        name[0].toUpperCase(),
                                        style: GoogleFonts.poppins(
                                          fontSize: 32,
                                          fontWeight: FontWeight.w600,
                                          color: AppTheme.primaryColor,
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
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
                                          fontSize: 22,
                                          fontWeight: FontWeight.bold,
                                          color: AppTheme.textDark,
                                        ),
                                      ),
                                    ),
                                    if (tutor['is_verified'] == true)
                                      Icon(
                                        Icons.verified,
                                        size: 24,
                                        color: Colors.blue[600],
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.star,
                                      size: 18,
                                      color: Colors.amber[700],
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      rating.toStringAsFixed(1),
                                      style: GoogleFonts.poppins(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: AppTheme.textDark,
                                      ),
                                    ),
                                    Text(
                                      ' ($totalReviews reviews)',
                                      style: GoogleFonts.poppins(
                                        fontSize: 14,
                                        color: AppTheme.textLight,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '$city, $quarter',
                                  style: GoogleFonts.poppins(
                                    fontSize: 13,
                                    color: AppTheme.textLight,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),

                      // Stats Row
                      Row(
                        children: [
                          Expanded(
                            child: _buildStatCard(
                              icon: Icons.people_outline,
                              label: 'Students',
                              value: studentCount.toString(),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildStatCard(
                              icon: Icons.class_outlined,
                              label: 'Sessions',
                              value: completedSessions.toString(),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildStatCard(
                              icon: Icons.work_outline,
                              label: 'Experience',
                              value: experience,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 24),

                      // Price Card
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppTheme.primaryColor.withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Hourly Rate',
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    color: AppTheme.textMedium,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${(rate / 1000).toStringAsFixed(0)}k XAF',
                                  style: GoogleFonts.poppins(
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.primaryColor,
                                  ),
                                ),
                              ],
                            ),
                            ElevatedButton(
                              onPressed: () {
                                // TODO: Book session
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Booking coming soon!'),
                                  ),
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primaryColor,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              child: Text(
                                'Book Now',
                                style: GoogleFonts.poppins(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // About
                      _buildSection(
                        title: 'About',
                        icon: Icons.person_outline,
                        child: Text(
                          bio,
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: AppTheme.textMedium,
                            height: 1.6,
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Education
                      _buildSection(
                        title: 'Education',
                        icon: Icons.school_outlined,
                        child: Text(
                          education,
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: AppTheme.textMedium,
                            height: 1.6,
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Subjects
                      _buildSection(
                        title: 'Subjects',
                        icon: Icons.library_books_outlined,
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children:
                              (tutor['subjects'] as List?)
                                  ?.map(
                                    (subject) => Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 8,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppTheme.primaryColor
                                            .withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: AppTheme.primaryColor
                                              .withOpacity(0.3),
                                        ),
                                      ),
                                      child: Text(
                                        subject.toString(),
                                        style: GoogleFonts.poppins(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                          color: AppTheme.primaryColor,
                                        ),
                                      ),
                                    ),
                                  )
                                  .toList() ??
                              [],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Teaching Style
                      _buildSection(
                        title: 'Teaching Style',
                        icon: Icons.lightbulb_outline,
                        child: Text(
                          teachingStyle,
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: AppTheme.textMedium,
                            height: 1.6,
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Success Stories
                      _buildSection(
                        title: 'Success Stories',
                        icon: Icons.emoji_events_outlined,
                        child: Text(
                          successStories,
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: AppTheme.textMedium,
                            height: 1.6,
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Certifications
                      if (tutor['certifications'] != null)
                        _buildSection(
                          title: 'Certifications',
                          icon: Icons.workspace_premium_outlined,
                          child: Column(
                            children: (tutor['certifications'] as List)
                                .map(
                                  (cert) => Padding(
                                    padding: const EdgeInsets.only(bottom: 8.0),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.check_circle,
                                          size: 18,
                                          color: Colors.green[600],
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            cert.toString(),
                                            style: GoogleFonts.poppins(
                                              fontSize: 14,
                                              color: AppTheme.textMedium,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                        ),

                      const SizedBox(height: 20),

                      // Video Introduction
                      if (videoIntro.isNotEmpty)
                        _buildSection(
                          title: 'Video Introduction',
                          icon: Icons.play_circle_outline,
                          child: InkWell(
                            onTap: () async {
                              final url = Uri.parse(videoIntro);
                              if (await canLaunchUrl(url)) {
                                await launchUrl(
                                  url,
                                  mode: LaunchMode.externalApplication,
                                );
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.red.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.red.withOpacity(0.3),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.play_circle_filled,
                                    size: 40,
                                    color: Colors.red[600],
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Watch Introduction Video',
                                          style: GoogleFonts.poppins(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: AppTheme.textDark,
                                          ),
                                        ),
                                        Text(
                                          'YouTube',
                                          style: GoogleFonts.poppins(
                                            fontSize: 12,
                                            color: AppTheme.textLight,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Icon(
                                    Icons.arrow_forward_ios,
                                    size: 16,
                                    color: AppTheme.textLight,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

                      const SizedBox(height: 80),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.softBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.softBorder),
      ),
      child: Column(
        children: [
          Icon(icon, color: AppTheme.primaryColor, size: 24),
          const SizedBox(height: 6),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppTheme.textDark,
            ),
          ),
          Text(
            label,
            style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.textLight),
          ),
        ],
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: AppTheme.primaryColor, size: 20),
            const SizedBox(width: 8),
            Text(
              title,
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppTheme.textDark,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        child,
      ],
    );
  }
}

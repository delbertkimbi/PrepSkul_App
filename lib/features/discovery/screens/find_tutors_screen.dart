import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:prepskul/core/theme/app_theme.dart';
import 'package:prepskul/features/discovery/screens/tutor_detail_screen.dart';
import 'package:prepskul/core/services/tutor_service.dart';
import 'package:prepskul/core/services/pricing_service.dart';
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

  final List<Map<String, dynamic>> _priceRanges = [
    {'label': 'Under 3k', 'min': 0, 'max': 3000},
    {'label': '3k - 5k', 'min': 3000, 'max': 5000},
    {'label': '5k - 8k', 'min': 5000, 'max': 8000},
    {'label': 'Above 8k', 'min': 8000, 'max': 50000},
  ];

  @override
  void initState() {
    super.initState();
    _loadTutors();
  }

  Future<void> _loadTutors() async {
    setState(() => _isLoading = true);

    try {
      // ✅ USING TutorService - Easy to swap demo/real data!
      // Change TutorService.USE_DEMO_DATA to false when ready for Supabase
      final tutors = await TutorService.fetchTutors();

      if (mounted) {
        setState(() {
          _tutors = tutors;
          _filteredTutors = _tutors;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading tutors: $e')));
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
          final rate = (tutor['hourly_rate'] ?? 0).toDouble();
          if (rate < priceRange['min'] || rate > priceRange['max']) {
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
      _filteredTutors = _tutors;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        title: Text(
          'Find Tutors',
          style: GoogleFonts.poppins(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: Colors.black,
          ),
        ),
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

          // Results Count
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                Text(
                  '${_filteredTutors.length} tutor${_filteredTutors.length != 1 ? 's' : ''}',
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

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
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
                                      fontSize: 28,
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
                                rating.toStringAsFixed(1),
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black,
                                ),
                              ),
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
                // Bio
                Text(
                  bio,
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 80, color: Colors.grey[300]),
            const SizedBox(height: 20),
            Text(
              'No tutors found',
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Try adjusting your search or filters',
              style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            TextButton(
              onPressed: _clearFilters,
              child: Text(
                'Clear all filters',
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primaryColor,
                ),
              ),
            ),
          ],
        ),
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
                    Text(
                      'Subject',
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
                      children: _subjects.map((subject) {
                        final isSelected = _selectedSubject == subject;
                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedSubject = isSelected ? null : subject;
                            });
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
                              subject,
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
                      'Price Range',
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
                    Row(
                      children: [
                        Expanded(
                          child: Slider(
                            value: _minRating,
                            min: 0,
                            max: 5,
                            divisions: 5,
                            activeColor: AppTheme.primaryColor,
                            onChanged: (value) {
                              setState(() => _minRating = value);
                            },
                          ),
                        ),
                        Container(
                          width: 60,
                          alignment: Alignment.center,
                          child: Text(
                            _minRating == 0 ? 'Any' : '${_minRating.toInt()}+',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.primaryColor,
                            ),
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
                  child: Image.asset(
                    tutor['avatar_url'] ?? 'assets/images/prepskul_profile.png',
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        height: 300,
                        color: AppTheme.primaryColor.withOpacity(0.1),
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                name[0].toUpperCase(),
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
                    },
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
    _searchController.dispose();
    super.dispose();
  }
}

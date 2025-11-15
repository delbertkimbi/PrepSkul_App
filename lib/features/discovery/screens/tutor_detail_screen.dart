import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:prepskul/core/theme/app_theme.dart';
import 'package:prepskul/core/services/pricing_service.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:prepskul/features/booking/screens/book_tutor_flow_screen.dart';
import 'package:prepskul/features/booking/screens/book_trial_session_screen.dart';
// Conditional import for web-specific video helper
import 'web_video_helper_stub.dart'
    if (dart.library.html) 'web_video_helper.dart'
    as web_video;

class TutorDetailScreen extends StatefulWidget {
  final Map<String, dynamic> tutor;

  const TutorDetailScreen({Key? key, required this.tutor}) : super(key: key);

  @override
  State<TutorDetailScreen> createState() => _TutorDetailScreenState();
}

class _TutorDetailScreenState extends State<TutorDetailScreen> {
  YoutubePlayerController? _youtubeController; // Nullable for web
  bool _isVideoInitialized = false;
  bool _isVideoLoading = false;
  String? _videoId; // For web iframe embed
  String? _videoUrl; // Store original URL for thumbnail

  @override
  void initState() {
    super.initState();
    _extractVideoId(); // Only extract ID, don't initialize player yet
  }

  void _extractVideoId() {
    try {
      // Use video_url (primary), fallback to video_intro or video_link
      _videoUrl =
          widget.tutor['video_url'] ??
          widget.tutor['video_intro'] ??
          widget.tutor['video_link'] ??
          '';
      if (_videoUrl!.isNotEmpty) {
        final videoId = YoutubePlayer.convertUrlToId(_videoUrl!);
        if (videoId != null && videoId.isNotEmpty) {
          setState(() {
            _videoId = videoId;
          });
        } else {
          print('⚠️ Could not extract video ID from URL: $_videoUrl');
        }
      } else {
        print('ℹ️ No video URL provided for tutor');
      }
    } catch (e) {
      print('❌ Error extracting video ID: $e');
    }
  }

  void _initializeVideo() {
    if (_isVideoInitialized || _isVideoLoading || _videoId == null) return;

    setState(() {
      _isVideoLoading = true;
    });

    try {
      // Check if running on web - use iframe embed instead
      if (kIsWeb) {
        // For web, we'll use an iframe embed (handled in build method)
        setState(() {
          _isVideoInitialized = true;
          _isVideoLoading = false;
        });
      } else {
        // For mobile, use YoutubePlayerController
        _youtubeController = YoutubePlayerController(
          initialVideoId: _videoId!,
          flags: const YoutubePlayerFlags(
            autoPlay: false,
            mute: false,
            enableCaption: true,
            controlsVisibleAtStart: true,
            hideControls: false,
          ),
        );
        setState(() {
          _isVideoInitialized = true;
          _isVideoLoading = false;
        });
      }
    } catch (e) {
      print('❌ Error initializing video: $e');
      setState(() {
        _isVideoLoading = false;
      });
    }
  }

  /// Get YouTube thumbnail URL
  String? _getThumbnailUrl() {
    if (_videoId == null) return null;
    // Use maxresdefault for best quality, fallback to hqdefault
    return 'https://img.youtube.com/vi/$_videoId/maxresdefault.jpg';
  }

  @override
  void dispose() {
    _youtubeController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.tutor['full_name'] ?? 'Unknown';
    // Use personal_statement (with "Hello!") for detail page "About" section
    // Fallback to bio (dynamic) if personal_statement not available
    final bio = widget.tutor['personal_statement'] ?? widget.tutor['bio'] ?? '';
    final education =
        widget.tutor['education'] ?? ''; // Formatted education string
    final experience = widget.tutor['experience'] ?? '';
    final rating = (widget.tutor['rating'] ?? 0.0).toDouble();
    final totalReviews = widget.tutor['total_reviews'] ?? 0;
    final totalStudents = widget.tutor['total_students'] ?? 0;
    final totalHoursTaught = widget.tutor['total_hours_taught'] ?? 0;
    final completedSessions =
        widget.tutor['completed_sessions'] ??
        widget.tutor['total_reviews'] ??
        0;
    final teachingStyle = widget.tutor['teaching_style'] ?? '';
    final city = widget.tutor['city'] ?? '';
    final quarter = widget.tutor['quarter'] ?? '';

    // Build student success text from metrics
    final successMetrics = <String>[];
    if (totalStudents > 0) {
      successMetrics.add(
        '$totalStudents student${totalStudents > 1 ? 's' : ''}',
      );
    }
    if (totalHoursTaught > 0) {
      successMetrics.add(
        '$totalHoursTaught hour${totalHoursTaught > 1 ? 's' : ''} taught',
      );
    }
    if (completedSessions > 0) {
      successMetrics.add(
        '$completedSessions session${completedSessions > 1 ? 's' : ''} completed',
      );
    }
    final studentSuccessText = successMetrics.isNotEmpty
        ? successMetrics.join(' • ')
        : 'No sessions completed yet';

    return Scaffold(
      backgroundColor: Colors.white,
      body: CustomScrollView(
        slivers: [
          // Modern App Bar with Video
          SliverAppBar(
            expandedHeight: 280,
            pinned: true,
            elevation: 0,
            backgroundColor: Colors.white,
            leading: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: const Icon(Icons.arrow_back, color: Colors.black),
              ),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              IconButton(
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  child: const Icon(Icons.favorite_border, color: Colors.black),
                ),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Added to favorites!')),
                  );
                },
              ),
              const SizedBox(width: 8),
            ],
            flexibleSpace: FlexibleSpaceBar(background: _buildVideoSection()),
          ),

          // Content
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Section
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          // Avatar (Larger & clickable)
                          GestureDetector(
                            onTap: () => _showProfileImage(context),
                            child: Container(
                              width: 90,
                              height: 90,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: AppTheme.primaryColor.withOpacity(0.3),
                                  width: 3,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.1),
                                    blurRadius: 10,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: ClipOval(
                                child: _buildAvatarImage(
                                  widget.tutor['avatar_url'],
                                  widget.tutor['full_name'] ?? 'Tutor',
                                ),
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
                                          fontSize: 24,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.black,
                                          height: 1.2,
                                        ),
                                      ),
                                    ),
                                    if (widget.tutor['is_verified'] == true)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppTheme.primaryColor
                                              .withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.verified,
                                              size: 14,
                                              color: AppTheme.primaryColor,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              'Verified',
                                              style: GoogleFonts.poppins(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                                color: AppTheme.primaryColor,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 6),
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
                                        fontWeight: FontWeight.w700,
                                        color: Colors.black,
                                      ),
                                    ),
                                    Text(
                                      ' ($totalReviews)',
                                      style: GoogleFonts.poppins(
                                        fontSize: 14,
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
                      const SizedBox(height: 16),

                      // Location
                      Row(
                        children: [
                          Icon(
                            Icons.location_on_outlined,
                            size: 18,
                            color: Colors.grey[600],
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '$city, $quarter',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Stats Bar
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    border: Border(
                      top: BorderSide(color: Colors.grey[200]!),
                      bottom: BorderSide(color: Colors.grey[200]!),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildQuickStat(
                        Icons.people_outline,
                        '$totalStudents',
                        'Students',
                      ),
                      Container(width: 1, height: 30, color: Colors.grey[300]),
                      _buildQuickStat(
                        Icons.class_outlined,
                        '$completedSessions',
                        'Lessons',
                      ),
                      Container(width: 1, height: 30, color: Colors.grey[300]),
                      _buildQuickStat(
                        Icons.work_outline,
                        experience,
                        'Experience',
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // About Section
                _buildSection('About', bio, Icons.person_outline),

                const SizedBox(height: 20),

                // Subjects
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Subjects',
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children:
                            (widget.tutor['subjects'] as List?)
                                ?.map(
                                  (subject) => Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppTheme.primaryColor.withOpacity(
                                        0.08,
                                      ),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: AppTheme.primaryColor
                                            .withOpacity(0.2),
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
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Education
                _buildSection('Education', education, Icons.school_outlined),

                const SizedBox(height: 20),

                // Teaching Style
                _buildSection(
                  'Teaching Style',
                  teachingStyle,
                  Icons.psychology_outlined,
                ),

                const SizedBox(height: 20),

                // Student Success
                _buildSection(
                  'Student Success',
                  studentSuccessText,
                  Icons.emoji_events_outlined,
                ),

                const SizedBox(height: 20),

                // Certifications
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Certifications',
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildCertificationsSection(),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Pricing & Availability (AFTER all information)
                _buildPricingSection(),

                const SizedBox(height: 32),

                // Action Buttons (AT THE VERY BOTTOM)
                _buildActionButtons(context),

                const SizedBox(height: 40),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Pricing Section (appears AFTER all information)
  Widget _buildPricingSection() {
    final pricing = PricingService.calculateFromTutorData(widget.tutor);
    final perSession = pricing['perSession'] as double;
    final perMonth = pricing['perMonth'] as double;
    final sessionsPerWeek = pricing['sessionsPerWeek'] as int;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.payments_outlined,
                size: 24,
                color: AppTheme.primaryColor,
              ),
              const SizedBox(width: 10),
              Text(
                'Pricing & Availability',
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Colors.black,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.primaryColor.withOpacity(0.2)),
            ),
            child: Column(
              children: [
                // Monthly estimate
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Monthly Package',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: Colors.grey[700],
                      ),
                    ),
                    Text(
                      PricingService.formatPrice(perMonth),
                      style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      'Based on $sessionsPerWeek session${sessionsPerWeek > 1 ? 's' : ''}/week',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
                Divider(color: Colors.grey[300], height: 32),
                // Per session rate
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Per Session',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: Colors.grey[700],
                      ),
                    ),
                    Text(
                      PricingService.formatPrice(perSession),
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Available times
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.schedule, size: 18, color: Colors.grey[600]),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Available Schedule',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[800],
                      ),
                    ),
                    const SizedBox(height: 4),
                    _buildAvailabilitySchedule(
                      widget.tutor['combined_availability']
                          as Map<String, dynamic>?,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Action Buttons (AT THE VERY BOTTOM)
  Widget _buildActionButtons(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          // Book Trial Session (outlined)
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        BookTrialSessionScreen(tutor: widget.tutor),
                  ),
                );
              },
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: AppTheme.primaryColor, width: 2),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'Book Trial Session',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primaryColor,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Book This Tutor (filled)
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => BookTutorFlowScreen(
                      tutor: widget.tutor,
                      // TODO: Pass actual survey data
                      surveyData: null,
                    ),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: Text(
                'Book This Tutor',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStat(IconData icon, String value, String label) {
    return Column(
      children: [
        Icon(icon, size: 24, color: AppTheme.primaryColor),
        const SizedBox(height: 6),
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Colors.black,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[600]),
        ),
      ],
    );
  }

  Widget _buildSection(String title, String content, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            content,
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Colors.grey[700],
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCertificationsSection() {
    // Get highest education level (this is the main certificate/degree)
    // Only show the level, NOT program/university (they might be currently in uni)
    final highestEducation = widget.tutor['highest_education'] as String?;

    // Get additional certifications
    final certifications = widget.tutor['certificates_urls'] as List?;
    final certificationsJson = widget.tutor['certifications'] as List?;
    final certList = certifications ?? certificationsJson;

    // Build list of items to display
    final List<Map<String, dynamic>> displayItems = [];

    // 1. Add highest education first (if available)
    // Only show the education level, NOT the program/university (they might be currently in uni)
    if (highestEducation != null && highestEducation.isNotEmpty) {
      displayItems.add({
        'text':
            highestEducation, // Just the level, e.g., "Advanced Level", "Bachelor's Degree"
        'type': 'education',
        'level': highestEducation.toLowerCase(),
      });
    }

    // 2. Add additional certifications
    if (certList != null && certList.isNotEmpty) {
      for (var cert in certList) {
        final certText = cert is Map
            ? cert['name']?.toString() ?? cert.toString()
            : cert.toString();
        if (certText.isNotEmpty) {
          displayItems.add({'text': certText, 'type': 'certification'});
        }
      }
    }

    // If no certifications at all
    if (displayItems.isEmpty) {
      return Text(
        'No certifications yet',
        style: GoogleFonts.poppins(
          fontSize: 14,
          color: Colors.grey[600],
          fontStyle: FontStyle.italic,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: displayItems.map((item) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon based on type and level
              _getEducationIcon(
                item['type'] as String,
                item['level'] as String?,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (item['type'] == 'education') ...[
                      Text(
                        'Highest Certificate',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.primaryColor,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                    ],
                    Text(
                      item['text'] as String,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: item['type'] == 'education'
                            ? FontWeight.w600
                            : FontWeight.w500,
                        color: item['type'] == 'education'
                            ? Colors.black
                            : Colors.grey[700],
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _getEducationIcon(String type, String? level) {
    if (type == 'education' && level != null) {
      final levelLower = level.toLowerCase();

      // Different icons for different education levels
      if (levelLower.contains('phd') ||
          levelLower.contains('doctorate') ||
          levelLower.contains('doctoral')) {
        return Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.purple.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(Icons.school, size: 24, color: Colors.purple[700]),
        );
      } else if (levelLower.contains('master') ||
          levelLower.contains('msc') ||
          levelLower.contains('mba') ||
          levelLower.contains('ms')) {
        return Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.blue.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            Icons.workspace_premium,
            size: 24,
            color: Colors.blue[700],
          ),
        );
      } else if (levelLower.contains('bachelor') ||
          levelLower.contains('bsc') ||
          levelLower.contains('ba') ||
          levelLower.contains('bachelor')) {
        return Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.green.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(Icons.verified, size: 24, color: Colors.green[700]),
        );
      } else if (levelLower.contains('diploma') ||
          levelLower.contains('certificate')) {
        return Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.orange.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            Icons.card_membership,
            size: 24,
            color: Colors.orange[700],
          ),
        );
      }
    }

    // Default icon for additional certifications
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.amber.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(Icons.workspace_premium, size: 24, color: Colors.amber[700]),
    );
  }

  Widget _buildAvatarImage(
    String? avatarUrl,
    String name, {
    bool isLarge = false,
  }) {
    // Check if avatarUrl is a network URL or asset path
    final isNetworkUrl =
        avatarUrl != null &&
        (avatarUrl.startsWith('http://') ||
            avatarUrl.startsWith('https://') ||
            avatarUrl.startsWith('//'));

    if (avatarUrl != null && avatarUrl.isNotEmpty) {
      if (isNetworkUrl) {
        // Use NetworkImage for URLs from Supabase storage
        return Image.network(
          avatarUrl,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return _buildAvatarPlaceholder(name, isLarge: isLarge);
          },
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Center(
              child: CircularProgressIndicator(
                value: loadingProgress.expectedTotalBytes != null
                    ? loadingProgress.cumulativeBytesLoaded /
                          loadingProgress.expectedTotalBytes!
                    : null,
                strokeWidth: 2,
              ),
            );
          },
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
            fontSize: 36,
            fontWeight: FontWeight.w600,
            color: AppTheme.primaryColor,
          ),
        ),
      ),
    );
  }

  Widget _buildAvailabilitySchedule(Map<String, dynamic>? availability) {
    if (availability == null || availability.isEmpty) {
      return Text(
        'Schedule not available',
        style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey[600]),
      );
    }

    // Format availability as day: times
    final scheduleItems = <Widget>[];
    availability.forEach((day, times) {
      if (times != null) {
        final timesList = times is List ? times : [times];
        if (timesList.isNotEmpty) {
          scheduleItems.add(
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '$day: ${timesList.join(', ')}',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: Colors.grey[600],
                ),
              ),
            ),
          );
        }
      }
    });

    if (scheduleItems.isEmpty) {
      return Text(
        'Schedule not available',
        style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey[600]),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: scheduleItems,
    );
  }

  /// Build video section with lazy loading and thumbnail preview
  Widget _buildVideoSection() {
    // If no video URL, show placeholder
    if (_videoId == null) {
      return Container(
        color: Colors.grey[200],
        child: Center(
          child: Icon(
            Icons.video_library_outlined,
            size: 80,
            color: Colors.grey[400],
          ),
        ),
      );
    }

    // If video is initialized, show player
    if (_isVideoInitialized) {
      return kIsWeb && _videoId != null
          ? _buildWebVideoPlayer(_videoId!)
          : (_youtubeController != null
                ? YoutubePlayerBuilder(
                    onExitFullScreen: () {},
                    player: YoutubePlayer(
                      controller: _youtubeController!,
                      showVideoProgressIndicator: false,
                      progressIndicatorColor: AppTheme.primaryColor,
                      progressColors: ProgressBarColors(
                        playedColor: AppTheme.primaryColor,
                        handleColor: AppTheme.primaryColor,
                        bufferedColor: Colors.grey[300]!,
                        backgroundColor: Colors.grey[200]!,
                      ),
                    ),
                    builder: (context, player) => player,
                  )
                : _buildThumbnailPreview());
    }

    // Show loading state
    if (_isVideoLoading) {
      return Container(
        color: Colors.black,
        child: Stack(
          children: [
            // Show thumbnail while loading
            if (_getThumbnailUrl() != null)
              CachedNetworkImage(
                imageUrl: _getThumbnailUrl()!,
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
                placeholder: (context, url) => Container(
                  color: Colors.grey[900],
                  child: const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  ),
                ),
                errorWidget: (context, url, error) =>
                    Container(color: Colors.grey[900]),
              ),
            // Loading overlay
            Container(
              color: Colors.black.withOpacity(0.5),
              child: const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            ),
          ],
        ),
      );
    }

    // Show thumbnail preview with play button (lazy load)
    return _buildThumbnailPreview();
  }

  /// Build thumbnail preview with play button overlay
  Widget _buildThumbnailPreview() {
    final thumbnailUrl = _getThumbnailUrl();

    return GestureDetector(
      onTap: () {
        // Initialize video when user taps
        _initializeVideo();
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Thumbnail image with caching
          thumbnailUrl != null
              ? CachedNetworkImage(
                  imageUrl: thumbnailUrl,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                  placeholder: (context, url) => Container(
                    color: Colors.grey[900],
                    child: const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    ),
                  ),
                  errorWidget: (context, url, error) {
                    return Container(
                      color: Colors.grey[900],
                      child: const Center(
                        child: Icon(
                          Icons.video_library_outlined,
                          size: 80,
                          color: Colors.white54,
                        ),
                      ),
                    );
                  },
                )
              : Container(
                  color: Colors.grey[900],
                  child: const Center(
                    child: Icon(
                      Icons.video_library_outlined,
                      size: 80,
                      color: Colors.white54,
                    ),
                  ),
                ),
          // Play button overlay
          Container(
            color: Colors.black.withOpacity(0.3),
            child: Center(
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.9),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.play_arrow,
                  color: Colors.white,
                  size: 60,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Build web-compatible YouTube video player using iframe
  Widget _buildWebVideoPlayer(String videoId) {
    if (kIsWeb) {
      // Use HtmlElementView for web
      final String viewType = 'youtube-iframe-$videoId';

      // Register the platform view (will be idempotent if already registered)
      try {
        web_video.registerYouTubeIframe(viewType, videoId);
      } catch (e) {
        // View factory might already be registered, that's okay
        print('ℹ️ View factory registration: $e');
      }

      return Container(
        color: Colors.black,
        child: HtmlElementView(viewType: viewType),
      );
    } else {
      // Fallback for non-web platforms
      return Container(
        color: Colors.grey[200],
        child: Center(
          child: Icon(
            Icons.play_circle_outline,
            size: 80,
            color: Colors.grey[400],
          ),
        ),
      );
    }
  }

  void _showProfileImage(BuildContext context) {
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
                    widget.tutor['avatar_url'],
                    widget.tutor['full_name'] ?? 'Tutor',
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
}

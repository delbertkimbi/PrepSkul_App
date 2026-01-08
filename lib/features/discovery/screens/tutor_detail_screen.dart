import 'package:flutter/material.dart';
import 'package:prepskul/core/services/log_service.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:prepskul/core/theme/app_theme.dart';
import 'package:prepskul/core/services/pricing_service.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:prepskul/features/booking/screens/book_tutor_flow_screen.dart';
import 'package:prepskul/features/booking/screens/book_trial_session_screen.dart';
import 'package:prepskul/features/booking/services/session_feedback_service.dart' hide LogService;
// TODO: Fix import path
// import 'package:prepskul/features/sessions/widgets/tutor_response_dialog.dart';
import 'package:prepskul/core/services/supabase_service.dart';
import 'package:prepskul/core/services/connectivity_service.dart';
import 'package:prepskul/core/services/offline_cache_service.dart';
import 'package:prepskul/core/services/tutor_service.dart';
import 'package:prepskul/core/widgets/offline_dialog.dart';
import 'package:prepskul/core/utils/safe_set_state.dart';
import 'dart:convert';
// Conditional import for web-specific video helper
import 'web_video_helper_stub.dart'
    if (dart.library.html) 'web_video_helper.dart'
    as web_video;
import 'package:prepskul/features/messaging/services/conversation_lifecycle_service.dart';
import 'package:prepskul/features/messaging/screens/chat_screen.dart';
import 'package:prepskul/features/messaging/models/conversation_model.dart';

class TutorDetailScreen extends StatefulWidget {
  final Map<String, dynamic> tutor;
  final bool isPreview;

  const TutorDetailScreen({
    Key? key, 
    required this.tutor,
    this.isPreview = false,
  }) : super(key: key);

  @override
  State<TutorDetailScreen> createState() => _TutorDetailScreenState();
}

class _TutorDetailScreenState extends State<TutorDetailScreen> {
  YoutubePlayerController? _youtubeController; // Nullable for web
  bool _isVideoInitialized = false;
  bool _isVideoLoading = false;
  String? _videoId; // For web iframe embed
  bool _isVideoPaused = false; // Track if video is paused
  List<Map<String, dynamic>> _reviews = [];
  Map<String, dynamic>? _ratingStats;
  bool _isLoadingReviews = false;
  String? _videoUrl; // Store original URL for thumbnail
  String? _currentUserId; // Current user ID to check if viewing own profile
  bool _isOffline = false;
  final ConnectivityService _connectivity = ConnectivityService();
  Map<String, dynamic>? _refreshedTutorData; // Store refreshed tutor data

  @override
  void initState() {
    super.initState();
    _currentUserId = SupabaseService.client.auth.currentUser?.id;
    _initializeConnectivity();
    _loadReviews(); // Load tutor reviews
    
    // CRITICAL: Refresh tutor data FIRST to get latest video URL from database
    // This ensures we show the updated approved video, not the stale cached one
    // Note: _refreshTutorData() will call _extractVideoIdFromData() internally,
    // so we don't need to call _extractVideoId() again here
    _refreshTutorData().catchError((e) {
      // If refresh fails, fall back to widget.tutor data
      LogService.warning('Refresh failed, using widget.tutor data: $e');
      if (mounted) {
        // Only extract from widget.tutor if refresh completely failed
        _extractVideoId();
      }
    });
    
    // Cache tutor details when loaded
    _cacheTutorDetails();
  }

  /// Refresh tutor data from database to get latest video URL
  /// Uses direct Supabase query (same as dashboard) to get exact data
  Future<void> _refreshTutorData() async {
    try {
      final tutorId = widget.tutor['id']?.toString() ?? widget.tutor['user_id']?.toString();
      if (tutorId == null) {
        LogService.warning('Cannot refresh tutor data: no tutor ID found');
        return;
      }

      // Fetch directly from Supabase (same method as dashboard) - no status filter
      // This ensures we get the latest data including video_url
      LogService.debug('🔄 Refreshing tutor data for ID: $tutorId');
      
      // Use specific relationship to avoid ambiguity: profiles!tutor_profiles_user_id_fkey
      // This explicitly uses the user_id foreign key relationship
      var response = await SupabaseService.client
          .from('tutor_profiles')
          .select('''
            *,
            profiles!tutor_profiles_user_id_fkey(
              full_name,
              avatar_url,
              email
            )
          ''')
          .eq('user_id', tutorId)
          .maybeSingle();
      
      // If not found by user_id, try by id (in case tutorId is actually tutor_profiles.id)
      if (response == null) {
        LogService.debug('Not found by user_id, trying by id...');
        response = await SupabaseService.client
            .from('tutor_profiles')
            .select('''
              *,
              profiles!tutor_profiles_user_id_fkey(
                full_name,
                avatar_url,
                email
              )
            ''')
            .eq('id', tutorId)
            .maybeSingle();
      }

      if (response != null && mounted) {
        // Handle profiles data - it might be a Map or List
        Map<String, dynamic>? profile;
        final profilesData = response['profiles'];
        if (profilesData is Map) {
          profile = Map<String, dynamic>.from(profilesData);
        } else if (profilesData is List && profilesData.isNotEmpty) {
          profile = Map<String, dynamic>.from(profilesData[0]);
        }
        
        // Get video: Use video_url (primary), fallback to video_link or video_intro
        final videoUrl = response['video_url']?.toString();
        final videoLink = response['video_link']?.toString();
        final videoIntro = response['video_intro']?.toString();
        final effectiveVideoUrl = videoUrl ?? videoLink ?? videoIntro;
        
        LogService.debug('📹 Video URLs from database:');
        LogService.debug('   video_url: ${videoUrl ?? "null"}');
        LogService.debug('   video_link: ${videoLink ?? "null"}');
        LogService.debug('   video_intro: ${videoIntro ?? "null"}');
        LogService.debug('   effectiveVideoUrl: ${effectiveVideoUrl ?? "null"}');
        
        // Compare with widget.tutor to see if video changed
        final oldVideoUrl = widget.tutor['video_url'] ?? widget.tutor['video_link'] ?? widget.tutor['video_intro'];
        if (oldVideoUrl != effectiveVideoUrl) {
          LogService.info('✅ Video URL changed! Old: $oldVideoUrl → New: $effectiveVideoUrl');
        } else {
          LogService.debug('ℹ️ Video URL unchanged: $effectiveVideoUrl');
        }
        
        // Get profile photo: Use profile_photo_url first, then avatar_url
        final profilePhotoUrl = response['profile_photo_url']?.toString();
        final avatarUrl = profile?['avatar_url']?.toString();
        final effectiveAvatarUrl = (profilePhotoUrl != null && profilePhotoUrl.isNotEmpty)
            ? profilePhotoUrl
            : (avatarUrl != null && avatarUrl.isNotEmpty)
            ? avatarUrl
            : null;

        // Build refreshed data map (same structure as TutorService)
        // Merge with original tutor data to preserve all fields, then override with refreshed values
        final refreshedData = {
          ...widget.tutor, // Preserve all original fields
          // Override with refreshed values
          'id': response['user_id']?.toString() ?? tutorId,
          'user_id': response['user_id']?.toString() ?? tutorId,
          'full_name': profile?['full_name']?.toString() ?? widget.tutor['full_name'] ?? 'Tutor',
          'avatar_url': effectiveAvatarUrl,
          'profile_photo_url': profilePhotoUrl,
          'video_url': effectiveVideoUrl,
          'video_link': videoLink,
          'video_intro': videoIntro,
          // Include other important fields
          'rating': response['rating'] ?? widget.tutor['rating'] ?? 0.0,
          'admin_approved_rating': response['admin_approved_rating'],
          'total_reviews': response['total_reviews'] ?? widget.tutor['total_reviews'] ?? 0,
          'status': response['status'],
          // CRITICAL: Include subjects and specializations from database
          'subjects': response['subjects'] ?? widget.tutor['subjects'],
          'specializations': response['specializations'] ?? widget.tutor['specializations'],
        };
        
        safeSetState(() {
          _refreshedTutorData = refreshedData;
        });
        
        // Log the video URLs for debugging
        LogService.debug('Refreshed tutor data - video_url: $videoUrl, video_link: $videoLink, video_intro: $videoIntro');
        LogService.debug('Effective video URL: $effectiveVideoUrl');
        
        // Re-extract video ID from refreshed data (will re-initialize if video changed)
        _extractVideoIdFromData(refreshedData);
      }
    } catch (e) {
      LogService.warning('Error refreshing tutor data: $e');
      // Continue with widget.tutor data if refresh fails
    }
  }

  /// Initialize connectivity monitoring
  Future<void> _initializeConnectivity() async {
    await _connectivity.initialize();
    _checkConnectivity();
    
    // Listen to connectivity changes
    _connectivity.connectivityStream.listen((isOnline) {
      if (mounted) {
        final wasOffline = _isOffline;
        safeSetState(() {
          _isOffline = !isOnline;
        });
        
        // If came back online, refresh tutor details
        if (isOnline && wasOffline) {
          LogService.info('🌐 Connection restored - refreshing tutor details');
          // Optionally reload tutor data if needed
        }
      }
    });
  }

  /// Check current connectivity status
  Future<void> _checkConnectivity() async {
    final isOnline = await _connectivity.checkConnectivity();
    if (mounted) {
      final wasOffline = _isOffline;
      safeSetState(() {
        _isOffline = !isOnline;
      });
      
      // If we just came back online, refresh data if needed
      if (isOnline && wasOffline) {
        LogService.info('🌐 Connection detected - tutor details screen');
      }
    }
  }

  /// Cache tutor details for offline access
  Future<void> _cacheTutorDetails() async {
    try {
      final tutorId = widget.tutor['id']?.toString() ?? widget.tutor['user_id']?.toString();
      if (tutorId != null) {
        await OfflineCacheService.cacheTutorDetails(tutorId, widget.tutor);
      }
    } catch (e) {
      LogService.warning('Error caching tutor details: $e');
    }
  }

  void _extractVideoId() {
    // Use refreshed data if available, otherwise fall back to widget.tutor
    final tutorData = _refreshedTutorData ?? widget.tutor;
    _extractVideoIdFromData(tutorData);
  }

  void _extractVideoIdFromData(Map<String, dynamic> tutorData) {
    try {
      // Use video_url (primary), fallback to video_intro or video_link
      final newVideoUrl =
          tutorData['video_url'] ??
          tutorData['video_intro'] ??
          tutorData['video_link'] ??
          '';
      
      if (newVideoUrl.isNotEmpty) {
        final newVideoId = YoutubePlayer.convertUrlToId(newVideoUrl);
        if (newVideoId != null && newVideoId.isNotEmpty) {
          // Check if video ID has changed or if this is the first time setting it
          final oldVideoId = _videoId;
          final videoIdChanged = oldVideoId != null && oldVideoId != newVideoId;
          final isFirstTime = oldVideoId == null;
          
          LogService.debug('📹 Video ID: old=$oldVideoId, new=$newVideoId, changed=$videoIdChanged, firstTime=$isFirstTime');
          
          safeSetState(() {
            _videoUrl = newVideoUrl;
            _videoId = newVideoId;
            
            // If video ID changed OR this is the first time, reset video initialization
            if (videoIdChanged || isFirstTime) {
              if (videoIdChanged) {
                LogService.info('🔄 Video ID changed from $oldVideoId to $newVideoId - resetting player');
              } else {
                LogService.info('🎬 Initializing video player with ID: $newVideoId');
              }
              _isVideoInitialized = false;
              _isVideoLoading = false;
              // Dispose old controller if exists
              _youtubeController?.dispose();
              _youtubeController = null;
            }
          });
          
          // If video ID changed OR this is the first time, initialize the video player
          if ((videoIdChanged || isFirstTime) && mounted) {
            // Wait a bit for state to update, then initialize
            Future.delayed(const Duration(milliseconds: 150), () {
              if (mounted && _videoId == newVideoId) {
                LogService.debug('🎥 Calling _initializeVideo() for video ID: $newVideoId');
                _initializeVideo();
              }
            });
          }
        } else {
          LogService.warning('Could not extract video ID from URL: $newVideoUrl');
        }
      } else {
        LogService.info('No video URL provided for tutor');
        safeSetState(() {
          _videoUrl = '';
          _videoId = null;
          // Reset video if URL is empty
          if (_isVideoInitialized) {
            _isVideoInitialized = false;
            _youtubeController?.dispose();
            _youtubeController = null;
          }
        });
      }
    } catch (e) {
      LogService.error('Error extracting video ID: $e');
    }
  }

  /// Get current tutor data (refreshed if available, otherwise from widget)
  Map<String, dynamic> get _currentTutorData => _refreshedTutorData ?? widget.tutor;

  void _initializeVideo() {
    if (_isVideoInitialized || _isVideoLoading || _videoId == null) return;

    safeSetState(() {
      _isVideoLoading = true;
    });

    try {
      // Check if running on web - use iframe embed instead
      if (kIsWeb) {
        // For web, we'll use an iframe embed (handled in build method)
        safeSetState(() {
          _isVideoInitialized = true;
          _isVideoLoading = false;
        });
      } else {
        // For mobile, use YoutubePlayerController with modern settings
          _youtubeController = YoutubePlayerController(
          initialVideoId: _videoId!,
            flags: const YoutubePlayerFlags(
            autoPlay: false, // Don't auto-play - wait for user to click
              mute: false,
              enableCaption: true,
            controlsVisibleAtStart: true, // Show controls when video starts
            hideControls: true, // Auto-hide controls after a few seconds
            hideThumbnail: false, // Show thumbnail initially
            loop: false,
            forceHD: true, // Force HD for better quality
            startAt: 0,
            showLiveFullscreenButton: true,
            useHybridComposition: true, // Better performance on Android
          ),
        );
        
        safeSetState(() {
          _isVideoInitialized = true;
          _isVideoLoading = false;
        });
        
        // Play video when user clicks (handled in _buildThumbnailPreview)
        // Don't auto-play here - wait for user interaction
      }
    } catch (e) {
      LogService.error('Error initializing video: $e');
      safeSetState(() {
        _isVideoLoading = false;
      });
    }
  }

  /// Get YouTube thumbnail URL
  String? _getThumbnailUrl() {
    if (_videoId == null) return null;
    // Use hqdefault for better reliability (maxresdefault often missing)
    return 'https://img.youtube.com/vi/$_videoId/hqdefault.jpg';
  }

  /// Pause video (both mobile and web)
  void _pauseVideo() {
    if (_isVideoPaused) return; // Already paused
    
    // Pause mobile YouTube player
    _youtubeController?.pause();
    
    // Pause web iframe video
    if (kIsWeb && _videoId != null) {
      web_video.pauseYouTubeVideo(_videoId!);
    }
    
    // Mark as paused
    _isVideoPaused = true;
  }

  @override
  void deactivate() {
    // Pause video when navigating away from this screen
    _pauseVideo();
    super.deactivate();
  }

  @override
  void dispose() {
    // Ensure video is paused before disposing
    _pauseVideo();
    _youtubeController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.tutor['full_name'] ?? 'Unknown';
    // Use personal_statement (with "Hello!") for detail page "About" section
    // Fallback to bio (dynamic) if personal_statement not available
    final bio = widget.tutor['personal_statement'] ?? widget.tutor['bio'] ?? '';
    // Parse education if it's JSON
    String education = '';
    final eduRaw = widget.tutor['education'];
    if (eduRaw is String) {
      if (eduRaw.trim().startsWith('{')) {
        try {
          final eduMap = json.decode(eduRaw);
          final degree = eduMap['highest_education']?.toString() ?? '';
          final field = eduMap['field_of_study']?.toString() ?? '';
          final uni = eduMap['institution']?.toString() ?? '';
          
          final parts = <String>[];
          if (degree.isNotEmpty) parts.add(degree);
          if (field.isNotEmpty) parts.add('in $field');
          final mainPart = parts.join(' ');
          
          education = mainPart.isNotEmpty 
              ? (uni.isNotEmpty ? '$mainPart at $uni' : mainPart)
              : uni;
        } catch (_) {
          education = eduRaw;
        }
      } else {
        education = eduRaw;
      }
    }
    final experience = widget.tutor['experience'] ?? '';
    // Calculate effective rating logic
    final totalReviewsVal = (widget.tutor['total_reviews'] as num?)?.toInt() ?? 0;
    final adminApprovedRating = (widget.tutor['admin_approved_rating'] as num?)?.toDouble();
    final calculatedRating = (widget.tutor['rating'] as num?)?.toDouble() ?? 0.0;

    final rating =
        (totalReviewsVal < 3 && adminApprovedRating != null)
        ? adminApprovedRating!
        : (calculatedRating > 0
              ? calculatedRating
              : (adminApprovedRating ?? 0.0));

    final totalReviews =
        (totalReviewsVal < 3 && adminApprovedRating != null)
        ? 10
        : totalReviewsVal;
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
      body: SafeArea(
        top: true,
        bottom: false,
        child: CustomScrollView(
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
                                    color: Colors.black.withOpacity(0.06),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
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
                const SizedBox(height: 20),
                // Reviews Section
                _buildReviewsSection(),
                const SizedBox(height: 20),
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
      ),
    );
  }

  // Pricing Section (appears AFTER all information)
  Widget _buildPricingSection() {
    final pricing = PricingService.calculateFromTutorData(widget.tutor);
    final perSession = pricing['perSession'] as double;
    final perMonth = pricing['perMonth'] as double;
    final sessionsPerWeek = pricing['sessionsPerWeek'] as int;
    final hasDiscount = pricing['hasDiscount'] as bool? ?? false;
    final originalPerMonth = pricing['originalPerMonth'] as double?;
    final originalPerSession = pricing['originalPerSession'] as double?;
    final discountPercent = pricing['discountPercent'] as double? ?? 0.0;

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
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        if (hasDiscount && originalPerMonth != null) ...[
                          Text(
                            PricingService.formatPrice(originalPerMonth),
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey[500],
                              decoration: TextDecoration.lineThrough,
                            ),
                          ),
                          const SizedBox(height: 4),
                        ],
                    Text(
                      PricingService.formatPrice(perMonth),
                      style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.primaryColor,
                          ),
                        ),
                        if (hasDiscount && discountPercent > 0) ...[
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${discountPercent.toStringAsFixed(0)}% OFF',
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Colors.green[700],
                              ),
                            ),
                          ),
                        ],
                      ],
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
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        if (hasDiscount && originalPerSession != null) ...[
                          Text(
                            PricingService.formatPrice(originalPerSession),
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey[500],
                              decoration: TextDecoration.lineThrough,
                            ),
                          ),
                          const SizedBox(height: 4),
                        ],
                    Text(
                      PricingService.formatPrice(perSession),
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                            color: AppTheme.primaryColor,
                      ),
                        ),
                      ],
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
    if (widget.isPreview) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Text(
              'Preview Mode - Booking Disabled',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey[600],
              ),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          // Book Trial Session (outlined)
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: _isOffline
                  ? () => OfflineDialog.show(
                        context,
                        message: 'Booking a session requires an internet connection. Please check your connection and try again.',
                      )
                  : () {
                // Pause video before navigating
                _pauseVideo();
                // Use refreshed tutor data if available (includes latest video_url and profile_photo_url)
                final tutorData = _currentTutorData;
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        BookTrialSessionScreen(tutor: tutorData),
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
              onPressed: _isOffline
                  ? () => OfflineDialog.show(
                        context,
                        message: 'Booking a tutor requires an internet connection. Please check your connection and try again.',
                      )
                  : () {
                // Pause video before navigating
                _pauseVideo();
                // Use refreshed tutor data if available (includes latest video_url and profile_photo_url)
                final tutorData = _currentTutorData;
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => BookTutorFlowScreen(
                      tutor: tutorData,
                      // TODO: Pass actual survey data
                      surveyData: null,
                    ),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _isOffline 
                    ? Colors.grey[400] 
                    : AppTheme.primaryColor,
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
          // Chat button (only show if there's an active booking/trial)
          FutureBuilder<bool>(
            future: _hasActiveBookingWithTutor(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SizedBox.shrink();
              }
              
              if (snapshot.data == true) {
                return Column(
                  children: [
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _isOffline
                            ? () => OfflineDialog.show(
                                  context,
                                  message: 'Messaging requires an internet connection. Please check your connection and try again.',
                                )
                            : () => _navigateToChat(context),
                        icon: const Icon(Icons.message),
                        label: Text(
                          'Message Tutor',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.primaryColor,
                          side: BorderSide(color: AppTheme.primaryColor, width: 1.5),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              }
              
              return const SizedBox.shrink();
            },
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
        key: const ValueKey('video-placeholder'),
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

    // Use video ID as key to force rebuild when video changes
    final videoKey = ValueKey('video-$_videoId');

    // Always show thumbnail preview first (before video is initialized)
    // Only show player after user clicks play and video is initialized
    if (!_isVideoInitialized && !_isVideoLoading) {
      return _buildThumbnailPreview();
    }

    // If video is initialized, show player
    if (_isVideoInitialized) {
      return kIsWeb && _videoId != null
          ? _buildWebVideoPlayer(_videoId!, key: videoKey)
          : (_youtubeController != null
                ? Container(
                    key: videoKey, // Force rebuild when video ID changes
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 20,
                          spreadRadius: 2,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: YoutubePlayerBuilder(
                    onExitFullScreen: () {},
                    player: YoutubePlayer(
                      controller: _youtubeController!,
                          showVideoProgressIndicator: true,
                      progressIndicatorColor: AppTheme.primaryColor,
                      progressColors: ProgressBarColors(
                        playedColor: AppTheme.primaryColor,
                        handleColor: AppTheme.primaryColor,
                            bufferedColor: Colors.white.withOpacity(0.3),
                            backgroundColor: Colors.white.withOpacity(0.1),
                          ),
                          thumbnail: _getThumbnailUrl() != null
                              ? CachedNetworkImage(
                                  imageUrl: _getThumbnailUrl()!,
                                  fit: BoxFit.cover,
                                )
                              : null,
                          onReady: () {
                            // Video is ready - user will click to play
                            // Don't auto-play here
                          },
                          onEnded: (metadata) {
                            // Handle video end - could show replay option
                            LogService.info('Video ended');
                          },
                        ),
                        builder: (context, player) => Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.2),
                                blurRadius: 10,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                          child: player,
                        ),
                      ),
                    ),
                  )
                : _buildThumbnailPreview());
    }

    // Show loading state with better UX
    if (_isVideoLoading) {
      return Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
        color: Colors.black,
        ),
        child: Stack(
          children: [
            // Show thumbnail while loading
            if (_getThumbnailUrl() != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: CachedNetworkImage(
                imageUrl: _getThumbnailUrl()!,
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
                placeholder: (context, url) => Container(
                  color: Colors.grey[900],
                  child: const Center(
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                  ),
                ),
                errorWidget: (context, url, error) =>
                    Container(color: Colors.grey[900]),
              ),
              ),
            // Modern loading overlay with pulse animation
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: Colors.black.withOpacity(0.6),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 3,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Loading video...',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Fallback: Show thumbnail preview if somehow we get here
    return _buildThumbnailPreview();
  }

  /// Build thumbnail preview with modern play button overlay
  Widget _buildThumbnailPreview() {
    final thumbnailUrl = _getThumbnailUrl();

    return GestureDetector(
      onTap: () {
        // Initialize video when user taps
        _initializeVideo();
        // Play video after initialization (for mobile)
        if (!kIsWeb && _youtubeController != null) {
          Future.delayed(const Duration(milliseconds: 500), () {
            if (_youtubeController?.value.isReady == true) {
              _youtubeController?.play();
            }
          });
        }
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 10,
              spreadRadius: 1,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
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
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
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
              // Modern play button overlay (smaller, more elegant)
          Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.4),
                    ],
                  ),
                ),
            child: Center(
              child: Container(
                    padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.95),
                  shape: BoxShape.circle,
                  boxShadow: [
                        BoxShadow(
                          color: Colors.red.withOpacity(0.5),
                          blurRadius: 20,
                          spreadRadius: 4,
                        ),
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 15,
                          spreadRadius: 2,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.play_arrow,
                  color: Colors.white,
                      size: 32,
                ),
              ),
            ),
          ),
        ],
          ),
        ),
      ),
    );
  }

  /// Build web-compatible YouTube video player using iframe
  Widget _buildWebVideoPlayer(String videoId, {Key? key}) {
    if (kIsWeb) {
      // Use HtmlElementView for web
      final String viewType = 'youtube-iframe-$videoId';

      // Register the platform view (will be idempotent if already registered)
      try {
        web_video.registerYouTubeIframe(viewType, videoId);
      } catch (e) {
        // View factory might already be registered, that's okay
        LogService.info('View factory registration: $e');
      }

      return Container(
        key: key, // Use key to force rebuild when video changes
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

  /// Load reviews for this tutor
  Future<void> _loadReviews() async {
    try {
      safeSetState(() => _isLoadingReviews = true);
      
      final tutorId = widget.tutor['user_id'] ?? widget.tutor['id'];
      if (tutorId == null) {
        safeSetState(() => _isLoadingReviews = false);
        return;
      }
      
      final reviews = await SessionFeedbackService.getTutorReviews(tutorId.toString());
      final ratingStats = await SessionFeedbackService.getTutorRatingStats(tutorId.toString());
      
      if (mounted) {
        safeSetState(() {
          _reviews = reviews;
          _ratingStats = ratingStats;
          _isLoadingReviews = false;
        });
      }
    } catch (e) {
      LogService.error('Error loading reviews: $e');
      if (mounted) {
        safeSetState(() => _isLoadingReviews = false);
      }
    }
  }

  /// Build reviews section
  Widget _buildReviewsSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.star_outline,
                size: 24,
                color: AppTheme.primaryColor,
              ),
              const SizedBox(width: 10),
              Text(
                'Reviews',
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Colors.black,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          if (_isLoadingReviews)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: CircularProgressIndicator(),
              ),
            )
          else if (_reviews.isEmpty)
            Text(
              'No reviews yet. Be the first to review this tutor!',
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.grey[600],
                fontStyle: FontStyle.italic,
              ),
            )
          else ...[
            // Rating Summary
            if (_ratingStats != null) ...[
              _buildRatingSummary(_ratingStats!),
              const SizedBox(height: 20),
            ],
            // Reviews List
            ..._reviews.take(5).map((review) => _buildReviewCard(review)),
            if (_reviews.length > 5)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  'Showing 5 of ${_reviews.length} reviews',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }

  /// Build rating summary
  Widget _buildRatingSummary(Map<String, dynamic> stats) {
    final averageRating = (stats['average_rating'] as num?)?.toDouble() ?? 0.0;
    final totalReviews = (stats['total_reviews'] as num?)?.toInt() ?? 0;
    final ratingDistribution = stats['rating_distribution'] as Map<int, int>? ?? {};
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                averageRating.toStringAsFixed(1),
                style: GoogleFonts.poppins(
                  fontSize: 32,
                  fontWeight: FontWeight.w700,
                  color: Colors.black,
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: List.generate(5, (index) {
                      return Icon(
                        index < averageRating.round()
                            ? Icons.star
                            : Icons.star_border,
                        size: 20,
                        color: Colors.amber[700],
                      );
                    }),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$totalReviews ${totalReviews == 1 ? 'review' : 'reviews'}',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (ratingDistribution.isNotEmpty) ...[
            const SizedBox(height: 16),
            ...ratingDistribution.entries.map((entry) {
              final rating = entry.key;
              final count = entry.value;
              final percentage = totalReviews > 0 ? (count / totalReviews * 100) : 0.0;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Text(
                      '$rating',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[700],
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(Icons.star, size: 14, color: Colors.amber[700]),
                    const SizedBox(width: 8),
                    Expanded(
                      child: LinearProgressIndicator(
                        value: percentage / 100,
                        backgroundColor: Colors.grey[200],
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.amber[700]!),
                        minHeight: 8,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '$count',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  /// Build individual review card
  Widget _buildReviewCard(Map<String, dynamic> review) {
    final rating = review['student_rating'] as int? ?? 0;
    final reviewText = review['student_review'] as String?;
    final submittedAt = review['student_feedback_submitted_at'] as String?;
    final wouldRecommend = review['student_would_recommend'] as bool?;
    final whatWentWell = review['student_what_went_well'] as String?;
    final whatCouldImprove = review['student_what_could_improve'] as String?;
    
    // Format date
    String dateText = 'Recently';
    if (submittedAt != null) {
      try {
        final date = DateTime.parse(submittedAt);
        final now = DateTime.now();
        final difference = now.difference(date);
        
        if (difference.inDays == 0) {
          dateText = 'Today';
        } else if (difference.inDays == 1) {
          dateText = 'Yesterday';
        } else if (difference.inDays < 7) {
          dateText = '${difference.inDays} days ago';
        } else if (difference.inDays < 30) {
          dateText = '${(difference.inDays / 7).floor()} weeks ago';
        } else {
          dateText = '${(difference.inDays / 30).floor()} months ago';
        }
      } catch (e) {
        dateText = 'Recently';
      }
    }
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Stars
              ...List.generate(5, (index) {
                return Icon(
                  index < rating ? Icons.star : Icons.star_border,
                  size: 16,
                  color: Colors.amber[700],
                );
              }),
              const SizedBox(width: 8),
              Text(
                dateText,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
              if (wouldRecommend == true) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.accentGreen.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.thumb_up, size: 12, color: AppTheme.accentGreen),
                      const SizedBox(width: 4),
                      Text(
                        'Recommended',
                        style: GoogleFonts.poppins(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.accentGreen,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          if (reviewText != null && reviewText.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              reviewText,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.grey[800],
                height: 1.5,
              ),
            ),
          ],
          if (whatWentWell != null && whatWentWell.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.accentGreen.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.check_circle_outline, size: 16, color: AppTheme.accentGreen),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'What went well:',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.accentGreen,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          whatWentWell,
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: Colors.grey[700],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (whatCouldImprove != null && whatCouldImprove.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.lightbulb_outline, size: 16, color: Colors.orange[700]),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Could improve:',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.orange[700],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          whatCouldImprove,
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: Colors.grey[700],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
          
          // Tutor Response Section
          if (review['tutor_response'] != null && (review['tutor_response'] as String).isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppTheme.primaryColor.withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.reply, size: 16, color: AppTheme.primaryColor),
                      const SizedBox(width: 8),
                      Text(
                        'Tutor Response:',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    review['tutor_response'] as String,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: Colors.grey[800],
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
          
          // Respond Button (only for tutor viewing their own profile)
          if (_currentUserId != null && 
              widget.tutor['user_id'] == _currentUserId &&
              (review['tutor_response'] == null || (review['tutor_response'] as String).isEmpty)) ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => _showResponseDialog(review),
                icon: const Icon(Icons.reply, size: 16),
                label: Text(
                  'Respond',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: TextButton.styleFrom(
                  foregroundColor: AppTheme.primaryColor,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
  
  Future<void> _showResponseDialog(Map<String, dynamic> review) async {
    final feedbackId = review['id'] as String;
    final existingResponse = review['tutor_response'] as String?;
    
    // TODO: Uncomment when file available
    // final result = await TutorResponseDialog.show(
    //   context,
    //   feedbackId: feedbackId,
    //   existingResponse: existingResponse,
    // );
    final result = null; // Placeholder
    if (result != null) {
      // Reload reviews to show the new response
      _loadReviews();
    }
  }

  /// Check if user has an active booking or trial with this tutor
  Future<bool> _hasActiveBookingWithTutor() async {
    try {
      final currentUserId = SupabaseService.currentUser?.id;
      if (currentUserId == null) return false;

      final tutorId = widget.tutor['id']?.toString() ?? widget.tutor['user_id']?.toString();
      if (tutorId == null) return false;

      final supabase = SupabaseService.client;

      // Check for active trial sessions
      final trialSessions = await supabase
          .from('trial_sessions')
          .select('id')
          .eq('learner_id', currentUserId)
          .eq('tutor_id', tutorId)
          .inFilter('status', ['pending', 'approved', 'scheduled'])
          .limit(1);

      if ((trialSessions as List).isNotEmpty) {
        return true;
      }

      // Check for active booking requests
      final bookingRequests = await supabase
          .from('booking_requests')
          .select('id')
          .eq('student_id', currentUserId)
          .eq('tutor_id', tutorId)
          .inFilter('status', ['pending', 'approved'])
          .limit(1);

      if ((bookingRequests as List).isNotEmpty) {
        return true;
      }

      // Check for active recurring sessions
      final recurringSessions = await supabase
          .from('recurring_sessions')
          .select('id')
          .eq('learner_id', currentUserId)
          .eq('tutor_id', tutorId)
          .eq('status', 'active')
          .limit(1);

      return (recurringSessions as List).isNotEmpty;
    } catch (e) {
      LogService.error('Error checking active booking: $e');
      return false;
    }
  }

  /// Navigate to chat with this tutor
  Future<void> _navigateToChat(BuildContext context) async {
    try {
      final currentUserId = SupabaseService.currentUser?.id;
      if (currentUserId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'You must be logged in to message.',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final tutorId = widget.tutor['id']?.toString() ?? widget.tutor['user_id']?.toString();
      if (tutorId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Unable to start conversation. Tutor ID not found.',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      final supabase = SupabaseService.client;

      // Try to find existing conversation
      // First check by booking request
      var conversationResponse = await supabase
          .from('conversations')
          .select('*')
          .eq('student_id', currentUserId)
          .eq('tutor_id', tutorId)
          .eq('status', 'active')
          .maybeSingle();

      // If not found, try to find by recurring session
      if (conversationResponse == null) {
        final recurringSession = await supabase
            .from('recurring_sessions')
            .select('id')
            .eq('learner_id', currentUserId)
            .eq('tutor_id', tutorId)
            .eq('status', 'active')
            .limit(1)
            .maybeSingle();

        if (recurringSession != null) {
          final recurringId = recurringSession['id'] as String;
          final conversationId = await ConversationLifecycleService.getConversationIdForRecurring(recurringId);
          
          if (conversationId != null) {
            conversationResponse = await supabase
                .from('conversations')
                .select('*')
                .eq('id', conversationId)
                .maybeSingle();
          }
        }
      }

      // If still not found, try to find by trial session
      if (conversationResponse == null) {
        final trialSession = await supabase
            .from('trial_sessions')
            .select('id')
            .eq('learner_id', currentUserId)
            .eq('tutor_id', tutorId)
            .inFilter('status', ['pending', 'approved', 'scheduled'])
            .limit(1)
            .maybeSingle();

        if (trialSession != null) {
          final trialId = trialSession['id'] as String;
          final conversationId = await ConversationLifecycleService.getConversationIdForTrial(trialId);
          
          if (conversationId != null) {
            conversationResponse = await supabase
                .from('conversations')
                .select('*')
                .eq('id', conversationId)
                .maybeSingle();
          }
        }
      }

      // If still not found, try to find by booking request
      if (conversationResponse == null) {
        final bookingRequest = await supabase
            .from('booking_requests')
            .select('id')
            .eq('student_id', currentUserId)
            .eq('tutor_id', tutorId)
            .inFilter('status', ['pending', 'approved'])
            .limit(1)
            .maybeSingle();

        if (bookingRequest != null) {
          final bookingId = bookingRequest['id'] as String;
          final conversationId = await ConversationLifecycleService.getConversationIdForBooking(bookingId);
          
          if (conversationId != null) {
            conversationResponse = await supabase
                .from('conversations')
                .select('*')
                .eq('id', conversationId)
                .maybeSingle();
          }
        }
      }

      // Dismiss loading
      if (mounted) Navigator.pop(context);

      if (conversationResponse == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'No active conversation found. Please book a session first.',
                style: GoogleFonts.poppins(),
              ),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      // Get tutor profile info
      final tutorProfile = await supabase
          .from('profiles')
          .select('full_name, avatar_url')
          .eq('id', tutorId)
          .maybeSingle();

      // Create Conversation object
      final conversation = Conversation(
        id: conversationResponse['id'] as String,
        studentId: conversationResponse['student_id'] as String,
        tutorId: conversationResponse['tutor_id'] as String,
        bookingRequestId: conversationResponse['booking_request_id'] as String?,
        recurringSessionId: conversationResponse['recurring_session_id'] as String?,
        individualSessionId: conversationResponse['individual_session_id'] as String?,
        trialSessionId: conversationResponse['trial_session_id'] as String?,
        status: conversationResponse['status'] as String? ?? 'active',
        expiresAt: conversationResponse['expires_at'] != null
            ? DateTime.parse(conversationResponse['expires_at'] as String)
            : null,
        lastMessageAt: conversationResponse['last_message_at'] != null
            ? DateTime.parse(conversationResponse['last_message_at'] as String)
            : null,
        createdAt: DateTime.parse(conversationResponse['created_at'] as String),
        otherUserName: tutorProfile?['full_name'] as String?,
        otherUserAvatarUrl: tutorProfile?['avatar_url'] as String?,
      );

      // Navigate to chat screen
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatScreen(conversation: conversation),
          ),
        );
      }
    } catch (e) {
      LogService.error('Error navigating to chat: $e');
      if (mounted) {
        // Dismiss loading if still showing
        Navigator.of(context, rootNavigator: true).popUntil((route) => !route.navigator!.canPop() || route.settings.name != null);
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Unable to start conversation. Please try again.',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
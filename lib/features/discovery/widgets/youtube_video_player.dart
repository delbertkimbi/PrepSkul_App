import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import 'package:prepskul/core/theme/app_theme.dart';
import 'package:prepskul/core/services/log_service.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
// Conditional import for web iframe player
import 'web_iframe_player_stub.dart'
    if (dart.library.html) 'web_iframe_player.dart'
    as web_iframe;

/// Simple YouTube video player widget using iframe-based approach
/// Works on both web and mobile platforms
class YoutubeVideoPlayer extends StatefulWidget {
  final String videoId;

  const YoutubeVideoPlayer({
    Key? key,
    required this.videoId,
  }) : super(key: key);

  @override
  State<YoutubeVideoPlayer> createState() => _YoutubeVideoPlayerState();
}

class _YoutubeVideoPlayerState extends State<YoutubeVideoPlayer> {
  bool _isPlaying = false;
  bool _hasEnded = false;
  YoutubePlayerController? _mobileController;

  @override
  void dispose() {
    _mobileController?.dispose();
    super.dispose();
  }

  /// Get YouTube thumbnail URL - use hqdefault first (faster loading, more reliable)
  String _getThumbnailUrl() {
    return 'https://img.youtube.com/vi/${widget.videoId}/hqdefault.jpg';
  }

  /// Get high quality thumbnail URL (fallback)
  String _getHighQualityThumbnailUrl() {
    return 'https://img.youtube.com/vi/${widget.videoId}/maxresdefault.jpg';
  }

  /// Build thumbnail preview with play button
  Widget _buildThumbnail() {
    final thumbnailUrl = _getThumbnailUrl();

    return Container(
      color: AppTheme.primaryColor.withOpacity(0.1), // Lighter deep blue background
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Thumbnail image with shimmer effect - optimized for faster loading
          CachedNetworkImage(
            imageUrl: thumbnailUrl,
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
            cacheKey: 'youtube_thumb_${widget.videoId}',
            memCacheWidth: 640, // Optimize memory usage
            memCacheHeight: 360,
            maxWidthDiskCache: 1280, // Cache at reasonable size
            maxHeightDiskCache: 720,
            fadeInDuration: const Duration(milliseconds: 200), // Smooth fade-in
            placeholder: (context, url) {
              // Show shimmer effect with lighter deep blue while loading
              return Shimmer.fromColors(
                baseColor: AppTheme.primaryColor.withOpacity(0.3),
                highlightColor: AppTheme.primaryLight.withOpacity(0.5),
                child: Container(
                  color: AppTheme.primaryColor.withOpacity(0.2),
                  width: double.infinity,
                  height: double.infinity,
                ),
              );
            },
            errorWidget: (context, url, error) {
              // Try high quality thumbnail URL with shimmer
              return CachedNetworkImage(
                imageUrl: _getHighQualityThumbnailUrl(),
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
                placeholder: (context, url) {
                  return Shimmer.fromColors(
                    baseColor: AppTheme.primaryColor.withOpacity(0.3),
                    highlightColor: AppTheme.primaryLight.withOpacity(0.5),
                    child: Container(
                      color: AppTheme.primaryColor.withOpacity(0.2),
                      width: double.infinity,
                      height: double.infinity,
                    ),
                  );
                },
                errorWidget: (context, url, error) {
                  // If both fail, show shimmer instead of black screen
                  return Shimmer.fromColors(
                    baseColor: AppTheme.primaryColor.withOpacity(0.3),
                    highlightColor: AppTheme.primaryLight.withOpacity(0.5),
                    child: Container(
                      color: AppTheme.primaryColor.withOpacity(0.2),
                      child: const Center(
                        child: Icon(
                          Icons.video_library_outlined,
                          size: 80,
                          color: Colors.white54,
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
          // Play button at bottom right
          Positioned(
            bottom: 14,
            right: 14,
            child: GestureDetector(
              onTap: () {
                LogService.debug('Play button tapped for video: ${widget.videoId}');
                setState(() {
                  _isPlaying = true;
                  _hasEnded = false; // Reset ended state when replaying
                });
              },
              behavior: HitTestBehavior.opaque,
              child: Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.4),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.play_arrow,
                  color: Colors.white,
                  size: 30,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Build web iframe player
  Widget _buildWebIframe() {
    return web_iframe.WebIframePlayer(videoId: widget.videoId);
  }

  /// Build mobile player using youtube_player_flutter (simplified)
  Widget _buildMobilePlayer() {
    // Initialize controller if not already done or if video ended (for replay)
    if (_mobileController == null || _hasEnded) {
      _mobileController?.dispose();
      _mobileController = YoutubePlayerController(
        initialVideoId: widget.videoId,
        flags: const YoutubePlayerFlags(
          autoPlay: true,
          mute: false, // Start unmuted since user clicked play
          enableCaption: false,
          controlsVisibleAtStart: false, // Hide controls initially
          hideControls: true, // Auto-hide controls
          hideThumbnail: true,
          loop: false,
          forceHD: false,
          startAt: 0,
          showLiveFullscreenButton: false,
          useHybridComposition: true,
          disableDragSeek: false,
          isLive: false,
        ),
      );
      
      // Listen to player state changes
      _mobileController!.addListener(() {
        // Handle video end
        if (_mobileController!.value.playerState == PlayerState.ended) {
          if (mounted && !_hasEnded) {
            setState(() {
              _hasEnded = true;
            });
            LogService.info('Video ended - ready for replay');
          }
        }
      });
    }

    // If video ended, show replay button overlay
    if (_hasEnded) {
      return Stack(
        children: [
          YoutubePlayerBuilder(
            onExitFullScreen: () {},
            player: YoutubePlayer(
              controller: _mobileController!,
              showVideoProgressIndicator: false, // Hide progress when ended
              progressIndicatorColor: AppTheme.primaryColor,
              progressColors: ProgressBarColors(
                playedColor: AppTheme.primaryColor,
                handleColor: AppTheme.primaryColor,
                bufferedColor: Colors.white.withOpacity(0.3),
                backgroundColor: Colors.white.withOpacity(0.1),
              ),
            ),
            builder: (context, player) => player,
          ),
          // Replay button overlay - tap anywhere to replay
          GestureDetector(
            onTap: () {
              setState(() {
                _hasEnded = false;
                _isPlaying = false; // Reset to show thumbnail, then replay
              });
              // Small delay to allow state reset, then play again
              Future.delayed(const Duration(milliseconds: 100), () {
                if (mounted) {
                  setState(() {
                    _isPlaying = true;
                  });
                }
              });
            },
            behavior: HitTestBehavior.opaque,
            child: Container(
              color: Colors.black.withOpacity(0.3),
              child: Center(
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.4),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.replay,
                    color: Colors.white,
                    size: 36,
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    }

    return GestureDetector(
      onTap: () {
        // Tap to pause/play functionality
        if (_mobileController != null) {
          if (_mobileController!.value.isPlaying) {
            _mobileController!.pause();
          } else {
            _mobileController!.play();
          }
        }
      },
      child: YoutubePlayerBuilder(
        onExitFullScreen: () {},
        player: YoutubePlayer(
          controller: _mobileController!,
          showVideoProgressIndicator: true,
          progressIndicatorColor: AppTheme.primaryColor,
          progressColors: ProgressBarColors(
            playedColor: AppTheme.primaryColor,
            handleColor: AppTheme.primaryColor,
            bufferedColor: Colors.white.withOpacity(0.3),
            backgroundColor: Colors.white.withOpacity(0.1),
          ),
          thumbnail: CachedNetworkImage(
            imageUrl: _getThumbnailUrl(),
            fit: BoxFit.cover,
            cacheKey: 'youtube_thumb_${widget.videoId}',
            memCacheWidth: 640,
            memCacheHeight: 360,
            maxWidthDiskCache: 1280,
            maxHeightDiskCache: 720,
            fadeInDuration: const Duration(milliseconds: 200),
            errorWidget: (context, url, error) {
              // Handle database caching errors gracefully
              LogService.debug('Thumbnail load error, trying HQ: $error');
              return CachedNetworkImage(
                imageUrl: _getHighQualityThumbnailUrl(),
                fit: BoxFit.cover,
                cacheKey: 'youtube_thumb_hq_${widget.videoId}',
                memCacheWidth: 1280,
                memCacheHeight: 720,
                maxWidthDiskCache: 1920,
                maxHeightDiskCache: 1080,
                fadeInDuration: const Duration(milliseconds: 200),
                errorWidget: (context, url, error) {
                  // If both fail, show shimmer placeholder
                  return Shimmer.fromColors(
                    baseColor: AppTheme.primaryColor.withOpacity(0.3),
                    highlightColor: AppTheme.primaryLight.withOpacity(0.5),
                    child: Container(
                      color: AppTheme.primaryColor.withOpacity(0.2),
                      child: const Center(
                        child: Icon(
                          Icons.video_library_outlined,
                          size: 60,
                          color: Colors.white54,
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
          onReady: () {
            LogService.debug('Mobile video player ready');
            // Video is already unmuted via flags (mute: false)
          },
          onEnded: (metadata) {
            LogService.info('Video ended');
            if (mounted) {
              setState(() {
                _hasEnded = true;
              });
            }
          },
        ),
        builder: (context, player) => player,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Show thumbnail if not playing yet
    if (!_isPlaying) {
      return _buildThumbnail();
    }

    // Show player when playing - wrap with shimmer during initial load
    if (kIsWeb) {
      return Stack(
        children: [
          _buildWebIframe(),
          // Show shimmer overlay briefly while iframe loads
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 1.0, end: 0.0),
            duration: const Duration(milliseconds: 800),
            builder: (context, opacity, child) {
              if (opacity <= 0) return const SizedBox.shrink();
              return Shimmer.fromColors(
                baseColor: Colors.grey[800]!,
                highlightColor: Colors.grey[700]!,
                child: Container(
                  color: Colors.grey[800]!.withOpacity(opacity),
                ),
              );
            },
          ),
        ],
      );
    } else {
      return _buildMobilePlayer();
    }
  }
}

// Web-specific video helper
// This file is only used on web platform

import 'dart:html' as html;
import 'dart:ui_web' as ui_web;
import 'dart:js' as js;

/// Register a YouTube iframe for web platform
/// Note: This function is kept for backward compatibility but is now handled
/// directly in the WebIframePlayer widget
void registerYouTubeIframe(String viewType, String videoId) {
  // This function is deprecated - iframe registration is now handled in WebIframePlayer
  // Keeping for backward compatibility
  try {
    ui_web.platformViewRegistry.registerViewFactory(viewType, (int viewId) {
      final iframe = html.IFrameElement()
        ..src = 'https://www.youtube.com/embed/$videoId?enablejsapi=1&rel=0&modestbranding=1&autoplay=1&mute=1&controls=1&playsinline=1&fs=0&cc_load_policy=0&iv_load_policy=3'
        ..style.border = 'none'
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.backgroundColor = 'transparent'
        ..allowFullscreen = false
        ..allow = 'autoplay; encrypted-media';
      
      iframe.onLoad.listen((_) {
        print('YouTube iframe loaded for video: $videoId');
      });
      
      return iframe;
    });
  } catch (e) {
    print('View factory registration note (may already exist): $e');
  }
}

/// Pause YouTube video by video ID (web only)
void pauseYouTubeVideo(String videoId) {
  try {
    // Use YouTube IFrame API to pause the video
    js.context.callMethod('eval', [
      '''
      (function() {
        var iframes = document.querySelectorAll('iframe[src*="$videoId"]');
        iframes.forEach(function(iframe) {
          if (iframe.contentWindow && iframe.contentWindow.postMessage) {
            iframe.contentWindow.postMessage('{"event":"command","func":"pauseVideo","args":""}', '*');
          }
        });
      })();
      '''
    ]);
  } catch (e) {
    // If JavaScript execution fails, that's okay - the iframe will be removed anyway
  }
}
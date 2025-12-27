// Web-specific video helper
// This file is only used on web platform

import 'dart:html' as html show IFrameElement, window;
import 'dart:ui_web' as ui_web;
import 'dart:js' as js;

/// Register a YouTube iframe for web platform
void registerYouTubeIframe(String viewType, String videoId) {
  ui_web.platformViewRegistry.registerViewFactory(viewType, (int viewId) {
    final iframe = html.IFrameElement()
      ..src = 'https://www.youtube.com/embed/$videoId?enablejsapi=1&rel=0&modestbranding=1&autoplay=1&mute=0'
      ..style.border = 'none'
      ..style.width = '100%'
      ..style.height = '100%'
      ..allowFullscreen = true
      ..allow = 'autoplay; encrypted-media';
    return iframe;
  });
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




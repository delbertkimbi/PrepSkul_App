// Web-specific video helper
// This file is only used on web platform

import 'dart:html' as html show IFrameElement;
import 'dart:ui_web' as ui_web;

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




// Web-specific iframe player
// This file is only used on web platform

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:html' as html;
import 'dart:ui_web' as ui_web show platformViewRegistry;
import 'package:flutter/rendering.dart' show HtmlElementView;
import 'package:prepskul/core/services/log_service.dart';

/// Web iframe player widget
class WebIframePlayer extends StatelessWidget {
  final String videoId;

  const WebIframePlayer({Key? key, required this.videoId}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) {
      return Container(
        color: Colors.black,
        child: const Center(
          child: Text('Web player only available on web platform'),
        ),
      );
    }

    // Use unique viewType with timestamp to avoid conflicts
    final String viewType = 'youtube-iframe-$videoId-${DateTime.now().millisecondsSinceEpoch}';

    try {
      // Register iframe factory
      ui_web.platformViewRegistry.registerViewFactory(viewType, (int viewId) {
        // Use mute=0 since user clicked play button (user interaction allows unmuted autoplay)
        final iframe = html.IFrameElement()
          ..src = 'https://www.youtube.com/embed/$videoId?enablejsapi=1&rel=0&modestbranding=1&autoplay=1&mute=0&controls=1&playsinline=1&fs=0&cc_load_policy=0&iv_load_policy=3&showinfo=0'
          ..style.border = 'none'
          ..style.width = '100%'
          ..style.height = '100%'
          ..style.backgroundColor = 'transparent'
          ..allowFullscreen = false
          ..allow = 'autoplay; encrypted-media';

        iframe.onLoad.listen((_) {
          LogService.debug('YouTube iframe loaded for video: $videoId');
        });

        return iframe;
      });
    } catch (e) {
      LogService.warning('View factory registration: $e');
    }

    return Container(
      color: const Color(0xFF1B2C4F).withOpacity(0.1), // Lighter deep blue background
      width: double.infinity,
      height: double.infinity,
      child: HtmlElementView(viewType: viewType),
    );
  }
}

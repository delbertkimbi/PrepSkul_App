// Stub file for non-web platforms
import 'package:flutter/material.dart';

/// Stub widget for non-web platforms
class WebIframePlayer extends StatelessWidget {
  final String videoId;

  const WebIframePlayer({Key? key, required this.videoId}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      child: const Center(
        child: Text('Web player not available on this platform'),
      ),
    );
  }
}

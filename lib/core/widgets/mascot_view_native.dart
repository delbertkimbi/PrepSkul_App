import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart' as mv;
import 'package:webview_flutter/webview_flutter.dart';
import 'mascot_motion.dart';

class MascotView extends StatefulWidget {
  const MascotView({super.key, required this.clip, required this.size});
  final String clip;
  final double size;
  @override
  State<MascotView> createState() => _MascotViewState();
}

class _MascotViewState extends State<MascotView> with WidgetsBindingObserver {
  WebViewController? _controller;
  bool _ready = false;
  bool _foreground = true;
  bool _animate = true;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _animate =
        TickerMode.valuesOf(context).enabled &&
        !MediaQuery.disableAnimationsOf(context);
    _sync();
  }

  @override
  void didUpdateWidget(MascotView oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _sync();
  }

  Future<void> _sync() async {
    if (!_ready || _controller == null) return;
    final clip = jsonEncode(widget.clip);
    try {
      await _controller!.runJavaScript('''
        (() => { const m = document.querySelector('model-viewer'); if (!m) return;
          if (m.animationName !== $clip) { m.animationName = $clip; m.currentTime = 0; }
          m.animationCrossfadeDuration = ${widget.clip == '33_talk' || widget.clip == '01_idle' ? 80 : 220};
          m.timeScale = ${mascotSpeed(widget.clip)};
          m.${_animate && _foreground ? 'play' : 'pause'}();
        })();
      ''');
    } catch (_) {
      /* A disposed platform view can finish a pending update. */
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    width: widget.size,
    height: widget.size,
    child: IgnorePointer(
      child: mv.ModelViewer(
        src: 'assets/3d/skulmate.glb',
        alt: 'Mate',
        cameraControls: false,
        disableZoom: true,
        ar: false,
        cameraOrbit: '0deg 85deg 7m',
        cameraTarget: widget.clip == '21_explaining'
            ? '0.25m 1.7m 0m'
            : '0m 1.7m 0m',
        fieldOfView: '30deg',
        backgroundColor: Colors.transparent,
        shadowIntensity: 0.35,
        exposure: 1,
        animationName: widget.clip,
        autoPlay: _animate && _foreground,
        animationCrossfadeDuration: 120,
        relatedCss:
            'model-viewer::part(default-progress-bar) { display:none; }',
        debugLogging: false,
        onWebViewCreated: (controller) {
          _controller = controller;
        },
        javascriptChannels: {
          mv.JavascriptChannel(
            'MateReady',
            onMessageReceived: (_) {
              _ready = true;
              _sync();
            },
          ),
        },
        relatedJs:
            "document.querySelector('model-viewer').addEventListener('load', () => MateReady.postMessage('ready'));",
      ),
    ),
  );
}

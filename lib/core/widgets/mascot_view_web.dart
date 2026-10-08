import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;
import 'mascot_motion.dart';

class MascotView extends StatefulWidget {
  const MascotView({super.key, required this.clip, required this.size});
  final String clip;
  final double size;
  @override
  State<MascotView> createState() => _MascotViewState();
}

class _MascotViewState extends State<MascotView> {
  web.HTMLElement? _element;
  late final JSFunction _onLoad;
  late final JSFunction _visibility;
  bool _animate = true;
  bool _visible = true;
  web.IntersectionObserver? _observer;
  @override
  void initState() {
    super.initState();
    _onLoad = ((web.Event _) {
      _sync();
    }).toJS;
    _visibility = ((web.Event _) {
      _sync();
    }).toJS;
    web.document.addEventListener('visibilitychange', _visibility);
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

  void _sync() {
    final m = _element;
    if (m == null) return;
    m.setAttribute('animation-name', widget.clip);
    m.setAttribute(
      'camera-target',
      widget.clip == '21_explaining' ? '0.25m 1.7m 0m' : '0m 1.7m 0m',
    );
    m.setProperty('timeScale'.toJS, mascotSpeed(widget.clip).toJS);
    m.setAttribute(
      'animation-crossfade-duration',
      widget.clip == '33_talk' || widget.clip == '01_idle' ? '80' : '220',
    );
    if (m.hasProperty('loaded'.toJS).toDart &&
        m.getProperty<JSBoolean>('loaded'.toJS).toDart) {
      m.callMethod<JSAny?>(
        (_animate && _visible && !web.document.hidden ? 'play' : 'pause').toJS,
      );
    }
  }

  void _created(Object element) {
    final m = element as web.HTMLElement;
    _element = m;
    m.style.width = '100%';
    m.style.height = '100%';
    m.style.pointerEvents = 'none';
    m.setAttribute('src', 'assets/assets/3d/skulmate.glb?v=soft-limbs-5');
    m.setAttribute('camera-orbit', '0deg 85deg 7m');
    m.setAttribute('camera-target', '0m 1.7m 0m');
    m.setAttribute('field-of-view', '30deg');
    m.setAttribute('shadow-intensity', '0.35');
    m.setAttribute('alt', 'Mate');
    m.addEventListener('load', _onLoad);
    _observer = web.IntersectionObserver(
      ((
            JSArray<web.IntersectionObserverEntry> entries,
            web.IntersectionObserver _,
          ) {
            _visible = entries.toDart.first.isIntersecting;
            _sync();
          })
          .toJS,
    )..observe(m);
    _sync();
  }

  @override
  void dispose() {
    _observer?.disconnect();
    _element?.removeEventListener('load', _onLoad);
    web.document.removeEventListener('visibilitychange', _visibility);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    width: widget.size,
    height: widget.size,
    child: HtmlElementView.fromTagName(
      tagName: 'model-viewer',
      onElementCreated: _created,
    ),
  );
}

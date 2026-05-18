import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:pdfx/pdfx.dart';

/// In-call PDF viewer for tutor-uploaded materials (bytes loaded via HTTPS URL).
class SessionMaterialsPdfPanel extends StatefulWidget {
  const SessionMaterialsPdfPanel({
    super.key,
    required this.pdfUrl,
    required this.pdfPageIndexZeroBased,
    this.onTutorPageChanged,
  });

  final String pdfUrl;
  /// Matches [WorkspaceViewState.pdfPageIndex] (0-based).
  final int pdfPageIndexZeroBased;
  /// Tutor only: fired when the visible page changes (0-based index).
  final ValueChanged<int>? onTutorPageChanged;

  @override
  State<SessionMaterialsPdfPanel> createState() =>
      _SessionMaterialsPdfPanelState();
}

class _SessionMaterialsPdfPanelState extends State<SessionMaterialsPdfPanel> {
  PdfControllerPinch? _controller;

  Future<Uint8List> _fetchBytes(String url) async {
    final res = await http.get(Uri.parse(url));
    if (res.statusCode != 200) {
      throw Exception('Could not load PDF (HTTP ${res.statusCode})');
    }
    return res.bodyBytes;
  }

  void _attachController(String url) {
    _controller?.dispose();
    _controller = PdfControllerPinch(
      document: PdfDocument.openData(_fetchBytes(url)),
      initialPage: widget.pdfPageIndexZeroBased + 1,
    );
  }

  @override
  void initState() {
    super.initState();
    _attachController(widget.pdfUrl);
  }

  @override
  void didUpdateWidget(SessionMaterialsPdfPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pdfUrl != widget.pdfUrl) {
      setState(() => _attachController(widget.pdfUrl));
      return;
    }
    if (oldWidget.pdfPageIndexZeroBased != widget.pdfPageIndexZeroBased &&
        _controller != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _controller == null) return;
        // [PdfControllerPinch.jumpToPage] treats its argument as a 0-based index.
        _controller!.jumpToPage(widget.pdfPageIndexZeroBased);
      });
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = _controller;
    if (c == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return PdfViewPinch(
      controller: c,
      onPageChanged: widget.onTutorPageChanged == null
          ? null
          : (pageOneBased) {
              widget.onTutorPageChanged!(pageOneBased - 1);
            },
      builders: PdfViewPinchBuilders<DefaultBuilderOptions>(
        options: const DefaultBuilderOptions(),
        documentLoaderBuilder: (_) => const Center(
          child: CircularProgressIndicator(color: Colors.white54),
        ),
        errorBuilder: (_, error) => Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Could not display PDF.\n$error',
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
        ),
      ),
      backgroundDecoration: const BoxDecoration(color: Color(0xFF1a2336)),
    );
  }
}

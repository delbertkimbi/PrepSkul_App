import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_fonts/google_fonts.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';

import 'package:prepskul/core/theme/app_theme.dart';

import '../services/incall_chat_realtime.dart';

/// In-call ephemeral chat (Meet-style). Not persisted when the call ends.
class IncallChatPanel extends StatefulWidget {
  const IncallChatPanel({
    super.key,
    required this.sync,
    required this.localUserId,
    required this.localDisplayName,
    required this.onClose,
    this.railMode = false,
    this.peerLabel = 'participant',
  });

  final IncallChatRealtime sync;
  final String localUserId;
  final String localDisplayName;
  final VoidCallback onClose;
  final bool railMode;
  final String peerLabel;

  @override
  State<IncallChatPanel> createState() => _IncallChatPanelState();
}

class _IncallChatPanelState extends State<IncallChatPanel> {
  static const int _kSenderBreakGapMs = 5 * 60 * 1000; // 5 minutes
  static final Map<String, List<IncallChatMessage>> _sessionMessageCache =
      <String, List<IncallChatMessage>>{};

  final TextEditingController _composer = TextEditingController();
  final ScrollController _scroll = ScrollController();
  final List<IncallChatMessage> _items = [];
  StreamSubscription<IncallChatMessage>? _sub;
  final Set<String> _seenIds = {};

  @override
  void initState() {
    super.initState();
    final cached = _sessionMessageCache[widget.sync.sessionId];
    if (cached != null && cached.isNotEmpty) {
      _items.addAll(cached);
      for (final message in cached) {
        _seenIds.add(message.messageId);
      }
    }
    _sub = widget.sync.messages.listen(_onIncoming);
  }

  void _onIncoming(IncallChatMessage m) {
    if (_seenIds.contains(m.messageId)) return;
    _seenIds.add(m.messageId);
    if (!mounted) return;
    setState(() => _items.add(m));
    _sessionMessageCache[widget.sync.sessionId] = List<IncallChatMessage>.from(
      _items,
    );
    _scrollToEnd();
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _composer.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final trimmed = _composer.text.trim();
    if (trimmed.isEmpty) return;

    final mid = await widget.sync.send(
      fromUserId: widget.localUserId,
      displayName: widget.localDisplayName,
      text: trimmed,
    );
    if (!mounted || mid == null) return;

    if (!_seenIds.contains(mid)) {
      _seenIds.add(mid);
      setState(() {
        _items.add(
          IncallChatMessage(
            fromUserId: widget.localUserId,
            displayName: widget.localDisplayName,
            text: trimmed,
            sentAtMs: DateTime.now().millisecondsSinceEpoch,
            messageId: mid,
          ),
        );
      });
      _sessionMessageCache[widget.sync.sessionId] =
          List<IncallChatMessage>.from(_items);
      _scrollToEnd();
    }
    _composer.clear();
  }

  Widget _emptyHint() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.forum_outlined,
              size: widget.railMode ? 36 : 40,
              color: Colors.white.withOpacity(0.35),
            ),
            const SizedBox(height: 10),
            Text(
              'Say hi or share a quick note with your ${widget.peerLabel}.',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                color: Colors.white60,
                fontSize: 13,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final keyboardOpen = mq.viewInsets.bottom > 0;
    final showCompactHeader = !widget.railMode && keyboardOpen;
    final header = Padding(
      padding: EdgeInsets.fromLTRB(
        12,
        showCompactHeader
            ? 6
            : widget.railMode
            ? 10
            : 8,
        8,
        showCompactHeader ? 4 : 6,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'In-call messages',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: showCompactHeader ? 16 : 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (!showCompactHeader) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Messages with your ${widget.peerLabel} are not saved when this lesson ends.',
                    style: GoogleFonts.poppins(
                      color: Colors.white60,
                      fontSize: 11.5,
                      height: 1.35,
                    ),
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            tooltip: 'Close',
            onPressed: widget.onClose,
            icon: const Icon(Icons.close, color: Colors.white70),
          ),
        ],
      ),
    );

    final Widget messageList = _items.isNotEmpty
        ? ListView.builder(
            controller: _scroll,
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            itemCount: _items.length,
            itemBuilder: (context, i) => _bubble(i),
          )
        : _emptyHint();

    const fieldFill = Color(0xFF1A2438);
    const borderIdle = Color(0x33FFFFFF);

    final composer = Container(
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 10),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.22),
        border: Border(top: BorderSide(color: Colors.white.withOpacity(0.08))),
      ),
      child: SafeArea(
        top: false,
        bottom: widget.railMode,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: _composer,
                minLines: 1,
                maxLines: 4,
                maxLength: IncallChatRealtime.maxMessageLength,
                cursorColor: Colors.white,
                style: GoogleFonts.poppins(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  counterText: '',
                  hintText: 'Message your ${widget.peerLabel}',
                  hintStyle: GoogleFonts.poppins(
                    color: Colors.white54,
                    fontSize: 14,
                  ),
                  filled: true,
                  fillColor: fieldFill,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(22),
                    borderSide: const BorderSide(color: borderIdle),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(22),
                    borderSide: const BorderSide(color: borderIdle),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(22),
                    borderSide: const BorderSide(
                      color: Colors.white54,
                      width: 1.5,
                    ),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                ),
                onSubmitted: (_) => _send(),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              style: IconButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
              ),
              onPressed: _send,
              icon: const Icon(Icons.send_rounded, size: 20),
            ),
          ],
        ),
      ),
    );

    final shell = AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(
        bottom: widget.railMode ? 0 : mq.viewInsets.bottom,
      ),
      child: Material(
        color: const Color(0xFF121A2E),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            header,
            Expanded(child: messageList),
            composer,
          ],
        ),
      ),
    );

    if (kIsWeb) {
      return PointerInterceptor(child: shell);
    }
    return shell;
  }

  Widget _bubble(int i) {
    final m = _items[i];
    final mine = m.fromUserId == widget.localUserId;
    final prev = i > 0 ? _items[i - 1] : null;
    final sameSenderAsPrev = prev != null && prev.fromUserId == m.fromUserId;
    final largeGapBefore =
        prev != null && (m.sentAtMs - prev.sentAtMs) > _kSenderBreakGapMs;
    final showSenderHeader =
        prev == null || !sameSenderAsPrev || (!mine && largeGapBefore);
    final senderLabel = mine
        ? 'You'
        : (m.displayName.trim().isEmpty ? 'Participant' : m.displayName);
    final bubbleBg = mine ? const Color(0xFF2451B2) : const Color(0xFF3C2A5F);

    final nameStyle = GoogleFonts.poppins(
      color: mine ? const Color(0xFFF4F8FF) : const Color(0xFFEDE3FF),
      fontSize: 11,
      fontWeight: FontWeight.w600,
    );

    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        constraints: BoxConstraints(
          maxWidth: widget.railMode
              ? 260
              : (MediaQuery.sizeOf(context).width < 420 ? 250 : 320),
        ),
        decoration: BoxDecoration(
          color: bubbleBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withOpacity(0.12)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (showSenderHeader) ...[
              Text(senderLabel, style: nameStyle),
              const SizedBox(height: 4),
            ],
            Text(
              m.text,
              style: GoogleFonts.poppins(
                color: const Color(0xFFF8FAFF),
                fontSize: 13.5,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

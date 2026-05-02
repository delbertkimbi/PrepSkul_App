import 'package:flutter/material.dart';

/// Reactions panel with emoji selection
/// Shows a compact horizontally-scrollable emoji strip
class ReactionsPanel extends StatelessWidget {
  final Function(String emoji) onEmojiSelected;
  final VoidCallback onClose;

  const ReactionsPanel({
    Key? key,
    required this.onEmojiSelected,
    required this.onClose,
  }) : super(key: key);

  static const List<String> _emojis = [
    '👍', '❤️', '😂', '👏', '🎉', '🔥',
    '😮', '😢', '🙌', '💯', '✨', '🎊',
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      width: 280, // Shows roughly 5 emojis, horizontal scroll for the rest.
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _emojis.length,
        physics: const BouncingScrollPhysics(),
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (context, index) {
          return _EmojiButton(
            emoji: _emojis[index],
            onTap: () {
              onEmojiSelected(_emojis[index]);
              onClose();
            },
          );
        },
      ),
    );
  }
}

class _EmojiButton extends StatefulWidget {
  final String emoji;
  final VoidCallback onTap;

  const _EmojiButton({
    Key? key,
    required this.emoji,
    required this.onTap,
  }) : super(key: key);

  @override
  State<_EmojiButton> createState() => _EmojiButtonState();
}

class _EmojiButtonState extends State<_EmojiButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.8).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) {
        _controller.reverse();
        widget.onTap();
      },
      onTapCancel: () => _controller.reverse(),
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: SizedBox(
          width: 50,
          height: 50,
          child: Center(
            child: Text(
              widget.emoji,
              style: const TextStyle(fontSize: 30),
            ),
          ),
        ),
      ),
    );
  }
}


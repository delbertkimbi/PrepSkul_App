import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:prepskul/core/services/supabase_service.dart';
import 'package:prepskul/core/theme/app_theme.dart';
import 'package:prepskul/core/utils/profile_display_utils.dart';

/// Current user's profile photo for SkulMate game chrome.
class SkulMateProfileAvatar extends StatefulWidget {
  final double size;

  /// When true, shows a settings icon instead of initials when no photo exists.
  final bool forGameAppBar;

  final String? userId;

  const SkulMateProfileAvatar({
    super.key,
    this.size = 32,
    this.forGameAppBar = false,
    this.userId,
  });

  @override
  State<SkulMateProfileAvatar> createState() => _SkulMateProfileAvatarState();
}

class _SkulMateProfileAvatarState extends State<SkulMateProfileAvatar> {
  String? _avatarUrl;
  String _displayName = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final userId = widget.userId ?? SupabaseService.client.auth.currentUser?.id;
    if (userId == null || userId.isEmpty) {
      if (mounted) setState(() {});
      return;
    }

    try {
      final profile = await SupabaseService.client
          .from('profiles')
          .select('avatar_url, full_name, email')
          .eq('id', userId)
          .maybeSingle();
      final url = await ProfileDisplayUtils.resolveAvatarUrl(
        profile?['avatar_url'] as String?,
        userId: userId,
      );
      final name = ProfileDisplayUtils.resolveDisplayName(
        primary: profile?['full_name'] as String?,
        profile: profile,
        fallback: '',
      );
      if (!mounted) return;
      setState(() {
        _avatarUrl = url;
        _displayName = name;
      });
    } catch (_) {
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final url = _avatarUrl;
    if (url != null && url.trim().isNotEmpty) {
      return ClipOval(
        child: CachedNetworkImage(
          imageUrl: url,
          width: widget.size,
          height: widget.size,
          fit: BoxFit.cover,
          placeholder: (_, __) => _fallback(),
          errorWidget: (_, __, ___) => _fallback(),
        ),
      );
    }
    return _fallback();
  }

  Widget _fallback() {
    if (widget.forGameAppBar) {
      return Icon(
        Icons.settings,
        size: widget.size * 0.57,
        color: Colors.white,
      );
    }

    final initials = _initials(_displayName);
    if (initials.isNotEmpty) {
      return Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppTheme.primaryColor.withValues(alpha: 0.15),
        ),
        alignment: Alignment.center,
        child: Text(
          initials,
          style: GoogleFonts.poppins(
            fontSize: widget.size * 0.38,
            fontWeight: FontWeight.w600,
            color: AppTheme.primaryColor,
          ),
        ),
      );
    }

    return Icon(
      Icons.person_rounded,
      size: widget.size * 0.5,
      color: AppTheme.primaryColor,
    );
  }

  String _initials(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '';
    final parts = trimmed.split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts[1][0]}'.toUpperCase();
    }
    return parts.first
        .substring(0, parts.first.length >= 2 ? 2 : 1)
        .toUpperCase();
  }
}

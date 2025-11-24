import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/pricing_service.dart';
import '../screens/tutor_detail_screen.dart';

class TutorCard extends StatelessWidget {
  final Map<String, dynamic> tutor;

  const TutorCard({Key? key, required this.tutor}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final name = tutor['full_name'] ?? 'Unknown';
    final rating = (tutor['rating'] ?? 0.0).toDouble();
    final totalReviews = tutor['total_reviews'] ?? 0;
    final bio = tutor['bio'] ?? '';
    final completedSessions = tutor['completed_sessions'] ?? 0;
    
    // Remove "Hello!" from bio if it starts with it (for cards)
    String displayBio = bio;
    if (displayBio.toLowerCase().startsWith('hello!')) {
      displayBio = displayBio.substring(6).trim();
      // Remove "I am" if it follows
      if (displayBio.toLowerCase().startsWith('i am')) {
        displayBio = displayBio.substring(4).trim();
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor, // Use theme surface color for neumorphic
        borderRadius: BorderRadius.circular(16),
        // Neumorphic shadows: light top-left, dark bottom-right
        boxShadow: [
          BoxShadow(
            color: Colors.white.withOpacity(0.7),
            blurRadius: 10,
            offset: const Offset(-4, -4),
            spreadRadius: 0,
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(4, 4),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => TutorDetailScreen(tutor: tutor),
              ),
            );
          },
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Avatar (Larger & clickable)
                    GestureDetector(
                      onTap: () => _showProfileImage(context, tutor),
                      child: Container(
                        width: 70,
                        height: 70,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppTheme.primaryColor.withOpacity(0.1), // Background for fallback
                          border: Border.all(
                            color: AppTheme.primaryColor.withOpacity(0.3),
                            width: 2.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.08),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: ClipOval(
                          child: _buildAvatarImage(
                            tutor['avatar_url'] ?? tutor['profile_photo_url'],
                            name,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  name,
                                  style: GoogleFonts.poppins(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.black,
                                  ),
                                ),
                              ),
                              if (tutor['is_verified'] == true)
                                Icon(
                                  Icons.verified,
                                  size: 18,
                                  color: AppTheme.primaryColor,
                                ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                Icons.star,
                                size: 16,
                                color: Colors.amber[700],
                              ),
                              const SizedBox(width: 4),
                              Text(
                                rating > 0 ? rating.toStringAsFixed(1) : 'N/A',
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black,
                                ),
                              ),
                              if (rating > 0 && totalReviews > 0)
                              Text(
                                ' ($totalReviews)',
                                style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Subjects
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children:
                      (tutor['subjects'] as List?)
                          ?.take(3)
                          .map(
                            (subject) => Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.grey[100],
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                subject.toString(),
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.grey[700],
                                ),
                              ),
                            ),
                          )
                          .toList() ??
                      [],
                ),
                const SizedBox(height: 12),
                // Bio (personal statement, with "Hello!" removed for cards)
                if (displayBio.isNotEmpty)
                Text(
                    displayBio,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: Colors.grey[600],
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 12),
                // Bottom Info Row - Focus on value, not pricing
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Sessions completed (bold as requested)
                    Row(
                      children: [
                        Icon(
                          Icons.school_outlined,
                          size: 16,
                          color: Colors.grey[600],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '$completedSessions',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: Colors.grey[700],
                            fontWeight: FontWeight.w700, // Bold as requested
                          ),
                        ),
                        Text(
                          ' lessons',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    // Subtle monthly estimate (not emphasized)
                    _buildSubtleMonthlyEstimate(tutor),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSubtleMonthlyEstimate(Map<String, dynamic> tutor) {
    // Calculate monthly pricing but display it subtly
    final pricing = PricingService.calculateFromTutorData(tutor);
    final monthlyAmount = pricing['perMonth'] as double;
    final hasDiscount = pricing['hasDiscount'] as bool? ?? false;

    // On cards, show only discount price if available
    if (hasDiscount) {
      return Text(
        'From ${PricingService.formatPrice(monthlyAmount)}/mo',
        style: GoogleFonts.poppins(
          fontSize: 12,
          color: AppTheme.primaryColor,
          fontWeight: FontWeight.w700,
        ),
      );
    }

    return Text(
      'From ${PricingService.formatPrice(monthlyAmount)}/mo',
      style: GoogleFonts.poppins(
        fontSize: 12,
        color: Colors.grey[700],
        fontWeight: FontWeight.w700, // Bold as requested
      ),
    );
  }

  void _showProfileImage(BuildContext context, Map<String, dynamic> tutor) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Stack(
          children: [
            // Profile Image
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.7,
                  maxWidth: MediaQuery.of(context).size.width * 0.9,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: _buildAvatarImage(
                    tutor['avatar_url'] ?? tutor['profile_photo_url'],
                    tutor['full_name'] ?? 'Tutor',
                    isLarge: true,
                  ),
                ),
              ),
            ),
            // Close button
            Positioned(
              top: 10,
              right: 10,
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close, color: Colors.white, size: 24),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatarImage(
    String? avatarUrl,
    String name, {
    bool isLarge = false,
  }) {
    // Check if avatarUrl is a network URL or asset path
    final isNetworkUrl =
        avatarUrl != null &&
        (avatarUrl.startsWith('http://') ||
            avatarUrl.startsWith('https://') ||
            avatarUrl.startsWith('//'));

    if (avatarUrl != null && avatarUrl.isNotEmpty) {
      if (isNetworkUrl) {
        // Use CachedNetworkImage for URLs from Supabase storage
        return CachedNetworkImage(
          imageUrl: avatarUrl,
          fit: BoxFit.cover,
          width: isLarge ? null : 70,
          height: isLarge ? null : 70,
          placeholder: (context, url) => Center(
            child: CircularProgressIndicator(
              color: AppTheme.primaryColor,
              strokeWidth: 2,
            ),
          ),
          errorWidget: (context, url, error) {
            return _buildAvatarPlaceholder(name, isLarge: isLarge);
          },
        );
      } else {
        // Use Image.asset for local asset paths
        return Image.asset(
          avatarUrl,
          fit: BoxFit.cover,
          width: isLarge ? null : 70,
          height: isLarge ? null : 70,
          errorBuilder: (context, error, stackTrace) {
            return _buildAvatarPlaceholder(name, isLarge: isLarge);
          },
        );
      }
    }

    // Fallback to placeholder
    return _buildAvatarPlaceholder(name, isLarge: isLarge);
  }

  Widget _buildAvatarPlaceholder(String name, {bool isLarge = false}) {
    if (isLarge) {
      return Container(
        height: 300,
        width: 300,
        color: AppTheme.primaryColor.withOpacity(0.1),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                name.isNotEmpty ? name[0].toUpperCase() : 'T',
                style: GoogleFonts.poppins(
                  fontSize: 80,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primaryColor,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                name,
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[700],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      color: AppTheme.primaryColor.withOpacity(0.1),
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : 'T',
          style: GoogleFonts.poppins(
            fontSize: 24,
            fontWeight: FontWeight.w600,
            color: AppTheme.primaryColor,
          ),
        ),
      ),
    );
  }
}


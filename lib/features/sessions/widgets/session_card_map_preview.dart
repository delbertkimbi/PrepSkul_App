import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:prepskul/core/theme/app_theme.dart';
import 'package:prepskul/core/utils/geocoding_helper.dart';
import 'package:prepskul/features/sessions/widgets/embedded_map_widget.dart';
import 'package:url_launcher/url_launcher.dart';

/// Compact map strip for onsite rows in session lists (My Sessions, etc.).
class SessionCardMapPreview extends StatelessWidget {
  final String address;
  final String? coordinates;
  final String? locationDescription;
  final double height;
  final VoidCallback? onTap;

  const SessionCardMapPreview({
    super.key,
    required this.address,
    this.coordinates,
    this.locationDescription,
    this.height = 76,
    this.onTap,
  });

  static String? coordinatesFromSession(Map<String, dynamic> session) {
    return (session['onsite_coordinates'] as String?) ??
        GeocodingHelper.extractEmbeddedCoordinates(
          session['location_description'] as String?,
        ) ??
        GeocodingHelper.extractEmbeddedCoordinates(session['address'] as String?) ??
        GeocodingHelper.extractEmbeddedCoordinates(
          session['onsite_address'] as String?,
        );
  }

  static String displayAddressFromSession(Map<String, dynamic> session) {
    final raw = (session['onsite_address'] as String?) ??
        (session['address'] as String?) ??
        (session['location_description'] as String?) ??
        '';
    return GeocodingHelper.stripEmbeddedCoords(raw.trim());
  }

  static bool isOnsiteSession(Map<String, dynamic> session) {
    final location = (session['location'] as String? ?? 'online').toLowerCase();
    return location != 'online' && location != 'hybrid';
  }

  Future<void> _openDirections() async {
    final displayAddress = GeocodingHelper.stripEmbeddedCoords(address);
    var dest = coordinates ??
        GeocodingHelper.extractEmbeddedCoordinates(address) ??
        GeocodingHelper.extractEmbeddedCoordinates(locationDescription);

    if (dest == null || dest.trim().isEmpty) {
      final resolved = await GeocodingHelper.resolve(displayAddress);
      if (resolved != null) {
        dest = '${resolved.lat},${resolved.lng}';
      }
    }

    final uri = dest != null && dest.trim().isNotEmpty
        ? Uri.parse(
            'https://www.google.com/maps/dir/?api=1&destination=$dest&travelmode=driving',
          )
        : Uri.parse(
            'https://www.google.com/maps/dir/?api=1&destination=${Uri.encodeComponent(displayAddress)}&travelmode=driving',
          );

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final displayAddress = GeocodingHelper.stripEmbeddedCoords(address);
    if (displayAddress.isEmpty) return const SizedBox.shrink();

    final coordStr = coordinates ??
        GeocodingHelper.extractEmbeddedCoordinates(address) ??
        GeocodingHelper.extractEmbeddedCoordinates(locationDescription);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap ?? _openDirections,
        borderRadius: BorderRadius.circular(10),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppTheme.softBorder),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(9),
            child: Stack(
              fit: StackFit.passthrough,
              children: [
                EmbeddedMapWidget(
                  address: displayAddress,
                  coordinates: coordStr,
                  height: height,
                  showMarker: true,
                ),
                Positioned(
                  left: 8,
                  bottom: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.92),
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.near_me_outlined,
                          size: 13,
                          color: AppTheme.primaryColor,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Directions',
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

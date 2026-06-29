import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:prepskul/core/theme/app_theme.dart';
import 'package:prepskul/core/utils/responsive_helper.dart';
import 'package:prepskul/core/utils/geocoding_helper.dart';
import 'package:prepskul/features/sessions/widgets/embedded_map_widget.dart';
import 'package:url_launcher/url_launcher.dart';

/// Location card with optional Leaflet map preview and Google Maps directions CTA.
class OnsiteLocationCard extends StatelessWidget {
  final String address;
  final String? coordinates;
  final String? statusLine;
  final String? locationDescription;
  final bool showMapPreview;
  final String? currentLocation;
  final String? userReferenceAddress;

  const OnsiteLocationCard({
    super.key,
    required this.address,
    this.coordinates,
    this.statusLine,
    this.locationDescription,
    this.showMapPreview = true,
    this.currentLocation,
    this.userReferenceAddress,
  });

  Future<void> _openDirections(BuildContext context) async {
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
    } else if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open Google Maps. Try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final pad = ResponsiveHelper.cardInnerPadding(context);
    final displayAddress = GeocodingHelper.stripEmbeddedCoords(address);
    final coordStr = coordinates ??
        GeocodingHelper.extractEmbeddedCoordinates(address) ??
        GeocodingHelper.extractEmbeddedCoordinates(locationDescription);
    final atUserLocation = userReferenceAddress != null &&
        !GeocodingHelper.shouldShowMapForSession(
          sessionAddress: displayAddress,
          userAddress: userReferenceAddress,
        );
    final effectiveShowMap = showMapPreview && !atUserLocation;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.softBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(pad),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.location_on, color: AppTheme.primaryColor, size: 22),
                const SizedBox(width: 8),
                Text(
                  'Session location',
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textDark,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              displayAddress,
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppTheme.textDark,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              atUserLocation
                  ? 'Session at your location'
                  : 'Open directions when you\'re ready to leave',
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: AppTheme.textMedium,
              ),
            ),
            if (statusLine != null && statusLine!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                statusLine!,
                style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.textMedium),
              ),
            ],
            if (locationDescription != null && locationDescription!.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                locationDescription!,
                style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.textMedium, height: 1.4),
              ),
            ],
            if (effectiveShowMap) ...[
              const SizedBox(height: 14),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: EmbeddedMapWidget(
                  address: displayAddress,
                  coordinates: coordStr,
                  height: 140,
                  currentLocation: currentLocation,
                ),
              ),
            ],
            if (!atUserLocation) ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _openDirections(context),
                icon: const Icon(Icons.directions, size: 18),
                label: Text(
                  'View directions',
                  style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
            ],
          ],
        ),
      ),
    );
  }
}

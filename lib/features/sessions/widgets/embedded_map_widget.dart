import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:prepskul/core/theme/app_theme.dart';
import 'package:prepskul/core/services/log_service.dart';
import 'package:geocoding/geocoding.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
// Conditional import for web map helpers
import 'web_map_helper_stub.dart'
    if (dart.library.html) 'web_map_helper.dart'
    as web_map;
// Mobile: Use flutter_map (Leaflet for Flutter)
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

/// Embedded Map Widget
///
/// Shows an embedded map view with the session location marked.
/// On web: Uses iframe (Leaflet) to keep users in-app
/// On mobile: Uses flutter_map (Leaflet for Flutter) - open-source, no API key needed
/// Falls back to a placeholder if maps are not configured or unavailable.
class EmbeddedMapWidget extends StatefulWidget {
  final String address;
  final String? coordinates; // Optional: "lat,lon" format
  final double height;
  final bool showMarker;
  final String? currentLocation; // Optional current location for routing

  const EmbeddedMapWidget({
    Key? key,
    required this.address,
    this.coordinates,
    this.height = 200,
    this.showMarker = true,
    this.currentLocation,
  }) : super(key: key);

  @override
  State<EmbeddedMapWidget> createState() => _EmbeddedMapWidgetState();
}

class _EmbeddedMapWidgetState extends State<EmbeddedMapWidget> {
  bool _isLoading = true;
  bool _hasError = false;
  String? _errorMessage;
  double? _latitude;
  double? _longitude;

  @override
  void initState() {
    super.initState();
    _initializeMap();
  }

  Future<void> _initializeMap() async {
    try {
      // Try to parse coordinates if provided
      if (widget.coordinates != null) {
        final parts = widget.coordinates!.split(',');
        if (parts.length == 2) {
          final lat = double.tryParse(parts[0].trim());
          final lon = double.tryParse(parts[1].trim());
          if (lat != null && lon != null) {
            setState(() {
              _latitude = lat;
              _longitude = lon;
              _isLoading = false;
            });
            return;
          }
        }
      }

      // Try to geocode the address
      try {
        final locations = await locationFromAddress(widget.address);
        if (locations.isNotEmpty) {
          setState(() {
            _latitude = locations.first.latitude;
            _longitude = locations.first.longitude;
            _isLoading = false;
          });
          return;
        }
      } catch (e) {
        LogService.warning('Geocoding failed: $e');
      }

      // If we can't get coordinates, show placeholder
      setState(() {
        _isLoading = false;
        _hasError = true;
        _errorMessage = 'Unable to locate address on map';
      });
    } catch (e) {
      LogService.error('Error initializing map: $e');
      setState(() {
        _isLoading = false;
        _hasError = true;
        _errorMessage = 'Map initialization failed';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        height: widget.height,
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
              ),
              const SizedBox(height: 12),
              Text(
                'Loading map...',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_hasError || _latitude == null || _longitude == null) {
      return Container(
        height: widget.height,
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.map_outlined,
                size: 48,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 8),
              Text(
                'Map Preview Unavailable',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Tap "View Map" to open in maps app',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Web: Use iframe to keep users in-app
    if (kIsWeb) {
      final viewType = 'map-iframe-${widget.address.hashCode}-${_latitude!.toStringAsFixed(4)}-${_longitude!.toStringAsFixed(4)}';
      
      try {
        // Use Leaflet (free, open-source, no API key needed, privacy-friendly)
        if (widget.currentLocation != null) {
          // Use Leaflet with routing if current location available
          web_map.registerLeafletRoutingIframe(
            viewType,
            widget.address,
            coordinates: widget.coordinates ?? '$_latitude,$_longitude',
            currentLocation: widget.currentLocation,
          );
        } else {
          // Use simple Leaflet map
          web_map.registerLeafletMapIframe(
            viewType,
            widget.address,
            coordinates: widget.coordinates ?? '$_latitude,$_longitude',
          );
        }
        
        // Return HtmlElementView with the registered iframe
        return Container(
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[300]!),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: HtmlElementView(viewType: viewType),
          ),
        );
      } catch (e) {
        LogService.warning('Error registering map iframe: $e');
        // Fallback to placeholder if iframe registration fails
      }
    }
    
    // Mobile: Use flutter_map (Leaflet for Flutter) - open-source, no API key needed
    return Container(
      height: widget.height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: FlutterMap(
          options: MapOptions(
            initialCenter: LatLng(_latitude!, _longitude!),
            initialZoom: 15.0,
            minZoom: 5.0,
            maxZoom: 18.0,
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
            ),
          ),
          children: [
            // OpenStreetMap tile layer
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.prepskul.app',
              maxZoom: 19,
              tileProvider: NetworkTileProvider(),
            ),
            // Marker layer
            if (widget.showMarker)
              MarkerLayer(
                markers: [
                  Marker(
                    point: LatLng(_latitude!, _longitude!),
                    width: 40,
                    height: 40,
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.location_on,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
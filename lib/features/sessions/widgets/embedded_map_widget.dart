import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_map/flutter_map.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:prepskul/core/services/log_service.dart';
import 'package:prepskul/core/theme/app_theme.dart';
import 'package:prepskul/features/sessions/services/location_checkin_service.dart';
import 'package:prepskul/features/sessions/services/onsite_geocoding_service.dart';

import 'web_map_helper_stub.dart'
    if (dart.library.html) 'web_map_helper.dart'
    as web_map;

/// In-app map with venue marker and optional route from current GPS (OSRM).
class EmbeddedMapWidget extends StatefulWidget {
  final String address;
  final String? coordinates;
  final double height;
  final bool showMarker;
  final String? currentLocation;
  final bool showRouteFromCurrentLocation;

  const EmbeddedMapWidget({
    super.key,
    required this.address,
    this.coordinates,
    this.height = 200,
    this.showMarker = true,
    this.currentLocation,
    this.showRouteFromCurrentLocation = false,
  });

  @override
  State<EmbeddedMapWidget> createState() => _EmbeddedMapWidgetState();
}

class _EmbeddedMapWidgetState extends State<EmbeddedMapWidget> {
  bool _isLoading = true;
  bool _hasError = false;
  double? _latitude;
  double? _longitude;
  LatLng? _userPoint;
  List<LatLng> _routePoints = [];

  @override
  void initState() {
    super.initState();
    _initializeMap();
  }

  @override
  void didUpdateWidget(EmbeddedMapWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentLocation != widget.currentLocation ||
        oldWidget.coordinates != widget.coordinates ||
        oldWidget.address != widget.address ||
        oldWidget.showRouteFromCurrentLocation != widget.showRouteFromCurrentLocation) {
      _isLoading = true;
      _initializeMap();
    }
  }

  Future<void> _initializeMap() async {
    try {
      double? lat;
      double? lon;

      if (widget.coordinates != null) {
        final parts = widget.coordinates!.split(',');
        if (parts.length == 2) {
          lat = double.tryParse(parts[0].trim());
          lon = double.tryParse(parts[1].trim());
        }
      }

      if (lat == null || lon == null) {
        final coords = await OnsiteGeocodingService.geocodeAddress(widget.address);
        if (coords != null) {
          lat = coords['latitude'];
          lon = coords['longitude'];
        }
      }

      if (lat == null || lon == null) {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _hasError = true;
          });
        }
        return;
      }

      LatLng? userPoint;
      if (widget.showRouteFromCurrentLocation) {
        userPoint = await _resolveUserPoint();
        if (userPoint != null) {
          _routePoints = await _fetchRoute(userPoint, LatLng(lat, lon));
        }
      }

      if (mounted) {
        setState(() {
          _latitude = lat;
          _longitude = lon;
          _userPoint = userPoint;
          _isLoading = false;
        });
      }
    } catch (e) {
      LogService.error('Error initializing map: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
      }
    }
  }

  Future<LatLng?> _resolveUserPoint() async {
    if (widget.currentLocation != null) {
      final parts = widget.currentLocation!.split(',');
      if (parts.length == 2) {
        final lat = double.tryParse(parts[0].trim());
        final lon = double.tryParse(parts[1].trim());
        if (lat != null && lon != null) return LatLng(lat, lon);
      }
    }
    try {
      final pos = await LocationCheckInService.getCurrentLocation();
      return LatLng(pos.latitude, pos.longitude);
    } catch (e) {
      LogService.warning('Map: could not read current location: $e');
      return null;
    }
  }

  Future<List<LatLng>> _fetchRoute(LatLng from, LatLng to) async {
    try {
      final url =
          'https://router.project-osrm.org/route/v1/driving/${from.longitude},${from.latitude};${to.longitude},${to.latitude}?overview=full&geometries=geojson';
      final res = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 12));
      if (res.statusCode != 200) return [];
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final routes = data['routes'] as List?;
      if (routes == null || routes.isEmpty) return [];
      final geometry = routes[0]['geometry'] as Map<String, dynamic>?;
      final coords = geometry?['coordinates'] as List?;
      if (coords == null) return [];
      return coords
          .map((c) {
            final pair = c as List;
            return LatLng((pair[1] as num).toDouble(), (pair[0] as num).toDouble());
          })
          .toList();
    } catch (e) {
      LogService.warning('OSRM route failed: $e');
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return _box(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
            ),
            const SizedBox(height: 12),
            Text('Loading map…', style: GoogleFonts.poppins(color: Colors.grey[600])),
          ],
        ),
      );
    }

    if (_hasError || _latitude == null || _longitude == null) {
      return _box(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.map_outlined, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 8),
            Text(
              'Map preview loading…',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: Colors.grey[700]),
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'We are resolving "${widget.address}". Use Directions below if the map is still empty.',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[600]),
              ),
            ),
          ],
        ),
      );
    }

    final dest = LatLng(_latitude!, _longitude!);

    if (kIsWeb) {
      final viewType =
          'map-iframe-${widget.address.hashCode}-${_latitude!.toStringAsFixed(4)}';
      try {
        if (_userPoint != null) {
          web_map.registerLeafletRoutingIframe(
            viewType,
            widget.address,
            coordinates: '${_latitude},${_longitude}',
            currentLocation: '${_userPoint!.latitude},${_userPoint!.longitude}',
          );
        } else {
          web_map.registerLeafletMapIframe(
            viewType,
            widget.address,
            coordinates: '${_latitude},${_longitude}',
          );
        }
        return _box(
          child: HtmlElementView(viewType: viewType),
        );
      } catch (e) {
        LogService.warning('Web map iframe failed: $e');
      }
    }

    final markers = <Marker>[
      if (_userPoint != null)
        Marker(
          point: _userPoint!,
          width: 36,
          height: 36,
          child: const Icon(Icons.my_location, color: Colors.blue, size: 28),
        ),
      if (widget.showMarker)
        Marker(
          point: dest,
          width: 40,
          height: 40,
          child: Container(
            decoration: BoxDecoration(
              color: AppTheme.primaryColor,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
            ),
            child: const Icon(Icons.location_on, color: Colors.white, size: 22),
          ),
        ),
    ];

  final fitBounds = _routePoints.isNotEmpty
        ? LatLngBounds.fromPoints([..._routePoints, if (_userPoint != null) _userPoint!, dest])
        : (_userPoint != null
            ? LatLngBounds.fromPoints([_userPoint!, dest])
            : null);

    return _box(
      child: FlutterMap(
        options: MapOptions(
          initialCenter: dest,
          initialZoom: 14,
          minZoom: 5,
          maxZoom: 18,
          interactionOptions: const InteractionOptions(
            flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
          ),
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.prepskul.app',
          ),
          if (_routePoints.isNotEmpty)
            PolylineLayer(
              polylines: [
                Polyline(
                  points: _routePoints,
                  color: AppTheme.primaryColor,
                  strokeWidth: 4,
                ),
              ],
            ),
          MarkerLayer(markers: markers),
        ],
      ),
    );
  }

  Widget _box({required Widget child}) {
    return Container(
      height: widget.height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.softBorder),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: child,
      ),
    );
  }
}

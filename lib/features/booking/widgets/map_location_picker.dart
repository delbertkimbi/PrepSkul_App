import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:prepskul/core/theme/app_theme.dart';
import 'package:prepskul/core/services/log_service.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

/// Map Location Picker Widget
///
/// Interactive map widget that allows users to:
/// - Tap/pan map to select location
/// - Drag marker to adjust position
/// - Reverse geocode to get address
/// - Edit address after selection
/// - Store both coordinates and address
class MapLocationPicker extends StatefulWidget {
  final String? initialAddress;
  final String? initialCoordinates; // "lat,lon" format
  final String? initialLocationDescription;
  final Function(String address, String coordinates, String? locationDescription)? onLocationSelected;
  final double height;

  const MapLocationPicker({
    super.key,
    this.initialAddress,
    this.initialCoordinates,
    this.initialLocationDescription,
    this.onLocationSelected,
    this.height = 400,
  });

  @override
  State<MapLocationPicker> createState() => _MapLocationPickerState();
}

class _MapLocationPickerState extends State<MapLocationPicker> {
  final MapController _mapController = MapController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _locationDescriptionController = TextEditingController();
  
  LatLng? _selectedLocation;
  String? _selectedAddress;
  bool _isLoading = true;
  bool _isReverseGeocoding = false;
  bool _isGettingCurrentLocation = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialLocationDescription != null) {
      _locationDescriptionController.text = widget.initialLocationDescription!;
    }
    _initializeLocation();
  }

  Future<void> _initializeLocation() async {
    try {
      // If initial coordinates provided, use them
      if (widget.initialCoordinates != null) {
        final parts = widget.initialCoordinates!.split(',');
        if (parts.length == 2) {
          final lat = double.tryParse(parts[0].trim());
          final lon = double.tryParse(parts[1].trim());
          if (lat != null && lon != null) {
            setState(() {
              _selectedLocation = LatLng(lat, lon);
              _selectedAddress = widget.initialAddress;
              _addressController.text = widget.initialAddress ?? '';
              _isLoading = false;
            });
            _mapController.move(_selectedLocation!, 15.0);
            return;
          }
        }
      }

      // If initial address provided, geocode it
      if (widget.initialAddress != null && widget.initialAddress!.isNotEmpty) {
        try {
          final locations = await locationFromAddress(widget.initialAddress!);
          if (locations.isNotEmpty) {
            final location = locations.first;
            setState(() {
              _selectedLocation = LatLng(location.latitude, location.longitude);
              _selectedAddress = widget.initialAddress;
              _addressController.text = widget.initialAddress!;
              _isLoading = false;
            });
            _mapController.move(_selectedLocation!, 15.0);
            return;
          }
        } catch (e) {
          LogService.warning('Geocoding failed: $e');
        }
      }

      // Default to Douala, Cameroon (center of Cameroon)
      final defaultLocation = LatLng(4.0511, 9.7679);
      setState(() {
        _selectedLocation = defaultLocation;
        _isLoading = false;
      });
      _mapController.move(defaultLocation, 12.0);
      _reverseGeocode(defaultLocation);
    } catch (e) {
      LogService.error('Error initializing map location picker: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _getCurrentLocation() async {
    setState(() => _isGettingCurrentLocation = true);
    try {
      // Check permissions
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Location services are disabled. Please enable them in your device settings.',
                style: GoogleFonts.poppins(),
              ),
              backgroundColor: Colors.orange,
            ),
          );
        }
        setState(() => _isGettingCurrentLocation = false);
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Location permission denied. Please enable location access in settings.',
                  style: GoogleFonts.poppins(),
                ),
                backgroundColor: Colors.orange,
              ),
            );
          }
          setState(() => _isGettingCurrentLocation = false);
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Location permission permanently denied. Please enable it in app settings.',
                style: GoogleFonts.poppins(),
              ),
              backgroundColor: Colors.orange,
            ),
          );
        }
        setState(() => _isGettingCurrentLocation = false);
        return;
      }

      // Get current position
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      final location = LatLng(position.latitude, position.longitude);
      setState(() {
        _selectedLocation = location;
        _isGettingCurrentLocation = false;
      });
      _mapController.move(location, 15.0);
      _reverseGeocode(location);
    } catch (e) {
      LogService.error('Error getting current location: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Could not get your current location. Please select a location on the map.',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
      setState(() => _isGettingCurrentLocation = false);
    }
  }

  Future<void> _reverseGeocode(LatLng location) async {
    setState(() => _isReverseGeocoding = true);
    try {
      final placemarks = await placemarkFromCoordinates(
        location.latitude,
        location.longitude,
      );

      if (placemarks.isNotEmpty) {
        final placemark = placemarks.first;
        final address = _formatAddress(placemark);
        setState(() {
          _selectedAddress = address;
          _addressController.text = address;
          _isReverseGeocoding = false;
        });
        _notifyParent();
      } else {
        setState(() => _isReverseGeocoding = false);
      }
    } catch (e) {
      LogService.error('Reverse geocoding failed: $e');
      setState(() => _isReverseGeocoding = false);
    }
  }

  String _formatAddress(Placemark placemark) {
    final parts = <String>[];
    if (placemark.street != null && placemark.street!.isNotEmpty) {
      parts.add(placemark.street!);
    }
    if (placemark.subLocality != null && placemark.subLocality!.isNotEmpty) {
      parts.add(placemark.subLocality!);
    }
    if (placemark.locality != null && placemark.locality!.isNotEmpty) {
      parts.add(placemark.locality!);
    }
    if (placemark.administrativeArea != null && placemark.administrativeArea!.isNotEmpty) {
      parts.add(placemark.administrativeArea!);
    }
    if (placemark.country != null && placemark.country!.isNotEmpty) {
      parts.add(placemark.country!);
    }
    return parts.join(', ');
  }

  void _onMapTap(TapPosition tapPosition, LatLng location) {
    setState(() {
      _selectedLocation = location;
    });
    _mapController.move(location, _mapController.camera.zoom);
    _reverseGeocode(location);
  }

  void _notifyParent() {
    if (_selectedLocation != null && widget.onLocationSelected != null) {
      final coordinates = '${_selectedLocation!.latitude},${_selectedLocation!.longitude}';
      widget.onLocationSelected!(
        _selectedAddress ?? coordinates,
        coordinates,
        _locationDescriptionController.text.trim().isNotEmpty
            ? _locationDescriptionController.text.trim()
            : null,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        height: widget.height,
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
              ),
              const SizedBox(height: 16),
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Map Container
        Container(
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
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _selectedLocation ?? LatLng(4.0511, 9.7679),
                    initialZoom: 15.0,
                    minZoom: 5.0,
                    maxZoom: 18.0,
                    onTap: _onMapTap,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.prepskul.app',
                    ),
                    if (_selectedLocation != null)
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: _selectedLocation!,
                            width: 40,
                            height: 40,
                            child: Icon(
                              Icons.location_on,
                              color: AppTheme.primaryColor,
                              size: 40,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
                // Current location button
                Positioned(
                  top: 16,
                  right: 16,
                  child: Material(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    elevation: 4,
                    child: InkWell(
                      onTap: _isGettingCurrentLocation ? null : _getCurrentLocation,
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        child: _isGettingCurrentLocation
                            ? SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
                                ),
                              )
                            : Icon(
                                Icons.my_location,
                                color: AppTheme.primaryColor,
                                size: 24,
                              ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        // Address display and edit
        Text(
          'Selected Address',
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _addressController,
          onChanged: (value) {
            setState(() {
              _selectedAddress = value;
            });
            _notifyParent();
          },
          decoration: InputDecoration(
            hintText: 'Address will appear here after selecting on map',
            prefixIcon: Icon(Icons.location_on, color: AppTheme.primaryColor),
            suffixIcon: _isReverseGeocoding
                ? Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
                      ),
                    ),
                  )
                : null,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            filled: true,
            fillColor: Colors.white,
          ),
          maxLines: 2,
        ),
        const SizedBox(height: 12),
        // Location description (optional)
        TextField(
          controller: _locationDescriptionController,
          onChanged: (_) => _notifyParent(),
          decoration: InputDecoration(
            hintText: 'Additional location details (optional)',
            prefixIcon: Icon(Icons.description_outlined, color: Colors.grey[600]),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            filled: true,
            fillColor: Colors.grey[50],
          ),
          maxLines: 2,
        ),
      ],
    );
  }

  @override
  void dispose() {
    _mapController.dispose();
    _addressController.dispose();
    _locationDescriptionController.dispose();
    super.dispose();
  }
}


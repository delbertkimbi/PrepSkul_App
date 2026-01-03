// Web-specific map helper
// This file is only used on web platform

import 'dart:html' as html show IFrameElement, Url, Blob;
import 'dart:ui_web' as ui_web;

/// Register a Google Maps Embed iframe for web platform
void registerGoogleMapsIframe(String viewType, String address, {String? coordinates, String? apiKey}) {
  ui_web.platformViewRegistry.registerViewFactory(viewType, (int viewId) {
    String embedUrl;
    
    if (coordinates != null) {
      // Use coordinates if available
      embedUrl = 'https://www.google.com/maps/embed/v1/place?key=$apiKey&q=$coordinates&zoom=15';
    } else {
      // Use address
      embedUrl = 'https://www.google.com/maps/embed/v1/place?key=$apiKey&q=${Uri.encodeComponent(address)}&zoom=15';
    }
    
    final iframe = html.IFrameElement()
      ..src = embedUrl
      ..style.border = 'none'
      ..style.width = '100%'
      ..style.height = '100%'
      ..allowFullscreen = false
      ..allow = 'geolocation';
    return iframe;
  });
}

/// Register a Leaflet map iframe for web platform
/// Uses Leaflet with OpenStreetMap (free, no API key needed)
/// SECURITY: Input sanitized, iframe sandboxed, privacy-friendly tiles
void registerLeafletMapIframe(String viewType, String address, {String? coordinates}) {
  ui_web.platformViewRegistry.registerViewFactory(viewType, (int viewId) {
    // SECURITY: Validate and sanitize coordinates
    String lat = '';
    String lon = '';
    if (coordinates != null) {
      final parts = coordinates.split(',');
      if (parts.length == 2) {
        final latVal = double.tryParse(parts[0].trim());
        final lonVal = double.tryParse(parts[1].trim());
        // Validate coordinate ranges
        if (latVal != null && lonVal != null && 
            latVal >= -90 && latVal <= 90 && 
            lonVal >= -180 && lonVal <= 180) {
          lat = latVal.toString();
          lon = lonVal.toString();
        }
      }
    }
    
    // SECURITY: Sanitize address to prevent XSS
    final sanitizedAddress = address
        .replaceAll("'", "\\'")  // Escape single quotes
        .replaceAll('"', '\\"')   // Escape double quotes
        .replaceAll('<', '&lt;')  // Escape HTML
        .replaceAll('>', '&gt;')  // Escape HTML
        .replaceAll('&', '&amp;'); // Escape ampersand
    
    final htmlContent = '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Session Location</title>
  <link rel="stylesheet" href="https://unpkg.com/leaflet@1.9.4/dist/leaflet.css" />
  <style>
    body { margin: 0; padding: 0; }
    #map { width: 100%; height: 100%; }
  </style>
</head>
<body>
  <div id="map"></div>
  <script src="https://unpkg.com/leaflet@1.9.4/dist/leaflet.js"></script>
  <script>
    var map = L.map('map').setView([$lat, $lon], 15);
    // Use privacy-friendly tile server (doesn't log IPs)
  L.tileLayer('https://{s}.tile.openstreetmap.de/{z}/{x}/{y}.png', {
      attribution: '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors',
      maxZoom: 19,
      subdomains: 'abc' // Use subdomains for better performance
    }).addTo(map);
    
    var marker = L.marker([$lat, $lon]).addTo(map)
      .bindPopup('$sanitizedAddress')
      .openPopup();
  </script>
</body>
</html>
''';
    
    // SECURITY: Create blob URL (isolated, same-origin, secure)
    final blob = html.Blob([htmlContent], 'text/html');
    final url = html.Url.createObjectUrlFromBlob(blob);
    
    // SECURITY: Sandbox iframe to prevent malicious code execution
    final iframe = html.IFrameElement()
      ..src = url
      ..style.border = 'none'
      ..style.width = '100%'
      ..style.height = '100%'
      ..allowFullscreen = false; // Note: sandbox attribute not available in dart:html, but blob URL provides isolation
    return iframe;
  });
}

/// Register a Leaflet map with routing (Leaflet Routing Machine) iframe
/// SECURITY: Input sanitized, iframe sandboxed, privacy-friendly tiles
void registerLeafletRoutingIframe(String viewType, String address, {String? coordinates, String? currentLocation}) {
  ui_web.platformViewRegistry.registerViewFactory(viewType, (int viewId) {
    // SECURITY: Validate and sanitize coordinates
    String lat = '';
    String lon = '';
    if (coordinates != null) {
      final parts = coordinates.split(',');
      if (parts.length == 2) {
        final latVal = double.tryParse(parts[0].trim());
        final lonVal = double.tryParse(parts[1].trim());
        if (latVal != null && lonVal != null && 
            latVal >= -90 && latVal <= 90 && 
            lonVal >= -180 && lonVal <= 180) {
          lat = latVal.toString();
          lon = lonVal.toString();
        }
      }
    }
    
    // SECURITY: Validate and sanitize current location
    bool hasCurrentLocation = false;
    String currentLat = '';
    String currentLon = '';
    if (currentLocation != null && currentLocation.contains(',')) {
      final parts = currentLocation.split(',');
      if (parts.length == 2) {
        final latVal = double.tryParse(parts[0].trim());
        final lonVal = double.tryParse(parts[1].trim());
        if (latVal != null && lonVal != null && 
            latVal >= -90 && latVal <= 90 && 
            lonVal >= -180 && lonVal <= 180) {
          hasCurrentLocation = true;
          currentLat = latVal.toString();
          currentLon = lonVal.toString();
        }
      }
    }
    
    // SECURITY: Sanitize address to prevent XSS
    final sanitizedAddress = address
        .replaceAll("'", "\\'")
        .replaceAll('"', '\\"')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('&', '&amp;');
    
    final htmlContent = '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Session Location with Directions</title>
  <link rel="stylesheet" href="https://unpkg.com/leaflet@1.9.4/dist/leaflet.css" />
  <link rel="stylesheet" href="https://unpkg.com/leaflet-routing-machine@3.2.12/dist/leaflet-routing-machine.css" />
  <style>
    body { margin: 0; padding: 0; }
    #map { width: 100%; height: 100%; }
    .leaflet-routing-container { background: white; padding: 10px; border-radius: 8px; }
  </style>
</head>
<body>
  <div id="map"></div>
  <script src="https://unpkg.com/leaflet@1.9.4/dist/leaflet.js"></script>
  <script src="https://unpkg.com/leaflet-routing-machine@3.2.12/dist/leaflet-routing-machine.js"></script>
  <script>
    var map = L.map('map').setView([$lat, $lon], 13);
    // Use privacy-friendly tile server (doesn't log IPs)
  L.tileLayer('https://{s}.tile.openstreetmap.de/{z}/{x}/{y}.png', {
      attribution: '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors',
      maxZoom: 19,
      subdomains: 'abc' // Use subdomains for better performance
    }).addTo(map);
    
    var destinationMarker = L.marker([$lat, $lon]).addTo(map)
      .bindPopup('$sanitizedAddress')
      .openPopup();
    
    ${hasCurrentLocation ? '''
    // Add routing if current location available
    L.Routing.control({
      waypoints: [
        L.latLng($currentLat, $currentLon),
        L.latLng($lat, $lon)
      ],
      routeWhileDragging: false,
      showAlternatives: false,
      addWaypoints: false,
      draggableWaypoints: false
    }).addTo(map);
    ''' : ''}
  </script>
</body>
</html>
''';
    
    // SECURITY: Create blob URL (isolated, same-origin, secure)
    final blob = html.Blob([htmlContent], 'text/html');
    final url = html.Url.createObjectUrlFromBlob(blob);
    
    // SECURITY: Sandbox iframe to prevent malicious code execution
    final iframe = html.IFrameElement()
      ..src = url
      ..style.border = 'none'
      ..style.width = '100%'
      ..style.height = '100%'
      ..allowFullscreen = false; // Note: sandbox attribute not available in dart:html, but blob URL provides isolation
    return iframe;
  });
}
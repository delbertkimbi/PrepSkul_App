import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:prepskul/core/services/connectivity_service.dart';
import 'package:prepskul/core/theme/app_theme.dart';

/// Offline Indicator Widget
/// 
/// Shows a banner at the top of the screen when offline
/// Displays "Offline Mode - Showing cached data" message
class OfflineIndicator extends StatefulWidget {
  const OfflineIndicator({Key? key}) : super(key: key);

  @override
  State<OfflineIndicator> createState() => _OfflineIndicatorState();
}

class _OfflineIndicatorState extends State<OfflineIndicator> {
  final ConnectivityService _connectivity = ConnectivityService();
  bool _isOnline = true;

  @override
  void initState() {
    super.initState();
    _checkConnectivity();
    _connectivity.connectivityStream.listen((isOnline) {
      if (mounted) {
        setState(() {
          _isOnline = isOnline;
        });
      }
    });
  }

  Future<void> _checkConnectivity() async {
    final isOnline = await _connectivity.checkConnectivity();
    if (mounted) {
      setState(() {
        _isOnline = isOnline;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isOnline) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.orange[700],
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(
            Icons.cloud_off,
            color: Colors.white,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Offline Mode - Showing cached data',
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

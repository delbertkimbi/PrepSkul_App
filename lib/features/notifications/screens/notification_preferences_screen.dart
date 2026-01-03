import 'package:flutter/material.dart';
import 'package:prepskul/core/services/log_service.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:prepskul/core/services/notification_service.dart';
import 'package:prepskul/core/theme/app_theme.dart';
import 'package:prepskul/core/widgets/branded_snackbar.dart';

/// Notification Preferences Screen
/// 
/// Allows users to customize their notification preferences
class NotificationPreferencesScreen extends StatefulWidget {
  const NotificationPreferencesScreen({super.key});

  @override
  State<NotificationPreferencesScreen> createState() =>
      _NotificationPreferencesScreenState();
}

class _NotificationPreferencesScreenState
    extends State<NotificationPreferencesScreen> {
  bool _emailEnabled = true;
  bool _inAppEnabled = true;
  bool _pushEnabled = true;
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final preferences = await NotificationService.getPreferences();
      if (preferences != null && mounted) {
        setState(() {
          _emailEnabled = preferences['email_enabled'] as bool? ?? true;
          _inAppEnabled = preferences['in_app_enabled'] as bool? ?? true;
          _pushEnabled = preferences['push_enabled'] as bool? ?? true;
          _isLoading = false;
        });
      } else {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      LogService.debug('Error loading preferences: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _savePreferences() async {
    setState(() {
      _isSaving = true;
    });

    try {
      await NotificationService.updatePreferences(
        emailEnabled: _emailEnabled,
        inAppEnabled: _inAppEnabled,
        pushEnabled: _pushEnabled,
      );

      if (mounted) {
        BrandedSnackBar.showSuccess(context, 'Preferences saved successfully');
      }
    } catch (e) {
      LogService.debug('Error saving preferences: $e');
      if (mounted) {
        BrandedSnackBar.showError(context, 'Failed to save preferences: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.softBackground,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.textDark),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Notification Preferences',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: AppTheme.textDark,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Channel Preferences
                  Text(
                    'Notification Channels',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textDark,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildPreferenceSwitch(
                    title: 'Email Notifications',
                    subtitle: 'Receive notifications via email',
                    value: _emailEnabled,
                    onChanged: (value) {
                      setState(() {
                        _emailEnabled = value;
                      });
                      _savePreferences();
                    },
                    icon: Icons.email_outlined,
                  ),
                  const SizedBox(height: 12),
                  _buildPreferenceSwitch(
                    title: 'In-App Notifications',
                    subtitle: 'Show notifications in the app',
                    value: _inAppEnabled,
                    onChanged: (value) {
                      setState(() {
                        _inAppEnabled = value;
                      });
                      _savePreferences();
                    },
                    icon: Icons.notifications_outlined,
                  ),
                  const SizedBox(height: 12),
                  _buildPreferenceSwitch(
                    title: 'Push Notifications',
                    subtitle: 'Receive push notifications on your device',
                    value: _pushEnabled,
                    onChanged: (value) {
                      setState(() {
                        _pushEnabled = value;
                      });
                      _savePreferences();
                    },
                    icon: Icons.phone_android_outlined,
                  ),
                  const SizedBox(height: 32),

                  // Info Box
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.accentLightBlue.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppTheme.primaryColor.withOpacity(0.2),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: AppTheme.primaryColor,
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'You can customize notification types (booking, payment, session) in the future.',
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              color: AppTheme.textDark,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildPreferenceSwitch({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.softBorder,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: AppTheme.primaryColor,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textDark,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: AppTheme.textMedium,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: _isSaving ? null : onChanged,
            activeColor: AppTheme.primaryColor,
          ),
        ],
      ),
    );
  }
}

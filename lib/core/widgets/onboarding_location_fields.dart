import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:prepskul/core/theme/app_theme.dart';
import 'package:prepskul/data/app_data.dart';

/// Location fields for onboarding surveys.
/// Cameroon cities by default; free-text country/city/area when outside Cameroon.
class OnboardingLocationFields extends StatefulWidget {
  final String? initialCity;
  final String? initialQuarter;
  final bool initialIsCustomQuarter;
  final void Function({
    required String? city,
    required String? quarter,
    required bool isCustomQuarter,
  }) onChanged;

  const OnboardingLocationFields({
    super.key,
    this.initialCity,
    this.initialQuarter,
    this.initialIsCustomQuarter = false,
    required this.onChanged,
  });

  @override
  State<OnboardingLocationFields> createState() =>
      _OnboardingLocationFieldsState();
}

class _OnboardingLocationFieldsState extends State<OnboardingLocationFields> {
  String? _selectedCity;
  String? _selectedQuarter;
  String? _customQuarter;
  List<String> _availableQuarters = [];
  bool _isCustomQuarter = false;

  bool _isOutsideCameroon = false;
  final _countryController = TextEditingController();
  final _intlCityController = TextEditingController();
  final _areaController = TextEditingController();
  final _customQuarterController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _hydrateInitial();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _notifyParent();
    });
  }

  void _hydrateInitial() {
    final city = widget.initialCity;
    if (AppData.isInternationalLocation(city)) {
      _isOutsideCameroon = true;
      _intlCityController.text = city ?? '';
      final quarter = widget.initialQuarter ?? '';
      final parts = quarter.split(',').map((p) => p.trim()).toList();
      if (parts.length >= 2) {
        _areaController.text = parts.sublist(0, parts.length - 1).join(', ');
        _countryController.text = parts.last;
      } else if (parts.length == 1 && parts.first.isNotEmpty) {
        _countryController.text = parts.first;
      }
      return;
    }

    if (city == AppData.outsideCameroonLabel) {
      _isOutsideCameroon = true;
      return;
    }

    _selectedCity = city;
    _availableQuarters =
        city != null ? (AppData.cities[city] ?? []) : [];
    _isCustomQuarter = widget.initialIsCustomQuarter;
    if (_isCustomQuarter) {
      _customQuarter = widget.initialQuarter;
      _customQuarterController.text = widget.initialQuarter ?? '';
    } else {
      _selectedQuarter = widget.initialQuarter;
    }
  }

  @override
  void dispose() {
    _countryController.dispose();
    _intlCityController.dispose();
    _areaController.dispose();
    _customQuarterController.dispose();
    super.dispose();
  }

  void _notifyParent() {
    if (_isOutsideCameroon) {
      final intlCity = _intlCityController.text.trim();
      final country = _countryController.text.trim();
      final area = _areaController.text.trim();
      final quarterParts = <String>[
        if (area.isNotEmpty) area,
        if (country.isNotEmpty) country,
      ];
      widget.onChanged(
        city: intlCity.isEmpty ? AppData.outsideCameroonLabel : intlCity,
        quarter: quarterParts.join(', '),
        isCustomQuarter: false,
      );
      return;
    }

    widget.onChanged(
      city: _selectedCity,
      quarter: _isCustomQuarter ? _customQuarter : _selectedQuarter,
      isCustomQuarter: _isCustomQuarter,
    );
  }

  String? _dropdownValue(String? value, List<String> items) {
    if (value == null || value.isEmpty) return null;
    return items.contains(value) ? value : null;
  }

  @override
  Widget build(BuildContext context) {
    if (_isOutsideCameroon) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _dropdown(
            label: 'Location',
            value: _dropdownValue(
              AppData.outsideCameroonLabel,
              AppData.cityDropdownOptions,
            ),
            items: AppData.cityDropdownOptions,
            onChanged: (value) {
              setState(() {
                if (value == AppData.outsideCameroonLabel) return;
                _isOutsideCameroon = false;
                _selectedCity = value;
                _selectedQuarter = null;
                _customQuarter = null;
                _isCustomQuarter = false;
                _availableQuarters =
                    value != null ? (AppData.cities[value] ?? []) : [];
              });
              _notifyParent();
            },
          ),
          const SizedBox(height: 20),
          _textField(
            label: 'Country',
            controller: _countryController,
            hint: 'e.g. Nigeria, France, USA',
            onChanged: (_) => _notifyParent(),
          ),
          const SizedBox(height: 20),
          _textField(
            label: 'City',
            controller: _intlCityController,
            hint: 'Your city',
            onChanged: (_) => _notifyParent(),
          ),
          const SizedBox(height: 20),
          _textField(
            label: 'Area / Neighborhood (optional)',
            controller: _areaController,
            hint: 'District, suburb, or landmark',
            onChanged: (_) => _notifyParent(),
            required: false,
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _dropdown(
          label: 'City',
          value: _dropdownValue(_selectedCity, AppData.cityDropdownOptions),
          items: AppData.cityDropdownOptions,
          onChanged: (value) {
            setState(() {
              if (value == AppData.outsideCameroonLabel) {
                _isOutsideCameroon = true;
                _selectedCity = null;
                _selectedQuarter = null;
                _customQuarter = null;
                _isCustomQuarter = false;
                _availableQuarters = [];
                return;
              }
              _selectedCity = value;
              _selectedQuarter = null;
              _customQuarter = null;
              _isCustomQuarter = false;
              _availableQuarters =
                  value != null ? (AppData.cities[value] ?? []) : [];
            });
            _notifyParent();
          },
        ),
        const SizedBox(height: 20),
        _dropdown(
          label: 'Quarter/Neighborhood',
          value: _dropdownValue(
            _isCustomQuarter ? 'Other' : _selectedQuarter,
            [..._availableQuarters, 'Other'],
          ),
          items: [..._availableQuarters, 'Other'],
          onChanged: _selectedCity == null
              ? null
              : (value) {
            setState(() {
              if (value == 'Other') {
                _isCustomQuarter = true;
                _selectedQuarter = null;
              } else {
                _isCustomQuarter = false;
                _selectedQuarter = value;
                _customQuarter = null;
              }
            });
            _notifyParent();
          },
        ),
        if (_isCustomQuarter) ...[
          const SizedBox(height: 20),
          _textField(
            label: 'Enter Quarter/Neighborhood',
            controller: _customQuarterController,
            hint: 'Type your quarter or neighborhood',
            onChanged: (value) {
              _customQuarter = value;
              _notifyParent();
            },
          ),
        ],
      ],
    );
  }

  Widget _dropdown({
    required String label,
    required String? value,
    required List<String> items,
    required ValueChanged<String?>? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppTheme.textDark,
              ),
            ),
            Text(
              ' *',
              style: GoogleFonts.poppins(
                color: AppTheme.primaryColor,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          value: value,
          onChanged: onChanged,
          decoration: _inputDecoration(),
          items: items
              .map(
                (item) => DropdownMenuItem(
                  value: item,
                  child: Text(
                    item,
                    style: GoogleFonts.poppins(fontSize: 14),
                  ),
                ),
              )
              .toList(),
          style: GoogleFonts.poppins(
            fontSize: 14,
            color: AppTheme.textDark,
          ),
        ),
      ],
    );
  }

  Widget _textField({
    required String label,
    required TextEditingController controller,
    required String hint,
    required void Function(String) onChanged,
    bool required = true,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppTheme.textDark,
              ),
            ),
            if (required)
              Text(
                ' *',
                style: GoogleFonts.poppins(
                  color: AppTheme.primaryColor,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          controller: controller,
          onChanged: onChanged,
          decoration: _inputDecoration(hint: hint),
          style: GoogleFonts.poppins(fontSize: 14, color: AppTheme.textDark),
        ),
      ],
    );
  }

  InputDecoration _inputDecoration({String? hint}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.poppins(color: AppTheme.textLight, fontSize: 12),
      filled: true,
      fillColor: AppTheme.softCard,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppTheme.softBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppTheme.softBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppTheme.primaryColor, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
    );
  }
}

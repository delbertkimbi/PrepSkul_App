import 'package:country_flags/country_flags.dart';
import 'package:flutter/material.dart';

/// Instant country flags — no network. Cameroon is painted locally; other
/// countries use bundled SVG assets (reliable on Android vs emoji fonts).
class CountryFlagIcon extends StatelessWidget {
  final String isoCode;
  final double size;

  const CountryFlagIcon({
    super.key,
    required this.isoCode,
    this.size = 20,
  });

  @override
  Widget build(BuildContext context) {
    final code = isoCode.toUpperCase();
    if (code == 'CM') {
      return _CameroonFlag(size: size);
    }
    return _SvgCountryFlag(isoCode: code, size: size);
  }
}

class _CameroonFlag extends StatelessWidget {
  final double size;

  const _CameroonFlag({required this.size});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(size * 0.12),
      child: SizedBox(
        width: size * 1.35,
        height: size,
        child: Row(
          children: [
            Expanded(child: Container(color: const Color(0xFF007A5E))),
            Expanded(
              child: Container(
                color: const Color(0xFFCE1126),
                alignment: Alignment.center,
                child: Icon(
                  Icons.star_rounded,
                  size: size * 0.38,
                  color: const Color(0xFFFCD116),
                ),
              ),
            ),
            Expanded(child: Container(color: const Color(0xFFFCD116))),
          ],
        ),
      ),
    );
  }
}

class _SvgCountryFlag extends StatelessWidget {
  final String isoCode;
  final double size;

  const _SvgCountryFlag({required this.isoCode, required this.size});

  @override
  Widget build(BuildContext context) {
    final width = size * 1.35;
    final radius = size * 0.12;

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox(
        width: width,
        height: size,
        child: CountryFlag.fromCountryCode(
          isoCode,
          theme: ImageTheme(
            width: width,
            height: size,
            shape: RoundedRectangle(radius),
          ),
        ),
      ),
    );
  }
}

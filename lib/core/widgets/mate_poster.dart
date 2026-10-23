import 'package:flutter/material.dart';

/// Local full-body render of the same Blender model used by the 3D view.
class MatePoster extends StatelessWidget {
  const MatePoster({super.key, required this.clip, required this.size});
  final String clip;
  final double size;
  @override
  Widget build(BuildContext context) => Image.asset(
    clip == '06_celebrate'
        ? 'assets/images/mate_3d/cheer.webp'
        : 'assets/mascot/model-front.webp',
    width: size,
    height: size,
    fit: BoxFit.contain,
    semanticLabel: 'Mate',
  );
}

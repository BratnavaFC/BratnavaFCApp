import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

class AvatarWidget extends StatelessWidget {
  final String name;
  final double size;

  const AvatarWidget({super.key, required this.name, this.size = 36});

  @override
  Widget build(BuildContext context) {
    final colors   = AppColors.gradientForName(name);
    final initials = _initials(name);

    return Container(
      width:  size,
      height: size,
      decoration: BoxDecoration(
        shape:    BoxShape.circle,
        gradient: LinearGradient(
          colors: colors,
          begin:  Alignment.topLeft,
          end:    Alignment.bottomRight,
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: TextStyle(
          color:      Colors.white,
          fontSize:   size * 0.38,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  static String _initials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }
}

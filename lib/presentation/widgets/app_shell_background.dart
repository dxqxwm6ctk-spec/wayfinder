import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class AppShellBackground extends StatelessWidget {
  const AppShellBackground({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
  });

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        gradient: isDark
            ? AppColors.navyGradient
            : const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: <Color>[Color(0xFFF7FAFF), Color(0xFFEAF2FF)],
              ),
      ),
      child: Stack(
        children: <Widget>[
          Positioned(
            top: -150,
            right: -100,
            child: _GlowOrb(
              size: 280,
              color: AppColors.accentElectric.withValues(alpha: isDark ? 0.2 : 0.11),
            ),
          ),
          Positioned(
            top: 240,
            left: -60,
            child: _GlowOrb(
              size: 190,
              color: AppColors.accentLight.withValues(alpha: isDark ? 0.13 : 0.08),
            ),
          ),
          Positioned(
            bottom: -130,
            right: -30,
            child: _GlowOrb(
              size: 220,
              color: AppColors.surfaceSoft.withValues(alpha: isDark ? 0.35 : 0.15),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: padding,
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}

class _GlowOrb extends StatelessWidget {
  const _GlowOrb({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: color,
            blurRadius: 80,
            spreadRadius: 30,
          ),
        ],
      ),
    );
  }
}

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
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isDark
              ? const <Color>[Color(0xFF070B14), Color(0xFF030406)]
              : const <Color>[Color(0xFFF8FAFF), Color(0xFFEFF4FF)],
        ),
      ),
      child: Stack(
        children: <Widget>[
          Positioned(
            top: -120,
            right: -120,
            child: _GlowOrb(
              size: 260,
              color: AppColors.accent.withValues(alpha: isDark ? 0.12 : 0.09),
            ),
          ),
          Positioned(
            top: 220,
            left: -80,
            child: _GlowOrb(
              size: 180,
              color: AppColors.accentLight.withValues(alpha: isDark ? 0.08 : 0.06),
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

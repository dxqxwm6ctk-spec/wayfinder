import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class HeaderRow extends StatelessWidget {
  const HeaderRow({
    super.key,
    required this.title,
    this.onMenuTap,
  });

  final String title;
  final VoidCallback? onMenuTap;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Row(
      children: <Widget>[
        _HeaderIcon(
          icon: Icons.menu,
          onTap: onMenuTap,
          isDark: isDark,
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: AppColors.accentLight,
                  fontSize: 22,
                ),
          ),
        ),
        _AvatarChip(isDark: isDark),
      ],
    );
  }
}

class _HeaderIcon extends StatelessWidget {
  const _HeaderIcon({required this.icon, this.onTap, required this.isDark});

  final IconData icon;
  final VoidCallback? onTap;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Ink(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: isDark ? AppColors.surface : const Color(0xFFE9EEF8),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.06)
                  : Colors.black.withValues(alpha: 0.06),
            ),
          ),
          child: Icon(
            icon,
            color: isDark ? AppColors.textPrimary : const Color(0xFF101828),
            size: 28,
          ),
        ),
      ),
    );
  }
}

class _AvatarChip extends StatelessWidget {
  const _AvatarChip({required this.isDark});

  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 54,
      height: 54,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: isDark ? const Color(0xFF1A2733) : const Color(0xFFE8F0FF),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.black.withValues(alpha: 0.08),
        ),
      ),
      child: Icon(
        Icons.person,
        color: isDark ? AppColors.textPrimary : const Color(0xFF1A3D7A),
      ),
    );
  }
}

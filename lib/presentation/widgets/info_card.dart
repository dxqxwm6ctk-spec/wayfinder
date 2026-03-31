import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class InfoCard extends StatelessWidget {
  const InfoCard({
    super.key,
    required this.title,
    required this.value,
    this.indicatorColor = AppColors.accentLight,
  });

  final String title;
  final String value;
  final Color indicatorColor;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.glass.withValues(alpha: 0.34)
            : Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.1)
              : Colors.black.withValues(alpha: 0.06),
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.24)
                : Colors.black.withValues(alpha: 0.08),
            blurRadius: isDark ? 24 : 18,
            spreadRadius: -10,
            offset: Offset(0, isDark ? 12 : 8),
          ),
        ],
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 6,
            height: 56,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(40),
              color: indicatorColor,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: isDark ? AppColors.textSecondary : const Color(0xFF6A7891),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  value,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: isDark ? AppColors.textPrimary : AppColors.lightTextPrimary,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

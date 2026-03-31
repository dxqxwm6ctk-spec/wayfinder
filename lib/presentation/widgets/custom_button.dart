import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class CustomButton extends StatefulWidget {
  const CustomButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.filled = true,
    this.isLoading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool filled;
  final bool isLoading;

  @override
  State<CustomButton> createState() => _CustomButtonState();
}

class _CustomButtonState extends State<CustomButton> {
  double _scale = 1;

  void _setPressed(bool value) {
    setState(() {
      _scale = value ? 0.985 : 1;
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    final Widget content = widget.isLoading
        ? const SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2.4,
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.textPrimary),
            ),
          )
        : Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Text(
                widget.label,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: widget.filled
                      ? const Color(0xFFF4F8FF)
                      : (isDark ? AppColors.textPrimary : AppColors.accent),
                  fontSize: 14.5,
                  letterSpacing: 0.2,
                    ),
              ),
              if (widget.icon != null) ...<Widget>[
                const SizedBox(width: 8),
                Icon(
                  widget.icon,
                  color: widget.filled
                      ? const Color(0xFFF4F8FF)
                      : (isDark ? AppColors.accentLight : AppColors.accent),
                  size: 19,
                ),
              ],
            ],
          );

    return AnimatedScale(
      duration: const Duration(milliseconds: 130),
      scale: _scale,
      curve: Curves.easeOut,
      child: GestureDetector(
        onTapDown: (_) => _setPressed(true),
        onTapCancel: () => _setPressed(false),
        onTapUp: (_) => _setPressed(false),
        child: Container(
          decoration: BoxDecoration(
            gradient: widget.filled
                ? AppColors.primaryGradient
                : null,
            color: widget.filled
                ? null
                : (isDark
                    ? Colors.white.withValues(alpha: 0.04)
                    : Colors.white.withValues(alpha: 0.9)),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: widget.filled
                  ? (isDark
                      ? Colors.white.withValues(alpha: 0.18)
                      : Colors.white.withValues(alpha: 0.45))
                  : AppColors.textSecondary.withValues(alpha: 0.22),
            ),
            boxShadow: widget.filled
                ? <BoxShadow>[
                    BoxShadow(
                      color: AppColors.accent.withValues(alpha: isDark ? 0.38 : 0.24),
                      blurRadius: isDark ? 26 : 18,
                      spreadRadius: -6,
                      offset: Offset(0, isDark ? 14 : 10),
                    ),
                  ]
                : const <BoxShadow>[],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: widget.isLoading ? null : widget.onPressed,
              child: SizedBox(
                height: 56,
                child: Center(child: content),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

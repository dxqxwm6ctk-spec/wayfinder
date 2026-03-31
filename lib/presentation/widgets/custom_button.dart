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
    final Widget content = widget.isLoading
        ? const SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2.8,
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0A2D63)),
            ),
          )
        : Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Text(
                widget.label,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: widget.filled
                          ? const Color(0xFF082A63)
                          : AppColors.accentLight,
                      fontSize: 14,
                    ),
              ),
              if (widget.icon != null) ...<Widget>[
                const SizedBox(width: 10),
                Icon(
                  widget.icon,
                  color: widget.filled
                      ? const Color(0xFF082A63)
                      : AppColors.accentLight,
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
                ? const LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: <Color>[AppColors.accentLight, AppColors.accent],
                  )
                : null,
            color: widget.filled ? null : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: widget.filled
                  ? Colors.transparent
                  : AppColors.textSecondary.withValues(alpha: 0.15),
            ),
            boxShadow: widget.filled
                ? <BoxShadow>[
                    BoxShadow(
                      color: AppColors.accent.withValues(alpha: 0.34),
                      blurRadius: 28,
                      spreadRadius: 1,
                      offset: const Offset(0, 14),
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
                height: 62,
                child: Center(child: content),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

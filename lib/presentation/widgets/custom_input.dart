import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class CustomInput extends StatelessWidget {
  const CustomInput({
    super.key,
    required this.controller,
    required this.hintText,
    this.obscureText = false,
    this.keyboardType,
    this.validator,
    this.trailing,
  });

  final TextEditingController controller;
  final String hintText;
  final bool obscureText;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      validator: validator,
      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
        color: isDark ? AppColors.textPrimary : const Color(0xFF111827),
            fontWeight: FontWeight.w500,
          ),
      decoration: InputDecoration(
        hintText: hintText,
        suffixIcon: trailing,
      ),
    );
  }
}

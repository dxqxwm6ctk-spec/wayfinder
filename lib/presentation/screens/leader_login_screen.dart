import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';

import '../localization/app_strings.dart';
import '../providers/app_settings_provider.dart';
import '../providers/auth_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/app_shell_background.dart';
import '../widgets/custom_button.dart';
import '../widgets/custom_input.dart';
import 'leader_web_screen.dart';
import 'leader_shell_screen.dart';

class LeaderLoginScreen extends StatefulWidget {
  const LeaderLoginScreen({super.key});

  @override
  State<LeaderLoginScreen> createState() => _LeaderLoginScreenState();
}

class _LeaderLoginScreenState extends State<LeaderLoginScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final AuthProvider authProvider = context.read<AuthProvider>();
    final AppSettingsProvider settings = context.read<AppSettingsProvider>();
    final AppStrings strings = AppStrings(isArabic: settings.isArabic);

    if (!_formKey.currentState!.validate()) {
      return;
    }

    final bool ok = await authProvider.loginLeader(
      email: _emailController.text,
      password: _passwordController.text,
    );

    if (!mounted) {
      return;
    }

    if (!ok) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(strings.leaderInvalidCredentials)));
      return;
    }

    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) =>
            kIsWeb ? const LeaderWebScreen() : const LeaderShellScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AuthProvider authProvider = context.watch<AuthProvider>();
    final AppSettingsProvider settings = context.watch<AppSettingsProvider>();
    final AppStrings strings = AppStrings(isArabic: settings.isArabic);

    return Scaffold(
      body: AppShellBackground(
        padding: const EdgeInsets.fromLTRB(24, 46, 24, 20),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                TextButton.icon(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 14),
                  label: Text(strings.back),
                ),
                const SizedBox(height: 8),
                Text(
                  strings.leaderLogin,
                  style: Theme.of(context).textTheme.displayLarge,
                ),
                const SizedBox(height: 28),
                Text(
                  strings.leaderEmail,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: AppColors.accentLight,
                  ),
                ),
                const SizedBox(height: 10),
                CustomInput(
                  controller: _emailController,
                  hintText: strings.leaderEmailHint,
                  keyboardType: TextInputType.emailAddress,
                  validator: (String? value) {
                    final String input = (value ?? '').trim().toLowerCase();
                    if (input.isEmpty) {
                      return strings.emailRequired;
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 18),
                Text(
                  strings.password,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: AppColors.accentLight,
                  ),
                ),
                const SizedBox(height: 10),
                CustomInput(
                  controller: _passwordController,
                  hintText: strings.leaderPasswordHint,
                  obscureText: true,
                  validator: (String? value) {
                    if ((value ?? '').isEmpty) {
                      return strings.passwordInvalid;
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 22),
                CustomButton(
                  label: strings.login,
                  onPressed: _submit,
                  isLoading: authProvider.isLeaderLoading,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

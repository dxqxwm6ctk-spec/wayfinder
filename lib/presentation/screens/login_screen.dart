import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../localization/app_strings.dart';
import '../providers/app_settings_provider.dart';
import '../providers/auth_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/app_shell_background.dart';
import '../widgets/custom_button.dart';
import '../widgets/custom_input.dart';
import '../widgets/info_card.dart';
import 'main_shell_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  static const String _demoEmail = 'demo@iu.edu.co';
  static const String _demoPassword = 'demo1234';

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

    final bool ok = await authProvider.login(
      email: _emailController.text,
      password: _passwordController.text,
    );

    if (!mounted) {
      return;
    }

    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(strings.invalidCredentials)),
      );
      return;
    }

    Navigator.of(context).pushReplacement(_slideRoute(const MainShellScreen()));
  }

  Route<void> _slideRoute(Widget page) {
    return PageRouteBuilder<void>(
      transitionDuration: const Duration(milliseconds: 380),
      pageBuilder: (BuildContext context, Animation<double> animation,
              Animation<double> secondaryAnimation) =>
          page,
      transitionsBuilder: (
        BuildContext context,
        Animation<double> animation,
        Animation<double> secondaryAnimation,
        Widget child,
      ) {
        final Animation<Offset> offset = Tween<Offset>(
          begin: const Offset(0.08, 0),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic));
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(position: offset, child: child),
        );
      },
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
                const SizedBox(height: 16),
                Text(
                  strings.portalTitle,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: AppColors.accentLight,
                      ),
                ),
                const SizedBox(height: 12),
                Text(
                  strings.studentLogin,
                  style: Theme.of(context).textTheme.displayLarge,
                ),
                const SizedBox(height: 18),
                _buildTopControls(context, settings),
                const SizedBox(height: 28),
                _buildLabel(context, strings.universityEmail),
                const SizedBox(height: 12),
                CustomInput(
                  controller: _emailController,
                  hintText: strings.emailHint,
                  keyboardType: TextInputType.emailAddress,
                  validator: (String? value) {
                    final String input = (value ?? '').trim();
                    if (input.isEmpty) {
                      return strings.emailRequired;
                    }
                    if (!authProvider.isUniversityEmail(input)) {
                      return strings.emailInvalid;
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 8),
                Text(
                  'Allowed domains: ${authProvider.allowedDomains.join(', ')}',
                  style: Theme.of(context).textTheme.labelMedium,
                ),
                const SizedBox(height: 22),
                Row(
                  children: <Widget>[
                    Expanded(child: _buildLabel(context, strings.password)),
                    Text(
                      strings.forgot,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: AppColors.accentLight,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                CustomInput(
                  controller: _passwordController,
                  hintText: '••••••••',
                  obscureText: true,
                  validator: (String? value) {
                    if ((value ?? '').length < 6) {
                      return strings.passwordInvalid;
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 26),
                CustomButton(
                  label: strings.login,
                  onPressed: _submit,
                  isLoading: authProvider.isLoading,
                ),
                const SizedBox(height: 14),
                Align(
                  alignment: Alignment.center,
                  child: TextButton(
                    onPressed: authProvider.isLoading
                        ? null
                        : () {
                            _emailController.text = _demoEmail;
                            _passwordController.text = _demoPassword;
                          },
                    child: Text(
                      strings.testUser,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: AppColors.accentLight,
                          ),
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.center,
                  child: Text(
                    '$_demoEmail  |  $_demoPassword',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: AppColors.textSecondary,
                          letterSpacing: 1,
                        ),
                  ),
                ),
                const SizedBox(height: 22),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Divider(
                        color: Colors.white.withValues(alpha: 0.08),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Text(
                      strings.or,
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Divider(
                        color: Colors.white.withValues(alpha: 0.08),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                CustomButton(
                  label: strings.requestAccess,
                  onPressed: null,
                  filled: false,
                ),
                const SizedBox(height: 58),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: InfoCard(
                        title: strings.activeStatus,
                        value: strings.systemLive,
                        indicatorColor: AppColors.accentLight,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: InfoCard(
                        title: strings.campusConnectivity,
                        value: strings.uptime,
                        indicatorColor: const Color(0xFF30343C),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 28),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(BuildContext context, String text) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Text(
      text,
      style: Theme.of(context).textTheme.labelLarge?.copyWith(
            fontSize: 12,
            color: (isDark ? AppColors.textPrimary : const Color(0xFF111827))
                .withValues(alpha: 0.72),
          ),
    );
  }

  Widget _buildTopControls(
    BuildContext context,
    AppSettingsProvider settings,
  ) {
    final AppStrings strings = AppStrings(isArabic: settings.isArabic);

    return Row(
      children: <Widget>[
        ChoiceChip(
          label: Text(strings.languageEnglish),
          selected: settings.language == AppLanguage.english,
          onSelected: (_) => settings.setLanguage(AppLanguage.english),
        ),
        const SizedBox(width: 8),
        ChoiceChip(
          label: Text(strings.languageArabic),
          selected: settings.language == AppLanguage.arabic,
          onSelected: (_) => settings.setLanguage(AppLanguage.arabic),
        ),
        const Spacer(),
        IconButton.filledTonal(
          onPressed: settings.toggleTheme,
          icon: Icon(
            settings.isDarkMode ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
          ),
        ),
      ],
    );
  }
}

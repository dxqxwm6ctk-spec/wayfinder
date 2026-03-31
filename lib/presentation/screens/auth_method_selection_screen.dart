import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/config/app_env.dart';
import '../providers/app_settings_provider.dart';
import './microsoft_login_screen.dart';

class AuthMethodSelectionScreen extends StatelessWidget {
  const AuthMethodSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<AppSettingsProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isArabic = settings.language == AppLanguage.arabic;
    final canUseMicrosoft = AppEnv.canUseMicrosoftAuth;

    return Scaffold(
      appBar: AppBar(
        title: Text(isArabic ? 'وايفندر' : 'WAYFINDER'),
        centerTitle: true,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(settings.themeMode == ThemeMode.dark
                ? Icons.light_mode
                : Icons.dark_mode),
            onPressed: settings.toggleTheme,
          ),
          IconButton(
            icon: const Text('AR', style: TextStyle(fontSize: 12)),
            onPressed: () => settings.setLanguage(
              isArabic 
                ? AppLanguage.english 
                : AppLanguage.arabic,
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              const SizedBox(height: 40),
              Icon(
                Icons.security,
                size: 80,
                color: Theme.of(context).primaryColor,
              ),
              const SizedBox(height: 32),
              Text(
                isArabic ? 'اختر طريقة الدخول' : 'Choose Sign In Method',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                isArabic
                    ? 'مسموح فقط الدخول عبر حساب Microsoft الجامعي'
                    : 'Only Microsoft university sign-in is allowed',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: isDark ? Colors.grey[400] : Colors.grey[700],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),
              // Microsoft Entra Button
              _AuthMethodButton(
                icon: Icons.business,
                title: isArabic ? 'Microsoft Entra' : 'Microsoft Entra',
                subtitle: canUseMicrosoft
                    ? (isArabic ? 'استخدم بريدك الجامعي' : 'University email (Microsoft)')
                    : (isArabic ? 'غير مفعّل حالياً' : 'Not configured yet'),
                onPressed: () {
                  if (!canUseMicrosoft) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          isArabic
                              ? 'دخول Microsoft غير مفعّل حالياً. ${AppEnv.microsoftConfigHint}'
                              : 'Microsoft sign-in is not configured yet. ${AppEnv.microsoftConfigHint}',
                        ),
                      ),
                    );
                    return;
                  }

                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const MicrosoftLoginScreen(),
                    ),
                  );
                },
                isDark: isDark,
                isEnabled: canUseMicrosoft,
              ),
              const SizedBox(height: 48),
            ],
          ),
        ),
      ),
    );
  }
}

class _AuthMethodButton extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onPressed;
  final bool isDark;
  final bool isEnabled;

  const _AuthMethodButton({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onPressed,
    required this.isDark,
    this.isEnabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isEnabled
        ? (isDark ? Colors.grey[900] : Colors.grey[100])
        : (isDark ? Colors.grey[850] : Colors.grey[200]),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: isEnabled ? onPressed : null,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(
              color: isEnabled
                  ? (isDark ? Colors.grey[800]! : Colors.grey[300]!)
                  : (isDark ? Colors.grey[700]! : Colors.grey[400]!),
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(
                icon,
                size: 28,
                color: isEnabled ? Theme.of(context).primaryColor : Colors.grey,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: isEnabled ? null : Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: isEnabled
                            ? (isDark ? Colors.grey[400] : Colors.grey[600])
                            : Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward,
                color: isEnabled ? Colors.grey[500] : Colors.grey[700],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

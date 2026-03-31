import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/config/app_env.dart';
import '../providers/app_settings_provider.dart';
import '../providers/unified_auth_provider.dart';
import './firebase_login_screen.dart';
import './microsoft_login_screen.dart';
import './phone_login_screen.dart';

class AuthMethodSelectionScreen extends StatelessWidget {
  const AuthMethodSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<AppSettingsProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isArabic = settings.language == AppLanguage.arabic;
    final canUseMicrosoft = AppEnv.canUseMicrosoftAuth;
    final canUseGoogle = AppEnv.googleSignInEnabled;

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
                    ? 'يمكنك استخدام بريدك الجامعي أو حسابات أخرى'
                    : 'Use your university email or other accounts',
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
              const SizedBox(height: 16),
              // Firebase Email Button
              _AuthMethodButton(
                icon: Icons.email,
                title: isArabic ? 'البريد الإلكتروني' : 'Email',
                subtitle: isArabic ? 'أنشئ حسابًا أو تسجيل دخول' : 'Create account or sign in',
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const FirebaseLoginScreen(),
                    ),
                  );
                },
                isDark: isDark,
              ),
              const SizedBox(height: 16),
              // Google Button
              _AuthMethodButton(
                icon: Icons.g_mobiledata,
                title: 'Google',
                subtitle: canUseGoogle
                    ? (isArabic ? 'دخول سريع مع Google' : 'Quick sign in with Google')
                    : (isArabic ? 'غير مفعّل حالياً' : 'Not configured yet'),
                onPressed: () {
                  _signInWithGoogle(context, isArabic, canUseGoogle);
                },
                isDark: isDark,
                isEnabled: canUseGoogle,
              ),
              const SizedBox(height: 16),
              // Phone Button
              _AuthMethodButton(
                icon: Icons.phone,
                title: isArabic ? 'رقم الهاتف' : 'Phone',
                subtitle: isArabic 
                    ? 'يتطلب ترقية Identity Platform' 
                    : 'Requires Identity Platform upgrade',
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const PhoneLoginScreen(),
                    ),
                  );
                },
                isDark: isDark,
                isEnabled: true,  // Show as available but will warn about upgrade
              ),
              const SizedBox(height: 48),
              // Development Mode - Mock Login
              if (true) // Toggle this flag based on environment
                Column(
                  children: [
                    Divider(color: isDark ? Colors.grey[800] : Colors.grey[300]),
                    const SizedBox(height: 16),
                    Text(
                      isArabic ? 'وضع التطوير' : 'Development Mode',
                      style: TextStyle(
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _AuthMethodButton(
                      icon: Icons.code,
                      title: isArabic ? 'تسجيل دخول وهمي' : 'Mock Login',
                      subtitle: isArabic ? 'للاختبار فقط' : 'For testing only',
                      onPressed: () {
                        _showMockLoginDialog(context, isArabic);
                      },
                      isDark: isDark,
                      isMockMode: true,
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _signInWithGoogle(
    BuildContext context,
    bool isArabic,
    bool canUseGoogle,
  ) async {
    if (!canUseGoogle) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isArabic
                ? 'تسجيل Google غير مفعّل حالياً. استخدم البريد الإلكتروني.'
                : 'Google sign-in is not configured yet. Use Email sign-in.',
          ),
        ),
      );
      return;
    }

    final auth = Provider.of<UnifiedAuthProvider>(context, listen: false);
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      final result = await auth.signInWithGoogle();
      if (!context.mounted) return;
      Navigator.pop(context); // Dismiss loading dialog

      if (result.success) {
        // Navigate to main app
        // This will be handled by auth state listener in main app
        Navigator.of(context).pushReplacementNamed('/main');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_mapGoogleError(result.error, isArabic))),
        );
      }
    } catch (e) {
      if (!context.mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_mapGoogleError(e.toString(), isArabic))),
      );
    }
  }

  String _mapGoogleError(String? raw, bool isArabic) {
    final text = (raw ?? '').toLowerCase();
    if (text.contains('apiexception: 10') || text.contains('sign_in_failed')) {
      return isArabic
          ? 'Google غير مهيأ على Android (خطأ 10). فعّل Google Sign-In في Firebase وأضف SHA-1/ SHA-256 ثم أعد تنزيل google-services.json.'
          : 'Google is not configured on Android (error 10). Enable Google Sign-In in Firebase, add SHA-1/SHA-256, then download a fresh google-services.json.';
    }
    return raw ?? (isArabic ? 'فشل تسجيل الدخول عبر Google' : 'Google sign in failed');
  }

  void _showMockLoginDialog(BuildContext context, bool isArabic) {
    final emailController = TextEditingController();
    final passwordController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isArabic ? 'تسجيل دخول وهمي' : 'Mock Login'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: emailController,
              decoration: InputDecoration(
                hintText: isArabic ? 'البريد الإلكتروني' : 'Email',
                prefixText: 'student@',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: InputDecoration(
                hintText: isArabic ? 'كلمة المرور' : 'Password',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(isArabic ? 'إلغاء' : 'Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final auth = Provider.of<UnifiedAuthProvider>(
                context,
                listen: false,
              );
              final email = '${emailController.text}iu.edu.co';
              final password = passwordController.text;

              final result = await auth.mockLogin(email, password);
              
              if (context.mounted) {
                Navigator.pop(context);
                if (result.success) {
                  Navigator.of(context).pushReplacementNamed('/main');
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(result.error ?? 'Login failed')),
                  );
                }
              }
            },
            child: Text(isArabic ? 'دخول' : 'Sign In'),
          ),
        ],
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
  final bool isMockMode;
  final bool isEnabled;

  const _AuthMethodButton({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onPressed,
    required this.isDark,
    this.isMockMode = false,
    this.isEnabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isMockMode
          ? Colors.transparent
          : (isEnabled
              ? (isDark ? Colors.grey[900] : Colors.grey[100])
              : (isDark ? Colors.grey[850] : Colors.grey[200])),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: isEnabled ? onPressed : null,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(
              color: isMockMode
                  ? Colors.grey
                  : (isEnabled
                      ? (isDark ? Colors.grey[800]! : Colors.grey[300]!)
                      : (isDark ? Colors.grey[700]! : Colors.grey[400]!)),
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

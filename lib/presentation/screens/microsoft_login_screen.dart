import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/config/app_env.dart';
import '../providers/app_settings_provider.dart';
import '../providers/unified_auth_provider.dart';

class MicrosoftLoginScreen extends StatefulWidget {
  const MicrosoftLoginScreen({super.key});

  @override
  State<MicrosoftLoginScreen> createState() => _MicrosoftLoginScreenState();
}

class _MicrosoftLoginScreenState extends State<MicrosoftLoginScreen> {
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<AppSettingsProvider>(context);
    final auth = Provider.of<UnifiedAuthProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isArabic = settings.language == AppLanguage.arabic;
    final canUseMicrosoft = AppEnv.canUseMicrosoftAuth;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(isArabic ? 'Microsoft Entra' : 'Microsoft Entra'),
      ),
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.business,
                  size: 80,
                  color: Theme.of(context).primaryColor,
                ),
                const SizedBox(height: 24),
                Text(
                  isArabic ? 'تسجيل دخول آمن' : 'Secure Sign In',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  isArabic
                    ? 'استخدم حسابك بـ Microsoft الجامعي'
                    : 'Use your university Microsoft account',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                if (!canUseMicrosoft) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.orange.withValues(alpha: 0.35)),
                    ),
                    child: Text(
                      isArabic
                          ? 'تسجيل Microsoft غير مفعّل حالياً. ${AppEnv.microsoftConfigHint}'
                          : 'Microsoft sign-in is not configured yet. ${AppEnv.microsoftConfigHint}',
                      style: TextStyle(color: isDark ? Colors.orange[200] : Colors.orange[900]),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                // Info Box
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isArabic ? '📋 ما الذي سنحتاج' : '📋 What we need',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        isArabic
                          ? '• البريد الإلكتروني الجامعي\n• معلومات الملف الشخصي الأساسية\n• هويتك الجامعية'
                          : '• University email\n• Basic profile information\n• Your university identity',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: isDark ? Colors.grey[400] : Colors.grey[700],
                          height: 1.6,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 48),
                // Sign In Button
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: !canUseMicrosoft || _isLoading || auth.isLoading
                      ? null
                      : () => _handleMicrosoftSignIn(context, auth, isArabic),
                    icon: const Icon(Icons.business),
                    label: _isLoading
                      ? Row(
                          children: [
                            const SizedBox(width: 12),
                            const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              isArabic ? 'جاري الدخول...' : 'Signing in...',
                            ),
                          ],
                        )
                      : Text(
                          isArabic
                            ? 'دخول عبر Microsoft'
                            : 'Sign in with Microsoft',
                          style: const TextStyle(fontSize: 16),
                        ),
                  ),
                ),
                const SizedBox(height: 16),
                // Cancel Button
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: OutlinedButton(
                    onPressed: _isLoading || auth.isLoading
                      ? null
                      : () => Navigator.pop(context),
                    child: Text(isArabic ? 'إلغاء' : 'Cancel'),
                  ),
                ),
                if (auth.authError != null) ...[
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error, color: Colors.red, size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            auth.authError ?? '',
                            style: const TextStyle(color: Colors.red),
                            textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                // Info Text
                Text(
                  canUseMicrosoft
                      ? (isArabic
                          ? 'سيتم إعادة توجيهك إلى صفحة Microsoft الآمنة'
                          : 'You will be redirected to Microsoft secure login')
                      : (isArabic
                          ? 'فعّل إعدادات Microsoft أولاً أو استخدم تسجيل البريد الإلكتروني.'
                          : 'Configure Microsoft first or use Email sign-in.'),
                  style: TextStyle(
                    color: isDark ? Colors.grey[500] : Colors.grey[600],
                    fontSize: 12,
                  ),
                  textAlign: TextAlign.center,
                  textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleMicrosoftSignIn(
    BuildContext context,
    UnifiedAuthProvider auth,
    bool isArabic,
  ) async {
    setState(() => _isLoading = true);

    try {
      final result = await auth.signInWithMicrosoft();

      if (context.mounted) {
        if (result.success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                isArabic
                  ? 'تم تسجيل الدخول بنجاح'
                  : 'Signed in successfully',
              ),
            ),
          );
          await Future.delayed(const Duration(milliseconds: 300));
          if (context.mounted) {
            Navigator.of(context).pushNamedAndRemoveUntil('/main', (route) => false);
          }
        } else if (result.message != 'cancelled') {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(result.error ?? 'Microsoft sign in failed')),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(isArabic ? 'حدث خطأ: $e' : 'Error: $e')),
        );
      }
    } finally {
      if (context.mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}

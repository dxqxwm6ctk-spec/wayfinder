import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/config/email_domain_policy.dart';
import '../providers/app_settings_provider.dart';
import '../providers/unified_auth_provider.dart';

class FirebaseLoginScreen extends StatefulWidget {
  const FirebaseLoginScreen({super.key});

  @override
  State<FirebaseLoginScreen> createState() => _FirebaseLoginScreenState();
}

class _FirebaseLoginScreenState extends State<FirebaseLoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isSignUp = false;
  bool _showPassword = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<AppSettingsProvider>(context);
    final auth = Provider.of<UnifiedAuthProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isArabic = settings.language == AppLanguage.arabic;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(isArabic ? (_isSignUp ? 'إنشاء حساب' : 'دخول') : (_isSignUp ? 'Sign Up' : 'Sign In')),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                const SizedBox(height: 32),
                Icon(
                  Icons.email,
                  size: 64,
                  color: Theme.of(context).primaryColor,
                ),
                const SizedBox(height: 24),
                Text(
                  isArabic 
                    ? (_isSignUp ? 'أنشئ حسابًا جديدًا' : 'تسجيل الدخول')
                    : (_isSignUp ? 'Create new account' : 'Sign In'),
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  isArabic
                    ? 'استخدم بريدك الجامعي'
                    : 'Use your university email',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 32),
                // Email Field
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
                  decoration: InputDecoration(
                    labelText: isArabic ? 'البريد الإلكتروني' : 'Email',
                    hintText: 'student@iu.edu.jo',
                    prefixIcon: const Icon(Icons.email),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  validator: (value) {
                    if (value?.isEmpty ?? true) {
                      return isArabic ? 'البريد مطلوب' : 'Email is required';
                    }
                    if (!value!.contains('@')) {
                      return isArabic ? 'البريد غير صحيح' : 'Invalid email';
                    }
                    if (!EmailDomainPolicy.isAllowedStudentEmail(value)) {
                      return isArabic 
                        ? 'يرجى استخدام الإيميل الجامعي فقط'
                        : 'Please use your university email only';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                // Password Field
                TextFormField(
                  controller: _passwordController,
                  obscureText: !_showPassword,
                  textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
                  decoration: InputDecoration(
                    labelText: isArabic ? 'كلمة المرور' : 'Password',
                    prefixIcon: const Icon(Icons.lock),
                    suffixIcon: IconButton(
                      icon: Icon(_showPassword ? Icons.visibility : Icons.visibility_off),
                      onPressed: () {
                        setState(() => _showPassword = !_showPassword);
                      },
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  validator: (value) {
                    if (value?.isEmpty ?? true) {
                      return isArabic ? 'كلمة المرور مطلوبة' : 'Password is required';
                    }
                    if (value!.length < 6) {
                      return isArabic
                        ? 'كلمة المرور يجب أن تكون 6 أحرف على الأقل'
                        : 'Password must be at least 6 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                // Sign In/Up Button
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: auth.isLoading
                      ? null
                      : () => _handleSubmit(context, auth, isArabic),
                    child: auth.isLoading
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(
                          isArabic
                            ? (_isSignUp ? 'إنشاء حساب' : 'دخول')
                            : (_isSignUp ? 'Sign Up' : 'Sign In'),
                          style: const TextStyle(fontSize: 16),
                        ),
                  ),
                ),
                if (auth.authError != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      auth.authError ?? '',
                      style: const TextStyle(color: Colors.red),
                      textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                // Toggle Sign In/Sign Up
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
                  children: [
                    Text(
                      isArabic
                        ? (_isSignUp ? 'لديك حساب؟' : 'لا تملك حسابًا؟')
                        : (_isSignUp ? 'Have an account?' : 'Don\'t have an account?'),
                      style: TextStyle(
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: () {
                        setState(() => _isSignUp = !_isSignUp);
                        _formKey.currentState?.reset();
                      },
                      child: Text(
                        isArabic
                          ? (_isSignUp ? 'تسجيل دخول' : 'إنشاء حساب')
                          : (_isSignUp ? 'Sign In' : 'Sign Up'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleSubmit(BuildContext context, UnifiedAuthProvider auth, bool isArabic) async {
    if (!_formKey.currentState!.validate()) return;

    final email = _emailController.text.trim();
    final password = _passwordController.text;

    try {
      final result = _isSignUp
        ? await auth.signUpWithFirebase(email, password)
        : await auth.signInWithFirebase(email, password);

      if (context.mounted) {
        if (result.success) {
          if (result.requiresEmailVerification) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  result.message ??
                      (isArabic
                          ? 'تم إنشاء الحساب. افتح الرابط المرسل على البريد لإكمال تسجيل الدخول.'
                          : 'Account created. Verify your email from the link sent, then sign in.'),
                ),
              ),
            );
            setState(() => _isSignUp = false);
            _passwordController.clear();
            return;
          }

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                isArabic
                  ? (_isSignUp ? 'تم إنشاء الحساب بنجاح' : 'تم تسجيل الدخول بنجاح')
                  : (_isSignUp ? 'Account created successfully' : 'Signed in successfully'),
              ),
            ),
          );

          if (_isSignUp) {
            // For sign-up with no verification requirement, return to previous step.
            await Future.delayed(const Duration(milliseconds: 500));
            if (context.mounted) Navigator.pop(context);
          } else {
            // After successful sign-in, move to main screen directly.
            await Future.delayed(const Duration(milliseconds: 300));
            if (context.mounted) {
              Navigator.of(context).pushNamedAndRemoveUntil('/main', (route) => false);
            }
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(result.error ?? 'Authentication failed')),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(isArabic ? 'حدث خطأ: $e' : 'Error: $e')),
        );
      }
    }
  }
}

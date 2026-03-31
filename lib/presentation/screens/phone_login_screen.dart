import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_settings_provider.dart';
import '../providers/unified_auth_provider.dart';

class PhoneLoginScreen extends StatefulWidget {
  const PhoneLoginScreen({super.key});

  @override
  State<PhoneLoginScreen> createState() => _PhoneLoginScreenState();
}

class _PhoneLoginScreenState extends State<PhoneLoginScreen> {
  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _codeSent = false;

  @override
  void dispose() {
    _phoneController.dispose();
    _codeController.dispose();
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
        title: Text(isArabic ? 'دخول برقم الهاتف' : 'Phone Sign In'),
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
                  Icons.phone,
                  size: 64,
                  color: Theme.of(context).primaryColor,
                ),
                const SizedBox(height: 24),
                Text(
                  isArabic ? 'دخول برقم الهاتف' : 'Sign In with Phone',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  isArabic
                    ? 'أدخل رقم هاتفك المحمول'
                    : 'Enter your mobile phone number',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 32),
                
                if (!_codeSent) ...[
                  // Phone Number Input
                  TextFormField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    enabled: !auth.isLoading,
                    decoration: InputDecoration(
                      labelText: isArabic ? 'رقم الهاتف' : 'Phone Number',
                      hintText: '+962791234567',
                      prefixIcon: const Icon(Icons.phone),
                      prefixText: '+',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    validator: (value) {
                      if (value?.isEmpty ?? true) {
                        return isArabic ? 'رقم الهاتف مطلوب' : 'Phone number is required';
                      }
                      if (!RegExp(r'^\d{10,15}$').hasMatch(value!.replaceAll('+', ''))) {
                        return isArabic ? 'رقم هاتف غير صحيح' : 'Invalid phone number';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: auth.isLoading ? null : () => _sendCode(context, isArabic),
                      child: auth.isLoading
                          ? const SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(isArabic ? 'إرسال الكود' : 'Send Code'),
                    ),
                  ),
                ] else ...[
                  // OTP Input
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.grey[900] : Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        Text(
                          isArabic
                            ? 'تم إرسال كود التحقق إلى ${_phoneController.text}'
                            : 'Verification code sent to ${_phoneController.text}',
                          style: Theme.of(context).textTheme.bodySmall,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _codeController,
                          keyboardType: TextInputType.number,
                          enabled: !auth.isLoading,
                          maxLength: 6,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 24, letterSpacing: 8),
                          decoration: InputDecoration(
                            hintText: '000000',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          validator: (value) {
                            if (value?.isEmpty ?? true) {
                              return isArabic ? 'الكود مطلوب' : 'Code is required';
                            }
                            if (value!.length != 6) {
                              return isArabic ? 'الكود يجب أن يكون 6 أرقام' : 'Code must be 6 digits';
                            }
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: auth.isLoading ? null : () => _verifyCode(context, isArabic),
                      child: auth.isLoading
                          ? const SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(isArabic ? 'التحقق' : 'Verify'),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: auth.isLoading ? null : () => setState(() => _codeSent = false),
                    child: Text(isArabic ? 'غير رقم الهاتف' : 'Change Phone Number'),
                  ),
                ],
                
                const SizedBox(height: 32),
                // Upgrade Notice
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orange),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.info_outline, color: Colors.orange),
                      const SizedBox(height: 8),
                      Text(
                        isArabic
                          ? 'تسجيل الدخول برقم الهاتف يتطلب ترقية Firebase إلى Identity Platform'
                          : 'Phone sign-in requires upgrading to Firebase Identity Platform',
                        style: TextStyle(color: Colors.orange, fontSize: 12),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _sendCode(BuildContext context, bool isArabic) async {
    if (!_formKey.currentState!.validate()) return;

    try {
      // TODO: Implement actual phone verification
      // final result = await auth.sendPhoneVerificationCode(phone);
      // if (result) {
      //   setState(() => _codeSent = true);
      // }
      
      // For now, show message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isArabic
              ? 'يتطلب ترقية إلى Identity Platform. استخدم البريد الإلكتروني حالياً.'
              : 'Requires upgrade to Identity Platform. Use Email sign-in for now.',
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  void _verifyCode(BuildContext context, bool isArabic) async {
    if (!_formKey.currentState!.validate()) return;

    try {
      // TODO: Implement actual phone verification
      // final result = await auth.signInWithPhoneVerificationCode(_verificationId, code);
      // if (result.success) {
      //   if (context.mounted) {
      //     Navigator.of(context).pushReplacementNamed('/main');
      //   }
      // }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }
}

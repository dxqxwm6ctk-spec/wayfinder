import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../localization/app_strings.dart';
import '../providers/app_settings_provider.dart';
import '../providers/unified_auth_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/app_shell_background.dart';
import '../widgets/header_row.dart';
import 'role_selection_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  static final RegExp _busNumberPattern = RegExp(r'^[A-Za-z0-9-]{1,12}$');

  static const List<String> _pickupLocations = <String>[
    // المناطق الشمالية
    'الجبل الشمالي',
    'جبل الحسين',
    'الجاردنز',
    'الزهور',
    'القويسمة',
    'أبو علندا',
    'النزهة',
    'طبربور',
    'المقابلين',
    // المناطق الجنوبية
    'البيادر',
    'سحاب',
    'الوحدات',
    'الشرق الأوسط',
    'أبو نصير',
    'ناعور',
    'الكرك',
    'السلط',
    'لواء الجيزة',
    // المناطق الشرقية
    'رغدان',
    'الصويفية',
    'صويلح',
    'جامعة البلقاء',
    'نزال',
    'مادبا',
    'مرج الحمام',
    'الزرقاء',
    'الرصيفة',
  ];

  final TextEditingController _busController = TextEditingController();
  String? _selectedLocation;
  bool _isEditing = false;
  bool _isSaving = false;

  @override
  void dispose() {
    _busController.dispose();
    super.dispose();
  }

  void _syncControllers(UnifiedAuthProvider auth, AppStrings strings) {
    if (_isEditing) {
      return;
    }

    // Check if the saved location exists in the current list
    final String? savedLocation = auth.defaultPickupArea?.trim().isNotEmpty == true
        ? auth.defaultPickupArea!.trim()
        : null;
    
    _selectedLocation = (savedLocation != null && _pickupLocations.contains(savedLocation))
        ? savedLocation
        : _pickupLocations.first; // Default to first location if not found
    
    _busController.text = auth.usualBusNumber?.trim() ?? '';
  }

  Future<void> _saveEditableFields(UnifiedAuthProvider auth, bool isArabic) async {
    final String pickup = _selectedLocation ?? '';
    final String bus = _busController.text.trim().toUpperCase().replaceAll(' ', '');

    if (pickup.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isArabic ? 'اختر موقع السكن أو نقطة الانطلاق.' : 'Please select your pickup/home location.',
          ),
        ),
      );
      return;
    }

    if (bus.isNotEmpty && !_busNumberPattern.hasMatch(bus)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isArabic
                ? 'صيغة رقم الباص غير صحيحة. المسموح: أحرف/أرقام/- فقط وبحد أقصى 12.'
                : 'Invalid bus format. Use letters/numbers/dash only (max 12).',
          ),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    final bool success = await auth.updateEditableStudentProfile(
      defaultPickupArea: pickup,
      usualBusNumber: bus,
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _isSaving = false;
      if (success) {
        _isEditing = false;
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? (isArabic ? 'تم حفظ التعديلات.' : 'Profile updated successfully.')
              : (auth.authError ?? (isArabic ? 'تعذر حفظ التعديلات.' : 'Failed to save changes.')),
        ),
      ),
    );
  }

  Future<void> _signOut(UnifiedAuthProvider auth, bool isArabic) async {
    setState(() => _isSaving = true);
    await auth.signOut();

    if (!mounted) {
      return;
    }

    setState(() {
      _isSaving = false;
      _isEditing = false;
    });

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const RoleSelectionScreen()),
      (Route<dynamic> route) => false,
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(isArabic ? 'تم تسجيل الخروج.' : 'Signed out successfully.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppSettingsProvider settings = context.watch<AppSettingsProvider>();
    final UnifiedAuthProvider auth = context.watch<UnifiedAuthProvider>();
    final AppStrings strings = AppStrings(isArabic: settings.isArabic);
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final bool isArabic = settings.isArabic;

    final String displayName = auth.currentName?.trim().isNotEmpty == true
      ? auth.currentName!.trim()
      : (isArabic ? 'الطالب' : 'Student');
    final String displayEmail = auth.currentEmail?.trim().isNotEmpty == true
      ? auth.currentEmail!.trim()
      : (isArabic ? 'لا يوجد بريد إلكتروني' : 'No email found');
    final String displayPickup = auth.defaultPickupArea?.trim().isNotEmpty == true
      ? auth.defaultPickupArea!.trim()
      : strings.defaultPickup;
    final String displayStudentId = auth.studentId?.trim().isNotEmpty == true
      ? auth.studentId!.trim()
      : (isArabic ? 'غير متوفر' : 'Not available');
    final String displayRole = auth.studentRole?.trim().isNotEmpty == true
      ? auth.studentRole!.trim()
      : (isArabic ? 'طالب' : 'Student');
    final String displayMajor = auth.studentMajor?.trim().isNotEmpty == true
      ? auth.studentMajor!.trim()
      : (isArabic ? 'غير متوفر' : 'Not available');
    final String displayPhone = auth.studentPhone?.trim().isNotEmpty == true
      ? auth.studentPhone!.trim()
      : (isArabic ? 'غير متوفر' : 'Not available');
    final String displayBus = auth.usualBusNumber?.trim().isNotEmpty == true
      ? auth.usualBusNumber!.trim()
      : (isArabic ? 'غير متوفر' : 'Not available');

    _syncControllers(auth, strings);

    return Scaffold(
      body: AppShellBackground(
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              HeaderRow(title: strings.appName),
              const SizedBox(height: 26),
              Text(
                strings.profileTitle,
                style: Theme.of(context).textTheme.headlineLarge,
              ),
              const SizedBox(height: 8),
              Text(
                strings.profileSubtitle,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 30),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.surface : Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.05)
                        : Colors.black.withValues(alpha: 0.07),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    if (auth.isProfileLoading) ...<Widget>[
                      const LinearProgressIndicator(minHeight: 3),
                      const SizedBox(height: 14),
                    ],
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: <Widget>[
                        Text(
                          isArabic ? 'البيانات الأساسية' : 'Basic Information',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        if (!_isEditing)
                          TextButton.icon(
                            onPressed: (_isSaving || auth.isProfileLoading)
                                ? null
                                : () => setState(() => _isEditing = true),
                            icon: const Icon(Icons.edit, size: 18),
                            label: Text(isArabic ? 'تعديل' : 'Edit'),
                          )
                        else
                          TextButton(
                            onPressed: (_isSaving || auth.isProfileLoading)
                                ? null
                                : () {
                                    setState(() => _isEditing = false);
                                    _syncControllers(auth, strings);
                                  },
                            child: Text(isArabic ? 'إلغاء' : 'Cancel'),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      displayName,
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      displayEmail,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 16),
                    if (_isEditing) ...<Widget>[
                      DropdownButtonFormField<String>(
                        initialValue: _selectedLocation,
                        decoration: InputDecoration(
                          labelText: isArabic ? 'السكن/نقطة الانطلاق' : 'Home / Pickup Location',
                          border: const OutlineInputBorder(),
                        ),
                        items: _pickupLocations.map((String location) {
                          return DropdownMenuItem<String>(
                            value: location,
                            child: Text(location),
                          );
                        }).toList(),
                        onChanged: (String? newValue) {
                          setState(() => _selectedLocation = newValue);
                        },
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _busController,
                        textInputAction: TextInputAction.done,
                        decoration: InputDecoration(
                          labelText: isArabic ? 'رقم الباص المعتاد' : 'Usual Bus Number',
                          border: const OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: (_isSaving || auth.isProfileLoading)
                              ? null
                              : () => _saveEditableFields(auth, isArabic),
                          child: _isSaving
                              ? const SizedBox(
                                  height: 18,
                                  width: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : Text(isArabic ? 'حفظ' : 'Save'),
                        ),
                      ),
                    ] else ...<Widget>[
                      Text(
                        displayPickup,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 10),
                      _ProfileInfoTile(
                        label: isArabic ? 'رقم الباص المعتاد' : 'Usual Bus Number',
                        value: displayBus,
                      ),
                    ],
                    const SizedBox(height: 20),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: _ProfileInfoTile(
                            label: isArabic ? 'الرقم الجامعي' : 'Student ID',
                            value: displayStudentId,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _ProfileInfoTile(
                            label: isArabic ? 'الدور' : 'Role',
                            value: displayRole,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _ProfileInfoTile(
                      label: isArabic ? 'التخصص' : 'Major / Faculty',
                      value: displayMajor,
                    ),
                    const SizedBox(height: 10),
                    _ProfileInfoTile(
                      label: isArabic ? 'رقم الهاتف' : 'Phone Number',
                      value: displayPhone,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      isArabic
                          ? 'يمكنك تعديل السكن/الانطلاق ورقم الباص فقط. الاسم والبريد وباقي البيانات للعرض فقط.'
                          : 'Only home/pickup and usual bus number are editable. Name, email, and other fields are read-only.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: (_isSaving || auth.isLoading)
                            ? null
                            : () => _signOut(auth, isArabic),
                        icon: const Icon(Icons.logout),
                        label: Text(isArabic ? 'تسجيل خروج' : 'Sign Out'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileInfoTile extends StatelessWidget {
  const _ProfileInfoTile({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

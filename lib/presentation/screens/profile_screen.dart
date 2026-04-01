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
    'شارع الجامعة',
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

  void _syncControllers(UnifiedAuthProvider auth) {
    if (_isEditing) {
      return;
    }

    final String? savedLocation = auth.defaultPickupArea?.trim().isNotEmpty == true
        ? auth.defaultPickupArea!.trim()
        : null;

    _selectedLocation = (savedLocation != null && _pickupLocations.contains(savedLocation))
        ? savedLocation
        : _pickupLocations.first;

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

  Future<void> _refreshProfile(UnifiedAuthProvider auth) async {
    await auth.refreshProfileData();
    if (!mounted) {
      return;
    }
    final bool isArabic = context.read<AppSettingsProvider>().isArabic;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(isArabic ? 'تم تحديث الملف الشخصي.' : 'Profile refreshed successfully.'),
        duration: const Duration(seconds: 2),
      ),
    );
    _syncControllers(auth);
  }

  @override
  Widget build(BuildContext context) {
    final AppSettingsProvider settings = context.watch<AppSettingsProvider>();
    final UnifiedAuthProvider auth = context.watch<UnifiedAuthProvider>();
    final AppStrings strings = AppStrings(isArabic: settings.isArabic);
    final bool isArabic = settings.isArabic;

    final String displayName = auth.currentName?.trim().isNotEmpty == true
      ? auth.currentName!.trim()
      : (isArabic ? 'الطالب' : 'Student');
    final photoBytes = auth.currentPhotoBytes;
    final String? profilePhotoUrl = _normalizeImageUrl(auth.currentPhotoUrl);
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

    _syncControllers(auth);

    return Scaffold(
      body: AppShellBackground(
        child: RefreshIndicator(
          onRefresh: () => _refreshProfile(auth),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                HeaderRow(title: strings.appName),
                const SizedBox(height: 24),
                Text(
                  strings.profileTitle,
                  style: Theme.of(context).textTheme.headlineLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  strings.profileSubtitle,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 24),
                _GlassPanel(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              gradient: AppColors.primaryGradient,
                              borderRadius: BorderRadius.circular(22),
                            ),
                            child: (photoBytes == null && profilePhotoUrl == null)
                                ? Center(
                                    child: Text(
                                      (displayName.isNotEmpty
                                              ? displayName.characters.first
                                              : 'S')
                                          .toUpperCase(),
                                      style: Theme.of(context)
                                          .textTheme
                                          .headlineMedium
                                          ?.copyWith(color: Colors.white),
                                    ),
                                  )
                                : ClipRRect(
                                    borderRadius: BorderRadius.circular(22),
                                    child: photoBytes != null
                                        ? Image.memory(
                                            photoBytes,
                                            fit: BoxFit.cover,
                                          )
                                        : Image.network(
                                            profilePhotoUrl!,
                                            fit: BoxFit.cover,
                                            errorBuilder: (
                                              BuildContext context,
                                              Object error,
                                              StackTrace? stackTrace,
                                            ) {
                                              return Center(
                                                child: Text(
                                                  (displayName.isNotEmpty
                                                          ? displayName.characters.first
                                                          : 'S')
                                                      .toUpperCase(),
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .headlineMedium
                                                      ?.copyWith(color: Colors.white),
                                                ),
                                              );
                                            },
                                          ),
                                  ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  displayName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.headlineMedium,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  displayEmail,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (!_isEditing)
                            IconButton.filledTonal(
                              onPressed: (_isSaving || auth.isProfileLoading)
                                  ? null
                                  : () => setState(() => _isEditing = true),
                              icon: const Icon(Icons.edit_rounded),
                            )
                          else
                            TextButton(
                              onPressed: (_isSaving || auth.isProfileLoading)
                                  ? null
                                  : () {
                                      setState(() => _isEditing = false);
                                      _syncControllers(auth);
                                    },
                              child: Text(isArabic ? 'إلغاء' : 'Cancel'),
                            ),
                        ],
                      ),
                      if (auth.isProfileLoading) ...<Widget>[
                        const SizedBox(height: 16),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: const LinearProgressIndicator(minHeight: 4),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _GlassPanel(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        isArabic ? 'المعلومات الأساسية' : 'Personal Details',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 16),
                      _ProfileMetaRow(
                        icon: Icons.badge_outlined,
                        label: isArabic ? 'الرقم الجامعي' : 'Student ID',
                        value: displayStudentId,
                      ),
                      const SizedBox(height: 12),
                      _ProfileMetaRow(
                        icon: Icons.school_outlined,
                        label: isArabic ? 'التخصص' : 'Major / Faculty',
                        value: displayMajor,
                      ),
                      const SizedBox(height: 12),
                      _ProfileMetaRow(
                        icon: Icons.phone_outlined,
                        label: isArabic ? 'رقم الهاتف' : 'Phone Number',
                        value: displayPhone,
                      ),
                      const SizedBox(height: 12),
                      _ProfileMetaRow(
                        icon: Icons.verified_user_outlined,
                        label: isArabic ? 'الدور' : 'Role',
                        value: displayRole,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _GlassPanel(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        isArabic ? 'تفضيلات الرحلة' : 'Ride Preferences',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        isArabic
                            ? 'يمكنك تعديل السكن/الانطلاق ورقم الباص فقط.'
                            : 'Only home pickup and bus number are editable.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 14),
                      if (_isEditing) ...<Widget>[
                        DropdownButtonFormField<String>(
                          initialValue: _selectedLocation,
                          decoration: InputDecoration(
                            labelText:
                                isArabic ? 'السكن/نقطة الانطلاق' : 'Home / Pickup Location',
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
                        const SizedBox(height: 12),
                        TextField(
                          controller: _busController,
                          textInputAction: TextInputAction.done,
                          decoration: InputDecoration(
                            labelText: isArabic ? 'رقم الباص المعتاد' : 'Usual Bus Number',
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: AppColors.primaryGradient,
                              borderRadius: BorderRadius.circular(18),
                              boxShadow: <BoxShadow>[
                                BoxShadow(
                                  color: AppColors.accent.withValues(alpha: 0.36),
                                  blurRadius: 24,
                                  spreadRadius: -10,
                                  offset: const Offset(0, 14),
                                ),
                              ],
                            ),
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                              ),
                              onPressed: (_isSaving || auth.isProfileLoading)
                                  ? null
                                  : () => _saveEditableFields(auth, isArabic),
                              child: _isSaving
                                  ? const SizedBox(
                                      height: 18,
                                      width: 18,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : Text(isArabic ? 'حفظ التغييرات' : 'Save Changes'),
                            ),
                          ),
                        ),
                      ] else ...<Widget>[
                        _ProfileMetaRow(
                          icon: Icons.place_outlined,
                          label: isArabic ? 'السكن/الانطلاق' : 'Home / Pickup',
                          value: displayPickup,
                        ),
                        const SizedBox(height: 12),
                        _ProfileMetaRow(
                          icon: Icons.directions_bus_outlined,
                          label: isArabic ? 'رقم الباص المعتاد' : 'Usual Bus Number',
                          value: displayBus,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: (_isSaving || auth.isLoading)
                        ? null
                        : () => _signOut(auth, isArabic),
                    icon: const Icon(Icons.logout_rounded),
                    label: Text(isArabic ? 'تسجيل خروج' : 'Sign Out'),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                        color: Colors.white.withValues(alpha: 0.15),
                      ),
                      backgroundColor: Colors.white.withValues(alpha: 0.03),
                      foregroundColor: AppColors.textSecondary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String? _normalizeImageUrl(String? rawUrl) {
    final String? trimmed = rawUrl?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }

    final Uri? uri = Uri.tryParse(trimmed);
    if (uri == null || !uri.hasScheme || !(uri.scheme == 'http' || uri.scheme == 'https')) {
      return null;
    }

    return trimmed;
  }
}

class _GlassPanel extends StatelessWidget {
  const _GlassPanel({
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.glass.withValues(alpha: 0.32)
            : Colors.white.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.1)
              : Colors.black.withValues(alpha: 0.05),
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.26 : 0.08),
            blurRadius: 26,
            spreadRadius: -12,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _ProfileMetaRow extends StatelessWidget {
  const _ProfileMetaRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.black.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: AppColors.accentLight),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(label, style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: value == 'غير متوفر' || value == 'Not available'
                        ? AppColors.textMuted
                        : null,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

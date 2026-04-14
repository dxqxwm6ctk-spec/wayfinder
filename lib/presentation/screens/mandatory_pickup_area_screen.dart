import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_settings_provider.dart';
import '../providers/unified_auth_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/app_shell_background.dart';

class MandatoryPickupAreaScreen extends StatefulWidget {
  const MandatoryPickupAreaScreen({super.key});

  @override
  State<MandatoryPickupAreaScreen> createState() =>
      _MandatoryPickupAreaScreenState();
}

class _MandatoryPickupAreaScreenState extends State<MandatoryPickupAreaScreen> {
  static const List<String> _pickupLocations = <String>[
    'الجبل الشمالي',
    'جبل الحسين',
    'الجاردنز',
    'الزهور',
    'القويسمة',
    'أبو علندا',
    'النزهة',
    'طبربور',
    'المقابلين',
    'البيادر',
    'سحاب',
    'الوحدات',
    'الشرق الأوسط',
    'أبو نصير',
    'ناعور',
    'الكرك',
    'السلط',
    'لواء الجيزة',
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

  static const List<_ScheduleOption> _scheduleOptions = <_ScheduleOption>[
    _ScheduleOption('أحد / ثلاثاء', 'sunday_tuesday'),
    _ScheduleOption('اثنين / أربعاء', 'monday_wednesday'),
    _ScheduleOption('يومي', 'daily'),
  ];

  String? _selectedLocation;
  String? _selectedSchedule;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final UnifiedAuthProvider auth = context.read<UnifiedAuthProvider>();
    final String? existing = auth.defaultPickupArea?.trim();
    if (existing != null &&
        existing.isNotEmpty &&
        _pickupLocations.contains(existing)) {
      _selectedLocation = existing;
    } else {
      _selectedLocation = _pickupLocations.first;
    }

    final String? existingSchedule = auth.pickupSchedule?.trim();
    if (existingSchedule != null && existingSchedule.isNotEmpty) {
      final _ScheduleOption matched = _scheduleOptions.firstWhere(
        (_ScheduleOption option) => option.value == existingSchedule,
        orElse: () => _scheduleOptions.first,
      );
      _selectedSchedule = matched.value;
    } else {
      _selectedSchedule = _scheduleOptions.first.value;
    }
  }

  Future<void> _save(UnifiedAuthProvider auth, bool isArabic) async {
    final String area = (_selectedLocation ?? '').trim();
    final String schedule = (_selectedSchedule ?? '').trim();
    if (area.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isArabic
                ? 'اختيار منطقة السكن إلزامي للمتابعة.'
                : 'Selecting a residence area is required to continue.',
          ),
        ),
      );
      return;
    }

    if (schedule.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isArabic
                ? 'اختيار الدوام إلزامي للمتابعة.'
                : 'Selecting the schedule is required to continue.',
          ),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    final bool ok = await auth.updateEditableStudentProfile(
      defaultPickupArea: area,
      usualBusNumber: auth.usualBusNumber ?? '',
      pickupSchedule: schedule,
    );

    if (!mounted) {
      return;
    }

    setState(() => _isSaving = false);

    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            auth.authError ??
                (isArabic
                    ? 'تعذر حفظ منطقة السكن، حاول مرة أخرى.'
                    : 'Could not save residence area. Please try again.'),
          ),
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isArabic
              ? 'تم حفظ منطقة السكن، يمكنك المتابعة الآن.'
              : 'Residence area saved. You can continue now.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final UnifiedAuthProvider auth = context.watch<UnifiedAuthProvider>();
    final AppSettingsProvider settings = context.watch<AppSettingsProvider>();
    final bool isArabic = settings.language == AppLanguage.arabic;

    return PopScope(
      canPop: false,
      child: Scaffold(
        body: AppShellBackground(
          padding: const EdgeInsets.fromLTRB(24, 56, 24, 24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.16),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      isArabic ? 'إكمال الملف الشخصي' : 'Complete Your Profile',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isArabic
                          ? 'لا يمكنك المتابعة قبل اختيار مكان السكن (منطقة الانطلاق).'
                          : 'You must select your residence/pickup area before continuing.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      isArabic ? 'منطقة السكن' : 'Residence Area',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: AppColors.accentLight,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      initialValue: _selectedLocation,
                      items: _pickupLocations
                          .map(
                            (String location) => DropdownMenuItem<String>(
                              value: location,
                              child: Text(location),
                            ),
                          )
                          .toList(growable: false),
                      onChanged: _isSaving
                          ? null
                          : (String? value) {
                              if (value == null) {
                                return;
                              }
                              setState(() => _selectedLocation = value);
                            },
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: 0.04),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      isArabic ? 'نوع الدوام' : 'Schedule Type',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: AppColors.accentLight,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: _scheduleOptions
                          .map((_ScheduleOption option) {
                            final bool selected =
                                _selectedSchedule == option.value;
                            return ChoiceChip(
                              label: Text(option.label),
                              selected: selected,
                              onSelected: _isSaving
                                  ? null
                                  : (bool value) {
                                      if (!value) {
                                        return;
                                      }
                                      setState(
                                        () => _selectedSchedule = option.value,
                                      );
                                    },
                            );
                          })
                          .toList(growable: false),
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _isSaving || auth.isLoading
                            ? null
                            : () => _save(auth, isArabic),
                        child: _isSaving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(
                                isArabic ? 'حفظ ومتابعة' : 'Save & Continue',
                                style: const TextStyle(fontSize: 16),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ScheduleOption {
  const _ScheduleOption(this.label, this.value);

  final String label;
  final String value;
}

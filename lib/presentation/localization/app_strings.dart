class AppStrings {
  const AppStrings({required this.isArabic});

  final bool isArabic;

  String get appName => isArabic ? 'وايفندر' : 'WAYFINDER';
  String get portalTitle =>
      isArabic ? 'بوابة النقل الجامعي' : 'UNIVERSITY TRANSIT PORTAL';
  String get studentLogin => isArabic ? 'تسجيل دخول الطالب' : 'Student Login';
  String get roleSelectionTitle =>
      isArabic ? 'اختر نوع الحساب' : 'Choose Account Type';
  String get roleSelectionSubtitle => isArabic
      ? 'ادخل كطالب أو كقائد أسطول.'
      : 'Sign in as a student or fleet leader.';
  String get continueAsStudent => isArabic ? 'الدخول كطالب' : 'Continue As Student';
  String get continueAsLeader => isArabic ? 'الدخول كقائد' : 'Continue As Leader';
  String get back => isArabic ? 'رجوع' : 'Back';
  String get leaderLogin => isArabic ? 'تسجيل دخول القائد' : 'Leader Login';
  String get leaderEmail => isArabic ? 'البريد الوظيفي' : 'LEADER EMAIL';
  String get leaderEmailHint =>
      isArabic ? 'leader@university.edu' : 'leader@university.edu';
  String get leaderPasswordHint =>
      isArabic ? 'أدخل كلمة مرور القائد' : 'Enter leader password';
  String get leaderInvalidCredentials => isArabic
      ? 'بيانات القائد غير صحيحة.'
      : 'Invalid leader credentials.';
  String get useLeaderTestUser =>
      isArabic ? 'استخدم حساب قائد تجريبي' : 'USE LEADER TEST USER';
  String get leaderPanelTitle =>
      isArabic ? 'لوحة القائد' : 'Leader Control';
  String get leaderPanelSubtitle => isArabic
      ? 'تعيين أرقام الباصات للمناطق.'
      : 'Assign buses to campus zones.';
  String get universityEmail =>
      isArabic ? 'البريد الجامعي' : 'UNIVERSITY EMAIL';
  String get emailHint =>
      isArabic ? 'username@iu.edu.co' : 'username@iu.edu.co';
  String get password => isArabic ? 'كلمة المرور' : 'PASSWORD';
  String get forgot => isArabic ? 'نسيت؟' : 'FORGOT?';
  String get login => isArabic ? 'دخول' : 'LOGIN';
  String get requestAccess => isArabic ? 'طلب صلاحية' : 'REQUEST ACCESS';
  String get or => isArabic ? 'أو' : 'OR';
  String get activeStatus => isArabic ? 'حالة النظام' : 'Active Status';
  String get systemLive => isArabic ? 'النظام يعمل' : 'System Live';
  String get campusConnectivity =>
      isArabic ? 'اتصال الحرم' : 'Campus Connectivity';
  String get uptime => isArabic ? 'جاهزية 98%' : '98% Uptime';
  String get testUser => isArabic ? 'استخدم حساب تجريبي' : 'USE TEST USER';
    String get languageEnglish => isArabic ? 'الإنجليزية' : 'English';
    String get languageArabic => isArabic ? 'العربية' : 'العربية';
  String get invalidCredentials => isArabic
      ? 'بيانات الجامعة غير صحيحة.'
      : 'Invalid university credentials.';
  String get emailRequired => isArabic ? 'البريد مطلوب' : 'Email is required';
  String get emailInvalid => isArabic
      ? 'استخدم بريد الجامعة المرتبط بمايكروسوفت.'
      : 'Use your Microsoft university email.';
  String get passwordInvalid => isArabic
      ? 'كلمة المرور لا تقل عن 6 أحرف'
      : 'Password must be at least 6 characters';

  String get onDemandTransit =>
      isArabic ? 'نقل حسب الطلب' : 'ON-DEMAND TRANSIT';
  String get requestRide => isArabic ? 'اطلب رحلة' : 'Request a Ride';
  String get requestSubtitle => isArabic
      ? 'تنقّل جامعي سلس للطالب الحديث.'
      : 'Seamless campus navigation for the modern scholar.';
  String get immediatePickup => isArabic ? 'استلام فوري' : 'Immediate Pickup';
  String get priorityDispatch =>
      isArabic ? 'أولوية الإرسال' : 'PRIORITY DISPATCH';
  String get pickupArea => isArabic ? 'اختر منطقة الانطلاق' : 'SELECT PICK-UP AREA';
  String get currentlyWaiting =>
      isArabic ? 'المنتظرون حاليًا' : 'Currently Waiting';
  String get students => isArabic ? 'طالب' : 'Students';
  String get fleetStatus => isArabic ? 'حالة الأسطول' : 'Fleet Status';
  String get confirmRequest =>
      isArabic ? 'تأكيد الطلب' : 'CONFIRM REQUEST';
  String get executeRequest => isArabic ? 'تنفيذ الطلب' : 'EXECUTE REQUEST';
  String get turnOnImmediateHint => isArabic
      ? 'فعّل الاستلام الفوري لتحديد المنطقة وتنفيذ الطلب.'
      : 'Turn on immediate pickup to select area and execute request.';
  String get requestSummaryTitle =>
      isArabic ? 'تفاصيل التنفيذ' : 'Execution Summary';
  String get selectedArea => isArabic ? 'المنطقة' : 'Area';
  String get assignedBus => isArabic ? 'رقم الباص' : 'Bus Number';
  String get noBusAssigned => isArabic ? 'لا يوجد باص مخصص' : 'No bus assigned';
  String requestConfirmedFor(String area) => isArabic
      ? 'تم تأكيد الرحلة لمنطقة $area'
      : 'Ride request confirmed for $area';

  String get requestTab => isArabic ? 'طلب' : 'REQUEST';
  String get statusTab => isArabic ? 'الحالة' : 'STATUS';
  String get fleetTab => isArabic ? 'الأسطول' : 'FLEET';
  String get profileTab => isArabic ? 'الملف' : 'PROFILE';

  String get transitStatusTitle => isArabic ? 'حالة\nالنقل' : 'Transit\nStatus';
  String get transitStatusSubtitle =>
      isArabic ? 'تشغيل حي عبر الحرم الجامعي.' : 'Live operations across your campus.';
  String get queueLoad => isArabic ? 'ضغط الطابور' : 'Queue Load';
  String studentsWaitingCount(int count) =>
      isArabic ? '$count طالب بانتظار الحافلة' : '$count Students Waiting';

  String get academicWayfinder =>
      isArabic ? 'وايفندر الأكاديمي' : 'ACADEMIC WAYFINDER';
  String get fleetCommandTitle => isArabic ? 'قيادة\nالأسطول' : 'Fleet\nCommand';
  String get fleetCommandSubtitle =>
      isArabic ? 'تخصيص ديناميكي للمناطق.' : 'Dynamic zone allocation.';
  String get campusLoadingZones =>
      isArabic ? 'مناطق التحميل في الحرم' : 'CAMPUS LOADING ZONES';
  String get studentsWaitingLabel =>
      isArabic ? 'طلاب بانتظار الحافلة' : 'STUDENTS WAITING';
  String get critical => isArabic ? 'حرج' : 'CRITICAL';
  String get moderate => isArabic ? 'متوسط' : 'MODERATE';
  String get stable => isArabic ? 'مستقر' : 'STABLE';
  String get remove => isArabic ? 'إزالة' : 'REMOVE';
  String get enterBus => isArabic ? 'أدخل رقم الباص' : 'Enter Bus #';
  String get assign => isArabic ? 'تعيين' : 'ASSIGN';
  String get busRequired =>
      isArabic ? 'رقم الحافلة مطلوب.' : 'Bus number is required.';

  String get profileTitle => isArabic ? 'الملف الشخصي' : 'Profile';
  String get profileSubtitle =>
      isArabic ? 'حساب الطالب وتفضيلات الرحلات.' : 'Student account and ride preferences.';
  String get defaultPickup =>
            isArabic
                    ? 'نقطة الانطلاق الافتراضية: ${localizePickupArea('North Campus (Library Hub)')}'
                    : 'Default Pickup: North Campus (Library Hub)';

    String localizePickupArea(String area) {
        if (!isArabic) {
            return area;
        }

        switch (area) {
            case 'North Campus (Library Hub)':
                return 'الحرم الشمالي (مركز المكتبة)';
            case 'STEM Plaza':
                return 'ساحة STEM';
            case 'South Terminal':
                return 'المحطة الجنوبية';
            case 'Housing Complex':
                return 'مجمع السكن';
            default:
                return area;
        }
    }

    String localizeZoneName(String name) {
        if (!isArabic) {
            return name;
        }

        switch (name) {
            case 'North Campus':
                return 'الحرم الشمالي';
            case 'STEM Plaza':
                return 'ساحة STEM';
            case 'South Terminal':
                return 'المحطة الجنوبية';
            case 'Housing Complex':
                return 'مجمع السكن';
            default:
                return name;
        }
    }

    String localizeSystemStatus(String status) {
        if (!isArabic) {
            return status;
        }
        if (status.toLowerCase() == 'system live') {
            return 'النظام يعمل';
        }
        return status;
    }

    String localizeCampusConnectivity(String text) {
        if (!isArabic) {
            return text;
        }
        if (text.toLowerCase() == '98% uptime') {
            return 'جاهزية 98%';
        }
        return text;
    }

    String localizeFleetStatus(String text) {
        if (!isArabic) {
            return text;
        }
        final RegExp busStatus = RegExp(r'^BUS\s*#?\s*([A-Za-z0-9]+)\s+READY$', caseSensitive: false);
        final RegExpMatch? match = busStatus.firstMatch(text.trim());
        if (match != null) {
            return 'الحافلة #${match.group(1)} جاهزة';
        }
        return text;
    }
}

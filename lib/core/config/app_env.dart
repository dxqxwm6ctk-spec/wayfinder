class AppEnv {
  static const bool useMock = bool.fromEnvironment(
    'USE_MOCK',
    defaultValue: true,
  );

  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: '',
  );

  static const String microsoftClientId = String.fromEnvironment(
    'MICROSOFT_CLIENT_ID',
    defaultValue: '4d68ab13-61fc-40b8-beb5-1220dd35e39d',
  );

  static const String microsoftTenantId = String.fromEnvironment(
    'MICROSOFT_TENANT_ID',
    defaultValue: '2f92683b-1e10-4a6c-aebd-5d03a4c9a258',
  );

  static const String microsoftRedirectUrl = String.fromEnvironment(
    'MICROSOFT_REDIRECT_URL',
    defaultValue: 'com.example.wayfinder://auth',
  );

  // Microsoft sign-in is now configured in Firebase Console.
  static const bool microsoftSignInEnabled = bool.fromEnvironment(
    'MICROSOFT_SIGN_IN_ENABLED',
    defaultValue: true,
  );

  static const bool googleSignInEnabled = bool.fromEnvironment(
    'GOOGLE_SIGN_IN_ENABLED',
    defaultValue: true,
  );

  static const String emailLinkContinueUrl = String.fromEnvironment(
    'EMAIL_LINK_CONTINUE_URL',
    defaultValue: 'https://wayfinder-recover-2026.firebaseapp.com',
  );

  // Optional Firebase Web config injected via --dart-define.
  static const String firebaseWebApiKey = String.fromEnvironment(
    'FIREBASE_WEB_API_KEY',
    defaultValue: '',
  );

  static const String firebaseWebAppId = String.fromEnvironment(
    'FIREBASE_WEB_APP_ID',
    defaultValue: '',
  );

  static const String firebaseWebMessagingSenderId = String.fromEnvironment(
    'FIREBASE_WEB_MESSAGING_SENDER_ID',
    defaultValue: '',
  );

  static const String firebaseWebProjectId = String.fromEnvironment(
    'FIREBASE_WEB_PROJECT_ID',
    defaultValue: '',
  );

  static const String firebaseWebAuthDomain = String.fromEnvironment(
    'FIREBASE_WEB_AUTH_DOMAIN',
    defaultValue: '',
  );

  static const String firebaseWebStorageBucket = String.fromEnvironment(
    'FIREBASE_WEB_STORAGE_BUCKET',
    defaultValue: '',
  );

  static const String firebaseWebMeasurementId = String.fromEnvironment(
    'FIREBASE_WEB_MEASUREMENT_ID',
    defaultValue: '',
  );

  static bool get hasFirebaseWebConfig {
    return firebaseWebApiKey.trim().isNotEmpty &&
        firebaseWebAppId.trim().isNotEmpty &&
        firebaseWebMessagingSenderId.trim().isNotEmpty &&
        firebaseWebProjectId.trim().isNotEmpty;
  }

  static bool get canUseRemote => !useMock && apiBaseUrl.trim().isNotEmpty;

  static bool get canUseMicrosoftAuth {
    return microsoftSignInEnabled;
  }

  static String get microsoftConfigHint {
    return microsoftSignInEnabled
        ? 'Configured in Firebase Authentication'
        : 'Disabled by MICROSOFT_SIGN_IN_ENABLED';
  }
}

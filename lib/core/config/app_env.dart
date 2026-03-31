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
    defaultValue: '',
  );

  static const String microsoftTenantId = String.fromEnvironment(
    'MICROSOFT_TENANT_ID',
    defaultValue: '074ab189-f952-432d-815b-4535fdc03417',
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
    defaultValue: 'https://wayfinder-284c0.firebaseapp.com',
  );

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

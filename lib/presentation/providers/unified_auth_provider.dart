import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/config/app_env.dart';
import '../../core/services/firebase_service.dart';
import '../../core/services/microsoft_auth_service.dart';
import '../../core/config/email_domain_policy.dart';

/// Authentication method types
enum AuthMethod { firebase, microsoft, mock }

/// Result of authentication attempt
class AuthResult {
  final bool success;
  final String? uid;
  final String? email;
  final String? name;
  final String? accessToken;
  final String? idToken;
  final String? refreshToken;
  final String? error;
  final String? message;
  final bool requiresEmailVerification;
  final AuthMethod method;

  AuthResult({
    required this.success,
    this.uid,
    this.email,
    this.name,
    this.accessToken,
    this.idToken,
    this.refreshToken,
    this.error,
    this.message,
    this.requiresEmailVerification = false,
    required this.method,
  });
}

/// Unified authentication provider combining Firebase and Microsoft
class UnifiedAuthProvider extends ChangeNotifier {
  static const String _lastUserRoleKey = 'app.last_user_role';
  static final RegExp _busNumberPattern = RegExp(r'^[A-Za-z0-9-]{1,12}$');

  final FirebaseService _firebaseService;
  final MicrosoftAuthService _microsoftAuthService;

  firebase.User? _currentUser;
  String? _currentEmail;
  String? _currentName;
  String? _currentPhotoUrl;
  Uint8List? _currentPhotoBytes;
  String? _studentId;
  String? _studentRole;
  String? _studentMajor;
  String? _studentPhone;
  String? _defaultPickupArea;
  String? _usualBusNumber;
  AuthMethod? _lastAuthMethod;
  bool _isLoading = false;
  bool _isProfileLoading = false;
  bool _isAuthStateReady = false;
  String? _authError;
  String? _microsoftRefreshToken;
  SharedPreferences? _preferences;

  UnifiedAuthProvider({
    required FirebaseService firebaseService,
    required MicrosoftAuthService microsoftAuthService,
  })  : _firebaseService = firebaseService,
        _microsoftAuthService = microsoftAuthService {
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    try {
      _preferences = await SharedPreferences.getInstance();
      await _firebaseService.initialize();
      _initializeAuthListener();
    } catch (e) {
      debugPrint('Auth bootstrap warning: $e');
    }
  }

  Future<void> _cacheLastUserRole(String role) async {
    final String normalized = role.trim().toLowerCase();
    if (normalized.isEmpty) {
      return;
    }
    _preferences ??= await SharedPreferences.getInstance();
    await _preferences?.setString(_lastUserRoleKey, normalized);
  }

  // Getters
  firebase.User? get currentUser => _currentUser;
  String? get currentEmail => _currentEmail;
  String? get currentName => _currentName;
  String? get currentPhotoUrl => _currentPhotoUrl;
  Uint8List? get currentPhotoBytes => _currentPhotoBytes;
  String? get studentId => _studentId;
  String? get studentRole => _studentRole;
  String? get studentMajor => _studentMajor;
  String? get studentPhone => _studentPhone;
  String? get defaultPickupArea => _defaultPickupArea;
  String? get usualBusNumber => _usualBusNumber;
  bool get isAuthenticated => _currentUser != null || _currentEmail != null;
  bool get isLoading => _isLoading;
  bool get isProfileLoading => _isProfileLoading;
  bool get isAuthStateReady => _isAuthStateReady;
  String? get authError => _authError;
  AuthMethod? get lastAuthMethod => _lastAuthMethod;
  List<String> get allowedDomains => EmailDomainPolicy.allowedDomains;

  /// Initialize Firebase auth state listener
  void _initializeAuthListener() {
    _firebaseService.authStateChanges().listen((user) {
      _currentUser = user;
      _isAuthStateReady = true;
      if (user != null) {
        _currentEmail = user.email;
        _currentName = user.displayName;
        _currentPhotoUrl = _extractPhotoUrlFromFirebaseUser(user);
        _lastAuthMethod = AuthMethod.firebase;
        _studentRole = _preferences?.getString(_lastUserRoleKey);
        _loadUserDataFromFirestore(user.uid);
      } else {
        _clearProfileFields();
      }
      notifyListeners();
    });
  }

  /// Load additional user data from Firestore
  Future<void> _loadUserDataFromFirestore(String uid) async {
    _isProfileLoading = true;
    notifyListeners();

    try {
      final doc = await _firebaseService
          .getUserData(uid)
          .timeout(const Duration(seconds: 10));
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>? ?? <String, dynamic>{};

        _currentName = _readStringValue(data, <String>[
              'name',
              'fullName',
              'displayName',
            ]) ??
            _currentName;
        _currentPhotoUrl = _readStringValue(data, <String>[
              'photoUrl',
              'photoURL',
              'avatarUrl',
              'profileImageUrl',
            'picture',
            'imageUrl',
            ]) ??
            _currentPhotoUrl;
        _currentEmail = _readStringValue(data, <String>['email']) ?? _currentEmail;
        _studentId = _readStringValue(data, <String>['studentId', 'universityId', 'id']);
        _studentRole = _readStringValue(data, <String>['role']);
        _studentMajor = _readStringValue(data, <String>['major', 'faculty', 'department']);
        _studentPhone = _readStringValue(data, <String>['phone', 'phoneNumber']);
        _defaultPickupArea = _readStringValue(data, <String>[
          'defaultPickupArea',
          'defaultPickup',
          'preferredPickupArea',
        ]);
        _usualBusNumber = _readStringValue(data, <String>[
          'usualBusNumber',
          'regularBusNumber',
          'busNumber',
        ]);
      }

      _studentRole ??= _preferences?.getString(_lastUserRoleKey);
      if ((_studentRole ?? '').trim().isNotEmpty) {
        await _cacheLastUserRole(_studentRole!);
      }

      debugPrint('User data loaded: ${doc.data()}');
    } catch (e) {
      debugPrint('Error loading user data: $e');
      _studentRole ??= _preferences?.getString(_lastUserRoleKey);
    } finally {
      _isProfileLoading = false;
      notifyListeners();
    }
  }

  Future<void> refreshProfileData() async {
    final firebase.User? user = _firebaseService.getCurrentUser() ?? _currentUser;
    if (user == null) {
      return;
    }

    _currentUser = user;
    _currentEmail = user.email;
    _currentName = user.displayName;
    _currentPhotoUrl = _extractPhotoUrlFromFirebaseUser(user);
    _currentPhotoBytes = null;
    _currentPhotoUrl ??= await _extractPhotoUrlFromIdTokenClaims(user);
    notifyListeners();

    await _loadUserDataFromFirestore(user.uid);
  }

  String? _readStringValue(Map<String, dynamic> data, List<String> keys) {
    for (final String key in keys) {
      final dynamic value = data[key];
      if (value == null) {
        continue;
      }

      final String normalized = value.toString().trim();
      if (normalized.isNotEmpty) {
        return normalized;
      }
    }
    return null;
  }

  String? _extractPhotoUrlFromFirebaseUser(firebase.User? user) {
    if (user == null) {
      return null;
    }

    final String? primary = user.photoURL?.trim();
    if (primary != null && primary.isNotEmpty) {
      return primary;
    }

    for (final firebase.UserInfo info in user.providerData) {
      final String? providerPhoto = info.photoURL?.trim();
      if (providerPhoto != null && providerPhoto.isNotEmpty) {
        return providerPhoto;
      }
    }

    return null;
  }

  String? _extractPhotoUrlFromAdditionalUserInfo(firebase.UserCredential credential) {
    final Map<String, dynamic>? profile = credential.additionalUserInfo?.profile;
    if (profile == null) {
      return null;
    }

    return _readStringValue(profile, <String>[
      'picture',
      'photo',
      'photoUrl',
      'photoURL',
      'avatar',
      'avatarUrl',
      'image',
      'imageUrl',
    ]);
  }

  String? _extractAccessTokenFromUserCredential(firebase.UserCredential credential) {
    final firebase.AuthCredential? rawCredential = credential.credential;
    if (rawCredential is firebase.OAuthCredential) {
      final String? accessToken = rawCredential.accessToken?.trim();
      if (accessToken != null && accessToken.isNotEmpty) {
        return accessToken;
      }
    }
    return null;
  }

  void _clearProfileFields() {
    _currentEmail = null;
    _currentName = null;
    _currentPhotoUrl = null;
    _currentPhotoBytes = null;
    _studentId = null;
    _studentRole = null;
    _studentMajor = null;
    _studentPhone = null;
    _defaultPickupArea = null;
    _usualBusNumber = null;
  }

  /// Update only editable student profile fields.
  Future<bool> updateEditableStudentProfile({
    required String defaultPickupArea,
    required String usualBusNumber,
  }) async {
    final firebase.User? user = _currentUser;
    if (user == null) {
      _authError = 'Not signed in.';
      notifyListeners();
      return false;
    }

    final String pickup = defaultPickupArea.trim();
    final String bus = usualBusNumber.trim().toUpperCase().replaceAll(' ', '');

    if (bus.isNotEmpty && !_busNumberPattern.hasMatch(bus)) {
      _authError =
          'Invalid bus number format. Use letters, numbers, or dash only (max 12 chars).';
      notifyListeners();
      return false;
    }

    _authError = null;
    _defaultPickupArea = pickup;
    _usualBusNumber = bus;
    notifyListeners();

    // Save in background so weak network does not block the UI.
    Future.microtask(() async {
      try {
        await _firebaseService
            .saveUserData(
              user.uid,
              <String, dynamic>{
                'defaultPickupArea': pickup,
                'usualBusNumber': bus,
                'updatedAt': FieldValue.serverTimestamp(),
              },
            )
            .timeout(const Duration(seconds: 10));
      } catch (e) {
        _authError =
            'Changes saved locally. Network is weak, will sync when connection improves.';
        notifyListeners();
      }
    });

    return true;
  }

  /// Sign up with Firebase (email/password)
  Future<AuthResult> signUpWithFirebase(String email, String password) async {
    _isLoading = true;
    _authError = null;
    notifyListeners();

    try {
      // Validate email domain
      if (!EmailDomainPolicy.isAllowedStudentEmail(email)) {
        throw Exception('Email domain not allowed');
      }

      final credential = await _firebaseService.signUpWithEmail(email, password);
      
      if (credential?.user != null) {
        _currentUser = credential!.user;
        _currentEmail = _currentUser!.email;
        _lastAuthMethod = AuthMethod.firebase;

        final String signUpMessage = await _sendSignUpEmails(email);

        // Keep non-critical tasks in background.
        _startBackgroundSignUpTasks(_currentUser!.uid, email);

        await _firebaseService.signOut();
        _currentUser = null;
        _currentEmail = null;
        _currentName = null;
        _lastAuthMethod = null;

        notifyListeners();
        return AuthResult(
          success: true,
          email: email,
          message: signUpMessage,
          requiresEmailVerification: true,
          method: AuthMethod.firebase,
        );
      }

      throw Exception('Failed to create account');
    } catch (e) {
      _authError = _mapAuthError(e);
      notifyListeners();
      return AuthResult(
        success: false,
        error: _authError,
        method: AuthMethod.firebase,
      );
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Send signup emails and return a user-facing status message.
  Future<String> _sendSignUpEmails(String email) async {
    try {
      await _firebaseService
          .sendEmailVerification()
          .timeout(const Duration(seconds: 8), onTimeout: () {});

      await _firebaseService
          .sendSignInLinkToEmail(email)
          .timeout(const Duration(seconds: 8), onTimeout: () {});

      return 'Account created. We sent you an email with a link to complete sign-in.';
    } catch (e) {
      debugPrint('Send signup emails failed: $e');
      return 'Account created, but email could not be sent now. Please try Sign In again to resend.';
    }
  }

  /// Background tasks for signup (send email, save data, etc.)
  void _startBackgroundSignUpTasks(String uid, String email) {
    Future.microtask(() async {
      try {
        // These run in background without blocking UI.
        await Future.wait([
          _firebaseService.saveUserData(
            uid,
            {
              'email': email,
              'emailVerified': false,
              'createdAt': FieldValue.serverTimestamp(),
              'role': 'student',
              'authMethod': 'firebase',
            },
          ).timeout(
            const Duration(seconds: 10),
            onTimeout: () => debugPrint('Save user data timeout'),
          ),
          _firebaseService.subscribeToTopic('all_students').timeout(
            const Duration(seconds: 5),
            onTimeout: () => debugPrint('Subscribe to topic timeout'),
          ),
        ]);
      } catch (e) {
        debugPrint('Background signup tasks error: $e');
        // Don't block if background tasks fail
      }
    });
  }

  /// Sign in with Firebase (email/password)
  Future<AuthResult> signInWithFirebase(String email, String password) async {
    _isLoading = true;
    _authError = null;
    notifyListeners();

    try {
      // Validate email domain
      if (!EmailDomainPolicy.isAllowedStudentEmail(email)) {
        throw Exception('Email domain not allowed');
      }

      final credential = await _firebaseService
          .signInWithEmail(email, password)
          .timeout(
            const Duration(seconds: 20),
            onTimeout: () => throw Exception('Sign-in request timed out. Please try again.'),
          );
      
      if (credential?.user != null) {
        final bool isVerified = await _firebaseService
            .reloadAndCheckEmailVerified()
            .timeout(
              const Duration(seconds: 8),
              onTimeout: () => false,
            );
        if (!isVerified) {
          await _firebaseService
              .sendEmailVerification()
              .timeout(const Duration(seconds: 5), onTimeout: () {});
          await _firebaseService.signOut();
          throw Exception(
            'Please verify your university email from the link sent to your inbox before signing in.',
          );
        }

        _currentUser = _firebaseService.getCurrentUser();
        _currentEmail = _currentUser?.email;
        _currentPhotoUrl = _extractPhotoUrlFromFirebaseUser(_currentUser);
        _studentRole = 'student';
        await _cacheLastUserRole('student');
        _lastAuthMethod = AuthMethod.firebase;
        
        _runPostSignInTasks(_currentUser!.uid);

        notifyListeners();
        return AuthResult(
          success: true,
          uid: _currentUser!.uid,
          email: email,
          method: AuthMethod.firebase,
        );
      }

      throw Exception('Failed to sign in');
    } catch (e) {
      _authError = _mapAuthError(e);
      notifyListeners();
      return AuthResult(
        success: false,
        error: _authError,
        method: AuthMethod.firebase,
      );
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Run non-critical sign-in updates without blocking UI.
  void _runPostSignInTasks(String uid) {
    Future.microtask(() async {
      try {
        await Future.wait([
          _loadUserDataFromFirestore(uid).timeout(
            const Duration(seconds: 8),
            onTimeout: () => null,
          ),
          _firebaseService
              .saveUserData(
                uid,
                <String, dynamic>{
                  'emailVerified': true,
                  'lastLogin': FieldValue.serverTimestamp(),
                },
              )
              .timeout(const Duration(seconds: 8), onTimeout: () {}),
          _firebaseService
              .subscribeToTopic('all_students')
              .timeout(const Duration(seconds: 5), onTimeout: () {}),
        ]);
      } catch (e) {
        debugPrint('Post sign-in tasks error: $e');
      }
    });
  }

  /// Reload current user and check whether email is verified
  Future<bool> checkEmailVerified() async {
    try {
      final bool verified = await _firebaseService.reloadAndCheckEmailVerified();
      if (verified) {
        _currentUser = _firebaseService.getCurrentUser();
        _currentEmail = _currentUser?.email;
      }
      return verified;
    } catch (e) {
      _authError = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Sign in with Microsoft Entra
  Future<AuthResult> signInWithMicrosoft() async {
    _isLoading = true;
    _authError = null;
    notifyListeners();

    try {
      await _firebaseService.initialize();
      firebase.UserCredential? credential;
      String? microsoftPhotoUrl;
      Uint8List? microsoftPhotoBytes;

      final bool useDirectMicrosoftFlow =
          !kIsWeb &&
          (defaultTargetPlatform == TargetPlatform.iOS ||
              defaultTargetPlatform == TargetPlatform.macOS);

      if (useDirectMicrosoftFlow) {
        final MicrosoftAuthResult? microsoftResult = await _microsoftAuthService
            .signInWithMicrosoft()
            .timeout(const Duration(seconds: 60));

        if (microsoftResult == null || microsoftResult.accessToken.isEmpty) {
          throw Exception('Microsoft authentication cancelled');
        }

        microsoftPhotoUrl = microsoftResult.photoUrl;
        microsoftPhotoBytes = await _microsoftAuthService
          .fetchProfilePhotoBytes(microsoftResult.accessToken)
          .timeout(const Duration(seconds: 8), onTimeout: () => null);

        credential = await _firebaseService
            .signInWithMicrosoftTokens(
              accessToken: microsoftResult.accessToken,
              idToken: microsoftResult.idToken,
            )
            .timeout(const Duration(seconds: 60));

        _microsoftRefreshToken = microsoftResult.refreshToken;
      } else {
        try {
          credential = await _firebaseService
              .signInWithMicrosoft()
              .timeout(const Duration(seconds: 60));
        } catch (e) {
          final String raw = e.toString().toLowerCase();
          if (!raw.contains('invalid-cert-hash') &&
              !raw.contains('invalid_cert_hash')) {
            rethrow;
          }

          if (AppEnv.microsoftClientId.trim().isEmpty) {
            throw Exception(
              'invalid-cert-hash: Android certificate hash is not registered in Firebase for com.example.wayfinder.',
            );
          }

          // Fallback for Android cert-hash mismatch: use AppAuth then Firebase credential.
          final MicrosoftAuthResult? microsoftResult = await _microsoftAuthService
              .signInWithMicrosoft()
              .timeout(const Duration(seconds: 60));

          if (microsoftResult == null || microsoftResult.accessToken.isEmpty) {
            throw Exception('Microsoft authentication cancelled');
          }

          microsoftPhotoUrl = microsoftResult.photoUrl;
            microsoftPhotoBytes = await _microsoftAuthService
              .fetchProfilePhotoBytes(microsoftResult.accessToken)
              .timeout(const Duration(seconds: 8), onTimeout: () => null);

          credential = await _firebaseService
              .signInWithMicrosoftTokens(
                accessToken: microsoftResult.accessToken,
                idToken: microsoftResult.idToken,
              )
              .timeout(const Duration(seconds: 60));

          _microsoftRefreshToken = microsoftResult.refreshToken;
        }
      }

      if (credential?.user == null) {
        throw Exception('Microsoft authentication cancelled');
      }

      final firebase.User user = credential!.user!;
      final String email = user.email ?? '';

      if (!EmailDomainPolicy.isAllowedMicrosoftEmail(email)) {
        await _firebaseService.signOut();
        throw Exception('Microsoft email domain not allowed');
      }

        final String? providerProfilePhotoUrl =
          _extractPhotoUrlFromAdditionalUserInfo(credential);
        final String? credentialAccessToken =
          _extractAccessTokenFromUserCredential(credential);
        if (microsoftPhotoBytes == null && credentialAccessToken != null) {
        microsoftPhotoBytes = await _microsoftAuthService
          .fetchProfilePhotoBytes(credentialAccessToken)
          .timeout(const Duration(seconds: 8), onTimeout: () => null);
        }

      _currentUser = user;
      _currentEmail = email;
      _currentName = user.displayName;
        _currentPhotoUrl =
          _extractPhotoUrlFromFirebaseUser(user) ??
          microsoftPhotoUrl ??
          providerProfilePhotoUrl;
      _currentPhotoBytes = microsoftPhotoBytes;

      _currentPhotoUrl ??= await _extractPhotoUrlFromIdTokenClaims(user);
      _studentRole = 'student';
      await _cacheLastUserRole('student');
      _lastAuthMethod = AuthMethod.microsoft;
      _microsoftRefreshToken = null;

      // Do not block navigation on network-dependent writes/subscriptions.
      Future.microtask(() async {
        try {
          await _firebaseService
              .firestore
              .collection('users')
              .doc(user.uid)
              .set({
                'email': _currentEmail,
                'name': _currentName,
                'photoUrl': _currentPhotoUrl,
                'authMethod': 'microsoft',
                'role': 'student',
                'lastLogin': FieldValue.serverTimestamp(),
              }, SetOptions(merge: true))
              .timeout(const Duration(seconds: 8), onTimeout: () {});

          await _firebaseService
              .subscribeToTopic('all_students')
              .timeout(const Duration(seconds: 5), onTimeout: () {});
        } catch (e) {
          debugPrint('Microsoft post sign-in tasks error: $e');
        }
      });

      notifyListeners();
      return AuthResult(
        success: true,
        uid: user.uid,
        email: _currentEmail,
        name: _currentName,
        method: AuthMethod.microsoft,
      );
    } catch (e) {
      if (_isMicrosoftAuthCancellation(e)) {
        _authError = null;
        notifyListeners();
        return AuthResult(
          success: false,
          error: null,
          message: 'cancelled',
          method: AuthMethod.microsoft,
        );
      }

      _authError = _mapAuthError(e);
      notifyListeners();
      return AuthResult(
        success: false,
        error: _authError,
        method: AuthMethod.microsoft,
      );
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Sign in with Google (Firebase)
  Future<AuthResult> signInWithGoogle() async {
    _isLoading = true;
    _authError = null;
    notifyListeners();

    try {
      final credential = await _firebaseService.signInWithGoogle();
      
      if (credential?.user != null) {
        _currentUser = credential!.user;
        _currentEmail = _currentUser!.email;
        _currentName = _currentUser!.displayName;
        _currentPhotoUrl = _extractPhotoUrlFromFirebaseUser(_currentUser);
        _currentPhotoBytes = null;
        _studentRole = 'student';
        await _cacheLastUserRole('student');
        _lastAuthMethod = AuthMethod.firebase;

        await _firebaseService.saveUserData(
          _currentUser!.uid,
          {
            'email': _currentEmail,
            'name': _currentName,
            'photoUrl': _currentPhotoUrl,
            'role': 'student',
            'authMethod': 'google',
            'lastLogin': FieldValue.serverTimestamp(),
          },
        );

        await _firebaseService.subscribeToTopic('all_students');

        notifyListeners();
        return AuthResult(
          success: true,
          uid: _currentUser!.uid,
          email: _currentEmail,
          name: _currentName,
          method: AuthMethod.firebase,
        );
      }

      throw Exception('Failed to sign in with Google');
    } catch (e) {
      _authError = e.toString();
      notifyListeners();
      return AuthResult(
        success: false,
        error: e.toString(),
        method: AuthMethod.firebase,
      );
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<String?> _extractPhotoUrlFromIdTokenClaims(firebase.User user) async {
    try {
      final firebase.IdTokenResult tokenResult = await user.getIdTokenResult(true);
      final dynamic pictureClaim = tokenResult.claims?['picture'];
      if (pictureClaim == null) {
        return null;
      }

      final String normalized = pictureClaim.toString().trim();
      return normalized.isEmpty ? null : normalized;
    } catch (_) {
      return null;
    }
  }

  /// Sign out
  Future<void> signOut() async {
    try {
      await _firebaseService.signOut();
      await _preferences?.remove(_lastUserRoleKey);
      _currentUser = null;
      _clearProfileFields();
      _microsoftRefreshToken = null;
      _lastAuthMethod = null;
      _authError = null;
      notifyListeners();
    } catch (e) {
      _authError = e.toString();
      notifyListeners();
    }
  }

  /// Mock login for development/testing
  Future<AuthResult> mockLogin(String email, String password) async {
    _isLoading = true;
    _authError = null;
    notifyListeners();

    try {
      if (!EmailDomainPolicy.isAllowedStudentEmail(email) || password.length < 6) {
        throw Exception('Invalid email or password');
      }

      _currentEmail = email;
      _currentName = email.split('@')[0];
      _currentPhotoUrl = null;
      _lastAuthMethod = AuthMethod.mock;

      notifyListeners();
      return AuthResult(
        success: true,
        uid: 'mock_${email.hashCode}',
        email: email,
        name: _currentName,
        method: AuthMethod.mock,
      );
    } catch (e) {
      _authError = e.toString();
      notifyListeners();
      return AuthResult(
        success: false,
        error: e.toString(),
        method: AuthMethod.mock,
      );
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Refresh Microsoft access token if needed
  Future<bool> refreshMicrosoftToken() async {
    if (_microsoftRefreshToken == null) return false;

    try {
      final newAccessToken =
          await _microsoftAuthService.refreshAccessToken(_microsoftRefreshToken);
      return newAccessToken != null;
    } catch (e) {
      debugPrint('Token refresh failed: $e');
      return false;
    }
  }

  String _mapAuthError(Object error) {
    if (error is firebase.FirebaseAuthException) {
      final String message = (error.message ?? '').toUpperCase();
      if (message.contains('CONFIGURATION_NOT_FOUND')) {
        return 'Firebase Android config is incomplete. Enable Email/Password in Firebase Authentication and verify the Android app package name is com.example.wayfinder.';
      }

      switch (error.code) {
        case 'invalid-email':
          return 'Invalid email format.';
        case 'email-already-in-use':
          return 'This email is already in use.';
        case 'weak-password':
          return 'Password is too weak. Use at least 6 characters.';
        case 'user-not-found':
        case 'wrong-password':
          return 'Incorrect email or password.';
        case 'operation-not-allowed':
          return 'Email/password sign-in is disabled in Firebase Authentication.';
      }
    }

    final String raw = error.toString();
    if (raw.contains('Email domain not allowed') ||
        raw.contains('Please use your university email only.')) {
      final String domains = allowedDomains.join(', ');
      return 'Please use your university email only. Allowed domains: $domains';
    }

    if (raw.contains('Microsoft email domain not allowed')) {
      final String domains = EmailDomainPolicy.microsoftAllowedDomains.join(', ');
      return 'Microsoft sign-in is limited to Isra University accounts only. Allowed domains: $domains';
    }

    if (raw.contains('invalid-cert-hash') || raw.contains('invalid_cert_hash')) {
      return 'Android certificate hash is not registered in Firebase for com.example.wayfinder. Add your current app SHA-1/SHA-256 in Firebase Console > Project settings > Android app, then download a fresh google-services.json and rebuild the app.';
    }

    if (raw.contains('Microsoft Entra is not configured')) {
      return 'Microsoft sign-in is not configured yet. Missing MICROSOFT_CLIENT_ID. Add it with --dart-define=MICROSOFT_CLIENT_ID=...';
    }

    if (raw.contains('AADSTS700016')) {
      return 'Microsoft app is not available in your organization tenant yet. Ask your university IT admin to grant consent for this app, or use an app registration created inside your university tenant.';
    }

    if (raw.contains('TimeoutException')) {
      return 'Microsoft sign-in took too long. Please try again and return to the app after approving permissions.';
    }

    if (raw.contains('consent') && raw.contains('tenant')) {
      return 'Microsoft sign-in requires tenant admin consent. Ask your university IT admin to approve this app.';
    }

    if (raw.toUpperCase().contains('CONFIGURATION_NOT_FOUND')) {
      return 'Firebase Android config is incomplete. Enable Email/Password in Firebase Authentication and verify the Android app package name is com.example.wayfinder.';
    }

    return raw;
  }

  bool _isMicrosoftAuthCancellation(Object error) {
    final String raw = error.toString().toLowerCase();
    return raw.contains('web-context-canceled') ||
        raw.contains('popup-closed-by-user') ||
        raw.contains('sign-in was canceled') ||
        raw.contains('authentication cancelled') ||
        raw.contains('authentication canceled');
  }
}

import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase;
import 'package:cloud_firestore/cloud_firestore.dart';
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
  final FirebaseService _firebaseService;
  final MicrosoftAuthService _microsoftAuthService;

  firebase.User? _currentUser;
  String? _currentEmail;
  String? _currentName;
  AuthMethod? _lastAuthMethod;
  bool _isLoading = false;
  String? _authError;
  String? _microsoftRefreshToken;

  UnifiedAuthProvider({
    required FirebaseService firebaseService,
    required MicrosoftAuthService microsoftAuthService,
  })  : _firebaseService = firebaseService,
        _microsoftAuthService = microsoftAuthService {
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    try {
      await _firebaseService.initialize();
      _initializeAuthListener();
    } catch (e) {
      debugPrint('Auth bootstrap warning: $e');
    }
  }

  // Getters
  firebase.User? get currentUser => _currentUser;
  String? get currentEmail => _currentEmail;
  String? get currentName => _currentName;
  bool get isAuthenticated => _currentUser != null || _currentEmail != null;
  bool get isLoading => _isLoading;
  String? get authError => _authError;
  AuthMethod? get lastAuthMethod => _lastAuthMethod;
  List<String> get allowedDomains => EmailDomainPolicy.allowedDomains;

  /// Initialize Firebase auth state listener
  void _initializeAuthListener() {
    _firebaseService.authStateChanges().listen((user) {
      _currentUser = user;
      if (user != null) {
        _currentEmail = user.email;
        _currentName = user.displayName;
        _lastAuthMethod = AuthMethod.firebase;
        _loadUserDataFromFirestore(user.uid);
      }
      notifyListeners();
    });
  }

  /// Load additional user data from Firestore
  Future<void> _loadUserDataFromFirestore(String uid) async {
    try {
      final doc = await _firebaseService.getUserData(uid);
      // Store additional user data like role, zone preferences, etc.
      debugPrint('User data loaded: ${doc.data()}');
    } catch (e) {
      debugPrint('Error loading user data: $e');
    }
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
      final credential = await _firebaseService.signInWithMicrosoft();

      if (credential?.user == null) {
        throw Exception('Microsoft authentication cancelled');
      }

      final firebase.User user = credential!.user!;
      final String email = user.email ?? '';

      if (!EmailDomainPolicy.isAllowedStudentEmail(email)) {
        await _firebaseService.signOut();
        throw Exception('Email domain not allowed');
      }

      _currentUser = user;
      _currentEmail = email;
      _currentName = user.displayName;
      _lastAuthMethod = AuthMethod.microsoft;
      _microsoftRefreshToken = null;

      await _firebaseService.firestore.collection('users').doc(user.uid).set({
        'email': _currentEmail,
        'name': _currentName,
        'authMethod': 'microsoft',
        'role': 'student',
        'lastLogin': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Subscribe to topics
      await _firebaseService.subscribeToTopic('all_students');

      notifyListeners();
      return AuthResult(
        success: true,
        uid: user.uid,
        email: _currentEmail,
        name: _currentName,
        method: AuthMethod.microsoft,
      );
    } catch (e) {
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
        _lastAuthMethod = AuthMethod.firebase;

        await _firebaseService.saveUserData(
          _currentUser!.uid,
          {
            'email': _currentEmail,
            'name': _currentName,
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

  /// Sign out
  Future<void> signOut() async {
    try {
      await _firebaseService.signOut();
      _currentUser = null;
      _currentEmail = null;
      _currentName = null;
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

    if (raw.contains('Microsoft Entra is not configured')) {
      return 'Microsoft sign-in is not configured yet. Missing MICROSOFT_CLIENT_ID. Add it with --dart-define=MICROSOFT_CLIENT_ID=...';
    }

    if (raw.toUpperCase().contains('CONFIGURATION_NOT_FOUND')) {
      return 'Firebase Android config is incomplete. Enable Email/Password in Firebase Authentication and verify the Android app package name is com.example.wayfinder.';
    }

    return raw;
  }
}

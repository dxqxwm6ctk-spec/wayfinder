import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../config/app_env.dart';

/// Firebase service for initializing and managing Firebase instances
class FirebaseService {
  static final FirebaseService _instance = FirebaseService._internal();

  FirebaseAuth? _auth;
  FirebaseFirestore? _firestore;
  FirebaseMessaging? _messaging;

  FirebaseService._internal();

  factory FirebaseService() {
    return _instance;
  }

  FirebaseAuth get auth {
    if (_auth == null) {
      throw StateError('FirebaseAuth is not initialized.');
    }
    return _auth!;
  }

  FirebaseFirestore get firestore {
    if (_firestore == null) {
      throw StateError('FirebaseFirestore is not initialized.');
    }
    return _firestore!;
  }

  FirebaseMessaging get messaging {
    if (_messaging == null) {
      throw StateError('FirebaseMessaging is not initialized.');
    }
    return _messaging!;
  }

  bool get isInitialized => _auth != null && _firestore != null;

  /// Initialize Firebase
  Future<void> initialize() async {
    if (isInitialized) {
      return;
    }

    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp();
      }

      final FirebaseApp app = Firebase.app();
      debugPrint(
        'Firebase app loaded: name=${app.name}, '
        'projectId=${app.options.projectId}, '
        'appId=${app.options.appId}, '
        'androidClientId=${app.options.androidClientId}',
      );

      // Core services: required for auth and firestore.
      _auth = FirebaseAuth.instance;
      _firestore = FirebaseFirestore.instance;
      _firestore!.settings = const Settings(
        persistenceEnabled: false,
      );

      // Messaging setup is optional; failures here must not break auth.
      try {
        _messaging = FirebaseMessaging.instance;

        NotificationSettings settings = await _messaging!.requestPermission(
          alert: true,
          announcement: false,
          badge: true,
          criticalAlert: false,
          provisional: false,
          sound: true,
        );

        debugPrint('User notification preference: ${settings.authorizationStatus}');

        String? token = await _messaging!.getToken();
        debugPrint('FCM Token: $token');
      } catch (e) {
        debugPrint('FCM setup skipped: $e');
      }
    } catch (e) {
      debugPrint('Firebase core initialization error: $e');
      rethrow;
    }
  }

  Future<void> _ensureInitialized() async {
    if (!isInitialized) {
      await initialize();
    }
  }

  /// Sign up with email and password (Firebase)
  Future<UserCredential?> signUpWithEmail(String email, String password) async {
    try {
      await _ensureInitialized();
      return await auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
    } catch (e) {
      debugPrint('Firebase signup error: $e');
      rethrow;
    }
  }

  /// Send verification email to the currently signed-in user
  Future<void> sendEmailVerification() async {
    try {
      await _ensureInitialized();
      await auth.currentUser?.sendEmailVerification();
    } catch (e) {
      debugPrint('Send verification email error: $e');
      rethrow;
    }
  }

  /// Send passwordless sign-in link to email.
  Future<void> sendSignInLinkToEmail(String email) async {
    try {
      await _ensureInitialized();
      final ActionCodeSettings settings = ActionCodeSettings(
        url: AppEnv.emailLinkContinueUrl,
        handleCodeInApp: true,
        androidPackageName: 'com.example.wayfinder',
        androidInstallApp: true,
        androidMinimumVersion: '21',
        iOSBundleId: 'com.example.wayfinder',
      );

      await auth.sendSignInLinkToEmail(
        email: email,
        actionCodeSettings: settings,
      );
    } catch (e) {
      debugPrint('Send sign-in link error: $e');
      rethrow;
    }
  }

  /// Reload the current user and return email verification status
  Future<bool> reloadAndCheckEmailVerified() async {
    try {
      await _ensureInitialized();
      final User? user = auth.currentUser;
      await user?.reload();
      return auth.currentUser?.emailVerified ?? false;
    } catch (e) {
      debugPrint('Email verification check error: $e');
      rethrow;
    }
  }

  /// Sign in with email and password (Firebase)
  Future<UserCredential?> signInWithEmail(String email, String password) async {
    try {
      await _ensureInitialized();
      return await auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } catch (e) {
      debugPrint('Firebase signin error: $e');
      rethrow;
    }
  }

  /// Sign in with Google
  Future<UserCredential?> signInWithGoogle() async {
    try {
      await _ensureInitialized();
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      final GoogleSignInAuthentication? googleAuth =
          await googleUser?.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth?.accessToken,
        idToken: googleAuth?.idToken,
      );
      return await auth.signInWithCredential(credential);
    } catch (e) {
      debugPrint('Google signin error: $e');
      rethrow;
    }
  }

  /// Sign in with Microsoft via Firebase provider
  Future<UserCredential?> signInWithMicrosoft() async {
    try {
      await _ensureInitialized();
      final OAuthProvider provider = OAuthProvider('microsoft.com');
      provider.addScope('openid');
      provider.addScope('profile');
      provider.addScope('email');
      return await auth.signInWithProvider(provider);
    } catch (e) {
      debugPrint('Microsoft signin error: $e');
      rethrow;
    }
  }

  /// Sign in with Microsoft tokens obtained from AppAuth.
  Future<UserCredential?> signInWithMicrosoftTokens({
    required String accessToken,
    String? idToken,
  }) async {
    try {
      await _ensureInitialized();
      final OAuthCredential credential = OAuthProvider(
        'microsoft.com',
      ).credential(
        accessToken: accessToken,
        idToken: idToken,
      );
      return await auth.signInWithCredential(credential);
    } catch (e) {
      debugPrint('Microsoft token signin error: $e');
      rethrow;
    }
  }

  /// Sign out
  Future<void> signOut() async {
    try {
      await _ensureInitialized();
      await GoogleSignIn().signOut();
      await auth.signOut();
    } catch (e) {
      debugPrint('Sign out error: $e');
      rethrow;
    }
  }

  /// Get current user
  User? getCurrentUser() => _auth?.currentUser;

  /// Stream of authentication state changes
  Stream<User?> authStateChanges() {
    if (_auth == null) {
      return const Stream<User?>.empty();
    }
    return _auth!.authStateChanges();
  }

  /// Save user data to Firestore
  Future<void> saveUserData(String uid, Map<String, dynamic> userData) async {
    try {
      await _ensureInitialized();
      await firestore.collection('users').doc(uid).set(userData, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Save user data error: $e');
      rethrow;
    }
  }

  /// Get user data from Firestore
  Future<DocumentSnapshot> getUserData(String uid) async {
    try {
      await _ensureInitialized();
      return await firestore.collection('users').doc(uid).get();
    } catch (e) {
      debugPrint('Get user data error: $e');
      rethrow;
    }
  }

  /// Subscribe to FCM topic
  Future<void> subscribeToTopic(String topic) async {
    try {
      if (_messaging == null) {
        return;
      }
      await _messaging!.subscribeToTopic(topic);
      debugPrint('Subscribed to topic: $topic');
    } catch (e) {
      debugPrint('Subscribe to topic error: $e');
      rethrow;
    }
  }

  /// Unsubscribe from FCM topic
  Future<void> unsubscribeFromTopic(String topic) async {
    try {
      if (_messaging == null) {
        return;
      }
      await _messaging!.unsubscribeFromTopic(topic);
      debugPrint('Unsubscribed from topic: $topic');
    } catch (e) {
      debugPrint('Unsubscribe from topic error: $e');
      rethrow;
    }
  }
}

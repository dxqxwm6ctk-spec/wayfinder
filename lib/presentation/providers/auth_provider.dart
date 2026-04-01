import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase;
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/config/email_domain_policy.dart';
import '../../core/services/firebase_service.dart';
import '../../domain/usecases/login_user.dart';

class AuthProvider extends ChangeNotifier {
  static const String _lastUserRoleKey = 'app.last_user_role';

  AuthProvider(
    this._loginUser, {
    FirebaseService? firebaseService,
  }) : _firebaseService = firebaseService ?? FirebaseService();

  final LoginUser _loginUser;
  final FirebaseService _firebaseService;

  bool _isLoading = false;
  bool _isLeaderLoading = false;
  bool _isAuthenticated = false;
  bool _isLeaderAuthenticated = false;

  bool get isLoading => _isLoading;
  bool get isLeaderLoading => _isLeaderLoading;
  bool get isAuthenticated => _isAuthenticated;
  bool get isLeaderAuthenticated => _isLeaderAuthenticated;
  List<String> get allowedDomains => EmailDomainPolicy.allowedDomains;

  bool isUniversityEmail(String value) {
    return EmailDomainPolicy.isAllowedStudentEmail(value);
  }

  Future<bool> login({required String email, required String password}) async {
    _isLoading = true;
    notifyListeners();

    final bool success = await _loginUser(
      email: email.trim().toLowerCase(),
      password: password,
    );

    _isAuthenticated = success;
    _isLoading = false;
    notifyListeners();
    return success;
  }

  Future<bool> loginLeader({required String email, required String password}) async {
    _isLeaderLoading = true;
    notifyListeners();

    bool success = false;
    try {
      await _firebaseService.initialize().timeout(const Duration(seconds: 10));
      try {
        // Ensure clean auth state before switching from student to leader.
        await _firebaseService.auth.signOut().timeout(const Duration(seconds: 2));
      } catch (_) {
        // Ignore cleanup failures; proceed to leader sign-in.
      }

      final firebase.UserCredential? credential = await _firebaseService.signInWithEmail(
        email.trim().toLowerCase(),
        password,
      ).timeout(const Duration(seconds: 20));
      success = credential?.user != null;

      if (success && credential?.user != null) {
        final firebase.User user = credential!.user!;
        // Save local role immediately so app-exit/open can restore leader route reliably.
        try {
          final SharedPreferences prefs = await SharedPreferences.getInstance();
          await prefs.setString(_lastUserRoleKey, 'leader');
        } catch (_) {
          // Keep login flow resilient if local storage fails.
        }

        // Keep Firestore sync in background to avoid slowing navigation.
        Future<void>.microtask(() async {
          try {
            await _firebaseService
                .saveUserData(user.uid, <String, dynamic>{
                  'email': user.email ?? email.trim().toLowerCase(),
                  'name': user.displayName,
                  'role': 'leader',
                })
                .timeout(const Duration(seconds: 8));
          } catch (_) {
            // Do not block leader login if profile sync fails.
          }
        });
      }
    } catch (_) {
      success = false;
    }

    _isLeaderAuthenticated = success;
    _isLeaderLoading = false;
    notifyListeners();
    return success;
  }

  Future<void> logoutLeader() async {
    _isLeaderLoading = true;
    notifyListeners();

    try {
      await _firebaseService.signOut();
    } catch (_) {
      // Keep logout resilient even if provider cleanup throws.
    }

    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.remove(_lastUserRoleKey);
    } catch (_) {
      // Ignore local storage cleanup errors.
    }

    _isLeaderAuthenticated = false;
    _isLeaderLoading = false;
    notifyListeners();
  }
}

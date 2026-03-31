import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase;

import '../../core/config/email_domain_policy.dart';
import '../../core/services/firebase_service.dart';
import '../../domain/usecases/login_user.dart';

class AuthProvider extends ChangeNotifier {
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
      await _firebaseService.initialize();
      final firebase.UserCredential? credential = await _firebaseService.signInWithEmail(
        email.trim().toLowerCase(),
        password,
      );
      success = credential?.user != null;
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

    _isLeaderAuthenticated = false;
    _isLeaderLoading = false;
    notifyListeners();
  }
}

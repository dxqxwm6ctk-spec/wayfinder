import 'package:flutter/foundation.dart';

import '../../core/config/email_domain_policy.dart';
import '../../domain/usecases/login_user.dart';

class AuthProvider extends ChangeNotifier {
  AuthProvider(this._loginUser);

  final LoginUser _loginUser;

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

    await Future<void>.delayed(const Duration(milliseconds: 800));
    final bool success =
        email.trim().toLowerCase() == 'leader@iu.edu.co' &&
            password == 'leader1234';

    _isLeaderAuthenticated = success;
    _isLeaderLoading = false;
    notifyListeners();
    return success;
  }
}

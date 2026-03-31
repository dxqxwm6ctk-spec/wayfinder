import '../repositories/auth_repository.dart';

class LoginUser {
  LoginUser(this._authRepository);

  final AuthRepository _authRepository;

  Future<bool> call({required String email, required String password}) {
    return _authRepository.signIn(email: email, password: password);
  }
}

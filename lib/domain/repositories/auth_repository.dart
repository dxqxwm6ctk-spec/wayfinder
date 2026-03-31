abstract class AuthRepository {
  Future<bool> signIn({required String email, required String password});
}

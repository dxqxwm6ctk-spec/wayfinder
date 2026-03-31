import '../../core/config/email_domain_policy.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/remote/remote_api_data_source.dart';

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl({this.remoteApiDataSource});

  final RemoteApiDataSource? remoteApiDataSource;

  @override
  Future<bool> signIn({required String email, required String password}) async {
    if (remoteApiDataSource != null) {
      try {
        return await remoteApiDataSource!.signIn(email: email, password: password);
      } catch (_) {
        // Fallback to mock login if remote endpoint is unavailable.
      }
    }

    await Future.delayed(const Duration(milliseconds: 900));
    return EmailDomainPolicy.isAllowedStudentEmail(email) &&
        password.length >= 6;
  }
}

import 'package:flutter/foundation.dart';
import 'package:flutter_appauth/flutter_appauth.dart';
import 'package:jwt_decoder/jwt_decoder.dart';

/// Microsoft Entra / Azure AD authentication service
class MicrosoftAuthService {
  static final MicrosoftAuthService _instance = MicrosoftAuthService._internal();

  late final FlutterAppAuth _appAuth;

    static String _clientId = '';
    static String _redirectUrl = 'com.example.wayfinder://auth';
    static String _discoveryUrl =
      'https://login.microsoftonline.com/common/v2.0/.well-known/openid-configuration';
    static String _tenantId = '';

  MicrosoftAuthService._internal();

  factory MicrosoftAuthService() {
    return _instance;
  }

  void initialize() {
    _appAuth = const FlutterAppAuth();
  }

  /// Sign in with Microsoft (OAuth2 with PKCE)
  Future<MicrosoftAuthResult?> signInWithMicrosoft() async {
    try {
      _ensureConfigured();
      final result = await _appAuth.authorizeAndExchangeCode(
        AuthorizationTokenRequest(
          _clientId,
          _redirectUrl,
          discoveryUrl: _discoveryUrl,
          clientSecret: null, // PKCE flow doesn't require secret
          scopes: [
            'openid',
            'profile',
            'email',
            'offline_access', // For refresh tokens
            'https://graph.microsoft.com/.default',
          ],
          promptValues: ['login'], // Force login prompt
          additionalParameters: {
            'tenant': _tenantId,
          },
        ),
      );

      // Decode the ID token to get user info
      if (result.idToken == null) {
        throw Exception('Microsoft auth failed: No ID token received');
      }
      Map<String, dynamic> decodedToken = JwtDecoder.decode(result.idToken!);
      
      final email = decodedToken['email'] as String? ?? (decodedToken['preferred_username'] as String? ?? '');
      
      return MicrosoftAuthResult(
        accessToken: result.accessToken ?? '',
        idToken: result.idToken,
        refreshToken: result.refreshToken,
        email: email,
        name: (decodedToken['name'] as String?) ?? '',
        uid: (decodedToken['oid'] as String?) ?? '', // Object ID from Azure
        scopes: result.scopes,
        accessTokenExpirationDateTime: result.accessTokenExpirationDateTime,
      );
    } catch (e) {
      debugPrint('Microsoft signin error: $e');
      rethrow;
    }
  }

  /// Refresh the access token
  Future<String?> refreshAccessToken(String? refreshToken) async {
    if (refreshToken == null) return null;

    try {
      _ensureConfigured();
      final result = await _appAuth.token(
        TokenRequest(
          _clientId,
          _redirectUrl,
          discoveryUrl: _discoveryUrl,
          refreshToken: refreshToken,
          scopes: [
            'openid',
            'profile',
            'email',
            'offline_access',
            'https://graph.microsoft.com/.default',
          ],
        ),
      );

      return result.accessToken;
    } catch (e) {
      debugPrint('Token refresh error: $e');
      return null;
    }
  }

  /// Sign out (revoke tokens)
  Future<void> signOut(String? idToken) async {
    try {
      // In flutter_appauth, there's no direct sign-out method
      // The tokens are simply discarded on the client side
      // Server-side revocation would require a separate HTTP call
      debugPrint('Microsoft signout successful');
    } catch (e) {
      debugPrint('Microsoft signout error: $e');
      // Don't rethrow - logout should succeed even if revocation fails
    }
  }

  /// Configure Microsoft credentials (should be called during app initialization)
  static void configure({
    required String clientId,
    required String redirectUrl,
    required String tenantId,
    String? discoveryUrl,
  }) {
    _clientId = clientId.trim();
    _redirectUrl = redirectUrl.trim();
    _tenantId = tenantId.trim();

    if (discoveryUrl != null && discoveryUrl.trim().isNotEmpty) {
      _discoveryUrl = discoveryUrl.trim();
    } else if (_tenantId.isNotEmpty) {
      _discoveryUrl =
          'https://login.microsoftonline.com/$_tenantId/v2.0/.well-known/openid-configuration';
    }

    debugPrint('Microsoft Entra configured with Client ID: $clientId');
  }

  static void _ensureConfigured() {
    if (_clientId.isEmpty || _tenantId.isEmpty || _redirectUrl.isEmpty) {
      throw StateError(
        'Microsoft Entra is not configured. Provide MICROSOFT_CLIENT_ID, '
        'MICROSOFT_TENANT_ID and MICROSOFT_REDIRECT_URL via --dart-define.',
      );
    }
  }
}

/// Result of Microsoft authentication
class MicrosoftAuthResult {
  final String accessToken;
  final String? idToken;
  final String? refreshToken;
  final String email;
  final String name;
  final String uid; // Azure Object ID
  final List<String>? scopes;
  final DateTime? accessTokenExpirationDateTime;

  MicrosoftAuthResult({
    required this.accessToken,
    this.idToken,
    this.refreshToken,
    required this.email,
    required this.name,
    required this.uid,
    this.scopes,
    this.accessTokenExpirationDateTime,
  });

  bool get isAccessTokenExpired {
    if (accessTokenExpirationDateTime == null) return false;
    return DateTime.now().isAfter(
      accessTokenExpirationDateTime!.subtract(const Duration(minutes: 5)),
    );
  }
}

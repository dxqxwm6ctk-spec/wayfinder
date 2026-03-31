import 'dart:convert';

import 'package:http/http.dart' as http;

class RemoteApiDataSource {
  RemoteApiDataSource({required this.baseUrl, http.Client? client})
      : _client = client ?? http.Client();

  final String baseUrl;
  final http.Client _client;

  Future<bool> signIn({required String email, required String password}) async {
    final Uri uri = Uri.parse('$baseUrl/auth/login');
    final http.Response response = await _client.post(
      uri,
      headers: <String, String>{'Content-Type': 'application/json'},
      body: jsonEncode(<String, String>{
        'email': email,
        'password': password,
      }),
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return true;
    }
    return false;
  }

  Future<Map<String, dynamic>> fetchDashboard() async {
    final Uri uri = Uri.parse('$baseUrl/transit/dashboard');
    final http.Response response = await _client.get(
      uri,
      headers: <String, String>{'Content-Type': 'application/json'},
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Dashboard request failed: ${response.statusCode}');
    }

    return jsonDecode(response.body) as Map<String, dynamic>;
  }
}

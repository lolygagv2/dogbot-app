import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/dio_client.dart';

/// Auth response from the server
class AuthResponse {
  final String token;
  final String? userId;
  final String? email;

  AuthResponse({required this.token, this.userId, this.email});

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    return AuthResponse(
      token: json['token'] as String? ?? json['access_token'] as String,
      userId: json['user_id'] as String?,
      email: json['email'] as String?,
    );
  }
}

/// Provider for AuthApi
final authApiProvider = Provider<AuthApi>((ref) {
  return AuthApi(ref.watch(dioClientProvider));
});

/// REST API client for authentication
class AuthApi {
  final Dio _dio;

  AuthApi(this._dio);

  /// Register a new account
  Future<AuthResponse> register(String email, String password) async {
    final response = await _dio.post(
      '/api/auth/register',
      data: {
        'email': email,
        'password': password,
      },
    );
    return AuthResponse.fromJson(response.data as Map<String, dynamic>);
  }

  /// Login with existing account
  Future<AuthResponse> login(String email, String password) async {
    final response = await _dio.post(
      '/api/auth/login',
      data: {
        'email': email,
        'password': password,
      },
    );
    return AuthResponse.fromJson(response.data as Map<String, dynamic>);
  }

  /// Validate token is still valid
  Future<bool> validateToken(String token) async {
    try {
      final response = await _dio.get(
        '/api/auth/validate',
        options: Options(
          headers: {'Authorization': 'Bearer $token'},
        ),
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
}

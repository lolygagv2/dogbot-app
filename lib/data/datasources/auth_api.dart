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

  /// Build 95: tri-state token check. `unreachable` lets the caller fail-open
  /// on transient relay issues (cold-start 5xx, DNS hiccup, timeout) without
  /// blowing away the user's stored JWT.
  Future<TokenValidation> validateToken(String token) async {
    try {
      final response = await _dio.get(
        '/api/auth/validate',
        options: Options(
          headers: {'Authorization': 'Bearer $token'},
        ),
      );
      if (response.statusCode == 200) return TokenValidation.valid;
      if (response.statusCode == 401 || response.statusCode == 403) {
        return TokenValidation.invalid;
      }
      return TokenValidation.unreachable;
    } on DioException catch (e) {
      final code = e.response?.statusCode;
      if (code == 401 || code == 403) return TokenValidation.invalid;
      return TokenValidation.unreachable;
    } catch (_) {
      return TokenValidation.unreachable;
    }
  }
}

/// Outcome of [AuthApi.validateToken]. `invalid` is the only state where the
/// caller should delete the stored JWT — everything else is transient.
enum TokenValidation { valid, invalid, unreachable }

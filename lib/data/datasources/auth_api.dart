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

  /// Step 1 of password recovery — relay emails a 6-digit code (15-min TTL)
  /// via AWS SES. Relay always returns 200 with a generic message to avoid
  /// leaking which emails are registered, so this method has no useful
  /// return value beyond "the request didn't error."
  Future<void> requestPasswordReset(String email) async {
    await _dio.post(
      '/api/auth/request-reset',
      data: {'email': email},
    );
  }

  /// Step 2 of password recovery — exchange the 6-digit code + new password
  /// for a JWT. Same TokenResponse shape as /login, so the caller can drop
  /// the user straight into the app without a second sign-in round-trip.
  Future<AuthResponse> resetPassword(
      String email, String code, String newPassword) async {
    final response = await _dio.post(
      '/api/auth/reset-password',
      data: {
        'email': email,
        'code': code,
        'new_password': newPassword,
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

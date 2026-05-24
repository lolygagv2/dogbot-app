import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/environment.dart';
import '../constants/app_constants.dart';

/// Provider for the Dio HTTP client
final dioClientProvider = Provider<Dio>((ref) {
  return DioClient.instance;
});

/// Singleton Dio HTTP client with configuration
class DioClient {
  DioClient._();

  /// Set by _WimzAppState.initState. Invoked by [_AuthInterceptor] when a
  /// request that carried a Bearer token comes back 401 — the registered
  /// callback decides whether to log the user out (it gates on
  /// isAuthenticated to avoid double-firing during sign-out races).
  static void Function()? onUnauthorized;

  static final Dio instance = Dio(
    BaseOptions(
      // Initialize with production base URL by default
      baseUrl: AppConfig.baseUrl(AppConfig.defaultHost),
      connectTimeout: AppConstants.connectionTimeout,
      receiveTimeout: AppConstants.receiveTimeout,
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ),
  )..interceptors.addAll([
      _LoggingInterceptor(),
      _AuthInterceptor(),
    ]);

  /// Update base URL when connecting to a different server
  static void setBaseUrl(String baseUrl) {
    instance.options.baseUrl = baseUrl;
  }
}

/// Build 99: routes REST 401s through the same logout-with-notice path as
/// WS 4001. Fires onUnauthorized() only when:
///   - status code is 401, AND
///   - the request carried an Authorization header (so /auth/login wrong-
///     password etc. doesn't kick anyone out).
/// The registered callback gates on isAuthenticated, so concurrent 401s
/// don't double-fire logout.
class _AuthInterceptor extends Interceptor {
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (err.response?.statusCode == 401) {
      final hadBearer = err.requestOptions.headers.containsKey('Authorization')
          || err.requestOptions.headers.containsKey('authorization');
      if (hadBearer) {
        print('Auth: REST 401 with Bearer token — triggering logout');
        DioClient.onUnauthorized?.call();
      }
    }
    handler.next(err);
  }
}

/// Logging interceptor for debugging
class _LoggingInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    print('→ ${options.method} ${options.uri}');
    if (options.data != null) {
      print('  Body: ${options.data}');
    }
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    print('← ${response.statusCode} ${response.requestOptions.uri}');
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    print('✗ ${err.type} ${err.requestOptions.uri}');
    print('  ${err.message}');
    handler.next(err);
  }
}

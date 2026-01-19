import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constants/app_constants.dart';

/// Provider for the Dio HTTP client
final dioClientProvider = Provider<Dio>((ref) {
  return DioClient.instance;
});

/// Singleton Dio HTTP client with configuration
class DioClient {
  DioClient._();

  static final Dio instance = Dio(
    BaseOptions(
      connectTimeout: AppConstants.connectionTimeout,
      receiveTimeout: AppConstants.receiveTimeout,
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ),
  )..interceptors.addAll([
      _LoggingInterceptor(),
    ]);

  /// Update base URL when connecting to a different server
  static void setBaseUrl(String baseUrl) {
    instance.options.baseUrl = baseUrl;
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

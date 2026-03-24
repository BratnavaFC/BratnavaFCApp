import 'package:dio/dio.dart';
import '../../auth/jwt_helper.dart';
import '../../constants/app_constants.dart';

typedef TokenGetter  = String? Function();
typedef TokenHandler = Future<void> Function(String access, String refresh);
typedef VoidAsync    = Future<void> Function();

class AuthInterceptor extends Interceptor {
  final TokenGetter  getAccessToken;
  final TokenGetter  getRefreshToken;
  final TokenHandler onTokensRefreshed;
  final VoidAsync    onUnauthorized;

  /// Dio dedicado para refresh (evita loop no interceptor principal).
  late final Dio _refreshDio;

  /// Serialises concurrent refresh attempts — all callers await the same Future.
  Future<String?>? _pendingRefresh;

  AuthInterceptor({
    required this.getAccessToken,
    required this.getRefreshToken,
    required this.onTokensRefreshed,
    required this.onUnauthorized,
  }) {
    _refreshDio = Dio(
      BaseOptions(
        baseUrl:        AppConstants.apiUrl,
        connectTimeout: AppConstants.connectTimeout,
        receiveTimeout: AppConstants.receiveTimeout,
      ),
    );
  }

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    var accessToken = getAccessToken();

    if (accessToken != null && JwtHelper.isExpiring(accessToken, bufferSeconds: 300)) {
      accessToken = await _tryRefresh() ?? accessToken;
    }

    if (accessToken != null) {
      options.headers['Authorization'] = 'Bearer $accessToken';
    }

    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    if (err.response?.statusCode == 401) {
      final newAccess = await _tryRefresh();
      if (newAccess != null) {
        // Retry original request with new token.
        try {
          final opts = err.requestOptions
            ..headers['Authorization'] = 'Bearer $newAccess';
          final cloned = await _refreshDio.fetch(opts);
          return handler.resolve(cloned);
        } catch (_) {}
      }
      await onUnauthorized();
    }
    handler.next(err);
  }

  /// Public entry-point used by proactive refresh outside the interceptor.
  /// Shares the same mutex as in-flight interceptor refresh calls.
  Future<String?> tryRefresh() => _tryRefresh();

  /// Serialised entry-point: concurrent callers share one in-flight Future.
  Future<String?> _tryRefresh() {
    return _pendingRefresh ??= _doRefresh().whenComplete(() {
      _pendingRefresh = null;
    });
  }

  Future<String?> _doRefresh() async {
    final refreshToken = getRefreshToken();
    if (refreshToken == null) return null;

    try {
      final res = await _refreshDio.post(
        '/api/Authentication/refresh-token',
        data: {'refreshToken': refreshToken},
      );
      // The API wraps tokens in { "data": { "token": "...", "refreshToken": "..." } }.
      final envelope = res.data as Map<String, dynamic>;
      final data     = (envelope['data'] as Map<String, dynamic>?) ?? envelope;

      final access  = (data['token']        ?? data['accessToken'] ?? data['jwt']) as String?;
      final refresh = (data['refreshToken'] ?? data['refresh'])                     as String?;

      if (access != null && refresh != null) {
        await onTokensRefreshed(access, refresh);
        return access;
      }
    } catch (_) {}
    return null;
  }
}

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter/foundation.dart';

import '../core/config/env.dart';
import '../core/config/local_probe.dart';
import '../core/storage/secure_storage.dart';
import '../data/auth/auth_models.dart';
import '../state/session_store.dart';

class ApiClient {
  ApiClient._internal() {
    _dio = _SessionDio(_options());
    _refreshDio = _SessionDio(_options(), attachAccess: false);
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (request, handler) {
        final origin = request.extra[sessionKey] as int;
        if (!_session.isCurrent(origin)) {
          handler.reject(DioException(
              requestOptions: request,
              type: DioExceptionType.cancel,
              error: const StaleSessionException()));
          return;
        }
        request.headers['Content-Type'] = 'application/json';
        request.headers['Accept'] = 'application/json';
        handler.next(request);
      },
      onResponse: (response, handler) {
        if (_isCurrent(response.requestOptions)) _session.setOnline(true);
        handler.next(response);
      },
      onError: (error, handler) async {
        // One completion at this outer boundary, including unexpected local
        // plugin/storage errors. Helpers never own a Dio handler.
        try {
          final response = await _recover(error);
          if (response == null) {
            handler.next(error);
          } else {
            handler.resolve(response);
          }
        } on DioException catch (actual) {
          handler.next(actual);
        } catch (local) {
          handler.next(
              DioException(requestOptions: error.requestOptions, error: local));
        }
      },
    ));
  }

  static const sessionKey = 'emie.sessionGeneration';
  static const noRefreshKey = 'emie.noAuthReplay';
  static Options sessionOptions(int? generation, {bool noRefresh = false}) =>
      Options(extra: {
        sessionKey: generation ?? SessionStore.instance.generation,
        noRefreshKey: noRefresh
      });
  static BaseOptions _options() => BaseOptions(
      baseUrl: Env.apiBaseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
      responseType: ResponseType.json);
  final SessionStore _session = SessionStore.instance;
  final Map<int, Future<void>> _refreshes = {};
  late final Dio _dio;
  late final Dio _refreshDio;
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;
  Dio get dio => _dio;
  @visibleForTesting
  Dio get refreshDio => _refreshDio;

  bool _isCurrent(RequestOptions request) =>
      request.extra[sessionKey] is int &&
      _session.isCurrent(request.extra[sessionKey] as int);

  Future<Response<dynamic>?> _recover(DioException error) async {
    final request = error.requestOptions;
    if (!_isCurrent(request)) {
      return null;
    }
    final origin = request.extra[sessionKey] as int;
    _session.setOnline(error.type != DioExceptionType.connectionError &&
        error.type != DioExceptionType.connectionTimeout &&
        error.type != DioExceptionType.receiveTimeout);
    // Defense in depth: even a caller omitting the option cannot replay DELETE.
    final deletion = request.method == 'DELETE' && request.uri.path == '/v1/me';
    if (error.response?.statusCode != 401 ||
        deletion ||
        request.extra[noRefreshKey] == true ||
        request.path.startsWith('/v1/auth/')) {
      return null;
    }
    if (request.extra['retry'] == true ||
        _session.refreshToken?.isNotEmpty != true) {
      await _clearInvalidAuth(origin);
      return null;
    }
    request.extra['retry'] = true;
    final currentAccess = _session.accessToken;
    if (currentAccess == null ||
        request.headers['Authorization'] == 'Bearer $currentAccess') {
      try {
        await _refresh(origin);
      } on DioException catch (refreshError) {
        if (refreshError.response?.statusCode == 401) {
          await _clearInvalidAuth(origin);
        }
        rethrow;
      }
    }
    if (!_session.isCurrent(origin)) {
      return null;
    }
    request.headers['Authorization'] = 'Bearer ${_session.accessToken}';
    // A retry's actual error is propagated. It is not replaced with the old 401.
    return _dio.fetch<dynamic>(request);
  }

  Future<void> _refresh(int origin) {
    final existing = _refreshes[origin];
    if (existing != null) {
      return existing;
    }
    final future = _performRefresh(origin);
    _refreshes[origin] = future;
    // Observe completion without creating an unhandled error future.
    future.then<void>((_) {
      _refreshes.remove(origin);
    }, onError: (Object _, StackTrace __) {
      _refreshes.remove(origin);
    });
    return future;
  }

  Future<void> _performRefresh(int origin) async {
    if (!_session.isCurrent(origin)) {
      return;
    }
    final refresh = _session.refreshToken;
    final response = await _refreshDio.post('/v1/auth/refresh',
        data: {'refresh_token': refresh},
        options: sessionOptions(origin, noRefresh: true));
    if (!_session.isCurrent(origin)) {
      return;
    }
    final data = response.data;
    if (data is! Map<String, dynamic> ||
        data['access_token'] is! String ||
        (data['access_token'] as String).isEmpty) {
      await _clearInvalidAuth(origin);
      throw DioException(
          requestOptions: response.requestOptions,
          type: DioExceptionType.badResponse,
          response: response);
    }
    final access = data['access_token'] as String;
    final nextRefresh = data['refresh_token'] is String
        ? data['refresh_token'] as String
        : refresh;
    _session.updateTokens(access, refresh: nextRefresh, generation: origin);
    await SecureStorageService.saveTokens(
        accessToken: access,
        refreshToken: nextRefresh,
        isCurrent: () => _session.isCurrent(origin));
  }

  Future<void> _clearInvalidAuth(int origin) async {
    final ended = _session.endSession(origin);
    final completion = ended.completionGeneration;
    if (completion == null) {
      return;
    }
    await SecureStorageService.clearTokens(
        isCurrent: () => _session.isCurrent(completion));
  }
}

/// Capture synchronously when fetch is called, before Dio schedules interceptors.
/// Retries retain both their original generation and explicitly rotated header.
class _SessionDio extends DioForNative {
  _SessionDio(super.options, {this.attachAccess = true});
  final bool attachAccess;
  static int _probeSequence = 0;
  late HttpClientAdapter _guardedAdapter;
  @override
  HttpClientAdapter get httpClientAdapter => _guardedAdapter;
  @override
  set httpClientAdapter(HttpClientAdapter value) {
    _guardedAdapter =
        value is _SessionHttpAdapter ? value : _SessionHttpAdapter(value);
  }

  @override
  Future<Response<T>> fetch<T>(RequestOptions requestOptions) {
    final session = SessionStore.instance;
    requestOptions.extra
        .putIfAbsent(ApiClient.sessionKey, () => session.generation);
    if (requestOptions.extra['emie.bound'] != true) {
      requestOptions.extra['emie.bound'] = true;
      requestOptions.headers.remove('Authorization');
      if (attachAccess &&
          session
              .isCurrent(requestOptions.extra[ApiClient.sessionKey] as int) &&
          session.accessToken?.isNotEmpty == true) {
        requestOptions.headers['Authorization'] =
            'Bearer ${session.accessToken}';
      }
    }
    if (!Env.localDebug) return super.fetch<T>(requestOptions);
    const routes = {'/v1/me':'me', '/v1/profile':'profile',
      '/v1/auth/login':'login', '/v1/auth/refresh':'refresh',
      '/v1/auth/password/reset/finish':'reset_finish',
      '/v1/auth/password/reset/start':'reset_start'};
    final phase = routes[requestOptions.path];
    if (phase == null) return super.fetch<T>(requestOptions);
    final number = ++_probeSequence;
    final watch = Stopwatch()..start();
    requestOptions.headers['X-Emie-Local-Probe'] = '$number';
    bool current() => session.isCurrent(requestOptions.extra[ApiClient.sessionKey] as int);
    localProbe('$phase.request', probe: number, current: current());
    return super.fetch<T>(requestOptions).then<Response<T>>((response) {
      localProbe('$phase.response', probe: number, status: response.statusCode,
          millis: watch.elapsedMilliseconds, current: current());
      return response;
    }, onError: (Object error, StackTrace stack) {
      localProbe('$phase.error', probe: number, millis: watch.elapsedMilliseconds,
          current: current(), errorClass: error.runtimeType.toString(),
          status: error is DioException ? error.response?.statusCode : null,
          transport: error is DioException ? error.type.name : null);
      Error.throwWithStackTrace(error, stack);
    });
  }
}

/// Last synchronous check before the actual transport begins. This also guards
/// requests delayed by asynchronous interceptors or body transformation.
class _SessionHttpAdapter implements HttpClientAdapter {
  _SessionHttpAdapter(this.delegate);
  final HttpClientAdapter delegate;
  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? stream,
      Future<void>? cancelFuture) {
    final origin = options.extra[ApiClient.sessionKey];
    if (origin is! int || !SessionStore.instance.isCurrent(origin)) {
      throw DioException(
          requestOptions: options,
          type: DioExceptionType.cancel,
          error: const StaleSessionException());
    }
    return delegate.fetch(options, stream, cancelFuture);
  }

  @override
  void close({bool force = false}) => delegate.close(force: force);
}

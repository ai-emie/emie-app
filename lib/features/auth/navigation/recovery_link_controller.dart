import 'package:flutter/widgets.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../../../state/session_store.dart';
import '../../../../core/config/env.dart';

/// A small ingress for the existing Navigator. Native URL association is B3.
/// Proofs remain in RAM, never in route names, preferences or secure storage.
class RecoveryLinkController extends ChangeNotifier
    with WidgetsBindingObserver {
  RecoveryLinkController({String? initialRoute, SessionStore? session})
      : _session = session ?? SessionStore.instance {
    WidgetsBinding.instance.addObserver(this);
    _session.addListener(_sessionChanged);
    acceptRoute(initialRoute ??
        WidgetsBinding.instance.platformDispatcher.defaultRouteName);
    if (!kIsWeb && (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS)) {
      _native.setMethodCallHandler((call) async {
        if (!_disposed && call.method == 'resetLink' && call.arguments is String) {
          acceptRoute(call.arguments as String);
        }
      });
      _takeInitial();
    }
  }

  static const _native = MethodChannel('ai.emie.app/recovery');
  bool _disposed = false;

  Future<void> _takeInitial() async {
    try {
      final route = await _native.invokeMethod<String>('takeInitial');
      if (!_disposed && route != null) acceptRoute(route);
    } on MissingPluginException {
      // Widget tests and platforms without a native bridge.
    } on PlatformException {
      if (!_disposed) acceptRoute('/reset-password');
    }
  }

  final SessionStore _session;
  bool _pending = false;
  String? _token;
  int? _origin;
  int _revision = 0;

  bool get hasPending => _pending;
  String? get token => _token;
  int get revision => _revision;

  bool acceptRoute(String route) {
    Uri? uri;
    try {
      if (route.length <= 4096) uri = Uri.tryParse(route);
    } catch (_) {
      return false;
    }
    if (uri == null || uri.path != '/reset-password') return false;
    String? token;
    try {
      final values = uri.queryParametersAll['token'];
      if (Env.allowsRecoveryOrigin(uri) &&
          uri.userInfo.isEmpty &&
          !uri.hasFragment &&
          uri.queryParametersAll.length == 1 &&
          values?.length == 1 &&
          RegExp(r'^[A-Za-z0-9_-]{20,256}$').hasMatch(values!.single)) {
        token = values.single;
      }
    } catch (_) {
      // A malformed recovery URI opens a neutral invalid-link state.
    }
    _pending = true;
    _token = token;
    _origin = _session.isBootstrapping ? null : _session.generation;
    _revision++;
    notifyListeners();
    return true;
  }

  void _sessionChanged() {
    if (!_pending || _session.isBootstrapping) return;
    if (_origin == null) {
      _origin = _session.generation;
    } else if (!_session.isCurrent(_origin!)) {
      dismiss();
    }
  }

  void dismiss() {
    _pending = false;
    _token = null;
    _origin = null;
    _revision++;
    notifyListeners();
  }

  @override
  Future<bool> didPushRoute(String route) async => acceptRoute(route);

  @override
  Future<bool> didPushRouteInformation(
          RouteInformation routeInformation) async =>
      acceptRoute(routeInformation.uri.toString());

  @override
  void dispose() {
    _disposed = true;
    if (!kIsWeb && (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS)) {
      _native.setMethodCallHandler(null);
    }
    WidgetsBinding.instance.removeObserver(this);
    _session.removeListener(_sessionChanged);
    _token = null;
    super.dispose();
  }
}

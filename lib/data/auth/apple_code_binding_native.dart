import 'package:flutter/foundation.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../../state/session_store.dart';

enum AppleCodeBindingNativeStatus {
  received,
  invalidRequest,
  invalidResponse,
  stateMismatch,
  cancelled,
  pluginFailure,
  unsupported,
  stale,
  busy,
  disposed,
}

/// A local, single-use identity bound to the caller's current session generation.
/// This is neither a server operation nor an account authorization proof.
class AppleCodeBindingOperation {
  AppleCodeBindingOperation({required this.originGeneration});

  final int originGeneration;
  bool _valid = true;
  bool _started = false;

  void cancel() => _valid = false;

  @override
  String toString() => 'AppleCodeBindingOperation(<local>)';
}

/// Unverified credentials from ONE native response, owned by the recipient.
/// Call release when finished; this drops references, not immutable string bytes.
class AppleCodeBindingPair {
  AppleCodeBindingPair._(
      this._identityToken, this._authorizationCode, this._state);

  String? _identityToken;
  String? _authorizationCode;
  String? _state;
  String? get identityToken => _identityToken;
  String? get authorizationCode => _authorizationCode;
  String? get state => _state;

  void release() {
    _identityToken = null;
    _authorizationCode = null;
    _state = null;
  }

  @override
  String toString() => 'AppleCodeBindingPair(<redacted>)';
}

class AppleCodeBindingNativeResult {
  const AppleCodeBindingNativeResult._(this.status, [this.pair]);

  final AppleCodeBindingNativeStatus status;
  final AppleCodeBindingPair? pair;

  @override
  String toString() => 'AppleCodeBindingNativeResult(${status.name})';
}

/// Explicitly invoked preparation only: no registration, HTTP or session writes.
class AppleCodeBindingNative {
  final SessionStore _session = SessionStore.instance;
  AppleCodeBindingOperation? _active;
  bool _inFlight = false;
  bool _disposed = false;

  bool get isSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS);

  bool _current(AppleCodeBindingOperation operation) =>
      !_disposed &&
      identical(_active, operation) &&
      operation._valid &&
      _session.isCurrent(operation.originGeneration) &&
      _session.isAuthenticated;

  /// Invalidate locally. An already opened native dialog may still return.
  void cancel() {
    _active?.cancel();
    _active = null;
    // Keep the native slot occupied until its pending call actually finishes.
  }

  void dispose() {
    _disposed = true;
    cancel();
  }

  Future<AppleCodeBindingNativeResult> request({
    required String nonce,
    required String state,
    required AppleCodeBindingOperation operation,
  }) async {
    if (_disposed) {
      return const AppleCodeBindingNativeResult._(
          AppleCodeBindingNativeStatus.disposed);
    }
    if (_inFlight) {
      return const AppleCodeBindingNativeResult._(
          AppleCodeBindingNativeStatus.busy);
    }
    if (!operation._valid ||
        operation._started ||
        !_session.isCurrent(operation.originGeneration) ||
        !_session.isAuthenticated) {
      return const AppleCodeBindingNativeResult._(
          AppleCodeBindingNativeStatus.stale);
    }
    if (nonce.isEmpty || state.isEmpty) {
      return const AppleCodeBindingNativeResult._(
          AppleCodeBindingNativeStatus.invalidRequest);
    }
    if (!isSupported) {
      return const AppleCodeBindingNativeResult._(
          AppleCodeBindingNativeStatus.unsupported);
    }
    _inFlight = true;
    _active = operation;
    operation._started = true;
    try {
      final credential = await SignInWithApple.getAppleIDCredential(
          scopes: const [], nonce: nonce, state: state);
      if (!_current(operation)) {
        return const AppleCodeBindingNativeResult._(
            AppleCodeBindingNativeStatus.stale);
      }
      final token = credential.identityToken;
      final code = credential.authorizationCode;
      final returnedState = credential.state;
      if (token == null ||
          token.isEmpty ||
          code.isEmpty ||
          returnedState == null ||
          returnedState.isEmpty) {
        return const AppleCodeBindingNativeResult._(
            AppleCodeBindingNativeStatus.invalidResponse);
      }
      if (returnedState != state) {
        return const AppleCodeBindingNativeResult._(
            AppleCodeBindingNativeStatus.stateMismatch);
      }
      if (!_current(operation)) {
        return const AppleCodeBindingNativeResult._(
            AppleCodeBindingNativeStatus.stale);
      }
      return AppleCodeBindingNativeResult._(
          AppleCodeBindingNativeStatus.received,
          AppleCodeBindingPair._(token, code, returnedState));
    } on SignInWithAppleAuthorizationException catch (error) {
      final status = switch (error.code) {
        AuthorizationErrorCode.canceled =>
          AppleCodeBindingNativeStatus.cancelled,
        AuthorizationErrorCode.invalidResponse =>
          AppleCodeBindingNativeStatus.invalidResponse,
        _ => AppleCodeBindingNativeStatus.pluginFailure,
      };
      return AppleCodeBindingNativeResult._(
          _current(operation) ? status : AppleCodeBindingNativeStatus.stale);
    } on SignInWithAppleNotSupportedException catch (_) {
      return AppleCodeBindingNativeResult._(_current(operation)
          ? AppleCodeBindingNativeStatus.unsupported
          : AppleCodeBindingNativeStatus.stale);
    } catch (_) {
      // Plugin errors may contain credentials. Do not forward or stringify them.
      return AppleCodeBindingNativeResult._(_current(operation)
          ? AppleCodeBindingNativeStatus.pluginFailure
          : AppleCodeBindingNativeStatus.stale);
    } finally {
      operation.cancel();
      if (identical(_active, operation)) _active = null;
      _inFlight = false;
      // No credential is retained by the adapter. The returned pair, if any,
      // belongs to its caller and has not been cryptographically verified.
    }
  }
}

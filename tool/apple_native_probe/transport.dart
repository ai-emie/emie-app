import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import 'evaluation.dart';

const _enabled = bool.fromEnvironment('EMIE_APPLE_NATIVE_PROBE');

enum ProbeGate { disabled, unsupported, ready }

ProbeGate probeGate(
    {required bool debug,
    required bool enabled,
    required bool web,
    required TargetPlatform platform}) {
  if (!debug || !enabled) return ProbeGate.disabled;
  if (web || platform != TargetPlatform.iOS) return ProbeGate.unsupported;
  return ProbeGate.ready;
}

ProbeGate requestProbe() => probeGate(
    debug: kDebugMode,
    enabled: _enabled,
    web: kIsWeb,
    platform: defaultTargetPlatform);

enum ProbePhase { idle, waiting, blocked, busy, timedOut, completed }

class _Attempt {
  _Attempt(this.generation);
  final int generation;
  String? state;
  String? nonce;
  void release() {
    state = null;
    nonce = null;
  }
}

/// Owns only redacted public state. The native slot spans all controller lives.
class ProbeController extends ChangeNotifier {
  ProbeController() : _random = Random.secure {
    _nativePending.addListener(_slotChanged);
  }
  @visibleForTesting
  ProbeController.withRandomSource(Random Function() random)
      : _random = random {
    _nativePending.addListener(_slotChanged);
  }
  static final _nativePending = ValueNotifier<bool>(false);
  static const timeout = Duration(minutes: 2);
  final Random Function() _random;
  bool _disposed = false;
  int _generation = 0;
  _Attempt? _active;
  Timer? _timer;
  ProbePhase phase = ProbePhase.idle;
  ProbeEvaluation? result;
  bool get nativePending => _nativePending.value;
  bool get canStart =>
      !_disposed && !nativePending && requestProbe() == ProbeGate.ready;
  void _slotChanged() {
    if (!_disposed) notifyListeners();
  }

  String _fresh(Random random) => base64Url
      .encode(List<int>.generate(32, (_) => random.nextInt(256)))
      .replaceAll('=', '');

  void start() {
    if (_disposed) return;
    if (requestProbe() != ProbeGate.ready) {
      phase = ProbePhase.blocked;
      notifyListeners();
      return;
    }
    if (nativePending) return; // Never invalidate the original attempt.
    final attempt = _Attempt(++_generation);
    _active = attempt;
    result = null;
    try {
      final random = _random();
      attempt.state = _fresh(random);
      attempt.nonce = _fresh(random);
    } catch (_) {
      attempt.release();
      _active = null;
      result = probeFailure(null);
      phase = ProbePhase.completed;
      notifyListeners();
      return;
    }
    phase = ProbePhase.waiting;
    _nativePending.value = true;
    _timer = Timer(timeout, () {
      if (!_current(attempt)) return;
      ++_generation;
      attempt.release();
      _active = null;
      phase = ProbePhase.timedOut;
      result = null;
      notifyListeners();
    });
    unawaited(_perform(attempt));
  }

  bool _current(_Attempt attempt) =>
      !_disposed &&
      identical(_active, attempt) &&
      attempt.generation == _generation;

  Future<void> _perform(_Attempt attempt) async {
    AuthorizationCredentialAppleID? credential;
    try {
      // Real build/flag/platform guard immediately at the plugin boundary.
      if (requestProbe() != ProbeGate.ready) {
        if (_current(attempt)) phase = ProbePhase.blocked;
        return;
      }
      credential = await SignInWithApple.getAppleIDCredential(
          scopes: const [], state: attempt.state, nonce: attempt.nonce);
      if (!_current(attempt)) return;
      result = evaluateProbe(
          identityToken: credential.identityToken,
          authorizationCode: credential.authorizationCode,
          returnedState: credential.state,
          expectedState: attempt.state!);
      phase = ProbePhase.completed;
    } on SignInWithAppleAuthorizationException catch (error) {
      if (_current(attempt)) {
        result = probeFailure(null,
            cancelled: error.code == AuthorizationErrorCode.canceled);
        phase = ProbePhase.completed;
      }
    } catch (_) {
      if (_current(attempt)) {
        result = probeFailure(null);
        phase = ProbePhase.completed;
      }
    } finally {
      credential = null;
      attempt.release();
      _timer?.cancel();
      _timer = null;
      if (identical(_active, attempt)) _active = null;
      // Only actual completion releases the process-wide native slot.
      _nativePending.value = false;
    }
  }

  @override
  void dispose() {
    _disposed = true;
    ++_generation;
    _timer?.cancel();
    _timer = null;
    _active?.release();
    _active = null;
    _nativePending.removeListener(_slotChanged);
    super.dispose();
  }
}

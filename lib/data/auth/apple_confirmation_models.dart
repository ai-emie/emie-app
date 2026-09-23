import 'package:dio/dio.dart';

enum AppleConfirmationOutcome {
  confirmed,
  cancelled,
  notAvailable,
  conflict,
  unconfirmed,
  authenticationRejected,
  invalidProof,
  stale,
  busy,
  expired,
  codeNotDemonstrable,
  codeInvalid,
  codeUnavailable,
  validationRejected,
}

/// A stored confirmation is historical evidence, never a reusable permission.
class AppleConfirmationResult {
  const AppleConfirmationResult(this.outcome,
      {this.operationId, this.completionMayHaveOccurred = false});
  final AppleConfirmationOutcome outcome;
  final String? operationId;

  /// A sent request cannot be undone by discarding its late/unknown reply.
  final bool completionMayHaveOccurred;

  @override
  String toString() =>
      'AppleConfirmationResult(${outcome.name}, uncertain: $completionMayHaveOccurred)';
}

/// Volatile local identity; never persisted or used as server authentication.
class AppleConfirmationOperation {
  AppleConfirmationOperation(this.originGeneration, {DateTime Function()? now})
      : _now = now ?? DateTime.now;
  final DateTime Function() _now;
  final int originGeneration;
  final Object identity = Object();
  final CancelToken transportCancellation = CancelToken();
  bool valid = true;
  bool statusAttempted = false;
  bool _completeAttempted = false;
  bool completeSent = false;
  DateTime? expiresAt;
  bool get isUnexpired => expiresAt != null && _now().isBefore(expiresAt!);

  bool claimComplete() {
    if (_completeAttempted) return false;
    _completeAttempted = true;
    return true;
  }

  String? serverId;
  String? nonce;
  String? state;

  void forgetChallenge() {
    nonce = null;
    state = null;
  }

  void invalidate() {
    valid = false;
    forgetChallenge();
    transportCancellation.cancel('Apple confirmation context changed');
  }
}

class AppleConfirmationReply {
  const AppleConfirmationReply(this.statusCode,
      {this.body, this.stale = false});
  final int? statusCode;
  final Map<String, dynamic>? body;
  final bool stale;
}

/// Request validation only; no JWT verification, normalization or persistence.
abstract final class AppleConfirmationInput {
  static bool valid(Map<String, String>? body) {
    if (body == null ||
        body.length != 3 ||
        !body.keys
            .toSet()
            .containsAll({'id_token', 'state', 'authorization_code'})) {
      return false;
    }
    final token = body['id_token']!,
        state = body['state']!,
        code = body['authorization_code']!;
    return token.isNotEmpty &&
        token.runes.length <= 16384 &&
        token.trim().isNotEmpty &&
        state.isNotEmpty &&
        state.runes.length <= 128 &&
        code.isNotEmpty &&
        code.length <= 4096 &&
        code.codeUnits.every((unit) => unit >= 33 && unit <= 126);
  }
}

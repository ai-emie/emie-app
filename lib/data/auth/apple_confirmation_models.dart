import 'package:dio/dio.dart';

enum AppleConfirmationOutcome {
  confirmed, cancelled, notAvailable, conflict, unconfirmed,
  authenticationRejected, invalidProof, stale,
}

/// A stored confirmation is historical evidence, never a reusable permission.
class AppleConfirmationResult {
  const AppleConfirmationResult(this.outcome, {this.operationId});
  final AppleConfirmationOutcome outcome;
  final String? operationId;
}

/// Volatile local identity; never persisted or used as server authentication.
class AppleConfirmationOperation {
  AppleConfirmationOperation(this.originGeneration);
  final int originGeneration;
  final Object identity = Object();
  final CancelToken transportCancellation = CancelToken();
  bool valid = true;
  bool statusAttempted = false;
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
  const AppleConfirmationReply(this.statusCode, {this.body, this.stale = false});
  final int? statusCode;
  final Map<String, dynamic>? body;
  final bool stale;
}

import 'dart:convert';

enum ProbeResponse { received, cancelled, error }

enum ProbeState { matching, missing, mismatching }

enum ProbeToken { notExamined, readable, unreadable }

enum ProbeCHash { notExamined, missing, empty, stringPresent, invalidType }

const probeDisclaimer =
    'Token nicht kryptografisch verifiziert; keine Codebindung und keine Emie-Anmeldung bestätigt.';

/// Only fixed, non-sensitive observations. No credentials are retained.
class ProbeEvaluation {
  const ProbeEvaluation({
    required this.response,
    this.tokenPresent = false,
    this.codePresent = false,
    this.state = ProbeState.missing,
    this.token = ProbeToken.notExamined,
    this.cHash = ProbeCHash.notExamined,
  });

  final ProbeResponse response;
  final bool tokenPresent;
  final bool codePresent;
  final ProbeState state;
  final ProbeToken token;
  final ProbeCHash cHash;

  @override
  String toString() =>
      'Antwort: ${response.name}; Token vorhanden: $tokenPresent; '
      'Code vorhanden: $codePresent; State: ${state.name}; '
      'Tokenstruktur: ${token.name}; c_hash: ${cHash.name}. $probeDisclaimer';
}

/// UNVERIFIED parsing only, not JWT validation or authorization.
/// Inputs belong to one synthetic/native response. This synchronous function
/// stores no input beyond its call; it cannot erase immutable Dart strings.
ProbeEvaluation evaluateProbe({
  required String? identityToken,
  required String? authorizationCode,
  required String? returnedState,
  required String expectedState,
}) {
  final hasToken = identityToken?.isNotEmpty == true;
  final hasCode = authorizationCode?.isNotEmpty == true;
  final state = returnedState == null || returnedState.isEmpty
      ? ProbeState.missing
      : expectedState.isNotEmpty && returnedState == expectedState
          ? ProbeState.matching
          : ProbeState.mismatching;
  ProbeEvaluation result(ProbeToken token, ProbeCHash hash) => ProbeEvaluation(
        response: state == ProbeState.matching
            ? ProbeResponse.received
            : ProbeResponse.error,
        tokenPresent: hasToken,
        codePresent: hasCode,
        state: state,
        token: token,
        cHash: hash,
      );
  if (state != ProbeState.matching || !hasToken) {
    return result(ProbeToken.notExamined, ProbeCHash.notExamined);
  }
  try {
    final input = identityToken!;
    if (input.length > 16384) throw const FormatException();
    final segments = input.split('.');
    if (segments.length != 3 ||
        segments.any((s) => !RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(s))) {
      throw const FormatException();
    }
    // Validate base64url encoding of all segments, without interpreting a
    // signature or claiming that the header/algorithm is trusted.
    for (final segment in segments) {
      final bytes = base64Url.decode(base64Url.normalize(segment));
      if (base64Url.encode(bytes).replaceAll('=', '') != segment) {
        throw const FormatException();
      }
    }
    final payloadBytes = base64Url.decode(base64Url.normalize(segments[1]));
    if (payloadBytes.length > 8192) throw const FormatException();
    final payload =
        jsonDecode(utf8.decode(payloadBytes, allowMalformed: false));
    if (payload is! Map<String, dynamic>) throw const FormatException();
    final claim = payload['c_hash'];
    final hash = !payload.containsKey('c_hash')
        ? ProbeCHash.missing
        : claim is! String
            ? ProbeCHash.invalidType
            : claim.isEmpty
                ? ProbeCHash.empty
                : ProbeCHash.stringPresent;
    return result(ProbeToken.readable, hash);
  } catch (_) {
    // Never stringify malformed payloads or exceptions.
    return result(ProbeToken.unreadable, ProbeCHash.notExamined);
  }
}

/// Exceptions may themselves contain credentials: deliberately ignore them.
ProbeEvaluation probeFailure(Object? ignored, {bool cancelled = false}) =>
    ProbeEvaluation(
      response: cancelled ? ProbeResponse.cancelled : ProbeResponse.error,
    );

import 'package:flutter/foundation.dart';
import 'env.dart';

/// Local Debug only. No values, identifiers, request URLs, queries or bodies.
void localProbe(String phase, {int? status, int? millis, int? probe,
    bool? current, bool? same, String? errorClass, String? transport}) {
  if (!Env.localDebug) return;
  final safe = RegExp(r'^[A-Za-z0-9_.<>]+$');
  if (!safe.hasMatch(phase) ||
      (errorClass != null && !safe.hasMatch(errorClass)) ||
      (transport != null && !safe.hasMatch(transport))) return;
  debugPrint('EMIE_LOCAL_PROBE phase=$phase probe=$probe status=$status '
      'ms=$millis current=$current same=$same error=$errorClass transport=$transport');
}

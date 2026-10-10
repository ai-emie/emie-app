// Explicit, per-build iPhone Local Debug target. Never a general URL override.
String resolveLocalDebugHost({
  required bool debug,
  required bool ios,
  required bool local,
  required bool device,
  required String host,
}) {
  final fallback = ios ? '127.0.0.1' : '10.0.2.2';
  if (!debug || !ios) return fallback;
  if (!device && host.isEmpty) return fallback;
  if (!local || !device || !isPrivateDebugIPv4(host)) {
    throw StateError('Explicit iPhone Local Debug activation and RFC1918 IPv4 required');
  }
  return host;
}

bool isPrivateDebugIPv4(String host) {
  final parts = host.split('.');
  if (parts.length != 4) return false;
  final values = <int>[];
  for (final part in parts) {
    if (!RegExp(r'^(0|[1-9][0-9]{0,2})$').hasMatch(part)) return false;
    final value = int.parse(part);
    if (value > 255) return false;
    values.add(value);
  }
  return values[0] == 10 ||
      (values[0] == 172 && values[1] >= 16 && values[1] <= 31) ||
      (values[0] == 192 && values[1] == 168);
}

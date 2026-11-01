/// Explicit shared backend target. No keys, discovery or network access.
class PublicTarget {
  const PublicTarget(this.apiOrigin, this.recoveryOrigin);
  final String apiOrigin;
  final String recoveryOrigin;
}

PublicTarget resolvePublicTarget({
  required String apiOrigin,
  required String recoveryOrigin,
  bool localMode = false,
  String environment = '',
}) {
  if (localMode || !const ['', 'prod', 'production'].contains(environment)) {
    throw StateError('Public and local build targets must not be combined.');
  }
  String canonical(String value) {
    final uri = Uri.tryParse(value);
    if (uri == null || value.isEmpty || value != value.trim() ||
        !RegExp(r'^[\x21-\x7e]+$').hasMatch(value) ||
        uri.scheme != 'https' || uri.userInfo.isNotEmpty ||
        uri.host.isEmpty || uri.port != 443 || uri.hasQuery || uri.hasFragment ||
        (uri.path.isNotEmpty && uri.path != '/') ||
        !RegExp(r'^[a-z0-9]+(?:[.-][a-z0-9]+)*\.[a-z]+$').hasMatch(uri.host) ||
        uri.host == 'localhost' ||
        const ['.localhost', '.local', '.internal'].any(uri.host.endsWith)) {
      throw StateError('An explicit canonical public HTTPS origin is required.');
    }
    final origin = 'https://${uri.host}';
    if (![origin, '$origin/', '$origin:443', '$origin:443/'].contains(value)) {
      throw StateError('The public origin must not contain URL credentials or paths.');
    }
    return origin;
  }

  final api = canonical(apiOrigin);
  final recovery = canonical(recoveryOrigin);
  if (api != recovery) {
    throw StateError('API and recovery must use the same public backend origin.');
  }
  return PublicTarget(api, recovery);
}

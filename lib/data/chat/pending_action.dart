import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../core/config/env.dart';

/// Only opaque IDs, never a prompt, response or credential. Scoped to account/API.
class PendingActionStore {
  const PendingActionStore();
  static const _storage = FlutterSecureStorage();
  String _key(String owner) => 'emie_pending_action_v1_${Env.apiBaseUrl}_$owner';
  Future<Map<String, String>?> read(String? owner) async {
    if (owner == null) return null;
    final value = await _storage.read(key: _key(owner));
    if (value == null) return null;
    final data = (jsonDecode(value) as Map).cast<String, String>();
    if (data.keys.toSet().difference({'action', 'session'}).isNotEmpty ||
        data['action'] == null || data['session'] == null) {
      throw const FormatException('Invalid pending action');
    }
    return data;
  }
  Future<void> save(String? owner, String action, String session) async {
    if (owner != null) await _storage.write(key: _key(owner), value: jsonEncode({'action': action, 'session': session}));
  }
  Future<void> clear(String? owner) async {
    if (owner != null) await _storage.delete(key: _key(owner));
  }
}

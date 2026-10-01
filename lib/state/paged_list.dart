import 'package:flutter/foundation.dart';
import 'session_store.dart';

class ListPage<T> {
  const ListPage(this.items, this.total, this.offset, this.limit);
  final List<T> items;
  final int total, offset, limit;

  void validate(int requestedOffset) {
    if (offset != requestedOffset ||
        limit < 1 ||
        items.length > limit ||
        total < 0 ||
        (items.isEmpty && offset < total)) {
      throw const FormatException('Invalid pagination response');
    }
  }
}

/// Offset belongs to the server page, never to the deduplicated visible list.
/// Every refresh/filter/identity change invalidates older completions.
class PagedList<T> extends ChangeNotifier {
  PagedList({required this.fetch, required this.id, SessionStore? session})
      : session = session ?? SessionStore.instance {
    _generation = this.session.generation;
    this.session.addListener(_sessionChanged);
  }
  final SessionStore session;
  final Future<ListPage<T>> Function(int offset, int generation) fetch;
  final String Function(T) id;
  List<T> items = [];
  int total = 0, _offset = 0, _request = 0;
  late int _generation;
  bool loading = false, failed = false, loaded = false, _disposed = false;
  bool _retryReset = true;
  int _retryThrough = 20;
  bool get hasMore => loaded && _offset < total;
  bool get stale => items.isNotEmpty && (failed || loading);

  void _sessionChanged() {
    if (_generation == session.generation) return;
    _generation = session.generation;
    _request++;
    items = [];
    total = _offset = 0;
    loading = failed = loaded = false;
    notifyListeners();
  }

  Future<void> refresh({bool clear = false, int through = 20}) =>
      _load(reset: true, clear: clear, through: through);
  Future<void> retry() => _load(reset: _retryReset, through: _retryThrough);
  Future<void> more() async {
    if (loading || !hasMore) return;
    await _load(reset: false);
  }

  Future<void> _load(
      {required bool reset, bool clear = false, int through = 20}) async {
    if (_disposed) return;
    final request = ++_request;
    final generation = session.generation;
    _retryReset = reset;
    _retryThrough = through;
    if (clear) {
      items = [];
      total = _offset = 0;
      loaded = false;
    }
    loading = true;
    failed = false;
    notifyListeners();
    bool current() =>
        !_disposed && request == _request && session.isCurrent(generation);
    try {
      var offset = reset ? 0 : _offset;
      final next = reset ? <T>[] : [...items];
      var count = total;
      do {
        final page = await fetch(offset, generation);
        if (!current()) return;
        page.validate(offset);
        final seen = next.map(id).toSet();
        for (final item in page.items) {
          if (seen.add(id(item))) next.add(item);
        }
        offset += page.items.length;
        count = page.total;
      } while (reset && offset < through && offset < count);
      items = next;
      total = count;
      _offset = offset;
      loaded = true;
    } catch (_) {
      if (!current()) return;
      failed = true;
    } finally {
      if (current()) {
        loading = false;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _request++;
    session.removeListener(_sessionChanged);
    super.dispose();
  }
}

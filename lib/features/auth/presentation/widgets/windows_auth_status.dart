import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../../../../api/client.dart';

/// Explicit local mode only. This public GET contains no credentials or proofs.
class WindowsAuthStatus extends StatefulWidget {
  const WindowsAuthStatus({super.key, this.dio});
  final Dio? dio;
  @override
  State<WindowsAuthStatus> createState() => _WindowsAuthStatusState();
}

class _WindowsAuthStatusState extends State<WindowsAuthStatus> {
  Timer? _timer;
  bool _checking = false;
  bool _ready = false;
  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => _check());
    scheduleMicrotask(_check);
  }

  Future<void> _check() async {
    if (_checking || !mounted) return;
    _checking = true;
    var ready = false;
    try {
      final response = await (widget.dio ?? ApiClient().dio).get<dynamic>(
          '/v1/local/mode',
          options: ApiClient.sessionOptions(null, noRefresh: true).copyWith(
              receiveTimeout: const Duration(seconds: 2),
              sendTimeout: const Duration(seconds: 2)));
      final data = response.data;
      ready = data is Map &&
          data['mode'] == 'P4' &&
          data['mail'] == 'local-only' &&
          data['ai'] == false;
    } catch (_) {
      ready = false;
    } finally {
      _checking = false;
    }
    if (mounted) setState(() => _ready = ready);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Material(
      color: Theme.of(context).colorScheme.surface,
      child: SafeArea(
          bottom: false,
          child: Padding(
              padding: const EdgeInsets.all(8),
              child: Text(
                  _ready
                      ? 'Windows Konto-Test · nur lokale Mailablage · KI aus'
                      : 'Windows Konto-Test · Backend nicht bereit oder nicht verbunden',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall))));
}

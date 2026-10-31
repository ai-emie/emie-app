import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../../../../api/api_error.dart';
import '../../../../api/client.dart';

/// Read-only polling: no provider probe, generation, or automatic chat replay.
class WindowsChatStatus extends StatefulWidget {
  const WindowsChatStatus({super.key, required this.onReady, this.dio});
  final ValueChanged<bool> onReady;
  final Dio? dio;

  @override
  State<WindowsChatStatus> createState() => _WindowsChatStatusState();
}

class _WindowsChatStatusState extends State<WindowsChatStatus> {
  Timer? _timer;
  bool _checking = false;
  String _text = 'Windows KI · lokales Backend wird geprüft …';

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => _check());
    scheduleMicrotask(_check);
  }

  Future<void> _check() async {
    if (_checking || !mounted) return;
    _checking = true;
    bool ready = false;
    String text;
    try {
      final response = await (widget.dio ?? ApiClient().dio).get<dynamic>(
        '/v1/local/status',
        options: Options(receiveTimeout: const Duration(seconds: 2),
            sendTimeout: const Duration(seconds: 2)),
      );
      final data = response.data;
      if (data is! Map || data['mode'] != 'P3' ||
          data['remaining_calls'] is! int || data['remaining_micro_usd'] is! int ||
          data['acceptance_calls'] is! int || data['acceptance'] is! bool ||
          (data['remaining_calls'] as int) < 0 || (data['remaining_calls'] as int) > 40 ||
          (data['remaining_micro_usd'] as int) < 0 || (data['remaining_micro_usd'] as int) > 1000000 ||
          (data['acceptance_calls'] as int) < 0 || (data['acceptance_calls'] as int) > 8) {
        throw const FormatException('Invalid local mode');
      }
      final dollars = (data['remaining_micro_usd'] as int) / 1000000;
      ready = data['blocked'] == null && data['remaining_calls'] > 0 && dollars > 0 &&
          (!data['acceptance'] || data['acceptance_calls'] < 8);
      text = 'Windows KI · echte API-Kosten\n'
          'Rest: ${data['remaining_calls']}/40 Aufrufe · ${dollars.toStringAsFixed(4)} USD reservierbar';
      if (!ready) {
        final request = RequestOptions(path: '/v1/local/status');
        final error = ApiError.fromDio(DioException(requestOptions: request,
            response: Response(requestOptions: request, statusCode: 503,
                data: {'detail': data['blocked'] ?? {'code': 'P3_BUDGET'}})));
        text += '\n${error.message}';
      }
    } catch (_) {
      text = 'Windows KI · Backend nicht bereit oder nicht verbunden.\n'
          'Senden gesperrt. Lokalen Status prüfen.';
    } finally {
      _checking = false;
    }
    if (!mounted) return;
    setState(() => _text = text);
    widget.onReady(ready);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.all(8), child: Text(_text, textAlign: TextAlign.center));
}

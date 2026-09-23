import 'package:flutter/material.dart';

import 'evaluation.dart';
import 'transport.dart';
export 'transport.dart' show ProbeGate, probeGate, requestProbe;

void main() => runApp(const AppleNativeProbeApp());

class AppleNativeProbeApp extends StatefulWidget {
  const AppleNativeProbeApp({super.key});
  @override
  State<AppleNativeProbeApp> createState() => _AppleNativeProbeAppState();
}

class _AppleNativeProbeAppState extends State<AppleNativeProbeApp> {
  final _controller = ProbeController();
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
          home: Scaffold(
        appBar: AppBar(
            title: const Text('Apple-Diagnose – keine Anmeldung bei Emie')),
        body: Padding(
            padding: const EdgeInsets.all(24),
            child: ListenableBuilder(
              listenable: _controller,
              builder: (context, _) => ListView(children: [
                const Text(probeDisclaimer),
                Text(switch (requestProbe()) {
                  ProbeGate.disabled =>
                    'Gesperrt: Debug und EMIE_APPLE_NATIVE_PROBE=true erforderlich.',
                  ProbeGate.unsupported =>
                    'Gesperrt: ausschließlich natives iOS.',
                  ProbeGate.ready =>
                    'Lokale Diagnose bereit; keine Server-Challenge.',
                }),
                Text('Ablauf: ${_controller.phase.name}'),
                if (_controller.nativePending)
                  const Text(
                      'Nativer Aufruf noch ausstehend. Kein weiterer Start möglich.'),
                if (_controller.phase == ProbePhase.timedOut)
                  const Text(
                      'Lokal nicht mehr ausgewertet. Der Apple-Dialog kann weiterlaufen.'),
                if (_controller.result != null)
                  Text(_controller.result.toString()),
                ElevatedButton(
                    onPressed: _controller.canStart ? _controller.start : null,
                    child: const Text('Apple-Diagnose starten')),
              ]),
            )),
      ));
}

import 'package:flutter/material.dart';
import '../../../../core/localization/b2_text.dart';

class EmiePlusScreen extends StatelessWidget {
  const EmiePlusScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Emie Plus')),
        body: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(b2(
                    context,
                    'Plus und Abrechnung sind in dieser Beta noch nicht verfügbar.',
                    'Plus and billing are not available in this beta yet.')),
                const SizedBox(height: 16),
                FilledButton(
                    onPressed: null,
                    child: Text(b2(
                        context, 'Noch nicht verfügbar', 'Not available yet'))),
              ],
            )),
      );
}

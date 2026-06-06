// ==============================================
// Emie • Plus Screen
// Pfad: lib/features/plus/presentation/screens/emie_plus_screen.dart
// ==============================================

import 'package:flutter/material.dart';

class EmiePlusScreen extends StatelessWidget {
  const EmiePlusScreen({super.key});

  static const Color _bg = Color(0xFF050307);
  static const Color _bg2 = Color(0xFF0A0712);

  static const Color _card = Color(0xFFFCF8F1);

  static const Color _gold = Color(0xFF8A6117);
  static const Color _champagne = Color(0xFFFCF6BA);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [_bg, _bg2, _bg],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Stack(
          children: [
            const _PlusBackground(),
            SafeArea(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(
                  22,
                  18,
                  22,
                  34,
                ),
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    IconButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      icon: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: _champagne,
                        size: 20,
                      ),
                    ),

                    const SizedBox(height: 26),

                    Center(
                      child: Column(
                        children: [
                          const Text(
                            'Emie Plus',
                            style: TextStyle(
                              color: _champagne,
                              fontSize: 42,
                              height: 1,
                              fontWeight: FontWeight.w500,
                              letterSpacing: -0.6,
                              fontFamily: 'Inter',
                            ),
                          ),

                          const SizedBox(height: 12),

                          Text(
                            'Mehr Kapazität. Mehr Geschwindigkeit.\nGleiche Fairness.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.62),
                              fontSize: 14.5,
                              height: 1.45,
                              fontFamily: 'Inter',
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 36),

                    _PlusCard(
                      child: Column(
                        children: const [
                          _BenefitTile(
                            icon:
                                Icons.all_inclusive_rounded,
                            title:
                                'Unlimitierte Konversationen',
                            subtitle:
                                'Keine Token-Limits für intensive Nutzung.',
                          ),

                          _BenefitDivider(),

                          _BenefitTile(
                            icon: Icons.bolt_rounded,
                            title: 'Priority Queue',
                            subtitle:
                                'Maximale Geschwindigkeit bei hoher Auslastung.',
                          ),

                          _BenefitDivider(),

                          _BenefitTile(
                            icon: Icons.memory_rounded,
                            title:
                                'Erweiterter Second-Brain-Speicher',
                            subtitle:
                                'Mehr Platz für langfristige Erinnerungen.',
                          ),

                          _BenefitDivider(),

                          _BenefitTile(
                            icon:
                                Icons.auto_awesome_rounded,
                            title: 'Early Access',
                            subtitle:
                                'Früherer Zugriff auf neue Updates.',
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 28),

                    SizedBox(
                      width: double.infinity,
                      height: 58,
                      child: ElevatedButton(
                        onPressed: () {
                          // TODO:
                          // Stripe / StoreKit /
                          // Google Billing
                        },
                        style: ElevatedButton.styleFrom(
                          elevation: 0,
                          backgroundColor: _champagne,
                          foregroundColor:
                              const Color(0xFF17130C),
                          shape:
                              RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(
                              999,
                            ),
                          ),
                        ),
                        child: const Text(
                          'Upgrade aktivieren',
                          style: TextStyle(
                            fontSize: 15.5,
                            fontWeight:
                                FontWeight.w800,
                            letterSpacing: 0.1,
                            fontFamily: 'Inter',
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    Text(
                      'Deine Intelligenz bleibt dieselbe. Mit Plus erweiterst du nur deine Kapazitäten und unterstützt die Entwicklung.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color:
                            Colors.white.withOpacity(0.44),
                        fontSize: 12.8,
                        height: 1.5,
                        fontFamily: 'Inter',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==============================================
// CARD
// ==============================================

class _PlusCard extends StatelessWidget {
  const _PlusCard({
    required this.child,
  });

  final Widget child;

  static const Color _card = Color(0xFFFCF8F1);

  static const Color _gold = Color(0xFF8A6117);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(0.8),
      decoration: BoxDecoration(
        borderRadius:
            BorderRadius.circular(28),
        gradient: LinearGradient(
          colors: [
            _gold.withOpacity(0.16),
            _gold.withOpacity(0.34),
            _gold.withOpacity(0.10),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(
          18,
          22,
          18,
          22,
        ),
        decoration: BoxDecoration(
          color: _card,
          borderRadius:
              BorderRadius.circular(27),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.42),
              blurRadius: 34,
              offset: const Offset(0, 20),
            ),
          ],
        ),
        child: child,
      ),
    );
  }
}

// ==============================================
// BENEFIT TILE
// ==============================================

class _BenefitTile extends StatelessWidget {
  const _BenefitTile({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  static const Color _gold = Color(0xFF8A6117);

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _gold.withOpacity(0.10),
          ),
          child: Icon(
            icon,
            color: _gold,
            size: 22,
          ),
        ),

        const SizedBox(width: 14),

        Expanded(
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: _gold,
                  fontSize: 15.2,
                  fontWeight: FontWeight.w700,
                  height: 1.2,
                  fontFamily: 'Inter',
                ),
              ),

              const SizedBox(height: 5),

              Text(
                subtitle,
                style: TextStyle(
                  color: Colors.black.withOpacity(
                    0.56,
                  ),
                  fontSize: 13.2,
                  height: 1.4,
                  fontFamily: 'Inter',
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ==============================================
// DIVIDER
// ==============================================

class _BenefitDivider extends StatelessWidget {
  const _BenefitDivider();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          const EdgeInsets.symmetric(vertical: 18),
      child: Divider(
        height: 1,
        color: const Color(0xFF8A6117)
            .withOpacity(0.12),
      ),
    );
  }
}

// ==============================================
// BACKGROUND
// ==============================================

class _PlusBackground extends StatelessWidget {
  const _PlusBackground();

  static const Color _gold = Color(0xFF8A6117);

  static const Color _champagne =
      Color(0xFFFCF6BA);

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Align(
          alignment: const Alignment(
            0,
            -0.78,
          ),
          child: Container(
            width: 540,
            height: 540,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  _champagne.withOpacity(0.08),
                  _gold.withOpacity(0.03),
                  Colors.transparent,
                ],
                stops: const [
                  0,
                  0.38,
                  0.78,
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
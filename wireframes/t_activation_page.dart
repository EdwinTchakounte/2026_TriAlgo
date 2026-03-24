// =============================================================
// FICHIER : lib/presentation/wireframes/t_activation_page.dart
// ROLE   : Activation premium avec design attractif
// COUCHE : Presentation > Wireframes
// =============================================================

import 'package:flutter/material.dart';
import 'package:trialgo/presentation/wireframes/t_theme.dart';
import 'package:trialgo/presentation/wireframes/t_locale.dart';
import 'package:trialgo/presentation/wireframes/t_mock_data.dart';
import 'package:trialgo/presentation/wireframes/t_illustrations.dart';
import 'package:trialgo/presentation/wireframes/t_auth_page.dart';
import 'package:trialgo/presentation/wireframes/t_home_page.dart';

/// Page d'activation premium avec mascotte et design pro.
class TActivationPage extends StatefulWidget {
  const TActivationPage({super.key});

  @override
  State<TActivationPage> createState() => _TActivationPageState();
}

class _TActivationPageState extends State<TActivationPage> {
  final _codeController = TextEditingController();
  bool _isActivating = false;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tr = TLocale.of(context);
    final viewHeight = MediaQuery.of(context).size.height;
    final topPadding = MediaQuery.of(context).padding.top;

    return Scaffold(
      body: TTheme.patterned(
        child: SafeArea(
          child: SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: viewHeight - topPadding),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Column(
                  children: [
                    const SizedBox(height: 12),

                    // --- Header avec back ---
                    Row(
                      children: [
                        GestureDetector(
                          onTap: () {
                            Navigator.of(context).pushReplacement(
                              MaterialPageRoute(builder: (_) => const TAuthPage()),
                            );
                          },
                          child: Container(
                            width: 40, height: 40,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.06),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.arrow_back_rounded, color: Colors.white54, size: 20),
                          ),
                        ),
                        const Spacer(),
                        // Etape indicator.
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                          decoration: BoxDecoration(
                            color: TTheme.gold.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: TTheme.gold.withValues(alpha: 0.2)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.vpn_key_rounded, color: TTheme.gold, size: 14),
                              const SizedBox(width: 5),
                              Text('Etape 2/2', style: TTheme.tagStyle(color: TTheme.gold, size: 11)),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // --- Logo TRIALGO ---
                    Image.asset(MockData.logo, width: 100, height: 100, fit: BoxFit.contain),

                    const SizedBox(height: 16),

                    // --- Illustration cle premium ---
                    TIllustrations.activationVisual(size: 120),

                    const SizedBox(height: 20),

                    // --- Icone + titre ---
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 40, height: 40,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(colors: [TTheme.gold, TTheme.orange]),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.vpn_key_rounded, color: Colors.white, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Text(tr('activation.title'), style: TTheme.titleStyle(size: 24)),
                      ],
                    ),

                    const SizedBox(height: 12),

                    Text(
                      tr('activation.desc'),
                      textAlign: TextAlign.center,
                      style: TTheme.bodyStyle(size: 13, color: Colors.white.withValues(alpha: 0.5)),
                    ),

                    const SizedBox(height: 28),

                    // --- Champ de saisie premium ---
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        gradient: _codeController.text.length >= 4
                            ? LinearGradient(colors: [
                                TTheme.gold.withValues(alpha: 0.3),
                                TTheme.orange.withValues(alpha: 0.2),
                              ])
                            : null,
                        color: _codeController.text.length >= 4 ? null : Colors.white.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF12122A),
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: TextField(
                          controller: _codeController,
                          style: TTheme.scoreStyle(size: 22),
                          textAlign: TextAlign.center,
                          textCapitalization: TextCapitalization.characters,
                          maxLength: 19,
                          decoration: InputDecoration(
                            hintText: tr('activation.hint'),
                            hintStyle: TTheme.bodyStyle(size: 18, color: Colors.white.withValues(alpha: 0.15)),
                            counterText: '',
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                    ),

                    const SizedBox(height: 8),

                    Text(
                      tr('activation.format'),
                      style: TTheme.bodyStyle(size: 11, color: Colors.white.withValues(alpha: 0.25)),
                    ),

                    const SizedBox(height: 28),

                    // --- Bouton Activer ---
                    SizedBox(
                      width: double.infinity, height: 54,
                      child: AnimatedOpacity(
                        opacity: _codeController.text.length >= 4 ? 1.0 : 0.35,
                        duration: const Duration(milliseconds: 200),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(colors: [TTheme.gold, TTheme.orange]),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: _codeController.text.length >= 4
                                ? [BoxShadow(color: TTheme.gold.withValues(alpha: 0.35), blurRadius: 18, offset: const Offset(0, 6))]
                                : [],
                          ),
                          child: ElevatedButton(
                            onPressed: _codeController.text.length >= 4 ? _activateCode : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              disabledBackgroundColor: Colors.transparent,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                            child: _isActivating
                                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                                : Text(tr('activation.button'), style: TTheme.buttonStyle()),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // --- Aide ---
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.03),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.help_outline_rounded, color: Colors.white.withValues(alpha: 0.25), size: 18),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Le code se trouve a l\'interieur de votre boite de jeu, sur le carton de protection.',
                              style: TTheme.bodyStyle(size: 11, color: Colors.white.withValues(alpha: 0.3)),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _activateCode() async {
    final tr = TLocale.of(context);
    setState(() => _isActivating = true);
    await Future.delayed(const Duration(milliseconds: 1200));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Text(tr('activation.success')),
          ]),
          backgroundColor: TTheme.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ),
      );
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const THomePage()),
      );
    }
  }
}

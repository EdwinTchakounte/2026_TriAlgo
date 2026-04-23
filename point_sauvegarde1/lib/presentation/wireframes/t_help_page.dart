// =============================================================
// FICHIER : lib/presentation/wireframes/t_help_page.dart
// ROLE   : Aide et FAQ interactive (sous-page Parametres)
// COUCHE : Presentation > Wireframes
// =============================================================

import 'package:flutter/material.dart';
import 'package:trialgo/presentation/wireframes/t_theme.dart';
import 'package:trialgo/presentation/wireframes/t_locale.dart';

/// Page d'aide et FAQ avec questions deroulantes.
class THelpPage extends StatelessWidget {
  const THelpPage({super.key});

  @override
  Widget build(BuildContext context) {
    final tr = TLocale.of(context);

    // Liste des questions/reponses.
    final faqs = [
      {
        'q': tr('help.q1'),
        'a': tr('help.a1'),
        'icon': Icons.extension_rounded,
        'color': TTheme.orange,
      },
      {
        'q': tr('help.q2'),
        'a': tr('help.a2'),
        'icon': Icons.image_rounded,
        'color': TTheme.blue,
      },
      {
        'q': tr('help.q3'),
        'a': tr('help.a3'),
        'icon': Icons.compare_arrows_rounded,
        'color': const Color(0xFFFFA726),
      },
      {
        'q': tr('help.q4'),
        'a': tr('help.a4'),
        'icon': Icons.favorite_rounded,
        'color': TTheme.red,
      },
      {
        'q': tr('help.q5'),
        'a': tr('help.a5'),
        'icon': Icons.star_rounded,
        'color': TTheme.gold,
      },
      {
        'q': tr('help.q6'),
        'a': tr('help.a6'),
        'icon': Icons.vpn_key_rounded,
        'color': TTheme.green,
      },
      {
        'q': tr('help.q7'),
        'a': tr('help.a7'),
        'icon': Icons.emoji_events_rounded,
        'color': const Color(0xFF7E57C2),
      },
      {
        'q': tr('help.q8'),
        'a': tr('help.a8'),
        'icon': Icons.touch_app_rounded,
        'color': const Color(0xFF42A5F5),
      },
    ];

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A1A),
      body: TTheme.patterned(
        child: SafeArea(
          child: Column(
            children: [
              // Header.
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 20, 0),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: Container(
                        width: 40, height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.arrow_back_rounded, color: Colors.white54, size: 20),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Text(tr('help.title'), style: TTheme.titleStyle(size: 20)),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Liste des FAQ.
              Expanded(
                child: ListView.builder(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                  itemCount: faqs.length,
                  itemBuilder: (context, index) {
                    final faq = faqs[index];
                    return _FaqTile(
                      question: faq['q'] as String,
                      answer: faq['a'] as String,
                      icon: faq['icon'] as IconData,
                      color: faq['color'] as Color,
                    );
                  },
                ),
              ),

              // Contact support.
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.03),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40, height: 40,
                        decoration: BoxDecoration(
                          color: TTheme.blue.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.mail_outline_rounded, color: TTheme.blue, size: 20),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(tr('help.contact'), style: TTheme.subtitleStyle(size: 14)),
                            Text(
                              'contact@trialgo.com',
                              style: TTheme.bodyStyle(size: 12, color: TTheme.blue),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Tuile FAQ deroulante (expand/collapse).
class _FaqTile extends StatefulWidget {
  final String question;
  final String answer;
  final IconData icon;
  final Color color;

  const _FaqTile({
    required this.question,
    required this.answer,
    required this.icon,
    required this.color,
  });

  @override
  State<_FaqTile> createState() => _FaqTileState();
}

class _FaqTileState extends State<_FaqTile> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        onTap: () => setState(() => _expanded = !_expanded),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _expanded
                ? widget.color.withValues(alpha: 0.06)
                : Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _expanded
                  ? widget.color.withValues(alpha: 0.2)
                  : Colors.white.withValues(alpha: 0.06),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Question.
              Row(
                children: [
                  Icon(widget.icon, color: widget.color, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.question,
                      style: TTheme.bodyStyle(
                        size: 14,
                        weight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  AnimatedRotation(
                    turns: _expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 250),
                    child: Icon(
                      Icons.expand_more_rounded,
                      color: Colors.white.withValues(alpha: 0.3),
                      size: 22,
                    ),
                  ),
                ],
              ),
              // Reponse (visible seulement si expanded).
              AnimatedCrossFade(
                firstChild: const SizedBox.shrink(),
                secondChild: Padding(
                  padding: const EdgeInsets.only(top: 12, left: 32),
                  child: Text(
                    widget.answer,
                    style: TTheme.bodyStyle(
                      size: 13,
                      color: Colors.white.withValues(alpha: 0.5),
                    ),
                  ),
                ),
                crossFadeState: _expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                duration: const Duration(milliseconds: 250),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

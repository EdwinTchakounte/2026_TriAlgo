// =============================================================
// FICHIER : lib/presentation/wireframes/t_tutorial_page.dart
// ROLE   : Tutoriel interactif expliquant le principe E + C = R
// COUCHE : Presentation > Wireframes
// =============================================================
//
// QU'EST-CE QUE LE TUTORIEL ?
// ----------------------------
// C'est un ecran PAGINE (style onboarding) qui explique
// les regles du jeu TRIALGO en 4 etapes visuelles :
//
//   Page 1 : Le principe fondamental (E + C = R)
//   Page 2 : Les 3 types de cartes (Emettrice, Cable, Receptrice)
//   Page 3 : Comment jouer (trouver la carte manquante)
//   Page 4 : Les configurations (A, B, C) et les niveaux
//
// Chaque page utilise des images et des animations simples
// pour rendre l'apprentissage visuel et intuitif.
//
// Le joueur navigue avec des swipes ou des boutons.
//
// REFERENCE : Recueil v3.0, section 1 + 6
// =============================================================

import 'package:flutter/material.dart';
import 'package:trialgo/presentation/wireframes/t_locale.dart';
import 'package:trialgo/presentation/wireframes/t_theme.dart';
import 'package:trialgo/presentation/wireframes/t_mock_data.dart';

/// Tutoriel interactif avec pages swipables.
///
/// 4 pages expliquant le principe E + C = R, les types de cartes,
/// le gameplay et la progression.
class TTutorialPage extends StatefulWidget {
  const TTutorialPage({super.key});

  @override
  State<TTutorialPage> createState() => _TTutorialPageState();
}

class _TTutorialPageState extends State<TTutorialPage> {
  // Controleur du PageView pour naviguer entre les pages.
  final _pageController = PageController();

  // Index de la page courante (0 a 3).
  int _currentPage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tr = TLocale.of(context);
    return Scaffold(
      body: TTheme.patterned(
        child: SafeArea(
          child: Column(
            children: [
              // --- Header ---
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 16, 0),
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
                    Text(tr('tuto.title'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 20)),
                    const Spacer(),
                    // Indicateur de page.
                    Text(
                      '${_currentPage + 1}/4',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),

              // --- Indicateurs de progression (dots) ---
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(4, (i) {
                    final isActive = i == _currentPage;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: isActive ? 28 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(4),
                        color: isActive
                            ? const Color(0xFFFF6B35)
                            : Colors.white.withValues(alpha: 0.12),
                      ),
                    );
                  }),
                ),
              ),

              // --- Pages swipables ---
              Expanded(
                child: PageView(
                  controller: _pageController,
                  onPageChanged: (index) => setState(() => _currentPage = index),
                  children: [
                    _buildPage1(),
                    _buildPage2(),
                    _buildPage3(),
                    _buildPage4(),
                  ],
                ),
              ),

              // --- Boutons de navigation ---
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: Row(
                  children: [
                    // Bouton precedent.
                    if (_currentPage > 0)
                      GestureDetector(
                        onTap: () {
                          _pageController.previousPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          );
                        },
                        child: Container(
                          width: 48, height: 48,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(Icons.arrow_back_rounded, color: Colors.white38, size: 22),
                        ),
                      )
                    else
                      const SizedBox(width: 48),

                    const Spacer(),

                    // Bouton suivant / Terminer.
                    GestureDetector(
                      onTap: () {
                        if (_currentPage < 3) {
                          _pageController.nextPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          );
                        } else {
                          Navigator.of(context).pop();
                        }
                      },
                      child: Container(
                        height: 48,
                        padding: const EdgeInsets.symmetric(horizontal: 28),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFF6B35), Color(0xFFF7C948)],
                          ),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFFF6B35).withValues(alpha: 0.3),
                              blurRadius: 12, offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            _currentPage < 3 ? tr('tuto.next') : tr('tuto.done'),
                            style: const TextStyle(
                              color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // =============================================================
  // PAGE 1 : Le principe fondamental
  // =============================================================
  Widget _buildPage1() {
    final tr = TLocale.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        children: [
          const SizedBox(height: 16),

          // Illustration E + C = R avec cartes.
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
            ),
            child: Column(
              children: [
                // Formule visuelle.
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _demoCard('E', 'Emettrice', const Color(0xFF42A5F5), MockData.emettrice1['imageUrl'] as String),
                    _operatorSymbol('+'),
                    _demoCard('C', 'Cable', const Color(0xFFFFA726), MockData.cable1['imageUrl'] as String),
                    _operatorSymbol('='),
                    _demoCard('R', 'Receptrice', const Color(0xFF66BB6A), MockData.receptrice1['imageUrl'] as String),
                  ],
                ),
                const SizedBox(height: 20),
                // Formule texte.
                ShaderMask(
                  shaderCallback: (bounds) => const LinearGradient(
                    colors: [Color(0xFFFF6B35), Color(0xFFF7C948)],
                  ).createShader(bounds),
                  child: const Text(
                    'E + C = R',
                    style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 4),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Logo officiel TRIALGO.
          Image.asset(MockData.logo, width: 80, height: 80, fit: BoxFit.contain),

          const SizedBox(height: 12),

          Text(
            tr('tuto.principle'),
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Colors.white),
          ),
          const SizedBox(height: 12),
          Text(
            'Dans TRIALGO, une image de base (Emettrice) combinee avec '
            'une transformation visuelle (Cable) produit un resultat (Receptrice).\n\n'
            'Le dessin du Cable EST l\'algorithme. Pas de code, pas de texte : '
            'l\'image elle-meme represente la transformation.',
            style: TextStyle(fontSize: 14, color: Colors.white.withValues(alpha: 0.5), height: 1.6),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // =============================================================
  // PAGE 2 : Les 3 types de cartes
  // =============================================================
  Widget _buildPage2() {
    final tr = TLocale.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        children: [
          const SizedBox(height: 16),

          Text(
            tr('tuto.card_types'),
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Colors.white),
          ),
          const SizedBox(height: 24),

          _cardTypeExplainer(
            letter: 'E',
            name: 'Emettrice',
            desc: 'L\'image de base : un animal, un objet, un paysage.',
            example: 'Ex : un lion',
            color: const Color(0xFF42A5F5),
            imageUrl: MockData.emettrice1['imageUrl'] as String,
          ),

          const SizedBox(height: 14),

          _cardTypeExplainer(
            letter: 'C',
            name: 'Cable (Image-Algorithme)',
            desc: 'Le dessin EST l\'algorithme. L\'image elle-meme represente la transformation a appliquer.',
            example: 'Ex : des fleches de miroir = transformation miroir',
            color: const Color(0xFFFFA726),
            imageUrl: MockData.cable1['imageUrl'] as String,
          ),

          const SizedBox(height: 14),

          _cardTypeExplainer(
            letter: 'R',
            name: 'Receptrice',
            desc: 'Le resultat : l\'image de base apres transformation.',
            example: 'Ex : lion retourne',
            color: const Color(0xFF66BB6A),
            imageUrl: MockData.receptrice1['imageUrl'] as String,
          ),
        ],
      ),
    );
  }

  // =============================================================
  // PAGE 3 : Comment jouer
  // =============================================================
  Widget _buildPage3() {
    final tr = TLocale.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        children: [
          const SizedBox(height: 16),

          Text(
            tr('tuto.how_to_play'),
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Colors.white),
          ),
          const SizedBox(height: 24),

          _stepCard(1, 'Observez le trio',
            'Deux cartes sont visibles. La troisieme est masquee par un "?".',
            Icons.visibility_rounded, const Color(0xFF42A5F5)),

          _stepCard(2, 'Analysez la transformation',
            'Comprenez la relation entre les images visibles. Quelle transformation a ete appliquee ?',
            Icons.psychology_rounded, const Color(0xFFFFA726)),

          _stepCard(3, 'Choisissez la bonne image',
            'Faites defiler les 10 propositions et tapez sur celle qui complete le trio.',
            Icons.touch_app_rounded, const Color(0xFF66BB6A)),

          _stepCard(4, 'Gagnez des points !',
            'Plus vous etes rapide, plus vous gagnez de points. Enchainez les bonnes reponses pour des bonus !',
            Icons.emoji_events_rounded, const Color(0xFFF7C948)),
        ],
      ),
    );
  }

  // =============================================================
  // PAGE 4 : Configurations et niveaux
  // =============================================================
  Widget _buildPage4() {
    final tr = TLocale.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        children: [
          const SizedBox(height: 16),

          Text(
            tr('tuto.progress'),
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Colors.white),
          ),
          const SizedBox(height: 10),
          Text(
            '3 configurations de difficulte croissante',
            style: TextStyle(fontSize: 14, color: Colors.white.withValues(alpha: 0.5)),
          ),
          const SizedBox(height: 24),

          _configCard(
            'Config A', 'Facile',
            'Vous voyez E et C → trouvez R (le resultat)',
            'E + C = ?',
            const Color(0xFF66BB6A),
          ),

          const SizedBox(height: 12),

          _configCard(
            'Config B', 'Moyen',
            'Vous voyez E et R → trouvez C (la transformation)',
            'E + ? = R',
            const Color(0xFFFFA726),
          ),

          const SizedBox(height: 12),

          _configCard(
            'Config C', 'Difficile',
            'Vous voyez C et R → trouvez E (l\'image de depart)',
            '? + C = R',
            const Color(0xFFEF5350),
          ),

          const SizedBox(height: 24),

          // Distances.
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
            ),
            child: Column(
              children: [
                Text('Distances', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white.withValues(alpha: 0.4), letterSpacing: 1)),
                const SizedBox(height: 12),
                _distanceRow('D1', '3 images', 'Trio simple', const Color(0xFF42A5F5)),
                const SizedBox(height: 8),
                _distanceRow('D2', '5 images', 'Chaine de trios', const Color(0xFFFFA726)),
                const SizedBox(height: 8),
                _distanceRow('D3', '7 images', 'Chaine etendue', const Color(0xFFEF5350)),
              ],
            ),
          ),

          const SizedBox(height: 16),
        ],
      ),
    );
  }

  // =============================================================
  // WIDGETS UTILITAIRES DU TUTORIEL
  // =============================================================

  /// Carte de demonstration dans le trio (page 1).
  Widget _demoCard(String letter, String name, Color color, String imageUrl) {
    return Column(
      children: [
        Container(
          width: 64, height: 64,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withValues(alpha: 0.5), width: 2),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.network(imageUrl, fit: BoxFit.cover,
              errorBuilder: (c, e, s) => Container(
                color: color.withValues(alpha: 0.2),
                child: Center(child: Text(letter, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: color))),
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(letter, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: color)),
      ],
    );
  }

  /// Symbole operateur entre les cartes.
  Widget _operatorSymbol(String symbol) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Text(
        symbol,
        style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white.withValues(alpha: 0.3)),
      ),
    );
  }

  /// Carte explicative d'un type de carte (page 2).
  Widget _cardTypeExplainer({
    required String letter, required String name, required String desc,
    required String example, required Color color, required String imageUrl,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          Container(
            width: 56, height: 56,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: color.withValues(alpha: 0.4)),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(13),
              child: Image.network(imageUrl, fit: BoxFit.cover,
                errorBuilder: (c, e, s) => Container(
                  color: color.withValues(alpha: 0.2),
                  child: Center(child: Text(letter, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: color))),
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(color: color.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(6)),
                      child: Text(letter, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: color)),
                    ),
                    Text(name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
                  ],
                ),
                const SizedBox(height: 4),
                Text(desc, style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.5), height: 1.4)),
                Text(example, style: TextStyle(fontSize: 11, color: color.withValues(alpha: 0.7), fontStyle: FontStyle.italic)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Carte d'etape numerotee (page 3).
  Widget _stepCard(int step, String title, String desc, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42, height: 42,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [color, color.withValues(alpha: 0.5)]),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(icon, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text('Etape $step', style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w700)),
                      Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(desc, style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.5), height: 1.4)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Carte de configuration A/B/C (page 4).
  Widget _configCard(String config, String difficulty, String desc, String formula, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(formula, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: color)),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(config, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(color: color.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(6)),
                      child: Text(difficulty, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color)),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(desc, style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.5))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Ligne de distance (page 4).
  Widget _distanceRow(String d, String count, String desc, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
          child: Text(d, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: color)),
        ),
        const SizedBox(width: 12),
        Text(count, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
        const Spacer(),
        Text(desc, style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.4))),
      ],
    );
  }
}

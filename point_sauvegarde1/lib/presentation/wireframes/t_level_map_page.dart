// =============================================================
// FICHIER : lib/presentation/wireframes/t_level_map_page.dart
// ROLE   : Carte des niveaux — design premium card game
// COUCHE : Presentation > Wireframes
// =============================================================
//
// Design refait : chaque niveau est une carte premium avec :
//   - Fond degrade colore selon l'etat (actif, complete, verrouille)
//   - Numero du niveau dans un cercle gradient
//   - Etoiles dorees pour les niveaux completes
//   - Icone play animee pour le niveau en cours
//   - Tags distance et config dans des pills colorees
//   - Effet de verrouillage avec opacite reduite et cadenas
//   - Animation d'entree echelonnee des cartes
//
// REFERENCE : Recueil v3.0, section 7.1
// =============================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:trialgo/domain/usecases/generate_logical_nodes_usecase.dart';
import 'package:trialgo/presentation/providers/graph_provider.dart';
import 'package:trialgo/presentation/providers/profile_provider.dart';
import 'package:trialgo/presentation/wireframes/t_game_page.dart';
import 'package:trialgo/presentation/wireframes/t_locale.dart';
import 'package:trialgo/presentation/wireframes/widgets/level_map/level_map_widgets.dart';


/// Carte de selection des niveaux premium.
///
/// StatefulWidget pour gerer l'AnimationController de l'entree
/// echelonnee et l'animation du bouton play du niveau en cours.
class TLevelMapPage extends ConsumerStatefulWidget {
  const TLevelMapPage({super.key});

  @override
  ConsumerState<TLevelMapPage> createState() => _TLevelMapPageState();
}

class _TLevelMapPageState extends ConsumerState<TLevelMapPage>
    with TickerProviderStateMixin {

  /// Controller pour l'entree echelonnee des cartes de niveaux.
  /// Les cartes glissent du bas avec un delai croissant.
  late AnimationController _entryController;

  /// Controller pour la pulsation du bouton play du niveau en cours.
  /// L'icone play pulse doucement pour attirer l'attention.
  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();

    // Entree echelonnee : 600ms total, les cartes apparaissent une par une.
    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();

    // Pulsation du play : scale 1.0 → 1.12 → 1.0 en 1.5s, boucle.
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 1.0, end: 1.12).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _entryController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  // =============================================================
  // GENERATION DYNAMIQUE DES NIVEAUX / PARTIES
  // =============================================================
  // La liste des parties est calculee a partir du POOL de noeuds
  // logiques precomputes (GraphSyncService.logicalNodes).
  //
  // Chaque "niveau" = une partie qui consomme un nombre fixe de
  // noeuds logiques selon la distance :
  //
  //   Distance 1 : 8 questions par partie
  //   Distance 2 : 10 questions par partie
  //   Distance 3 : 12 questions par partie
  //
  // Le nombre total de parties depend donc directement de la
  // taille du graphe synchronise.
  //
  // ATTRIBUTION DES ETATS :
  //   - niveau < currentLevel : completed (etoiles attribuees)
  //   - niveau == currentLevel : en cours
  //   - niveau > currentLevel  : verrouille
  // =============================================================

  // =============================================================
  // METADATA DES PALLIERS (TIERS)
  // =============================================================
  // Chaque distance (D1..D5) correspond a un pallier visuel avec
  // son propre titre, son sous-titre pedagogique et sa couleur
  // d'accent. L'intensite de la couleur croit avec la difficulte.
  // =============================================================

  static const List<Map<String, dynamic>> _tierMeta = [
    {
      'distance': 1,
      'title': 'PALIER I · Initiation',
      'subtitle': 'Trios simples (E + C = R)',
      'icon': Icons.school_rounded,
      'color': Color(0xFF42A5F5), // Bleu
    },
    {
      'distance': 2,
      'title': 'PALIER II · Chaines courtes',
      'subtitle': 'Quintettes — 2 trios enchaines',
      'icon': Icons.link_rounded,
      'color': Color(0xFF26C6DA), // Cyan
    },
    {
      'distance': 3,
      'title': 'PALIER III · Chaines moyennes',
      'subtitle': 'Septettes — 3 trios enchaines',
      'icon': Icons.auto_awesome_rounded,
      'color': Color(0xFF66BB6A), // Vert
    },
    {
      'distance': 4,
      'title': 'PALIER IV · Expert',
      'subtitle': 'Chaines de 4 trios',
      'icon': Icons.local_fire_department_rounded,
      'color': Color(0xFFFF9800), // Orange
    },
    {
      'distance': 5,
      'title': 'PALIER V · Maitre',
      'subtitle': 'Chaines de 5 trios',
      'icon': Icons.workspace_premium_rounded,
      'color': Color(0xFFE53935), // Rouge
    },
  ];

  /// Construit la liste d'items mixtes (entetes de pallier + niveaux).
  ///
  /// Chaque item a une cle 'type' :
  ///   - 'tier'  : entete de pallier (distance, titre, stats)
  ///   - 'level' : carte de niveau jouable
  List<Map<String, dynamic>> _generateLevelsFromPool(
    LogicalNodesPool? pool,
    int currentLevel,
  ) {
    // Si le pool n'est pas charge, retourner une liste vide.
    if (pool == null) return [];

    // NOUVELLE LOGIQUE : 1 niveau = 1 table d'une distance donnee.
    // Chaque partie utilise une seule table, garantissant qu'aucun
    // trio de la meme chaine n'apparait deux fois dans la partie.
    //
    // Ordre de progression :
    //   Niveau 1 = 1ere table de D1
    //   Niveau 2, 3, ... = suite des tables D1 (s'il y en a plusieurs)
    //   Puis tables D2, D3, D4, D5

    final result = <Map<String, dynamic>>[];
    int levelNum = 1;

    // Parcourir chaque distance de 1 a 5 et injecter un entete
    // de pallier avant les niveaux correspondants.
    for (int k = 1; k <= 5; k++) {
      final nbTables = pool.numberOfTables(k);
      if (nbTables == 0) continue;

      // Calculer les stats du pallier avant d'ajouter les niveaux.
      final tierStartLevel = levelNum;
      final tierEndLevel = levelNum + nbTables - 1;
      final completedInTier = [
        for (int lv = tierStartLevel; lv <= tierEndLevel; lv++)
          if (lv < currentLevel) lv,
      ].length;
      final hasCurrentInTier =
          currentLevel >= tierStartLevel && currentLevel <= tierEndLevel;
      final tierUnlocked = currentLevel >= tierStartLevel;

      // Injecter l'entete de pallier.
      final meta = _tierMeta[k - 1];
      result.add({
        'type': 'tier',
        'distance': k,
        'title': meta['title'],
        'subtitle': meta['subtitle'],
        'icon': meta['icon'],
        'color': meta['color'],
        'totalLevels': nbTables,
        'completedLevels': completedInTier,
        'isActive': hasCurrentInTier,
        'unlocked': tierUnlocked,
        'startLevel': tierStartLevel,
        'endLevel': tierEndLevel,
      });

      // Ajouter chaque niveau du pallier.
      for (int t = 0; t < nbTables; t++) {
        // Labels de configs selon la distance et le tableIndex.
        String cfg;
        if (k == 1) {
          cfg = 'A';
        } else if (k == 2) {
          cfg = t < 3 ? 'A+B' : 'B';
        } else if (k == 3) {
          cfg = t < 7 ? 'B+C' : 'C';
        } else {
          cfg = k == 4 ? 'B+C' : 'C';
        }
        result.add({
          'type': 'level',
          'level': levelNum,
          'label': 'Partie ${t + 1}',
          'distance': 'D$k',
          'tierColor': meta['color'],
          'configs': cfg,
          'unlocked': levelNum <= currentLevel,
          'completed': levelNum < currentLevel,
          'stars': levelNum < currentLevel ? 2 : 0,
        });
        levelNum++;
      }
    }

    return result;
  }

  @override
  Widget build(BuildContext context) {
    final tr = TLocale.of(context);

    // Recuperer le niveau actuel du joueur.
    final profile = ref.watch(profileProvider);
    final currentLevel = profile.level;

    // Generer dynamiquement la liste des parties a partir du POOL
    // de noeuds logiques precomputes. Chaque partie correspond a
    // un niveau de la liste affichee.
    //
    // Le calcul se base sur :
    //   - Le nombre de noeuds logiques disponibles par distance
    //   - Le nombre fixe de questions par partie (8, 10, 12)
    final pool = ref.watch(graphSyncServiceProvider).logicalNodes;
    final items = _generateLevelsFromPool(pool, currentLevel);

    // Separer les niveaux jouables des entetes de pallier pour
    // le calcul de la progression globale.
    final levelItems = items.where((l) => l['type'] == 'level').toList();
    final completed =
        levelItems.where((l) => l['completed'] == true).length;
    final progressRatio =
        levelItems.isEmpty ? 0.0 : completed / levelItems.length;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A1A),
      body: Stack(
        children: [
          // Fond degrade profond.
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF0A0A1A),
                  Color(0xFF1A1035),
                  Color(0xFF0D1B2A),
                ],
              ),
            ),
          ),

          // Contenu.
          SafeArea(
            child: Column(
              children: [
                // =======================================================
                // HEADER PREMIUM
                // =======================================================
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Row(
                    children: [
                      // Bouton retour frosted glass.
                      GestureDetector(
                        onTap: () => Navigator.of(context).pop(),
                        child: Container(
                          width: 42, height: 42,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.08),
                            ),
                          ),
                          child: const Icon(
                            Icons.arrow_back_rounded,
                            color: Colors.white54,
                            size: 20,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      // Titre avec gradient.
                      Expanded(
                        child: ShaderMask(
                          shaderCallback: (bounds) => const LinearGradient(
                            colors: [Colors.white, Color(0xFFF7C948)],
                          ).createShader(bounds),
                          child: Text(
                            tr('levels.title'),
                            style: GoogleFonts.rajdhani(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      // Badge de completion.
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              const Color(0xFFFF6B35).withValues(alpha: 0.2),
                              const Color(0xFFF7C948).withValues(alpha: 0.1),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: const Color(0xFFFF6B35).withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.emoji_events_rounded,
                              color: Color(0xFFF7C948),
                              size: 14,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '$completed/${levelItems.length}',
                              style: GoogleFonts.rajdhani(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFFF7C948),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // =======================================================
                // BARRE DE PROGRESSION PREMIUM
                // =======================================================
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
                  child: Column(
                    children: [
                      // Pourcentage a droite.
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Progression',
                            style: GoogleFonts.exo2(
                              fontSize: 11,
                              color: Colors.white.withValues(alpha: 0.35),
                            ),
                          ),
                          Text(
                            '${(progressRatio * 100).round()}%',
                            style: GoogleFonts.rajdhani(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFFF7C948),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      // Barre custom avec degrade.
                      Container(
                        height: 6,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            return Stack(
                              children: [
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 500),
                                  width: constraints.maxWidth * progressRatio,
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [
                                        Color(0xFFFF6B35),
                                        Color(0xFFF7C948),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(3),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFFFF6B35)
                                            .withValues(alpha: 0.4),
                                        blurRadius: 6,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 8),

                // =======================================================
                // LISTE DES NIVEAUX — CARTES PREMIUM
                // =======================================================
                Expanded(
                  child: AnimatedBuilder(
                    animation: _entryController,
                    builder: (context, _) {
                      return ListView.builder(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                        itemCount: items.length,
                        itemBuilder: (context, index) {
                          // Entree echelonnee : chaque carte a un delai base
                          // sur son index. Les premieres apparaissent vite.
                          final delay = (index * 0.04).clamp(0.0, 0.6);
                          final progress = ((_entryController.value - delay) / 0.4)
                              .clamp(0.0, 1.0);

                          final item = items[index];
                          final child = item['type'] == 'tier'
                              ? LevelMapTierHeader(
                                  color: item['color'] as Color,
                                  title: item['title'] as String,
                                  subtitle: item['subtitle'] as String,
                                  icon: item['icon'] as IconData,
                                  totalLevels: item['totalLevels'] as int,
                                  completedLevels:
                                      item['completedLevels'] as int,
                                  isActive: item['isActive'] as bool,
                                  unlocked: item['unlocked'] as bool,
                                  isFirst: index == 0,
                                )
                              : _buildLevelCardFromItem(item, tr);

                          return Opacity(
                            opacity: progress,
                            child: Transform.translate(
                              offset: Offset(0, 30 * (1.0 - progress)),
                              child: child,
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // =============================================================
  // ADAPTATION item Map → LevelMapLevelCard
  // =============================================================
  // La liste `items` contient des `Map<String, dynamic>` heritage
  // du design precedent. Cette methode extrait les champs typiques
  // et construit un [LevelMapLevelCard] avec le callback `onTap`
  // lie a ce state (pour acceder a `Navigator.of(context)`).
  // =============================================================

  Widget _buildLevelCardFromItem(
    Map<String, dynamic> lv,
    String Function(String) tr,
  ) {
    final unlocked = lv['unlocked'] as bool;
    final lvNum = lv['level'] as int;
    return LevelMapLevelCard(
      lvNum: lvNum,
      lvLabel: lv['label'] as String,
      distance: lv['distance'] as String,
      configs: lv['configs'] as String,
      unlocked: unlocked,
      isCompleted: lv['completed'] as bool,
      stars: lv['stars'] as int,
      levelWord: tr('common.level'),
      pulseAnim: _pulseAnim,
      onTap: unlocked
          ? () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => TGamePage(level: lvNum)),
              )
          : null,
    );
  }
}

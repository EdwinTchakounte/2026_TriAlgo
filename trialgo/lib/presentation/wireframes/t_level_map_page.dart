// =============================================================
// FICHIER : lib/presentation/wireframes/t_level_map_page.dart
// ROLE   : Carte des niveaux - trading cards inclinees + connecteurs
// COUCHE : Presentation > Wireframes
// =============================================================
//
// REFONTE ENHANCEMENT :
// ---------------------
// - Chaque niveau devient une TRADING CARD rectangulaire (110x140)
//   avec rotation legere (~+/-5 deg) pour un rendu dynamique
// - Contours designes : double bordure (gradient exterieur + trait
//   clair interieur, style carte a collectionner Hearthstone-like)
// - Connecteurs pointilles entre les cartes, colore selon la zone
// - Etat de chaque carte bien differencie :
//     completed : fond dore + etoiles visibles
//     current   : fond orange + glow pulsant + mascot flottant
//     locked    : silhouette grise + cadenas
// - Badge D1/D2/D3 dans le coin superieur
// - Mini label "Partie X / Y" dans le coin inferieur pour situer
//   le tour dans la distance (tient compte de tablesPerDistance)
// =============================================================

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:trialgo/core/design_system/tokens/colors.dart';
import 'package:trialgo/core/design_system/tokens/elevation.dart';
import 'package:trialgo/core/design_system/tokens/motion.dart';
import 'package:trialgo/core/design_system/tokens/radius.dart';
import 'package:trialgo/core/design_system/tokens/spacing.dart';
import 'package:trialgo/core/design_system/tokens/typography.dart';
import 'package:trialgo/domain/usecases/generate_logical_nodes_usecase.dart';
import 'package:trialgo/presentation/providers/graph_provider.dart';
import 'package:trialgo/presentation/providers/profile_provider.dart';
import 'package:trialgo/presentation/widgets/core/page_scaffold.dart';
import 'package:trialgo/presentation/wireframes/t_game_page.dart';
import 'package:trialgo/presentation/wireframes/t_locale.dart';
import 'package:trialgo/presentation/wireframes/t_mock_data.dart';


// =============================================================
// MODELE INTERNE : entree de la serpentine
// =============================================================

enum _NodeKind { zoneBanner, level }

class _PathNode {
  final _NodeKind kind;
  final int levelNumber;
  final int distance;
  final int indexInDistance;   // 1-based dans la zone (Partie X / Y)
  final int totalInDistance;   // nombre total de niveaux dans cette zone
  final bool completed;
  final bool current;
  final bool locked;
  final int stars;
  final String zoneLabel;
  final Color zoneColor;
  // URL de l'image representative de la partie (receptrice du 1er trio
  // de la table). Permet d'afficher un visuel dans la carte de niveau.
  // Null si on ne peut pas le resoudre (pool pas pret, table vide).
  final String? imageUrl;

  const _PathNode.zone({required this.zoneLabel, required this.zoneColor})
      : kind = _NodeKind.zoneBanner,
        levelNumber = 0,
        distance = 0,
        indexInDistance = 0,
        totalInDistance = 0,
        completed = false,
        current = false,
        locked = false,
        stars = 0,
        imageUrl = null;

  const _PathNode.level({
    required this.levelNumber,
    required this.distance,
    required this.indexInDistance,
    required this.totalInDistance,
    required this.completed,
    required this.current,
    required this.locked,
    required this.stars,
    required this.zoneColor,
    this.imageUrl,
  })  : kind = _NodeKind.level,
        zoneLabel = '';
}


// =============================================================
// COULEURS DE ZONE (pastel soft, kid-friendly)
// =============================================================
// D1-D3 : tonalites douces (vert menthe, peche, lilas) pour debut
// de progression. D4-D5 : tonalites plus intenses (corail, indigo)
// pour signaler les zones avancees / experts. Evite le rouge sature
// pour ne pas signaler "danger" a un enfant.
const Color _zoneColorD1 = Color(0xFF7EE7C1);
const Color _zoneColorD2 = Color(0xFFFFB87C);
const Color _zoneColorD3 = Color(0xFFA9A3E5);
const Color _zoneColorD4 = Color(0xFFFF8F87);
const Color _zoneColorD5 = Color(0xFF7AB6FF);


// =============================================================
// WIDGET : TLevelMapPage
// =============================================================

class TLevelMapPage extends ConsumerStatefulWidget {
  const TLevelMapPage({super.key});

  @override
  ConsumerState<TLevelMapPage> createState() => _TLevelMapPageState();
}

class _TLevelMapPageState extends ConsumerState<TLevelMapPage>
    with SingleTickerProviderStateMixin {

  final _scroll = ScrollController();

  /// Pulse du niveau courant (boucle infinie 1.5s reverse).
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToCurrent());
  }

  @override
  void dispose() {
    _scroll.dispose();
    _pulse.dispose();
    super.dispose();
  }

  /// Defile doucement vers le niveau courant.
  void _scrollToCurrent() {
    if (!_scroll.hasClients) return;
    final profile = ref.read(profileProvider);
    // ~170px par carte (y compris connecteur) + ~80px par banniere.
    final targetOffset =
        (profile.level - 1) * 170.0 + 80.0 - 200.0;
    _scroll.animateTo(
      targetOffset.clamp(0.0, _scroll.position.maxScrollExtent),
      duration: const Duration(milliseconds: 600),
      curve: TCurve.standard,
    );
  }

  // =============================================================
  // GENERATION DU CHEMIN
  // =============================================================

  List<_PathNode> _buildPath(
    List<int> tablesPerDistance,
    int currentLevel,
    String Function(String) tr,
    LogicalNodesPool pool,
  ) {
    final result = <_PathNode>[];
    int levelCounter = 1;

    for (int k = 1; k <= 5; k++) {
      final nbTables = tablesPerDistance[k - 1];
      if (nbTables == 0) continue;

      final zoneColor = _zoneColorForDistance(k);

      // Banniere de debut de zone.
      result.add(_PathNode.zone(
        zoneLabel: _zoneLabelFor(k, tr),
        zoneColor: zoneColor,
      ));

      // Niveaux de cette zone avec info "Partie X / Y".
      for (int i = 0; i < nbTables; i++) {
        final lvl = levelCounter;
        final completed = lvl < currentLevel;
        final current = lvl == currentLevel;
        final locked = lvl > currentLevel;
        final stars = completed ? 2 : 0;

        // Image representative : receptrice (cardC) du 1er trio de la
        // table. On utilise la derniere carte de la chaine car c'est
        // celle qui identifie le mieux le "theme" de la table pour le
        // joueur. Null-safe : table vide -> imageUrl = null -> fallback.
        String? imageUrl;
        final table = pool.table(distance: k, tableIndex: i);
        if (table.isNotEmpty) {
          imageUrl = table.first.cardC.imageUrl;
        }

        result.add(_PathNode.level(
          levelNumber: lvl,
          distance: k,
          indexInDistance: i + 1,
          totalInDistance: nbTables,
          completed: completed,
          current: current,
          locked: locked,
          stars: stars,
          zoneColor: zoneColor,
          imageUrl: imageUrl,
        ));
        levelCounter++;
      }
    }

    return result;
  }

  Color _zoneColorForDistance(int k) {
    switch (k) {
      case 1:
        return _zoneColorD1;
      case 2:
        return _zoneColorD2;
      case 3:
        return _zoneColorD3;
      case 4:
        return _zoneColorD4;
      case 5:
        return _zoneColorD5;
      default:
        return _zoneColorD1;
    }
  }

  String _zoneLabelFor(int k, String Function(String) tr) {
    switch (k) {
      case 1:
        return tr('levelmap.zone_d1');
      case 2:
        return tr('levelmap.zone_d2');
      case 3:
        return tr('levelmap.zone_d3');
      case 4:
        return tr('levelmap.zone_d4');
      case 5:
        return tr('levelmap.zone_d5');
      default:
        return 'ZONE';
    }
  }

  @override
  Widget build(BuildContext context) {
    final tr = TLocale.of(context);
    final profile = ref.watch(profileProvider);
    final pool = ref.watch(graphSyncServiceProvider).logicalNodes;

    if (pool == null) {
      return PageScaffold(
        title: tr('levelmap.title'),
        child: const SizedBox.shrink(),
      );
    }

    final tablesPerDistance = [
      pool.numberOfTables(1),
      pool.numberOfTables(2),
      pool.numberOfTables(3),
      pool.numberOfTables(4),
      pool.numberOfTables(5),
    ];
    final path = _buildPath(tablesPerDistance, profile.level, tr, pool);
    final levelsOnly = path.where((n) => n.kind == _NodeKind.level).toList();
    final completedCount = levelsOnly.where((n) => n.completed).length;

    return PageScaffold(
      title: tr('levelmap.title'),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: TSpacing.md),
          child: Center(child: _buildProgressBadge(
            completed: completedCount,
            total: levelsOnly.length,
          )),
        ),
      ],
      child: ListView.builder(
        controller: _scroll,
        padding: const EdgeInsets.only(
          top: TSpacing.md,
          bottom: TSpacing.huge,
        ),
        itemCount: path.length,
        itemBuilder: (context, index) {
          final node = path[index];
          if (node.kind == _NodeKind.zoneBanner) {
            return _buildZoneBanner(node);
          }
          // Alternance gauche/droite + dernier node = pas de connecteur apres.
          final levelIndexInPath = path
              .sublist(0, index)
              .where((n) => n.kind == _NodeKind.level)
              .length;
          final alignmentX = levelIndexInPath.isEven ? -0.55 : 0.55;
          final isLastNode = index == path.length - 1;
          return Column(
            children: [
              _buildLevelNodeRow(node, alignmentX, levelIndexInPath),
              // Connecteur vertical pointille entre les cartes
              // (ne pas afficher apres la toute derniere carte).
              if (!isLastNode) _buildConnector(node.zoneColor),
            ],
          );
        },
      ),
    );
  }

  Widget _buildProgressBadge({required int completed, required int total}) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: TSpacing.sm,
        vertical: TSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: Color.fromARGB(
          0x33,
          TColors.primaryVariant.r.round(),
          TColors.primaryVariant.g.round(),
          TColors.primaryVariant.b.round(),
        ),
        borderRadius: const BorderRadius.all(Radius.circular(TRadius.full)),
        border: Border.all(
          color: TColors.primaryVariant.withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.emoji_events_rounded,
              color: TColors.primaryVariant, size: 14),
          const SizedBox(width: TSpacing.xs),
          Text(
            '$completed/$total',
            style: TTypography.numericSm(color: TColors.primaryVariant),
          ),
        ],
      ),
    );
  }

  // =============================================================
  // WIDGET : banniere de zone
  // =============================================================

  Widget _buildZoneBanner(_PathNode node) {
    final colors = TColors.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: TSpacing.lg,
        vertical: TSpacing.xl,
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 1,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.transparent, node.zoneColor],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: TSpacing.md),
            child: Column(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color.fromARGB(
                      0x40,
                      node.zoneColor.r.round(),
                      node.zoneColor.g.round(),
                      node.zoneColor.b.round(),
                    ),
                    border: Border.all(color: node.zoneColor, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: node.zoneColor.withValues(alpha: 0.3),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                  child: Icon(Icons.map_outlined,
                      size: 18, color: node.zoneColor),
                ),
                const SizedBox(height: TSpacing.xs),
                Text(
                  node.zoneLabel,
                  style: TTypography.labelSm(color: colors.textSecondary),
                ),
              ],
            ),
          ),
          Expanded(
            child: Container(
              height: 1,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [node.zoneColor, Colors.transparent],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // =============================================================
  // CONNECTEUR VERTICAL ENTRE LES CARTES
  // =============================================================

  /// Ligne pointillee verticale entre deux cartes, couleur de la zone.
  /// CustomPaint pour dessiner des dots proprement.
  Widget _buildConnector(Color zoneColor) {
    return SizedBox(
      height: 28,
      child: CustomPaint(
        size: const Size.fromHeight(28),
        painter: _DottedConnectorPainter(color: zoneColor),
      ),
    );
  }

  // =============================================================
  // ROW D'UN NIVEAU AVEC ALIGNEMENT SERPENTIN
  // =============================================================

  Widget _buildLevelNodeRow(
    _PathNode node,
    double alignmentX,
    int indexInPath,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: TSpacing.xs),
      child: Align(
        alignment: Alignment(alignmentX, 0),
        child: _buildTradingCard(node, indexInPath),
      ),
    );
  }

  // =============================================================
  // LA TRADING CARD ELLE-MEME
  // =============================================================

  Widget _buildTradingCard(_PathNode node, int indexInPath) {
    // Inclinaison stable pseudo-aleatoire : le meme niveau aura
    // toujours la meme inclinaison entre les builds. Amplitude
    // ~-5° a +5° (en radians : -0.09 a +0.09).
    final tiltRad = ((indexInPath * 17) % 11 - 5) * 0.018;

    return GestureDetector(
      onTap: () => _handleLevelTap(node),
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        // Conteneur plus grand pour accueillir mascotte et ombre
        // debordante sans clip.
        width: 140,
        height: 170,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            // --- Etoiles au-dessus (completed) ---
            if (node.completed)
              Positioned(
                top: 0,
                child: _buildStars(node.stars),
              ),

            // --- La carte inclinee ---
            Positioned(
              top: 16,
              child: AnimatedBuilder(
                animation: _pulse,
                builder: (context, child) {
                  final pulseScale = node.current
                      ? 1.0 + 0.04 * _pulse.value
                      : 1.0;
                  return Transform.rotate(
                    angle: tiltRad,
                    child: Transform.scale(
                      scale: pulseScale,
                      child: child,
                    ),
                  );
                },
                child: _buildCardContent(node),
              ),
            ),

            // --- Mascot sur niveau courant ---
            if (node.current)
              Positioned(
                top: -4,
                right: -8,
                child: Image.asset(
                  MockData.mascotDuo,
                  width: 54,
                  height: 54,
                  fit: BoxFit.contain,
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Contenu interne de la carte. STRUCTURE EN 3 BANDES :
  ///   - Top strip : badge distance (D1..D5) + couleur de zone
  ///   - Image zone : visuel receptrice (ou lock/verrou si locked)
  ///   - Bottom strip : numero de niveau + "Partie X/Y"
  /// La carte respecte les conventions trading-card (double bordure
  /// gradient + contenu masque en arrondi) tout en mettant en avant
  /// une VRAIE image du jeu plutot qu'un simple numero.
  Widget _buildCardContent(_PathNode node) {
    final colors = TColors.of(context);

    // Couleur du strip/badge pour contraste selon l'etat :
    //   - current / completed : fond zoneColor pleine intensite
    //   - locked              : gris de surface (sans spoiler l'image)
    final stripColor = node.locked
        ? colors.bgRaised
        : node.zoneColor.withValues(alpha: 0.9);
    final stripTextColor = node.locked ? colors.textTertiary : Colors.white;

    // Glow autour de la carte : fort sur current (doit attirer l'oeil),
    // doux sur completed (victoire passee), tres subtil sur locked.
    final List<BoxShadow> outerShadow;
    if (node.current) {
      outerShadow = TElevation.glowPrimary;
    } else if (node.completed) {
      outerShadow = TElevation.glowGold;
    } else {
      outerShadow = TElevation.subtle;
    }

    return Container(
      // Ombre de fond pour la sensation "posee sur la table".
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.all(Radius.circular(TRadius.lg)),
        boxShadow: outerShadow,
      ),
      child: Container(
        // Couche externe : gradient de bordure (effet trading card).
        padding: const EdgeInsets.all(2.5),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              node.zoneColor.withValues(alpha: 0.85),
              node.zoneColor.withValues(alpha: 0.45),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: const BorderRadius.all(Radius.circular(TRadius.lg)),
        ),
        child: ClipRRect(
          // ClipRRect masque l'image au coin arrondi interieur.
          borderRadius:
              const BorderRadius.all(Radius.circular(TRadius.md)),
          child: Container(
            width: 108,
            height: 138,
            color: colors.surface,
            child: Column(
              children: [
                // --- Bande superieure : distance ---
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    vertical: 4,
                    horizontal: 6,
                  ),
                  color: stripColor,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'D${node.distance}',
                        style: TTypography.labelSm(color: stripTextColor)
                            .copyWith(fontWeight: FontWeight.w800),
                      ),
                      if (node.current)
                        const Icon(Icons.play_arrow_rounded,
                            color: Colors.white, size: 14)
                      else if (node.completed)
                        const Icon(Icons.check_rounded,
                            color: Colors.white, size: 14)
                      else
                        Icon(Icons.lock_rounded,
                            color: colors.textTertiary, size: 12),
                    ],
                  ),
                ),

                // --- Image centrale (receptrice representative) ---
                Expanded(
                  child: _buildCardImage(node, colors),
                ),

                // --- Bande inferieure : numero + Partie X/Y ---
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    vertical: 4,
                    horizontal: 6,
                  ),
                  decoration: BoxDecoration(
                    color: stripColor,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'N${node.levelNumber}',
                        style: TTypography.labelSm(color: stripTextColor)
                            .copyWith(fontWeight: FontWeight.w800),
                      ),
                      Text(
                        '${node.indexInDistance}/${node.totalInDistance}',
                        style: TTypography.labelSm(color: stripTextColor),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Zone image de la carte. Gere 3 cas :
  ///   - current/completed avec imageUrl : image reseau cachee + overlay
  ///     de la couleur de zone pour harmoniser, glow doux sur current
  ///   - locked : silhouette grise + cadenas (pas de spoiler visuel)
  ///   - sans imageUrl (table vide / hors ligne) : fallback icone
  Widget _buildCardImage(_PathNode node, TSurfaceColors colors) {
    if (node.locked) {
      // Silhouette verrouillee : on ne spoil pas l'image de la prochaine
      // zone. Couleur neutre + cadenas central.
      return Container(
        color: colors.bgSunken,
        alignment: Alignment.center,
        child: Icon(Icons.lock_rounded,
            color: colors.textTertiary, size: 30),
      );
    }

    final url = node.imageUrl;
    if (url == null || url.isEmpty) {
      // Fallback : pas d'URL resolvable. On affiche le numero en grand
      // sur fond de zone pour que la carte reste informative.
      return Container(
        color: node.zoneColor.withValues(alpha: 0.25),
        alignment: Alignment.center,
        child: Text(
          '${node.levelNumber}',
          style: TTypography.displaySm(color: colors.textPrimary),
        ),
      );
    }

    // Image reelle. On superpose un tint leger de la couleur de zone
    // sur completed pour signaler "deja jouee" sans l'obscurcir, et
    // rien sur current (image pleinement visible pour accrocher).
    return Stack(
      fit: StackFit.expand,
      children: [
        CachedNetworkImage(
          imageUrl: url,
          fit: BoxFit.cover,
          placeholder: (_, _) => Container(
            color: colors.bgRaised,
            alignment: Alignment.center,
            child: SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: node.zoneColor,
              ),
            ),
          ),
          errorWidget: (_, _, _) => Container(
            color: colors.bgRaised,
            alignment: Alignment.center,
            child: Icon(Icons.image_outlined,
                color: colors.textTertiary, size: 24),
          ),
        ),
        if (node.completed)
          // Tint dore tres subtil pour marquer "deja fait", mais image
          // reste lisible.
          Container(
            color: TColors.primaryVariant.withValues(alpha: 0.15),
          ),
        if (node.current)
          // Glow discret haut -> bas pour attirer l'oeil sur le niveau
          // courant sans masquer l'image (gradient top->transparent).
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.center,
                colors: [
                  TColors.primary.withValues(alpha: 0.25),
                  Colors.transparent,
                ],
              ),
            ),
          ),
      ],
    );
  }

  /// Row de 3 etoiles (pleines selon [filled]) avec leger glow sur
  /// les etoiles pleines.
  Widget _buildStars(int filled) {
    final colors = TColors.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (i) {
        final isFilled = i < filled;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 1),
          child: Icon(
            isFilled ? Icons.star_rounded : Icons.star_outline_rounded,
            size: 16,
            color: isFilled
                ? TColors.primaryVariant
                : colors.borderStrong,
            shadows: isFilled
                ? [
                    BoxShadow(
                      color: TColors.primaryVariant.withValues(alpha: 0.5),
                      blurRadius: 6,
                    ),
                  ]
                : null,
          ),
        );
      }),
    );
  }

  // =============================================================
  // NAVIGATION : tap sur niveau
  // =============================================================

  void _handleLevelTap(_PathNode node) {
    if (node.kind != _NodeKind.level) return;

    if (node.locked) {
      final tr = TLocale.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            tr('levelmap.unlock_hint')
                .replaceAll('{n}', '${node.levelNumber - 1}'),
          ),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TGamePage(level: node.levelNumber),
      ),
    );
  }
}


// =============================================================
// PAINTER : ligne pointillee verticale (connecteur inter-cartes)
// =============================================================

class _DottedConnectorPainter extends CustomPainter {
  final Color color;

  _DottedConnectorPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.5)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    // 4 dots verticalement centres.
    const dotCount = 4;
    final cx = size.width / 2;
    final spacing = size.height / (dotCount + 1);
    for (int i = 1; i <= dotCount; i++) {
      canvas.drawCircle(Offset(cx, spacing * i), 2, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _DottedConnectorPainter old) =>
      old.color != color;
}

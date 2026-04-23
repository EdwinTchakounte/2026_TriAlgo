// =============================================================
// FICHIER : lib/presentation/wireframes/t_collective_mode_page.dart
// ROLE   : Mode collectif - assistant de partie physique
// COUCHE : Presentation > Wireframes
// =============================================================
//
// VRAIE LOGIQUE (d'apres cahier des charges) :
// --------------------------------------------
// Le joueur (ou un groupe de joueurs) joue AVEC LES CARTES PHYSIQUES
// de sa boite TRIALGO. L'app sert d'assistant de vérification :
//
//   1. Au debut, l'utilisateur specifie le NOMBRE DE TOURS a jouer
//      (ex: 5, 10, 15 rounds)
//   2. A chaque tour :
//        - Il pose 3 cartes physiques sur la table (le "trio")
//        - Il les SCANNE (3 QR codes) OU saisit le numero du noeud
//        - L'app verifie si le trio est valide (existe dans le
//          LogicalNodesPool en memoire)
//        - Feedback ✓ ou ✗ + possibilite de passer au tour suivant
//   3. A la fin : recap "X bonnes reponses sur N tours"
//
// AUCUNE SESSION N'EST TRACKEE cote Supabase. C'est un verificateur
// pur, independant des stats solo. Tu peux jouer 100 tours sans
// que ton score "solo" soit impacte.
//
// VERIFICATION COTE CLIENT :
// --------------------------
// VerifyTrioCardsUseCase (deja existant) verifie contre le
// LogicalNodesPool en memoire (D1/D2/D3), sans appel reseau.
// =============================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:trialgo/core/design_system/tokens/colors.dart';
import 'package:trialgo/core/design_system/tokens/elevation.dart';
import 'package:trialgo/core/design_system/tokens/motion.dart';
import 'package:trialgo/core/design_system/tokens/radius.dart';
import 'package:trialgo/core/design_system/tokens/spacing.dart';
import 'package:trialgo/core/design_system/tokens/typography.dart';
import 'package:trialgo/data/services/audio_service.dart';
import 'package:trialgo/domain/entities/verify_trio_result.dart';
import 'package:trialgo/presentation/providers/audio_provider.dart';
import 'package:trialgo/presentation/providers/graph_provider.dart';
import 'package:trialgo/presentation/widgets/core/app_button.dart';
import 'package:trialgo/presentation/widgets/core/app_card.dart';
import 'package:trialgo/presentation/widgets/core/app_chip.dart';
import 'package:trialgo/presentation/widgets/core/app_text_field.dart';
import 'package:trialgo/presentation/widgets/core/page_scaffold.dart';
import 'package:trialgo/presentation/wireframes/t_qr_scanner_page.dart';


// =============================================================
// ENUMS + MODELE INTERNE
// =============================================================

/// Phase de la page : choix du nombre de tours, jeu en cours, recap.
enum _Phase { config, playing, done }

/// Resultat d'un tour (archive pour le recap).
class _RoundResult {
  final int round;
  final bool valid;
  final int? distance;
  final List<String>? cardLabels;

  const _RoundResult({
    required this.round,
    required this.valid,
    this.distance,
    this.cardLabels,
  });
}


// =============================================================
// WIDGET : TCollectiveModePage
// =============================================================

class TCollectiveModePage extends ConsumerStatefulWidget {
  const TCollectiveModePage({super.key});

  @override
  ConsumerState<TCollectiveModePage> createState() =>
      _TCollectiveModePageState();
}

class _TCollectiveModePageState extends ConsumerState<TCollectiveModePage> {

  // ---------------------------------------------------------------
  // ETAT GLOBAL
  // ---------------------------------------------------------------

  /// Phase courante de la page.
  _Phase _phase = _Phase.config;

  /// Nombre total de tours choisi au config.
  int _totalRounds = 5;

  /// Tour en cours (1-based).
  int _currentRound = 1;

  /// Nombre de bonnes reponses cumulees.
  int _correctCount = 0;

  /// Historique des tours (pour le recap final).
  final List<_RoundResult> _history = [];

  /// Resultat du tour courant (null si pas encore verifie).
  /// Tant que ce resultat est non-null, on affiche le feedback
  /// et on attend que l'utilisateur clique "Tour suivant".
  VerifyTrioResult? _pendingResult;

  /// Controller pour la saisie manuelle du numero de noeud.
  final _manualNodeController = TextEditingController();

  @override
  void dispose() {
    _manualNodeController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------
  // LOGIQUE DE FLOW
  // ---------------------------------------------------------------

  /// Passe au jeu avec le nombre de tours choisi.
  void _startGame() {
    HapticFeedback.mediumImpact();
    setState(() {
      _phase = _Phase.playing;
      _currentRound = 1;
      _correctCount = 0;
      _history.clear();
      _pendingResult = null;
    });
  }

  /// Lance le scan QR pour le tour courant.
  Future<void> _scanForRound() async {
    final uuids = await Navigator.of(context).push<List<String>>(
      MaterialPageRoute(builder: (_) => const TQrScannerPage()),
    );
    if (uuids == null || uuids.length != 3) return;

    // Verification cote client (pool logique en memoire).
    final result =
        ref.read(verifyTrioCardsProvider).verifyByCardIds(uuids);
    _applyResult(result);
  }

  /// Verifie par saisie manuelle du numero de noeud.
  void _verifyByNumber() {
    final raw = _manualNodeController.text.trim();
    final idx = int.tryParse(raw);
    if (idx == null) {
      _applyResult(VerifyTrioResult.invalid('Numero invalide'));
      return;
    }
    final result =
        ref.read(verifyTrioCardsProvider).verifyByNodeIndex(idx);
    _applyResult(result);
  }

  /// Applique un resultat de verification au tour courant.
  void _applyResult(VerifyTrioResult result) {
    final audio = ref.read(audioServiceProvider);
    if (result.valid) {
      HapticFeedback.heavyImpact();
      audio.playSfx(SoundEffect.correct);
    } else {
      HapticFeedback.mediumImpact();
      audio.playSfx(SoundEffect.wrong);
    }
    setState(() {
      _pendingResult = result;
    });
  }

  /// Valide le tour courant et passe au suivant (ou termine).
  void _nextRound() {
    HapticFeedback.lightImpact();
    // Archiver le resultat dans l'historique.
    final r = _pendingResult;
    if (r != null) {
      if (r.valid) _correctCount++;
      _history.add(_RoundResult(
        round: _currentRound,
        valid: r.valid,
        distance: r.distance,
        cardLabels: r.cardLabels,
      ));
    }

    setState(() {
      _manualNodeController.clear();
      _pendingResult = null;
      if (_currentRound >= _totalRounds) {
        // Fin de la partie : on bascule en phase recap.
        _phase = _Phase.done;
      } else {
        _currentRound++;
      }
    });
  }

  /// Permet de retenter le tour courant (efface le resultat pending).
  void _retryRound() {
    HapticFeedback.lightImpact();
    setState(() {
      _manualNodeController.clear();
      _pendingResult = null;
    });
  }

  /// Relance une nouvelle partie (reset tout).
  void _restart() {
    HapticFeedback.lightImpact();
    setState(() {
      _phase = _Phase.config;
      _currentRound = 1;
      _correctCount = 0;
      _history.clear();
      _pendingResult = null;
      _manualNodeController.clear();
    });
  }

  // ---------------------------------------------------------------
  // BUILD
  // ---------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return PageScaffold(
      title: 'Mode Collectif',
      // Bloque le back pendant une partie en cours pour eviter les
      // sorties accidentelles. Force le passage par "Abandonner"
      // en appuyant sur le bouton back du header reellement.
      showBack: true,
      child: switch (_phase) {
        _Phase.config => _buildConfig(),
        _Phase.playing => _buildPlaying(),
        _Phase.done => _buildDone(),
      },
    );
  }

  // =============================================================
  // PHASE 1 : CONFIG (choix du nombre de tours)
  // =============================================================

  Widget _buildConfig() {
    final colors = TColors.of(context);

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(
        horizontal: TSpacing.xxl,
        vertical: TSpacing.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: TSpacing.xl),

          // --- Icone hero ---
          Center(
            child: Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Color.fromARGB(
                  0x33,
                  TColors.success.r.round(),
                  TColors.success.g.round(),
                  TColors.success.b.round(),
                ),
                boxShadow: TElevation.glowSuccess,
              ),
              child: const Icon(
                Icons.groups_rounded,
                size: 48,
                color: TColors.success,
              ),
            ),
          ),
          const SizedBox(height: TSpacing.xl),

          // --- Titre + description ---
          Text(
            'Assistant de partie',
            textAlign: TextAlign.center,
            style: TTypography.headlineLg(color: colors.textPrimary),
          ),
          const SizedBox(height: TSpacing.sm),
          Text(
            "Joue avec tes cartes physiques TRIALGO.\n"
            "Scanne 3 cartes a chaque tour pour verifier\n"
            "si ton trio est valide.",
            textAlign: TextAlign.center,
            style: TTypography.bodyMd(color: colors.textSecondary),
          ),
          const SizedBox(height: TSpacing.xxl),

          // --- Choix du nombre de tours ---
          Text(
            'NOMBRE DE TOURS',
            textAlign: TextAlign.center,
            style: TTypography.labelSm(color: colors.textTertiary),
          ),
          const SizedBox(height: TSpacing.sm),
          Center(
            child: Text(
              '$_totalRounds',
              style: TTypography.displayLg(color: TColors.primary),
            ),
          ),
          const SizedBox(height: TSpacing.md),

          // --- Chips pour les presets courants ---
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: TSpacing.xs),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (final n in const [3, 5, 10, 15, 20]) ...[
                  AppChip(
                    label: '$n',
                    selected: _totalRounds == n,
                    onTap: () => setState(() => _totalRounds = n),
                  ),
                  const SizedBox(width: TSpacing.sm),
                ],
              ],
            ),
          ),
          const SizedBox(height: TSpacing.md),

          // --- Slider pour ajustement fin (1 a 30) ---
          Slider(
            value: _totalRounds.toDouble(),
            min: 1,
            max: 30,
            divisions: 29,
            label: '$_totalRounds',
            activeColor: TColors.primary,
            onChanged: (v) => setState(() => _totalRounds = v.round()),
          ),
          const SizedBox(height: TSpacing.xxl),

          // --- CTA ---
          AppButton.primary(
            label: 'COMMENCER LA PARTIE',
            trailingIcon: Icons.play_arrow_rounded,
            fullWidth: true,
            size: AppButtonSize.lg,
            onPressed: _startGame,
          ),
          const SizedBox(height: TSpacing.xxl),
        ],
      ),
    );
  }

  // =============================================================
  // PHASE 2 : PLAYING (tour en cours)
  // =============================================================

  Widget _buildPlaying() {
    final colors = TColors.of(context);
    final progress = _currentRound / _totalRounds;
    final hasResult = _pendingResult != null;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(
        horizontal: TSpacing.xxl,
        vertical: TSpacing.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // --- Compteur de tour + progress bar ---
          Row(
            children: [
              Expanded(
                child: Text(
                  'Tour $_currentRound / $_totalRounds',
                  style: TTypography.headlineMd(color: colors.textPrimary),
                ),
              ),
              _ScoreBadge(correct: _correctCount, total: _currentRound - (hasResult ? 0 : 1) - 1 + (hasResult ? 1 : 0)),
            ],
          ),
          const SizedBox(height: TSpacing.sm),
          ClipRRect(
            borderRadius: const BorderRadius.all(Radius.circular(4)),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: colors.surface,
              valueColor: const AlwaysStoppedAnimation(TColors.primary),
            ),
          ),
          const SizedBox(height: TSpacing.xl),

          // --- Zone de contenu : SI resultat -> feedback, SINON -> scan ---
          if (hasResult)
            _buildRoundResultBlock(_pendingResult!)
          else
            _buildRoundActionBlock(),

          const SizedBox(height: TSpacing.xl),
        ],
      ),
    );
  }

  /// Bloc d'action : scan ou saisie manuelle (avant verification).
  Widget _buildRoundActionBlock() {
    final colors = TColors.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // --- 3 slots d'attente ---
        AppCard.glass(
          padding: const EdgeInsets.all(TSpacing.lg),
          child: Column(
            children: [
              Text(
                'Pose 3 cartes et scanne-les',
                textAlign: TextAlign.center,
                style: TTypography.bodyMd(color: colors.textSecondary),
              ),
              const SizedBox(height: TSpacing.md),
              Row(
                children: List.generate(3, (i) {
                  return Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(right: i < 2 ? TSpacing.sm : 0),
                      child: _buildEmptySlot(i + 1),
                    ),
                  );
                }),
              ),
            ],
          ),
        ),
        const SizedBox(height: TSpacing.xl),

        // --- CTA principal : SCANNER ---
        AppButton.primary(
          label: 'SCANNER 3 CARTES',
          icon: Icons.qr_code_scanner_rounded,
          fullWidth: true,
          size: AppButtonSize.lg,
          onPressed: _scanForRound,
        ),
        const SizedBox(height: TSpacing.md),

        // --- Separateur "ou saisir numero" ---
        Row(
          children: [
            Expanded(child: Divider(color: colors.borderSubtle)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: TSpacing.md),
              child: Text(
                'OU NUMERO DE NOEUD',
                style: TTypography.labelSm(color: colors.textTertiary),
              ),
            ),
            Expanded(child: Divider(color: colors.borderSubtle)),
          ],
        ),
        const SizedBox(height: TSpacing.md),

        // --- Saisie numero + verif ---
        Row(
          children: [
            Expanded(
              child: AppTextField(
                controller: _manualNodeController,
                hint: 'Ex: 12',
                prefixIcon: Icons.numbers_rounded,
                keyboardType: TextInputType.number,
              ),
            ),
            const SizedBox(width: TSpacing.sm),
            AppButton.secondary(
              label: 'OK',
              onPressed: _verifyByNumber,
            ),
          ],
        ),
      ],
    );
  }

  /// Bloc de feedback apres verification (✓ ou ✗ + CTA tour suivant).
  Widget _buildRoundResultBlock(VerifyTrioResult result) {
    final colors = TColors.of(context);
    final isLastRound = _currentRound >= _totalRounds;
    final tone = result.valid ? TColors.success : TColors.error;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // --- Banniere resultat ---
        Container(
          padding: const EdgeInsets.all(TSpacing.xl),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                tone.withValues(alpha: 0.25),
                tone.withValues(alpha: 0.08),
              ],
            ),
            borderRadius: TRadius.xlAll,
            border: Border.all(color: tone.withValues(alpha: 0.5), width: 2),
            boxShadow: result.valid
                ? TElevation.glowSuccess
                : TElevation.glowError,
          ),
          child: Column(
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: tone,
                  boxShadow: [
                    BoxShadow(
                      color: tone.withValues(alpha: 0.4),
                      blurRadius: 20,
                    ),
                  ],
                ),
                child: Icon(
                  result.valid ? Icons.check_rounded : Icons.close_rounded,
                  size: 40,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: TSpacing.md),
              Text(
                result.valid
                    ? 'Trio D${result.distance} valide !'
                    : 'Trio invalide',
                textAlign: TextAlign.center,
                style: TTypography.headlineMd(color: colors.textPrimary),
              ),
              if (result.valid && result.cardLabels != null) ...[
                const SizedBox(height: TSpacing.sm),
                Text(
                  result.cardLabels!.join(' · '),
                  textAlign: TextAlign.center,
                  style: TTypography.bodyMd(color: colors.textSecondary),
                ),
              ] else if (!result.valid && result.errorMessage != null) ...[
                const SizedBox(height: TSpacing.sm),
                Text(
                  result.errorMessage!,
                  textAlign: TextAlign.center,
                  style: TTypography.bodyMd(color: colors.textSecondary),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: TSpacing.xl),

        // --- CTA principal : tour suivant ou terminer ---
        AppButton.primary(
          label: isLastRound ? 'TERMINER LA PARTIE' : 'TOUR SUIVANT',
          trailingIcon: isLastRound
              ? Icons.emoji_events_rounded
              : Icons.arrow_forward_rounded,
          fullWidth: true,
          size: AppButtonSize.lg,
          onPressed: _nextRound,
        ),
        const SizedBox(height: TSpacing.sm),

        // --- Recommencer ce tour (si erreur, 2e chance) ---
        AppButton.ghost(
          label: 'Recommencer ce tour',
          icon: Icons.refresh_rounded,
          fullWidth: true,
          onPressed: _retryRound,
        ),
      ],
    );
  }

  /// Slot vide avec numero (1, 2, 3) en gris.
  Widget _buildEmptySlot(int n) {
    final colors = TColors.of(context);
    return Container(
      height: 80,
      decoration: BoxDecoration(
        color: colors.bgSunken,
        borderRadius: TRadius.mdAll,
        border: Border.all(
          color: colors.borderDefault,
          style: BorderStyle.solid,
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        '#$n',
        style: TTypography.numericMd(color: colors.textTertiary),
      ),
    );
  }

  // =============================================================
  // PHASE 3 : DONE (recap)
  // =============================================================

  Widget _buildDone() {
    final colors = TColors.of(context);
    final accuracy = _totalRounds > 0
        ? (_correctCount / _totalRounds * 100).round()
        : 0;

    // Tonalite recap : vert si >=70%, orange si 40-70%, rouge si <40%.
    final Color tone;
    final String title;
    if (accuracy >= 70) {
      tone = TColors.success;
      title = 'Bravo !';
    } else if (accuracy >= 40) {
      tone = TColors.warning;
      title = 'Continue !';
    } else {
      tone = TColors.error;
      title = 'A retenter !';
    }

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(
        horizontal: TSpacing.xxl,
        vertical: TSpacing.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: TSpacing.xl),

          // --- Icone trophee ---
          Center(
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Color.fromARGB(
                  0x33, tone.r.round(), tone.g.round(), tone.b.round(),
                ),
                boxShadow: [
                  BoxShadow(
                    color: tone.withValues(alpha: 0.4),
                    blurRadius: 24,
                  ),
                ],
              ),
              child: Icon(
                Icons.emoji_events_rounded,
                size: 56,
                color: tone,
              ),
            ),
          ),
          const SizedBox(height: TSpacing.xl),

          Text(
            title,
            textAlign: TextAlign.center,
            style: TTypography.displaySm(color: tone),
          ),
          const SizedBox(height: TSpacing.sm),
          Text(
            'Partie terminee',
            textAlign: TextAlign.center,
            style: TTypography.bodyMd(color: colors.textSecondary),
          ),
          const SizedBox(height: TSpacing.xxl),

          // --- Score final gros ---
          AppCard.elevated(
            child: Column(
              children: [
                Text(
                  'SCORE',
                  style: TTypography.labelSm(color: colors.textTertiary),
                ),
                const SizedBox(height: TSpacing.xs),
                TweenAnimationBuilder<int>(
                  tween: IntTween(begin: 0, end: _correctCount),
                  duration: const Duration(milliseconds: 1000),
                  curve: TCurve.standard,
                  builder: (context, v, _) => Text(
                    '$v / $_totalRounds',
                    style: TTypography.displayMd(color: TColors.primary),
                  ),
                ),
                const SizedBox(height: TSpacing.sm),
                Text(
                  'Precision : $accuracy%',
                  style: TTypography.bodyLg(color: colors.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(height: TSpacing.xl),

          // --- Historique des tours (simple liste) ---
          Text(
            'HISTORIQUE',
            style: TTypography.labelSm(color: colors.textTertiary),
          ),
          const SizedBox(height: TSpacing.sm),
          ..._history.map((r) => _buildHistoryRow(r)),

          const SizedBox(height: TSpacing.xxl),

          // --- CTA : rejouer / accueil ---
          AppButton.primary(
            label: 'REJOUER UNE PARTIE',
            icon: Icons.replay_rounded,
            fullWidth: true,
            size: AppButtonSize.lg,
            onPressed: _restart,
          ),
          const SizedBox(height: TSpacing.sm),
          AppButton.ghost(
            label: "Retour a l'accueil",
            icon: Icons.home_rounded,
            fullWidth: true,
            onPressed: () => Navigator.of(context).pop(),
          ),

          const SizedBox(height: TSpacing.xxl),
        ],
      ),
    );
  }

  Widget _buildHistoryRow(_RoundResult r) {
    final colors = TColors.of(context);
    final tone = r.valid ? TColors.success : TColors.error;
    return Padding(
      padding: const EdgeInsets.only(bottom: TSpacing.sm),
      child: AppCard.glass(
        padding: const EdgeInsets.all(TSpacing.md),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Color.fromARGB(
                  0x33, tone.r.round(), tone.g.round(), tone.b.round(),
                ),
              ),
              child: Icon(
                r.valid ? Icons.check_rounded : Icons.close_rounded,
                color: tone,
                size: 20,
              ),
            ),
            const SizedBox(width: TSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tour ${r.round}'
                    '${r.valid && r.distance != null ? " · D${r.distance}" : ""}',
                    style: TTypography.titleMd(color: colors.textPrimary),
                  ),
                  if (r.cardLabels != null && r.cardLabels!.isNotEmpty)
                    Text(
                      r.cardLabels!.join(' · '),
                      style: TTypography.labelMd(color: colors.textSecondary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}


// =============================================================
// WIDGET INTERNE : _ScoreBadge
// =============================================================

class _ScoreBadge extends StatelessWidget {
  final int correct;
  final int total;

  const _ScoreBadge({required this.correct, required this.total});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: TSpacing.sm,
        vertical: TSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: Color.fromARGB(
          0x33,
          TColors.success.r.round(),
          TColors.success.g.round(),
          TColors.success.b.round(),
        ),
        borderRadius: const BorderRadius.all(Radius.circular(TRadius.full)),
        border: Border.all(
          color: TColors.success.withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check_rounded, size: 14, color: TColors.success),
          const SizedBox(width: TSpacing.xxs),
          Text(
            '$correct',
            style: TTypography.numericSm(color: TColors.success),
          ),
        ],
      ),
    );
  }
}

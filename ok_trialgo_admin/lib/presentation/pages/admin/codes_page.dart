// =============================================================
// FICHIER : codes_page.dart
// ROLE    : Console de gestion des codes d'activation
// =============================================================
//
// CE QUE CET ECRAN COMBLE
// -----------------------
// Les cinq routes /api/admin/codes existaient depuis la premiere
// version du backend, sans aucune interface pour les appeler. Les
// codes se fabriquaient a la main, via /docs ou curl. C'est le
// genre de trou qui ne se voit pas tant qu'on n'a pas une boite a
// expedier.
//
// CE QU'ON PEUT Y FAIRE
// ---------------------
//   - lister les codes, filtres par jeu, page par page
//   - en creer un, seul ou par lot
//   - activer / desactiver
//   - reinitialiser (service apres-vente : telephone perdu)
//   - supprimer
//
// POURQUOI LA GENERATION PAR LOT
// ------------------------------
// Une boite = un code. Un tirage = quelques centaines de boites.
// Saisir les codes un par un n'est pas une option. Le backend, lui,
// ne cree qu'un code par appel : c'est donc l'ecran qui boucle, en
// affichant sa progression et en s'arretant sur la premiere erreur
// pour ne pas noyer l'administrateur sous des messages identiques.
// =============================================================

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../domain/entities/activation_code.dart';
import '../../../domain/entities/game.dart';
import '../../providers/codes_provider.dart';
import '../../providers/games_provider.dart';
import '../../widgets/empty_state.dart';

class CodesPage extends ConsumerWidget {
  const CodesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final etatAsync = ref.watch(codesProvider);
    final filtre = ref.watch(codesFilterProvider);
    final jeux = ref.watch(gamesProvider).valueOrNull ?? const <Game>[];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Codes d\'activation'),
        actions: [
          IconButton(
            tooltip: 'Recharger',
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.read(codesProvider.notifier).refresh(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: jeux.isEmpty
            // Sans jeu, un code n'a rien a rattacher : le serveur
            // repondrait 404. On desactive plutot que de laisser
            // l'administrateur decouvrir l'erreur apres coup.
            ? null
            : () => _ouvrirCreation(context, ref, jeux, filtre),
        icon: const Icon(Icons.add),
        label: const Text('Nouveaux codes'),
        backgroundColor: jeux.isEmpty ? AppColors.border : AppColors.brand,
      ),
      body: Column(
        children: [
          _BarreDeFiltre(jeux: jeux),
          Expanded(
            child: etatAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => _VueErreur(
                message: '$e',
                onRetry: () => ref.read(codesProvider.notifier).refresh(),
              ),
              data: (etat) {
                if (etat.codes.isEmpty) {
                  return const EmptyState(
                    icon: Icons.confirmation_number_outlined,
                    title: 'Aucun code',
                    description:
                        'Creez des codes pour que les joueurs puissent '
                        'debloquer ce jeu depuis leur boite.',
                  );
                }
                return _ListeDesCodes(etat: etat, jeux: jeux);
              },
            ),
          ),
        ],
      ),
    );
  }

  // -----------------------------------------------------------
  // CREATION
  // -----------------------------------------------------------

  Future<void> _ouvrirCreation(
    BuildContext context,
    WidgetRef ref,
    List<Game> jeux,
    String? filtreCourant,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      builder: (_) => _FeuilleDeCreation(
        jeux: jeux,
        gameIdInitial: filtreCourant,
      ),
    );
  }
}

// =============================================================
// BARRE DE FILTRE
// =============================================================

class _BarreDeFiltre extends ConsumerWidget {
  const _BarreDeFiltre({required this.jeux});

  final List<Game> jeux;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filtre = ref.watch(codesFilterProvider);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: DropdownButtonFormField<String?>(
        initialValue: filtre,
        isExpanded: true,
        decoration: const InputDecoration(
          labelText: 'Filtrer par jeu',
          prefixIcon: Icon(Icons.filter_list),
        ),
        items: [
          const DropdownMenuItem<String?>(
            value: null,
            child: Text('Tous les jeux'),
          ),
          for (final jeu in jeux)
            DropdownMenuItem<String?>(
              value: jeu.id,
              child: Text(jeu.name, overflow: TextOverflow.ellipsis),
            ),
        ],
        // Modifier le filtre suffit : codesProvider le surveille et
        // relance sa requete tout seul.
        onChanged: (valeur) =>
            ref.read(codesFilterProvider.notifier).state = valeur,
      ),
    );
  }
}

// =============================================================
// LISTE
// =============================================================

class _ListeDesCodes extends ConsumerWidget {
  const _ListeDesCodes({required this.etat, required this.jeux});

  final EtatDesCodes etat;
  final List<Game> jeux;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return RefreshIndicator(
      onRefresh: () => ref.read(codesProvider.notifier).refresh(),
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
        // +1 pour le pied de liste (compteur + bouton "charger la suite").
        itemCount: etat.codes.length + 1,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          if (index == etat.codes.length) {
            return _PiedDeListe(etat: etat);
          }
          return _CarteDeCode(
            code: etat.codes[index],
            nomDuJeu: _nomDuJeu(etat.codes[index].gameId),
          );
        },
      ),
    );
  }

  /// Retrouve le nom lisible d'un jeu depuis son UUID.
  ///
  /// Le point d'interrogation couvre le cas ou la liste des jeux
  /// n'est pas encore chargee : on prefere un libelle neutre a un
  /// UUID brut, illisible pour l'administrateur.
  String _nomDuJeu(String gameId) {
    for (final jeu in jeux) {
      if (jeu.id == gameId) return jeu.name;
    }
    return 'Jeu inconnu';
  }
}

class _PiedDeListe extends ConsumerWidget {
  const _PiedDeListe({required this.etat});

  final EtatDesCodes etat;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        children: [
          Text(
            '${etat.codes.length} code(s) affiche(s) sur ${etat.total}',
            style: AppTextStyles.caption(),
          ),
          if (etat.aUneSuite) ...[
            const SizedBox(height: 12),
            if (etat.chargeLaSuite)
              const CircularProgressIndicator()
            else
              OutlinedButton.icon(
                onPressed: () =>
                    ref.read(codesProvider.notifier).chargerLaSuite(),
                icon: const Icon(Icons.expand_more),
                label: const Text('Charger la suite'),
              ),
          ],
        ],
      ),
    );
  }
}

// =============================================================
// CARTE D'UN CODE
// =============================================================

class _CarteDeCode extends ConsumerWidget {
  const _CarteDeCode({required this.code, required this.nomDuJeu});

  final ActivationCode code;
  final String nomDuJeu;

  /// Couleur du badge de statut, par ordre de gravite decroissante.
  Color get _couleurDuStatut {
    if (!code.isActive) return AppColors.textSecondary;
    if (code.isBlocked) return AppColors.danger;
    if (code.estUtilise) return AppColors.info;
    return AppColors.success;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        code.code,
                        style: AppTextStyles.sectionTitle()
                            .copyWith(fontSize: 18, letterSpacing: 1.2),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    _Badge(
                      texte: code.statutLisible,
                      couleur: _couleurDuStatut,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(nomDuJeu, style: AppTextStyles.caption()),
                const SizedBox(height: 6),
                Text(
                  code.estUtilise
                      // Le compteur de changements d'appareil est
                      // l'information de service apres-vente la plus
                      // demandee : on la met en clair, pas dans un
                      // sous-menu.
                      ? 'Appareil : ${code.deviceChangesCount}/'
                          '${code.maxDeviceChanges} changement(s) '
                          '- ${code.changementsRestants} restant(s)'
                      : 'Jamais active - quota '
                          '${code.maxDeviceChanges} changement(s)',
                  style: AppTextStyles.caption(),
                ),
              ],
            ),
          ),
          _MenuDActions(code: code),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.texte, required this.couleur});

  final String texte;
  final Color couleur;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: couleur.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: couleur.withValues(alpha: 0.5)),
      ),
      child: Text(
        texte,
        style: AppTextStyles.caption().copyWith(color: couleur, fontSize: 11),
      ),
    );
  }
}

// =============================================================
// MENU D'ACTIONS
// =============================================================
// Les deux actions destructrices (reinitialiser, supprimer)
// passent par une confirmation. Les autres non : desactiver un
// code se defait d'un second appui.
// =============================================================

enum _Action { copier, basculer, reinitialiser, supprimer }

class _MenuDActions extends ConsumerWidget {
  const _MenuDActions({required this.code});

  final ActivationCode code;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopupMenuButton<_Action>(
      icon: const Icon(Icons.more_vert),
      color: AppColors.surface2,
      onSelected: (action) => _executer(context, ref, action),
      itemBuilder: (_) => [
        const PopupMenuItem(
          value: _Action.copier,
          child: ListTile(
            leading: Icon(Icons.copy),
            title: Text('Copier le code'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        PopupMenuItem(
          value: _Action.basculer,
          child: ListTile(
            leading: Icon(code.isActive ? Icons.block : Icons.check_circle),
            title: Text(code.isActive ? 'Desactiver' : 'Reactiver'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        // Reinitialiser n'a aucun sens sur un code jamais active :
        // il est deja dans l'etat cible.
        if (code.estUtilise || code.isBlocked)
          const PopupMenuItem(
            value: _Action.reinitialiser,
            child: ListTile(
              leading: Icon(Icons.restart_alt),
              title: Text('Reinitialiser (SAV)'),
              contentPadding: EdgeInsets.zero,
            ),
          ),
        const PopupMenuItem(
          value: _Action.supprimer,
          child: ListTile(
            leading: Icon(Icons.delete_outline, color: AppColors.danger),
            title: Text('Supprimer'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
      ],
    );
  }

  Future<void> _executer(
    BuildContext context,
    WidgetRef ref,
    _Action action,
  ) async {
    final notifier = ref.read(codesProvider.notifier);
    final messenger = ScaffoldMessenger.of(context);

    switch (action) {
      case _Action.copier:
        await Clipboard.setData(ClipboardData(text: code.code));
        messenger.showSnackBar(
          SnackBar(content: Text('Code ${code.code} copie')),
        );

      case _Action.basculer:
        final erreur = await notifier.basculerActivation(
          code: code.code,
          versActif: !code.isActive,
        );
        _annoncer(
          messenger,
          erreur,
          code.isActive ? 'Code desactive' : 'Code reactive',
        );

      case _Action.reinitialiser:
        final confirme = await _confirmer(
          context,
          titre: 'Reinitialiser ${code.code} ?',
          corps: 'Le code sera detache de son proprietaire et de son '
              'appareil, le compteur repart a zero et le blocage est '
              'leve.\n\nA n\'utiliser que pour un joueur ayant '
              'reellement perdu son telephone : le code redevient '
              'utilisable par quiconque le connait.',
          libelleConfirmation: 'Reinitialiser',
        );
        if (!confirme) return;
        _annoncer(
          messenger,
          await notifier.reinitialiser(code.code),
          'Code reinitialise',
        );

      case _Action.supprimer:
        final confirme = await _confirmer(
          context,
          titre: 'Supprimer ${code.code} ?',
          corps: 'Suppression definitive.\n\nElle echouera si un joueur '
              'est encore rattache a ce code : dans ce cas, '
              'reinitialisez-le d\'abord.',
          libelleConfirmation: 'Supprimer',
          destructif: true,
        );
        if (!confirme) return;
        _annoncer(
          messenger,
          await notifier.supprimer(code.code),
          'Code supprime',
        );
    }
  }

  /// Affiche le message du serveur en cas d'echec, sinon le succes.
  void _annoncer(
    ScaffoldMessengerState messenger,
    String? erreur,
    String messageDeSucces,
  ) {
    messenger.showSnackBar(
      SnackBar(
        content: Text(erreur ?? messageDeSucces),
        backgroundColor: erreur == null ? AppColors.success : AppColors.danger,
      ),
    );
  }
}

/// Boite de confirmation. Retourne false si l'utilisateur annule.
Future<bool> _confirmer(
  BuildContext context, {
  required String titre,
  required String corps,
  required String libelleConfirmation,
  bool destructif = false,
}) async {
  final reponse = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppColors.surface,
      title: Text(titre),
      content: Text(corps),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('Annuler'),
        ),
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          style: TextButton.styleFrom(
            foregroundColor:
                destructif ? AppColors.danger : AppColors.brand,
          ),
          child: Text(libelleConfirmation),
        ),
      ],
    ),
  );
  return reponse ?? false;
}

// =============================================================
// VUE D'ERREUR
// =============================================================

class _VueErreur extends StatelessWidget {
  const _VueErreur({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline,
                size: 48, color: AppColors.danger),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTextStyles.body(),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Reessayer'),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================
// FEUILLE DE CREATION
// =============================================================
// Genere un ou plusieurs codes d'un coup.
//
// POURQUOI Random.secure() ET PAS Random()
// ----------------------------------------
// Un code d'activation est un secret a valeur marchande : le
// deviner, c'est obtenir le jeu gratuitement. Random() est un
// generateur pseudo-aleatoire deterministe -- observer quelques
// codes d'un meme lot suffit a en prevoir d'autres. Random.secure()
// s'appuie sur le generateur cryptographique du systeme, ce qui
// ferme cette porte pour un cout nul a cette echelle.
//
// L'ALPHABET, ET CE QU'ON EN A RETIRE
// -----------------------------------
// Les codes sont imprimes sur du carton puis retapes a la main par
// des joueurs, parfois des enfants. On enleve donc tout ce qui se
// confond a la lecture : 0 et O, 1 et I et L, 5 et S, 8 et B. Ce
// qui reste se lit sans hesitation, meme mal imprime.
// =============================================================

/// Caracteres utilisables dans un code, sans ambiguite visuelle.
const String _alphabetDesCodes = 'ACDEFGHJKMNPQRTUVWXY2346789';

/// Longueur de la partie aleatoire d'un code.
///
/// 27 caracteres possibles sur 6 positions, soit environ 3.9 x 10^8
/// combinaisons : largement de quoi rendre une recherche a l'aveugle
/// inutile face a un stock de quelques milliers de codes.
const int _longueurAleatoire = 6;

class _FeuilleDeCreation extends ConsumerStatefulWidget {
  const _FeuilleDeCreation({required this.jeux, this.gameIdInitial});

  final List<Game> jeux;
  final String? gameIdInitial;

  @override
  ConsumerState<_FeuilleDeCreation> createState() =>
      _FeuilleDeCreationState();
}

class _FeuilleDeCreationState extends ConsumerState<_FeuilleDeCreation> {
  final _prefixeController = TextEditingController();
  final _quantiteController = TextEditingController(text: '1');
  final _quotaController = TextEditingController(text: '3');

  /// Jeu auquel rattacher les codes.
  String? _gameId;

  /// Progression pendant la generation d'un lot, null au repos.
  String? _progression;

  /// True pendant la generation : verrouille le formulaire.
  bool _enCours = false;

  @override
  void initState() {
    super.initState();
    // On preselectionne le jeu du filtre courant : dans neuf cas
    // sur dix, l'administrateur cree des codes pour le jeu qu'il
    // est justement en train de regarder.
    _gameId = widget.gameIdInitial ??
        (widget.jeux.isNotEmpty ? widget.jeux.first.id : null);
  }

  @override
  void dispose() {
    _prefixeController.dispose();
    _quantiteController.dispose();
    _quotaController.dispose();
    super.dispose();
  }

  // -----------------------------------------------------------
  // GENERATION
  // -----------------------------------------------------------

  /// Fabrique un code : prefixe optionnel + tirage aleatoire.
  String _fabriquerUnCode(String prefixe, Random tirage) {
    final corps = List.generate(
      _longueurAleatoire,
      (_) => _alphabetDesCodes[tirage.nextInt(_alphabetDesCodes.length)],
    ).join();

    return prefixe.isEmpty ? corps : '$prefixe-$corps';
  }

  Future<void> _generer() async {
    final gameId = _gameId;
    if (gameId == null) return;

    final quantite = int.tryParse(_quantiteController.text.trim()) ?? 0;
    final quota = int.tryParse(_quotaController.text.trim()) ?? 3;

    // Bornes alignees sur ce que le serveur accepte
    // (max_device_changes entre 1 et 20).
    if (quantite < 1 || quantite > 500) {
      _afficher('La quantite doit etre comprise entre 1 et 500.');
      return;
    }
    if (quota < 1 || quota > 20) {
      _afficher('Le quota doit etre compris entre 1 et 20.');
      return;
    }

    final prefixe = _prefixeController.text.trim().toUpperCase();
    final tirage = Random.secure();
    final notifier = ref.read(codesProvider.notifier);

    setState(() {
      _enCours = true;
      _progression = '0 / $quantite';
    });

    var crees = 0;
    for (var i = 0; i < quantite; i++) {
      final erreur = await notifier.creer(
        code: _fabriquerUnCode(prefixe, tirage),
        gameId: gameId,
        maxDeviceChanges: quota,
      );

      if (erreur != null) {
        // On s'arrete a la premiere erreur : enchainer produirait
        // le meme echec N fois. Les codes deja crees sont conserves,
        // d'ou le compte rendu partiel.
        if (!mounted) return;
        setState(() {
          _enCours = false;
          _progression = null;
        });
        _afficher('Arret apres $crees code(s) cree(s) : $erreur');
        return;
      }

      crees++;
      if (!mounted) return;
      setState(() => _progression = '$crees / $quantite');
    }

    if (!mounted) return;
    Navigator.of(context).pop();
    _afficher('$crees code(s) cree(s).', succes: true);
  }

  void _afficher(String message, {bool succes = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: succes ? AppColors.success : AppColors.danger,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      // viewInsets : remonte la feuille au-dessus du clavier.
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Nouveaux codes', style: AppTextStyles.sectionTitle()),
          const SizedBox(height: 4),
          Text(
            'Les codes sont tires au hasard, sans caracteres '
            'ambigus (ni 0/O ni 1/I).',
            style: AppTextStyles.caption(),
          ),
          const SizedBox(height: 16),

          DropdownButtonFormField<String>(
            initialValue: _gameId,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Jeu a debloquer',
              prefixIcon: Icon(Icons.videogame_asset),
            ),
            items: [
              for (final jeu in widget.jeux)
                DropdownMenuItem(
                  value: jeu.id,
                  child: Text(jeu.name, overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged:
                _enCours ? null : (v) => setState(() => _gameId = v),
          ),
          const SizedBox(height: 12),

          TextField(
            controller: _prefixeController,
            enabled: !_enCours,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(
              labelText: 'Prefixe (optionnel)',
              hintText: 'Ex : SAVANE',
              helperText: 'Aide a reconnaitre un lot d\'un coup d\'oeil.',
              prefixIcon: Icon(Icons.label_outline),
            ),
          ),
          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _quantiteController,
                  enabled: !_enCours,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Quantite',
                    helperText: '1 a 500',
                    prefixIcon: Icon(Icons.numbers),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _quotaController,
                  enabled: !_enCours,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Changements',
                    helperText: '1 a 20',
                    prefixIcon: Icon(Icons.phone_android),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          if (_progression != null) ...[
            Row(
              children: [
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 12),
                Text('Creation en cours : $_progression',
                    style: AppTextStyles.caption()),
              ],
            ),
            const SizedBox(height: 12),
          ],

          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: (_enCours || _gameId == null) ? null : _generer,
              icon: const Icon(Icons.add),
              label: const Text('Generer'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.brand,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

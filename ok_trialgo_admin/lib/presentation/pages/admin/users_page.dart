// =============================================================
// FICHIER : users_page.dart
// ROLE    : Console de gestion des comptes utilisateurs
// =============================================================
//
// CE QUE CET ECRAN COMBLE
// -----------------------
// Les quatre routes /api/admin/users existaient sans interface.
// Consequence concrete : promouvoir un second administrateur
// exigeait un appel curl. Si le premier compte administrateur
// devenait inaccessible, plus personne ne pouvait entrer.
//
// CE QU'ON PEUT Y FAIRE
// ---------------------
//   - lister les comptes, du plus recent au plus ancien
//   - promouvoir / retrograder un administrateur
//   - suspendre / reactiver un compte
//
// CE QU'ON NE PEUT PAS Y FAIRE, ET POURQUOI
// -----------------------------------------
// Ni changer une adresse de courriel, ni changer un mot de passe.
// Le serveur ne l'expose pas, et c'est deliberе : un administrateur
// capable de modifier l'adresse d'un compte pourrait ensuite y
// declencher une reinitialisation de mot de passe et s'en emparer.
//
// LES GARDE-FOUS RESTENT COTE SERVEUR
// -----------------------------------
// Le dernier administrateur actif ne peut ni se retrograder ni se
// suspendre. On ne reimplemente pas ces regles ici -- le client ne
// sait pas combien d'administrateurs actifs subsistent, et deux
// implementations de la meme regle divergent tot ou tard. On
// affiche la reponse du serveur telle quelle.
// =============================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../domain/entities/admin_user.dart';
import '../../providers/auth_provider.dart';
import '../../providers/users_provider.dart';
import '../../widgets/empty_state.dart';

class UsersPage extends ConsumerWidget {
  const UsersPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final etatAsync = ref.watch(usersProvider);

    // L'identifiant de l'administrateur connecte sert a marquer sa
    // propre ligne : sans repere visuel, il est facile de se
    // retrograder soi-meme par erreur.
    final moi = ref.watch(authProvider).profile?.id;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Comptes utilisateurs'),
        actions: [
          IconButton(
            tooltip: 'Recharger',
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.read(usersProvider.notifier).refresh(),
          ),
        ],
      ),
      body: etatAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _VueErreurComptes(
          message: '$e',
          onRetry: () => ref.read(usersProvider.notifier).refresh(),
        ),
        data: (etat) {
          if (etat.comptes.isEmpty) {
            return const EmptyState(
              icon: Icons.people_outline,
              title: 'Aucun compte',
              description: 'Aucun joueur ne s\'est encore inscrit.',
            );
          }

          return RefreshIndicator(
            onRefresh: () => ref.read(usersProvider.notifier).refresh(),
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              itemCount: etat.comptes.length + 1,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                if (index == etat.comptes.length) {
                  return _PiedDeListeComptes(etat: etat);
                }
                final compte = etat.comptes[index];
                return _CarteDeCompte(
                  compte: compte,
                  estMoi: compte.id == moi,
                );
              },
            ),
          );
        },
      ),
    );
  }
}

// =============================================================
// PIED DE LISTE
// =============================================================

class _PiedDeListeComptes extends ConsumerWidget {
  const _PiedDeListeComptes({required this.etat});

  final EtatDesComptes etat;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        children: [
          Text(
            '${etat.comptes.length} compte(s) affiche(s) sur ${etat.total}',
            style: AppTextStyles.caption(),
          ),
          if (etat.aUneSuite) ...[
            const SizedBox(height: 12),
            if (etat.chargeLaSuite)
              const CircularProgressIndicator()
            else
              OutlinedButton.icon(
                onPressed: () =>
                    ref.read(usersProvider.notifier).chargerLaSuite(),
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
// CARTE D'UN COMPTE
// =============================================================

class _CarteDeCompte extends ConsumerWidget {
  const _CarteDeCompte({required this.compte, required this.estMoi});

  final AdminUser compte;
  final bool estMoi;

  Color get _couleurDuStatut {
    if (!compte.isActive) return AppColors.danger;
    if (compte.isAdmin) return AppColors.brand;
    return AppColors.textSecondary;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          // La ligne de l'administrateur connecte est soulignee :
          // c'est la seule sur laquelle une fausse manoeuvre le
          // verrouille hors de sa propre console.
          color: estMoi ? AppColors.brand : AppColors.border,
          width: estMoi ? 1.5 : 1,
        ),
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
                        compte.email,
                        style: AppTextStyles.body(),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (estMoi) ...[
                      const SizedBox(width: 8),
                      _BadgeCompte(
                        texte: 'Vous',
                        couleur: AppColors.brand,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    _BadgeCompte(
                      texte: compte.statutLisible,
                      couleur: _couleurDuStatut,
                    ),
                    if (!compte.emailConfirme)
                      _BadgeCompte(
                        texte: 'Adresse non confirmee',
                        couleur: AppColors.warning,
                      ),
                  ],
                ),
              ],
            ),
          ),
          _MenuDeCompte(compte: compte),
        ],
      ),
    );
  }
}

class _BadgeCompte extends StatelessWidget {
  const _BadgeCompte({required this.texte, required this.couleur});

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

enum _ActionCompte { promotion, activation }

class _MenuDeCompte extends ConsumerWidget {
  const _MenuDeCompte({required this.compte});

  final AdminUser compte;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopupMenuButton<_ActionCompte>(
      icon: const Icon(Icons.more_vert),
      color: AppColors.surface2,
      onSelected: (action) => _executer(context, ref, action),
      itemBuilder: (_) => [
        PopupMenuItem(
          value: _ActionCompte.promotion,
          child: ListTile(
            leading: Icon(compte.isAdmin
                ? Icons.remove_moderator_outlined
                : Icons.admin_panel_settings_outlined),
            title: Text(compte.isAdmin
                ? 'Retirer les droits admin'
                : 'Promouvoir administrateur'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        PopupMenuItem(
          value: _ActionCompte.activation,
          child: ListTile(
            leading: Icon(
              compte.isActive ? Icons.block : Icons.check_circle_outline,
              color: compte.isActive ? AppColors.danger : null,
            ),
            title: Text(
                compte.isActive ? 'Suspendre le compte' : 'Reactiver'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
      ],
    );
  }

  Future<void> _executer(
    BuildContext context,
    WidgetRef ref,
    _ActionCompte action,
  ) async {
    final notifier = ref.read(usersProvider.notifier);
    final messenger = ScaffoldMessenger.of(context);

    switch (action) {
      case _ActionCompte.promotion:
        final confirme = await _confirmerCompte(
          context,
          titre: compte.isAdmin
              ? 'Retirer les droits de ${compte.email} ?'
              : 'Promouvoir ${compte.email} ?',
          corps: compte.isAdmin
              ? 'Ce compte perdra l\'acces au studio d\'administration.'
              : 'Ce compte pourra creer et modifier les jeux, les '
                  'cartes et les trios. Un courriel l\'en informera.',
          libelleConfirmation: compte.isAdmin ? 'Retirer' : 'Promouvoir',
          destructif: compte.isAdmin,
        );
        if (!confirme) return;
        _annoncerCompte(
          messenger,
          await notifier.basculerPromotion(compte.id),
          compte.isAdmin ? 'Droits retires' : 'Compte promu administrateur',
        );

      case _ActionCompte.activation:
        final confirme = await _confirmerCompte(
          context,
          titre: compte.isActive
              ? 'Suspendre ${compte.email} ?'
              : 'Reactiver ${compte.email} ?',
          corps: compte.isActive
              ? 'Le compte ne pourra plus se connecter. Sa progression '
                  'et ses scores sont conserves. Un courriel l\'en '
                  'informera.'
              : 'Le compte pourra de nouveau se connecter.',
          libelleConfirmation:
              compte.isActive ? 'Suspendre' : 'Reactiver',
          destructif: compte.isActive,
        );
        if (!confirme) return;
        _annoncerCompte(
          messenger,
          await notifier.basculerActivation(
            userId: compte.id,
            versActif: !compte.isActive,
          ),
          compte.isActive ? 'Compte suspendu' : 'Compte reactive',
        );
    }
  }

  /// Affiche le message du serveur en cas d'echec, sinon le succes.
  ///
  /// C'est par ce chemin que remontent les garde-fous du backend
  /// ("Vous ne pouvez pas vous demouvoir : aucun autre admin
  /// actif"), d'ou l'importance de ne pas les remplacer par un
  /// message generique.
  void _annoncerCompte(
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
Future<bool> _confirmerCompte(
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

class _VueErreurComptes extends StatelessWidget {
  const _VueErreurComptes({required this.message, required this.onRetry});

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

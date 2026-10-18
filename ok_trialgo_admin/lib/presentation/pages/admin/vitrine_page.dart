// =============================================================
// FICHIER : vitrine_page.dart
// ROLE    : Editer les textes et images de la page d'accueil
//           de mixalgo.com, puis les publier
// =============================================================
//
// CE QUE L'ADMINISTRATEUR FAIT ICI
// --------------------------------
// La vitrine a des textes par defaut, ecrits dans son HTML. Cet
// ecran permet d'en remplacer certains, et de choisir les images
// mises en avant, SANS redeployer le site : la vitrine lit ce
// document au chargement (GET /api/public/site/accueil).
//
// Organisation :
//   - colonne gauche  : les textes (hero + cinq sections)
//   - colonne droite  : la galerie d'images
//   - barre du haut   : indicateur "non publie" + bouton Publier
//
// Sur un telephone, les deux colonnes s'empilent : la galerie
// passe simplement sous les textes.
//
// RIEN NE PART SANS "PUBLIER"
// ---------------------------
// Toutes les saisies modifient un brouillon local (vitrineProvider).
// Quitter l'ecran sans publier les abandonne : c'est voulu, la
// vitrine est publique et une demi-modification ne doit jamais s'y
// retrouver par accident.
// =============================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mime/mime.dart';

import '../../../core/responsive/breakpoints.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/result.dart';
import '../../../domain/entities/game.dart';
import '../../../domain/entities/game_card.dart';
import '../../../domain/entities/site_content.dart';
import '../../providers/games_provider.dart';
import '../../providers/repositories_provider.dart';
import '../../providers/site_provider.dart';
import '../../widgets/guidance_banner.dart';

/// Adresse publique de la vitrine, affichee pour verification.
const String kUrlVitrine = 'https://mixalgo.com';

// Memes reglages que l'import de cartes (step2_cards_page) : une
// image de 2048 px en qualite 92 reste sous les 5 Mo acceptes par
// l'API, et le serveur la retaille de toute facon.
const int _kDimensionSource = 2048;
const int _kQualiteSource = 92;

class VitrinePage extends ConsumerWidget {
  const VitrinePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final etatAsync = ref.watch(vitrineProvider);
    final etat = etatAsync.valueOrNull;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Vitrine du site'),
        actions: [
          if (etat != null && etat.modifie)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Center(child: _PastilleNonPublie()),
            ),
          if (etat != null)
            Padding(
              padding: const EdgeInsets.only(right: 12, left: 4),
              child: _BoutonPublier(etat: etat),
            ),
        ],
      ),
      body: etatAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _VueErreur(
          message: '$e'.replaceFirst('Exception: ', ''),
          onRetry: () => ref.read(vitrineProvider.notifier).recharger(),
        ),
        data: (etat) => _Contenu(etat: etat),
      ),
    );
  }
}

// =============================================================
// _Contenu : une ou deux colonnes selon la largeur
// =============================================================
class _Contenu extends StatelessWidget {
  final EtatVitrine etat;
  const _Contenu({required this.etat});

  @override
  Widget build(BuildContext context) {
    final pad = Breakpoints.horizontalPadding(context);
    // La cle suit la version publiee : apres un rechargement, les
    // champs de saisie sont recrees a partir du nouveau document
    // au lieu de garder l'ancien texte dans leurs controleurs.
    final textes = _FormulaireTextes(
      key: ValueKey('textes-${etat.empreintePubliee}'),
      contenu: etat.brouillon,
    );
    final galerie = _Galerie(etat: etat);

    if (Breakpoints.of(context) != DeviceSize.expanded) {
      return ListView(
        padding: EdgeInsets.fromLTRB(pad, 16, pad, 32),
        children: [textes, const SizedBox(height: 24), galerie],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: ListView(
            padding: EdgeInsets.fromLTRB(pad, 16, 12, 32),
            children: [textes],
          ),
        ),
        Expanded(
          child: ListView(
            padding: EdgeInsets.fromLTRB(12, 16, pad, 32),
            children: [galerie],
          ),
        ),
      ],
    );
  }
}

// =============================================================
// _FormulaireTextes : hero + sections
// =============================================================
class _FormulaireTextes extends ConsumerWidget {
  final ContenuAccueil contenu;
  const _FormulaireTextes({super.key, required this.contenu});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(vitrineProvider.notifier);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const GuidanceBanner(
          icon: Icons.storefront_outlined,
          title: 'Ce que vous modifiez ici',
          description:
              'Les textes et images de la page d\'accueil de mixalgo.com. '
              'Un champ laissé vide garde le texte d\'origine du site. '
              'Rien n\'est visible en ligne avant d\'avoir cliqué sur « Publier ».',
        ),
        const SizedBox(height: 10),
        _LienSite(majLe: contenu.majLe),
        const SizedBox(height: 18),
        _Bloc(
          titre: 'En-tête de la page',
          sousTitre: 'Le premier écran que voit le visiteur.',
          enfants: [
            for (final champ in kChampsHero)
              _ChampSaisie(
                champ: champ,
                initial: contenu.hero[champ.cle] ?? '',
                onChanged: (v) => notifier.majHero(champ.cle, v),
              ),
          ],
        ),
        for (final section in kSections.entries) ...[
          const SizedBox(height: 14),
          _Bloc(
            titre: section.value,
            enfants: [
              for (final champ in kChampsSection)
                _ChampSaisie(
                  champ: champ,
                  initial: contenu.sections[section.key]?[champ.cle] ?? '',
                  onChanged: (v) =>
                      notifier.majSection(section.key, champ.cle, v),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

// Un panneau titre + champs, au style des cartes du studio.
class _Bloc extends StatelessWidget {
  final String titre;
  final String? sousTitre;
  final List<Widget> enfants;
  const _Bloc({required this.titre, this.sousTitre, required this.enfants});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(titre, style: AppTextStyles.sectionTitle()),
          if (sousTitre != null) ...[
            const SizedBox(height: 2),
            Text(sousTitre!, style: AppTextStyles.caption()),
          ],
          const SizedBox(height: 12),
          for (final e in enfants) ...[e, const SizedBox(height: 10)],
        ],
      ),
    );
  }
}

// =============================================================
// _ChampSaisie : un champ texte borne par la limite du contrat
// =============================================================
// StatefulWidget pour posseder son TextEditingController : le
// recreer a chaque reconstruction replacerait le curseur au debut
// a chaque frappe.
class _ChampSaisie extends StatefulWidget {
  final ChampTexte champ;
  final String initial;
  final ValueChanged<String> onChanged;
  const _ChampSaisie({
    required this.champ,
    required this.initial,
    required this.onChanged,
  });

  @override
  State<_ChampSaisie> createState() => _ChampSaisieState();
}

class _ChampSaisieState extends State<_ChampSaisie> {
  late final _ctrl = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.champ;
    return TextField(
      controller: _ctrl,
      onChanged: widget.onChanged,
      // maxLength affiche le compteur "12/120" ET bloque la saisie :
      // le serveur refuserait de toute facon au-dela (422).
      maxLength: c.max,
      maxLengthEnforcement: MaxLengthEnforcement.enforced,
      minLines: c.multiligne ? 2 : 1,
      maxLines: c.multiligne ? 6 : 1,
      decoration: InputDecoration(
        labelText: c.libelle,
        hintText: 'Vide = texte d\'origine du site',
      ),
    );
  }
}

// =============================================================
// _Galerie : images mises en avant
// =============================================================
class _Galerie extends ConsumerWidget {
  final EtatVitrine etat;
  const _Galerie({required this.etat});

  Future<void> _televerser(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final choisie = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: _kQualiteSource,
      maxWidth: _kDimensionSource.toDouble(),
      maxHeight: _kDimensionSource.toDouble(),
    );
    if (choisie == null) return;
    final octets = await choisie.readAsBytes();
    final erreur = await ref.read(vitrineProvider.notifier).televerser(
          octets: octets,
          nomFichier: choisie.name,
          // Le serveur verifie le vrai type par les magic bytes ; ce
          // type n'est qu'une indication pour le multipart.
          typeMime: lookupMimeType(choisie.name) ?? 'image/jpeg',
        );
    messenger.showSnackBar(SnackBar(
      content: Text(erreur ?? 'Image ajoutée à la galerie (non publiée).'),
    ));
  }

  Future<void> _ajouterDepuisUnJeu(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final notifier = ref.read(vitrineProvider.notifier);
    final cartes = await showModalBottomSheet<List<GameCard>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (_) => _FeuilleCartesDUnJeu(placesLibres: notifier.placesLibres),
    );
    if (cartes == null || cartes.isEmpty) return;
    final ajoutees = notifier.ajouterImages([
      for (final c in cartes) (url: c.imagePath, nom: c.label, code: c.label),
    ]);
    messenger.showSnackBar(SnackBar(
      content: Text(ajoutees < cartes.length
          ? '$ajoutees carte(s) ajoutée(s) : la galerie est limitée à $kGalerieMax images.'
          : '$ajoutees carte(s) ajoutée(s) à la galerie (non publiée).'),
    ));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final galerie = etat.brouillon.galerie;
    final pleine = galerie.length >= kGalerieMax;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text('Galerie', style: AppTextStyles.sectionTitle()),
            ),
            Text('${galerie.length} / $kGalerieMax',
                style: AppTextStyles.caption()),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'Les $kImagesDuHero premières images forment l\'éventail de cartes '
          'du haut de page. Toutes défilent ensuite dans le bandeau et la '
          'grille du deck. Galerie vide = images d\'origine du site.',
          style: AppTextStyles.caption(),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            ElevatedButton.icon(
              onPressed: pleine || etat.enTeleversement
                  ? null
                  : () => _televerser(context, ref),
              icon: etat.enTeleversement
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.upload_outlined),
              label: const Text('Téléverser une image'),
            ),
            OutlinedButton.icon(
              onPressed: pleine ? null : () => _ajouterDepuisUnJeu(context, ref),
              icon: const Icon(Icons.style_outlined),
              label: const Text('Ajouter depuis un jeu'),
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (galerie.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: Text(
              'Aucune image : la vitrine affiche ses cartes d\'origine.',
              style: AppTextStyles.caption(),
              textAlign: TextAlign.center,
            ),
          )
        else
          for (final (i, element) in galerie.indexed)
            _LigneGalerie(
              key: ValueKey(element.idLocal),
              element: element,
              rang: i,
              total: galerie.length,
            ),
      ],
    );
  }
}

// =============================================================
// _LigneGalerie : vignette + nom + code + actions
// =============================================================
class _LigneGalerie extends ConsumerStatefulWidget {
  final ElementGalerie element;
  final int rang;
  final int total;
  const _LigneGalerie({
    super.key,
    required this.element,
    required this.rang,
    required this.total,
  });

  @override
  ConsumerState<_LigneGalerie> createState() => _LigneGalerieState();
}

class _LigneGalerieState extends ConsumerState<_LigneGalerie> {
  late final _nom = TextEditingController(text: widget.element.nom);
  late final _code = TextEditingController(text: widget.element.code);

  @override
  void dispose() {
    _nom.dispose();
    _code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final notifier = ref.read(vitrineProvider.notifier);
    final id = widget.element.idLocal;
    final duHero = widget.rang < kImagesDuHero;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          // Les images de l'eventail du hero sont soulignees : leur
          // ordre a un effet visible en haut de page.
          color: duHero
              ? AppColors.brand.withValues(alpha: 0.6)
              : AppColors.border,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              _Apercu(url: widget.element.imageUrl),
              const SizedBox(height: 4),
              Text(
                duHero ? 'Hero ${widget.rang + 1}' : '#${widget.rang + 1}',
                style: AppTextStyles.caption().copyWith(
                  color: duHero ? AppColors.brand : null,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              children: [
                TextField(
                  controller: _nom,
                  maxLength: kNomMax,
                  onChanged: (v) => notifier.majElement(id, nom: v),
                  decoration: const InputDecoration(
                    labelText: 'Nom (facultatif)',
                    counterText: '',
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _code,
                  maxLength: kCodeMax,
                  onChanged: (v) => notifier.majElement(id, code: v),
                  decoration: const InputDecoration(
                    labelText: 'Code (facultatif)',
                    counterText: '',
                    isDense: true,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          Column(
            children: [
              IconButton(
                tooltip: 'Monter',
                visualDensity: VisualDensity.compact,
                onPressed: widget.rang == 0
                    ? null
                    : () => notifier.deplacerElement(id, -1),
                icon: const Icon(Icons.arrow_upward),
              ),
              IconButton(
                tooltip: 'Descendre',
                visualDensity: VisualDensity.compact,
                onPressed: widget.rang >= widget.total - 1
                    ? null
                    : () => notifier.deplacerElement(id, 1),
                icon: const Icon(Icons.arrow_downward),
              ),
              IconButton(
                tooltip: 'Retirer de la galerie',
                visualDensity: VisualDensity.compact,
                onPressed: () => notifier.supprimerElement(id),
                icon: const Icon(Icons.delete_outline, color: AppColors.danger),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// Vignette d'une image distante, avec repli si elle ne charge pas.
class _Apercu extends StatelessWidget {
  final String url;
  const _Apercu({required this.url});

  static const double largeur = 72;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: largeur,
        height: largeur * 1.25,
        color: AppColors.surface2,
        child: Image.network(
          url,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => const Icon(
            Icons.broken_image_outlined,
            color: AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

// =============================================================
// _FeuilleCartesDUnJeu : choisir des cartes existantes
// =============================================================
// Les illustrations sont deja en ligne, televersees dans les jeux :
// les reutiliser evite de televerser deux fois la meme image. La
// feuille liste d'abord les jeux, puis les cartes du jeu choisi,
// en multi-selection. Elle renvoie la liste des cartes cochees.
class _FeuilleCartesDUnJeu extends ConsumerStatefulWidget {
  final int placesLibres;
  const _FeuilleCartesDUnJeu({required this.placesLibres});

  @override
  ConsumerState<_FeuilleCartesDUnJeu> createState() =>
      _FeuilleCartesDUnJeuState();
}

class _FeuilleCartesDUnJeuState extends ConsumerState<_FeuilleCartesDUnJeu> {
  Game? _jeu;
  List<GameCard>? _cartes;
  String? _erreur;
  // Ordre de selection conserve : c'est l'ordre d'ajout dans la galerie.
  final List<GameCard> _choix = [];

  Future<void> _ouvrirJeu(Game jeu) async {
    setState(() {
      _jeu = jeu;
      _cartes = null;
      _erreur = null;
      _choix.clear();
    });
    final res = await ref.read(cardRepositoryProvider).listByGame(jeu.id);
    if (!mounted) return;
    setState(() {
      switch (res) {
        case Ok(value: final cartes):
          _cartes = cartes;
        case Err(failure: final f):
          _erreur = f.message;
      }
    });
  }

  void _basculer(GameCard c) {
    setState(() {
      if (_choix.any((x) => x.id == c.id)) {
        _choix.removeWhere((x) => x.id == c.id);
      } else if (_choix.length < widget.placesLibres) {
        _choix.add(c);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final hauteur = MediaQuery.sizeOf(context).height * 0.8;
    return SafeArea(
      child: SizedBox(
        height: hauteur,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  if (_jeu != null)
                    IconButton(
                      tooltip: 'Changer de jeu',
                      onPressed: () => setState(() {
                        _jeu = null;
                        _choix.clear();
                      }),
                      icon: const Icon(Icons.arrow_back),
                    ),
                  Expanded(
                    child: Text(
                      _jeu == null ? 'Choisir un jeu' : _jeu!.name,
                      style: AppTextStyles.sectionTitle(),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (_jeu != null)
                    Text(
                      '${_choix.length} / ${widget.placesLibres} place(s)',
                      style: AppTextStyles.caption(),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Expanded(child: _jeu == null ? _listeDesJeux() : _grilleDesCartes()),
              if (_jeu != null) ...[
                const SizedBox(height: 10),
                ElevatedButton.icon(
                  onPressed: _choix.isEmpty
                      ? null
                      : () => Navigator.of(context).pop(List.of(_choix)),
                  icon: const Icon(Icons.add),
                  label: Text('Ajouter ${_choix.length} carte(s)'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _listeDesJeux() {
    final jeux = ref.watch(gamesProvider);
    return jeux.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('$e', style: AppTextStyles.caption())),
      data: (liste) => liste.isEmpty
          ? Center(child: Text('Aucun jeu.', style: AppTextStyles.caption()))
          : ListView.separated(
              itemCount: liste.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (_, i) {
                final jeu = liste[i];
                return ListTile(
                  tileColor: AppColors.surface2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  leading: const Icon(Icons.style_outlined),
                  title: Text(jeu.name),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _ouvrirJeu(jeu),
                );
              },
            ),
    );
  }

  Widget _grilleDesCartes() {
    if (_erreur != null) {
      return Center(child: Text(_erreur!, style: AppTextStyles.caption()));
    }
    final cartes = _cartes;
    if (cartes == null) return const Center(child: CircularProgressIndicator());
    if (cartes.isEmpty) {
      return Center(
        child: Text('Ce jeu n\'a aucune carte.', style: AppTextStyles.caption()),
      );
    }
    return GridView.builder(
      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 120,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 0.72,
      ),
      itemCount: cartes.length,
      itemBuilder: (_, i) {
        final c = cartes[i];
        final rang = _choix.indexWhere((x) => x.id == c.id);
        final coche = rang >= 0;
        return InkWell(
          onTap: () => _basculer(c),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: coche ? AppColors.brand : AppColors.border,
                width: coche ? 2 : 1,
              ),
            ),
            child: Column(
              children: [
                Expanded(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          c.imagePath,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) =>
                              const Icon(Icons.broken_image_outlined),
                        ),
                      ),
                      // Le numero d'ordre plutot qu'une simple coche :
                      // il annonce la position dans la galerie.
                      if (coche)
                        Positioned(
                          top: 4,
                          right: 4,
                          child: CircleAvatar(
                            radius: 11,
                            backgroundColor: AppColors.brand,
                            child: Text(
                              '${rang + 1}',
                              style: const TextStyle(
                                color: AppColors.textOnBrand,
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  c.label,
                  style: AppTextStyles.caption(),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// =============================================================
// Petits elements de la barre et de l'en-tete
// =============================================================

class _PastilleNonPublie extends StatelessWidget {
  const _PastilleNonPublie();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.5)),
      ),
      child: Text(
        'Modifications non publiées',
        style: AppTextStyles.caption().copyWith(
          color: AppColors.warning,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _BoutonPublier extends ConsumerWidget {
  final EtatVitrine etat;
  const _BoutonPublier({required this.etat});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ElevatedButton.icon(
      // Le theme impose minimumSize: Size.fromHeight(48), soit une
      // largeur minimale INFINIE (boutons pleine largeur des
      // formulaires). Dans les actions d'une AppBar, cette largeur
      // impossible effondrait toute la barre : ni titre, ni bouton,
      // et la pastille « non publie » glissait sur la fleche retour.
      style: ElevatedButton.styleFrom(
        minimumSize: const Size(0, 40),
        padding: const EdgeInsets.symmetric(horizontal: 16),
      ),
      // Publier un document identique a celui en ligne n'a pas de
      // sens : le bouton ne s'active que s'il y a quelque chose a
      // envoyer.
      onPressed: !etat.modifie || etat.enPublication
          ? null
          : () async {
              final messenger = ScaffoldMessenger.of(context);
              final erreur =
                  await ref.read(vitrineProvider.notifier).publier();
              messenger.showSnackBar(SnackBar(
                content: Text(erreur == null
                    ? 'Vitrine publiée. Elle sera visible sur le site d\'ici une minute.'
                    : 'Publication refusée :\n$erreur'),
                backgroundColor: erreur == null ? null : AppColors.danger,
                duration: Duration(seconds: erreur == null ? 4 : 8),
              ));
            },
      icon: etat.enPublication
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.publish_outlined),
      label: const Text('Publier'),
    );
  }
}

// Adresse du site (copiable) + date de derniere publication.
// SelectableText plutot qu'un lien : le studio n'embarque pas
// url_launcher, et ajouter une dependance pour un seul lien ne se
// justifie pas.
class _LienSite extends StatelessWidget {
  final DateTime? majLe;
  const _LienSite({required this.majLe});

  @override
  Widget build(BuildContext context) {
    final d = majLe?.toLocal();
    String deux(int n) => n.toString().padLeft(2, '0');
    final date = d == null
        ? 'Jamais publiée'
        : 'Publiée le ${deux(d.day)}/${deux(d.month)}/${d.year} '
            'à ${deux(d.hour)}:${deux(d.minute)}';
    return Row(
      children: [
        const Icon(Icons.public, size: 16, color: AppColors.accent),
        const SizedBox(width: 6),
        SelectableText(
          kUrlVitrine,
          style: AppTextStyles.caption().copyWith(color: AppColors.accent),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            date,
            style: AppTextStyles.caption(),
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.end,
          ),
        ),
      ],
    );
  }
}

class _VueErreur extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _VueErreur({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off, size: 40, color: AppColors.textSecondary),
            const SizedBox(height: 12),
            Text(message,
                style: AppTextStyles.caption(), textAlign: TextAlign.center),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Réessayer'),
            ),
          ],
        ),
      ),
    );
  }
}

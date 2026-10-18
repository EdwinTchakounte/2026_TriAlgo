// =============================================================
// FICHIER : site_content.dart
// ROLE    : Contenu editable de la page d'accueil de mixalgo.com
// =============================================================
//
// CE QUE CETTE ENTITE REPRESENTE
// ------------------------------
// La vitrine (mixalgo.com) est une page statique : tous ses textes
// et ses images ont une valeur PAR DEFAUT ecrite dans le HTML. Ce
// document ne la remplace pas, il la SURCHARGE : chaque champ
// renseigne ici prend la place du texte d'origine, chaque champ
// laisse vide le laisse intact.
//
// D'ou la regle centrale de toJson() : un champ vide n'est PAS
// envoye. Envoyer "" effacerait le titre de la page au lieu de
// revenir au texte par defaut.
//
// LES LIMITES DE LONGUEUR
// -----------------------
// Elles sont celles du contrat backend (le serveur refuse au-dela,
// en 422). Les repeter ici permet au formulaire de bloquer la
// saisie AVANT l'envoi : un compteur de caracteres vaut mieux
// qu'un refus apres coup.
// =============================================================

/// Description d'un champ texte editable : sa cle JSON, son
/// libelle a l'ecran et sa longueur maximale.
class ChampTexte {
  final String cle;
  final String libelle;
  final int max;

  // multiligne : les textes longs (accroche, paragraphes) meritent
  // une zone de saisie haute ; un titre tient sur une ligne.
  final bool multiligne;

  const ChampTexte(this.cle, this.libelle, this.max, {this.multiligne = false});
}

/// Les six champs du hero, dans l'ordre ou ils apparaissent sur la page.
const List<ChampTexte> kChampsHero = [
  ChampTexte('surtitre', 'Surtitre', 80),
  ChampTexte('titre', 'Titre', 120),
  ChampTexte('titre_accent', 'Titre (partie colorée)', 120),
  ChampTexte('accroche', 'Accroche', 400, multiligne: true),
  ChampTexte('bouton_principal', 'Bouton principal', 40),
  ChampTexte('bouton_secondaire', 'Bouton secondaire', 40),
];

/// Les cinq sections editables : cle JSON -> libelle a l'ecran.
/// L'ordre est celui de la page.
const Map<String, String> kSections = {
  'demo': 'Démo jouable',
  'regle': 'La règle',
  'deck': 'Le deck',
  'collectif': 'Mode collectif',
  'telecharger': 'Téléchargement',
};

/// Les deux champs de chaque section.
const List<ChampTexte> kChampsSection = [
  ChampTexte('titre', 'Titre', 120),
  ChampTexte('texte', 'Texte', 600, multiligne: true),
];

/// Limites de la galerie, alignees sur le contrat.
const int kGalerieMax = 24;
const int kNomMax = 40;
const int kCodeMax = 8;

/// Nombre d'images de la galerie qui forment l'eventail du hero.
const int kImagesDuHero = 3;

// =============================================================
// ElementGalerie : une image de la galerie
// =============================================================
class ElementGalerie {
  // Identifiant LOCAL, jamais envoye au serveur. Il sert a garder
  // l'identite d'une ligne quand on la deplace : sans lui, monter
  // une image ferait "glisser" le texte saisi d'une ligne a l'autre,
  // parce que Flutter reutiliserait les champs par position.
  final String idLocal;
  final String imageUrl;
  final String nom;
  final String code;

  const ElementGalerie({
    required this.idLocal,
    required this.imageUrl,
    this.nom = '',
    this.code = '',
  });

  ElementGalerie copyWith({String? nom, String? code}) => ElementGalerie(
        idLocal: idLocal,
        imageUrl: imageUrl,
        nom: nom ?? this.nom,
        code: code ?? this.code,
      );

  // nom et code sont optionnels cote vitrine : on ne les envoie
  // que s'ils sont renseignes, pour la meme raison que les textes.
  Map<String, dynamic> toJson() => {
        'image_url': imageUrl,
        if (nom.trim().isNotEmpty) 'nom': nom.trim(),
        if (code.trim().isNotEmpty) 'code': code.trim(),
      };
}

// =============================================================
// ContenuAccueil : le document complet "accueil"
// =============================================================
class ContenuAccueil {
  /// Champs du hero : cle -> valeur. Une cle absente = texte par defaut.
  final Map<String, String> hero;

  /// Images de la galerie, dans l'ordre d'affichage.
  final List<ElementGalerie> galerie;

  /// Sections : cle de section -> (cle de champ -> valeur).
  final Map<String, Map<String, String>> sections;

  /// Date de la derniere publication, null si jamais publie.
  final DateTime? majLe;

  const ContenuAccueil({
    this.hero = const {},
    this.galerie = const [],
    this.sections = const {},
    this.majLe,
  });

  ContenuAccueil copyWith({
    Map<String, String>? hero,
    List<ElementGalerie>? galerie,
    Map<String, Map<String, String>>? sections,
    DateTime? majLe,
  }) {
    return ContenuAccueil(
      hero: hero ?? this.hero,
      galerie: galerie ?? this.galerie,
      sections: sections ?? this.sections,
      majLe: majLe ?? this.majLe,
    );
  }

  // -----------------------------------------------------------
  // Serialisation vers le contrat
  // -----------------------------------------------------------
  // Trois regles :
  //   - un texte vide (ou fait d'espaces) n'est pas envoye ;
  //   - un bloc devenu vide n'est pas envoye non plus : "hero": {}
  //     est inoffensif, mais l'omettre garde le document lisible ;
  //   - majLe n'est jamais envoye, c'est le serveur qui le date.
  Map<String, dynamic> toJson() {
    Map<String, String> nettoyer(Map<String, String> m) => {
          for (final e in m.entries)
            if (e.value.trim().isNotEmpty) e.key: e.value.trim(),
        };

    final heroPropre = nettoyer(hero);
    final sectionsPropres = <String, Map<String, String>>{};
    for (final e in sections.entries) {
      final champs = nettoyer(e.value);
      if (champs.isNotEmpty) sectionsPropres[e.key] = champs;
    }

    return {
      if (heroPropre.isNotEmpty) 'hero': heroPropre,
      if (galerie.isNotEmpty)
        'galerie': [for (final g in galerie) g.toJson()],
      if (sectionsPropres.isNotEmpty) 'sections': sectionsPropres,
    };
  }

  // -----------------------------------------------------------
  // Lecture depuis le contrat
  // -----------------------------------------------------------
  // Tolerante par construction : un champ de mauvais type est
  // ignore plutot que de faire echouer tout l'ecran. Le document
  // vient du serveur, qui l'a deja valide ; si quelque chose
  // detonne, mieux vaut un champ vide qu'un studio inutilisable.
  factory ContenuAccueil.fromJson(
    Map<String, dynamic> contenu, {
    DateTime? majLe,
  }) {
    Map<String, String> chaines(Object? brut) {
      if (brut is! Map) return {};
      return {
        for (final e in brut.entries)
          if (e.value is String) e.key.toString(): e.value as String,
      };
    }

    final sections = <String, Map<String, String>>{};
    final brutSections = contenu['sections'];
    if (brutSections is Map) {
      for (final e in brutSections.entries) {
        sections[e.key.toString()] = chaines(e.value);
      }
    }

    final galerie = <ElementGalerie>[];
    final brutGalerie = contenu['galerie'];
    if (brutGalerie is List) {
      for (final (i, g) in brutGalerie.indexed) {
        if (g is! Map || g['image_url'] is! String) continue;
        galerie.add(ElementGalerie(
          idLocal: 'srv-$i-${g['image_url']}',
          imageUrl: g['image_url'] as String,
          nom: (g['nom'] as String?) ?? '',
          code: (g['code'] as String?) ?? '',
        ));
      }
    }

    return ContenuAccueil(
      hero: chaines(contenu['hero']),
      galerie: galerie,
      sections: sections,
      majLe: majLe,
    );
  }
}

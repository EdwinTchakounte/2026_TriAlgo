// =============================================================
// FICHIER : lib/domain/entities/graph_node_entity.dart
// ROLE   : Representer un noeud du graphe de jeu
// COUCHE : Domain > Entities
// =============================================================
//
// QU'EST-CE QU'UN NOEUD ?
// -----------------------
// Un noeud est un trio de 3 cartes : E + C = R
//   - E (Emettrice)  : donne la forme dominante
//   - C (Cable)      : apporte le decor / les transformations
//   - R (Receptrice) : resultat visuel de la fusion E + C
//
// Les noeuds forment un ARBRE de profondeur 3 :
//   Profondeur 1 : noeuds racines  — E est une carte de base
//   Profondeur 2 : noeuds enfants  — E est la R du parent
//   Profondeur 3 : noeuds petits-enfants — E est la R du parent (P2)
//
// CHAINAGE :
// ----------
// La relation cle du graphe est :
//   enfant.emettrice = parent.receptrice
//
// Exemple :
//   N01 (P1) : Lion   + Etoile  = Lion Etoile
//   N16 (P2) : Lion Etoile + Vague = Lion Bleu
//              ↑ E de N16 = R de N01
//
// EMETTRICE_ID NULLABLE :
// -----------------------
// Pour les noeuds enfants (depth > 1), emettrice_id est NULL
// en base de donnees. La valeur est deduite du parent lors
// de la construction locale du graphe par Flutter.
//
// Cela evite :
//   - La redondance (stocker 2 fois la meme info)
//   - Les erreurs de saisie admin (remplir E different de parent.R)
//
// Le champ resolvedEmettriceId est rempli par Flutter APRES
// la construction du graphe, via la methode resolveEmettrice().
//
// REFERENCE : Discussion architecture graphe, avril 2026
// =============================================================

/// Represente un noeud du graphe de jeu TRIALGO.
///
/// Un noeud contient un trio de 3 cartes (E + C = R) et un lien
/// optionnel vers son noeud parent dans l'arbre.
///
/// Pour les noeuds enfants, [emettriceId] est null — la valeur
/// reelle est la [receptriceId] du parent, resolue localement
/// par Flutter via [resolveEmettrice].
class GraphNodeEntity {

  // =============================================================
  // PROPRIETE : id
  // =============================================================
  // UUID v4 genere par PostgreSQL.
  // Identifiant unique dans la table "nodes".
  // =============================================================

  /// Identifiant unique du noeud.
  final String id;

  // =============================================================
  // PROPRIETE : nodeIndex
  // =============================================================
  // Index numerique unique du noeud dans le graphe.
  // Sert de reference rapide : 1, 2, ... 50.
  // Unique : deux noeuds ne peuvent pas avoir le meme index.
  // =============================================================

  /// Index numerique unique du noeud (1 a 50).
  final int nodeIndex;

  // =============================================================
  // PROPRIETE : emettriceId
  // =============================================================
  // UUID de la carte qui joue le role d'Emettrice.
  //
  // NULLABLE : null pour les noeuds enfants (depth > 1).
  // Pour ces noeuds, l'emettrice est deduite du parent :
  //   enfant.emettrice = parent.receptrice
  //
  // Renseigne uniquement pour les noeuds racines (depth = 1).
  // =============================================================

  /// ID de la carte Emettrice. Null si noeud enfant (deduit du parent).
  final String? emettriceId;

  // =============================================================
  // PROPRIETE : cableId
  // =============================================================
  // UUID de la carte qui joue le role de Cable.
  // Toujours renseigne, que le noeud soit racine ou enfant.
  // =============================================================

  /// ID de la carte Cable. Toujours renseigne.
  final String cableId;

  // =============================================================
  // PROPRIETE : receptriceId
  // =============================================================
  // UUID de la carte qui joue le role de Receptrice.
  // Toujours renseigne. Cette carte peut devenir l'Emettrice
  // d'un noeud enfant (c'est le principe du chainage).
  // =============================================================

  /// ID de la carte Receptrice. Toujours renseigne.
  final String receptriceId;

  // =============================================================
  // PROPRIETE : parentNodeId
  // =============================================================
  // UUID du noeud parent dans le graphe.
  // NULL pour les noeuds racines (profondeur 1).
  // Pointe vers un autre noeud pour les enfants (profondeur 2, 3).
  // =============================================================

  /// ID du noeud parent. Null si racine (profondeur 1).
  final String? parentNodeId;

  // =============================================================
  // PROPRIETE : depth
  // =============================================================
  // Profondeur du noeud dans l'arbre.
  // 1 = racine, 2 = enfant, 3 = petit-enfant.
  // =============================================================

  /// Profondeur du noeud dans l'arbre (1, 2 ou 3).
  final int depth;

  // =============================================================
  // PROPRIETE MUTABLE : resolvedEmettriceId
  // =============================================================
  // Pour les noeuds enfants, emettriceId est null en BDD.
  // Ce champ est rempli PAR FLUTTER lors de la construction
  // du graphe local, en copiant parent.receptriceId.
  //
  // C'est le SEUL champ mutable de cette entite.
  // Il n'est pas "final" car il est assigne APRES la creation.
  //
  // Apres resolution, pour obtenir l'ID de l'emettrice effective,
  // utiliser le getter effectiveEmettriceId.
  // =============================================================

  /// ID de l'emettrice resolue (rempli par Flutter pour les enfants).
  String? resolvedEmettriceId;

  // =============================================================
  // CONSTRUCTEUR
  // =============================================================
  // Pas "const" car resolvedEmettriceId est mutable.
  // cableId et receptriceId sont toujours requis.
  // emettriceId et parentNodeId sont optionnels (nullable).
  // =============================================================

  /// Cree un noeud du graphe.
  GraphNodeEntity({
    required this.id,
    required this.nodeIndex,
    this.emettriceId,
    required this.cableId,
    required this.receptriceId,
    this.parentNodeId,
    required this.depth,
  });

  // =============================================================
  // GETTER : effectiveEmettriceId
  // =============================================================
  // Retourne l'ID de l'emettrice effective de ce noeud :
  //   - Si racine : emettriceId (stocke en BDD)
  //   - Si enfant : resolvedEmettriceId (calcule par Flutter)
  //
  // Leve une erreur si aucun des deux n'est disponible
  // (le graphe n'a pas ete correctement construit).
  // =============================================================

  /// L'ID de l'emettrice effective (stockee ou resolue).
  ///
  /// Pour les racines, retourne [emettriceId].
  /// Pour les enfants, retourne [resolvedEmettriceId].
  /// Leve une erreur si l'emettrice n'est pas disponible.
  String get effectiveEmettriceId {
    final id = emettriceId ?? resolvedEmettriceId;
    if (id == null) {
      throw StateError(
        'Noeud N$nodeIndex : emettrice non resolue. '
        'Appeler resolveEmettrice() apres construction du graphe.',
      );
    }
    return id;
  }

  // =============================================================
  // GETTER : isRoot
  // =============================================================
  // Un noeud est racine s'il n'a pas de parent.
  // Equivalent de : depth == 1
  // =============================================================

  /// True si ce noeud est une racine (profondeur 1, pas de parent).
  bool get isRoot => parentNodeId == null;

  // =============================================================
  // METHODE : resolveEmettrice
  // =============================================================
  // Appele par Flutter lors de la construction du graphe.
  // Prend la receptriceId du parent et l'assigne comme emettrice
  // de ce noeud enfant.
  //
  // Ne fait rien si le noeud est une racine (emettrice deja connue).
  // =============================================================

  /// Resout l'emettrice d'un noeud enfant depuis son parent.
  ///
  /// [parentReceptriceId] : la receptriceId du noeud parent.
  ///
  /// Apres cet appel, [effectiveEmettriceId] retourne la valeur resolue.
  void resolveEmettrice(String parentReceptriceId) {
    if (!isRoot) {
      resolvedEmettriceId = parentReceptriceId;
    }
  }
}

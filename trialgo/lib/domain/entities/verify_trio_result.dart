// =============================================================
// FICHIER : lib/domain/entities/verify_trio_result.dart
// ROLE   : Resultat d'une verification de trio (mode collectif)
// COUCHE : Domain > Entities
// =============================================================
//
// POURQUOI CE FICHIER ?
// ---------------------
// La verification d'un trio peut renvoyer DEUX types d'information :
//   - SUCCES : le trio existe dans le graphe, on affiche la distance,
//     les labels des 3 cartes et la chaine de noeuds sources.
//   - ECHEC  : le trio n'existe pas, on affiche un message clair.
//
// Cette classe encapsule les 2 cas dans un seul type typeé, ce qui
// permet au code appelant de faire un simple `if (result.valid)`.
//
// VERIFICATION DES LOGICAL NODES, PAS DES NATIVE NODES :
// ------------------------------------------------------
// Un trio valide est une entree du LogicalNodesPool (tables D1-D3).
// Cela inclut :
//   - Les 50 noeuds natifs (D1 direct)
//   - Les combinaisons D2 (5 tables × N paires parent-enfant)
//   - Les combinaisons D3 (14 tables × N chaines de 3 noeuds)
//
// Autrement dit : TOUS les trios que le jeu pourrait presenter au
// joueur en mode solo. Si le joueur scanne ces 3 cartes et que le
// jeu les reconnait, alors le mode collectif les reconnait aussi.
// =============================================================


/// Resultat d'une verification de trio (scan QR ou saisie manuelle).
class VerifyTrioResult {

  /// True si le trio est valide (existe dans le pool logique).
  /// Quand false, seul [errorMessage] est significatif.
  final bool valid;

  /// Message d'erreur lisible. Non-null si valid == false.
  final String? errorMessage;

  /// Distance du trio trouve : 1, 2 ou 3.
  /// Null si valid == false.
  final int? distance;

  /// Labels des 3 cartes du trio valide, dans l'ordre cardA, cardB, cardC
  /// du noeud logique (ex: [E1_label, R1_label, R2_label] pour un D2).
  /// Null si valid == false.
  final List<String>? cardLabels;

  /// Numeros des noeuds natifs sources :
  ///   - D1 : 1 element (ex: [12])
  ///   - D2 : 2 elements (ex: [1, 16] pour "N01 → N16")
  ///   - D3 : 3 elements (ex: [1, 16, 36])
  /// Null si valid == false.
  final List<int>? sourceNodeIndices;

  /// Cle de tracking du noeud logique matche (debug, optionnel).
  /// Ex: "D2#N01-N16#E1-R1-R2". Null si valid == false.
  final String? trackingKey;

  const VerifyTrioResult._({
    required this.valid,
    this.errorMessage,
    this.distance,
    this.cardLabels,
    this.sourceNodeIndices,
    this.trackingKey,
  });

  // =============================================================
  // FACTORY : success
  // =============================================================
  // Force tous les champs utiles non-null pour eviter les resultats
  // partiels cote UI.
  // =============================================================

  /// Resultat positif : trio logique trouve.
  factory VerifyTrioResult.success({
    required int distance,
    required List<String> cardLabels,
    required List<int> sourceNodeIndices,
    required String trackingKey,
  }) {
    return VerifyTrioResult._(
      valid: true,
      distance: distance,
      cardLabels: cardLabels,
      sourceNodeIndices: sourceNodeIndices,
      trackingKey: trackingKey,
    );
  }

  // =============================================================
  // FACTORY : invalid
  // =============================================================

  /// Resultat negatif : trio non trouve ou entree invalide.
  factory VerifyTrioResult.invalid(String message) {
    return VerifyTrioResult._(valid: false, errorMessage: message);
  }
}

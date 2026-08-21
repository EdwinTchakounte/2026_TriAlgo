// =============================================================
// FICHIER : card_type.dart
// ROLE    : Enum metier des 3 roles d'une carte TRIALGO
// =============================================================
//
// Le jeu TRIALGO repose sur des "trios" :
//
//        EMETTRICE  +  CABLE  =  RECEPTRICE
//        (gauche)      (op)       (resultat)
//
// Chaque carte joue un role figé dans la table cards.card_type.
// Cet enum modelise ces 3 roles en Dart pour eviter les chaines
// magiques disseminees dans le code.
// =============================================================

enum CardType {
  // Carte de gauche, "source" de la transformation.
  // Ex : "Lion".
  emettrice('emettrice', 'Émettrice'),

  // Carte du milieu, transformation a appliquer.
  // Ex : "Rotation".
  cable('cable', 'Câble'),

  // Carte de droite, resultat de la transformation.
  // Ex : "Lion Rotation".
  receptrice('receptrice', 'Réceptrice');

  // Cle stockee en DB (correspond exactement a la valeur du
  // CHECK SQL `card_type IN ('emettrice', 'cable', 'receptrice')`).
  final String dbKey;

  // Libelle FR pour l'UI (affiche dans les filtres, picker, etc).
  final String label;

  const CardType(this.dbKey, this.label);

  // Reverse lookup : convertit la chaine DB vers l'enum.
  // Throw si la valeur est inconnue : on prefere echouer fort
  // plutot que d'afficher silencieusement n'importe quoi.
  static CardType fromDb(String value) {
    return CardType.values.firstWhere(
      (e) => e.dbKey == value,
      orElse: () => throw ArgumentError('CardType inconnu: $value'),
    );
  }
}

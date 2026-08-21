// =============================================================
// FICHIER : card_type.dart
// ROLE    : Enum representant le role d'une carte dans la fusion
// =============================================================
//
// Modele mental TRIALGO : une fusion est une operation binaire
//
//   ingredient A  +  ingredient B   =>   produit
//
// Une carte TRIALGO appartient TOUJOURS a une des 3 categories :
//
//   emettrice (dbKey)  -> "Ingredient A" cote UI : 1er ingredient
//   cable     (dbKey)  -> "Ingredient B" cote UI : 2e ingredient
//   receptrice(dbKey)  -> "Produit"      cote UI : resultat de la fusion
//
// La cle DB reste "emettrice/cable/receptrice" pour ne PAS casser
// le backend ; seul le label UI bascule sur le vocabulaire fusion.
// Cote app, on modelise par un enum pour beneficier du typage
// fort : impossible de creer une carte de type 'mauvaisLabel'.
// =============================================================

enum CardType {
  emettrice('emettrice', 'Ingredient A'),
  cable('cable', 'Ingredient B'),
  receptrice('receptrice', 'Produit');

  // Constructeur const : associe a chaque valeur enum une cle DB
  // (utilisee pour serialiser vers Supabase) et un label UI (pour
  // affichage dans les chips, filtres, etc.).
  const CardType(this.dbKey, this.label);

  // Cle stockee en base. C'est l'unique source de verite cote DB.
  final String dbKey;
  // Label montre dans l'UI (capitalise, en francais).
  final String label;

  // Constructeur "inverse" : a partir de la cle DB on retrouve
  // l'enum. Utilise dans les fromJson() des modeles.
  // Si la cle ne matche rien on retourne null plutot que de throw,
  // pour que le caller decide (souvent : ignorer la ligne, ne pas
  // crasher tout le fetch).
  static CardType? fromDb(String? key) {
    if (key == null) return null;
    for (final v in CardType.values) {
      if (v.dbKey == key) return v;
    }
    return null;
  }
}

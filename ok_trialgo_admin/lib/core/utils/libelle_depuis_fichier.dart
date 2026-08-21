// =============================================================
// FICHIER : libelle_depuis_fichier.dart
// ROLE    : Deduire un libelle de carte depuis un nom de fichier
// =============================================================
//
// POURQUOI CETTE FONCTION EXISTE
// ------------------------------
// A l'import par lot, l'administrateur choisit une cinquantaine
// d'images d'un coup. Lui demander de saisir cinquante libelles
// reintroduirait exactement la friction que l'import par lot vise
// a supprimer.
//
// Or, dans la pratique, les images d'un jeu sont deja nommees :
// "lion.jpg", "miroir_brise.png", "reflet-eau.jpg". Il suffit de
// lire ces noms pour proposer un libelle correct dans la grande
// majorite des cas. L'administrateur ne corrige que les exceptions.
//
// CE QU'ELLE NE CHERCHE PAS A FAIRE
// ---------------------------------
// Etre parfaite. Un fichier "IMG_4032.JPG" produira "Img 4032",
// qui ne veut rien dire -- et c'est tres bien : le champ reste
// editable, et le cas se voit d'un coup d'oeil dans la liste.
// L'objectif est d'epargner la saisie quand c'est possible, pas de
// deviner l'intention.
//
// Fonction PURE : aucune dependance, donc testable directement.
// C'est la raison pour laquelle elle vit ici et non dans le
// fichier de la page.
// =============================================================

/// Transforme "lion_savane.JPG" en "Lion savane".
///
/// Retourne 'Carte' si [nom] ne donne rien d'exploitable.
String libelleDepuisNomDeFichier(String nom) {
  // 1. Retirer l'extension, s'il y en a une.
  //
  // lastIndexOf('.') et non indexOf : "reflet.eau.jpg" doit perdre
  // ".jpg", pas ".eau.jpg". Le test `> 0` et non `>= 0` protege les
  // fichiers caches facon Unix (".gitkeep"), dont le point initial
  // n'est pas un separateur d'extension.
  final point = nom.lastIndexOf('.');
  var base = point > 0 ? nom.substring(0, point) : nom;

  // 2. Les separateurs techniques deviennent des espaces.
  base = base.replaceAll(RegExp(r'[_\-]+'), ' ');

  // 3. Ecraser les espaces multiples et rogner les bords.
  base = base.replaceAll(RegExp(r'\s+'), ' ').trim();

  if (base.isEmpty) return 'Carte';

  // 4. Premiere lettre en majuscule, le reste en minuscules.
  //
  // Le passage en minuscules n'est pas cosmetique : les appareils
  // photo produisent des noms en capitales ("DSC_0042"), et une
  // carte intitulee "DSC 0042" en pleine partie jure autant qu'elle
  // informe peu.
  return base[0].toUpperCase() + base.substring(1).toLowerCase();
}

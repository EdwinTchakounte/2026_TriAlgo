// =============================================================
// FICHIER : activation_code.dart (entite domain)
// ROLE    : Modeliser un code d'activation d'un jeu
// =============================================================
//
// A QUOI SERT UN CODE D'ACTIVATION
// --------------------------------
// TRIALGO se vend en boite physique. Chaque boite contient un code
// imprime. Le joueur telecharge l'app, saisit son code, et le jeu
// correspondant se debloque sur SON telephone.
//
// LE MECANISME ANTI-PARTAGE
// -------------------------
// Un code memorise l'identifiant de l'appareil sur lequel il a ete
// active ([deviceId]). Le rejouer depuis un autre telephone
// consomme un "changement d'appareil" ([deviceChangesCount]), dans
// la limite de [maxDeviceChanges]. Passe cette limite, le code se
// bloque ([isBlocked]).
//
// L'intention : tolerer un changement de telephone honnete, sans
// laisser un code circuler dans toute une classe.
//
// LES DEUX FACONS DE NEUTRALISER UN CODE, ET LEUR DIFFERENCE
// ----------------------------------------------------------
//   isActive = false  L'administrateur coupe le code. Le joueur
//                     deja active perd l'acces. Reversible.
//   isBlocked = true  Le quota de changements d'appareil est
//                     epuise. Ce n'est PAS une decision admin,
//                     c'est le systeme qui a compte. Seul un
//                     "reset SAV" (cf. resetAssignment cote
//                     repository) remet le compteur a zero.
//
// Entite PURE : aucune serialisation ici, c'est le role du
// repository HTTP.
// =============================================================

class ActivationCode {
  /// Le code lui-meme, tel qu'imprime dans la boite.
  /// C'est la cle primaire cote serveur : il est unique.
  final String code;

  /// UUID du jeu que ce code debloque.
  final String gameId;

  /// UUID du joueur qui a active ce code, ou null si jamais active.
  final String? assignedTo;

  /// Identifiant de l'appareil sur lequel le code a ete active.
  /// Null tant que personne ne l'a utilise.
  final String? deviceId;

  /// Nombre de changements d'appareil deja consommes.
  final int deviceChangesCount;

  /// Quota de changements d'appareil autorises.
  final int maxDeviceChanges;

  /// True si le quota est epuise : le code ne fonctionne plus.
  final bool isBlocked;

  /// True si l'administrateur laisse ce code utilisable.
  final bool isActive;

  /// Date de la premiere activation, ou null si jamais active.
  final DateTime? activatedAt;

  /// Date de creation du code.
  final DateTime createdAt;

  const ActivationCode({
    required this.code,
    required this.gameId,
    required this.assignedTo,
    required this.deviceId,
    required this.deviceChangesCount,
    required this.maxDeviceChanges,
    required this.isBlocked,
    required this.isActive,
    required this.activatedAt,
    required this.createdAt,
  });

  // =============================================================
  // GETTER : estUtilise
  // =============================================================

  /// True si un joueur s'est deja approprie ce code.
  bool get estUtilise => assignedTo != null;

  // =============================================================
  // GETTER : changementsRestants
  // =============================================================
  // Ce que le joueur verrait s'il demandait "combien de fois
  // puis-je encore changer de telephone ?".
  //
  // Borne a zero : un compteur qui depasserait le quota (donnee
  // incoherente) ne doit pas produire un nombre negatif a l'ecran.
  // =============================================================

  /// Nombre de changements d'appareil encore possibles.
  int get changementsRestants {
    final restants = maxDeviceChanges - deviceChangesCount;
    return restants < 0 ? 0 : restants;
  }

  // =============================================================
  // GETTER : statutLisible
  // =============================================================
  // Un seul libelle a afficher dans la liste, par ordre de
  // gravite decroissante : ce qui empeche de jouer d'abord.
  // =============================================================

  /// Libelle court decrivant l'etat du code.
  String get statutLisible {
    if (!isActive) return 'Desactive';
    if (isBlocked) return 'Bloque';
    if (estUtilise) return 'Active';
    return 'Disponible';
  }
}

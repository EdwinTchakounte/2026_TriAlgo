// =============================================================
// FICHIER : lib/domain/entities/logical_node_entity.dart
// ROLE   : Representer un noeud LOGIQUE precompute (D1/D2/D3)
// COUCHE : Domain > Entities
// =============================================================
//
// QU'EST-CE QU'UN NOEUD LOGIQUE ?
// -------------------------------
// Le graphe en BDD contient les noeuds NATIFS (50 noeuds, chacun
// = E + C = R). Mais le jeu ne joue pas directement ces noeuds :
//   - En distance 1, oui (1 noeud natif = 1 noeud logique)
//   - En distance 2, on combine 2 noeuds voisins en plusieurs
//     combinaisons valides (4 par paire parent-enfant)
//   - En distance 3, on combine 3 noeuds voisins en plusieurs
//     combinaisons valides (X par chaine)
//
// CHAQUE NOEUD LOGIQUE = un trio jouable de 3 cartes.
// Tous les noeuds logiques sont PRECOMPUTES une fois au lancement
// du jeu (apres la synchronisation), puis stockes dans 3 tableaux :
//   logicalD1 : tous les noeuds logiques de distance 1
//   logicalD2 : tous les noeuds logiques de distance 2
//   logicalD3 : tous les noeuds logiques de distance 3
//
// Pendant le jeu, on tire un noeud logique au hasard dans le bon
// tableau. Pas de generation a la volee.
//
// EXEMPLE DISTANCE 2 :
// --------------------
// Noeud N01 (parent) : E1 + C1 = R1
// Noeud N02 (enfant) : R1 + C2 = R2
//
// Les 4 noeuds logiques D2 generes pour cette paire :
//   1. (E1, R1, R2)  → start + lien + fin
//   2. (E1, C1, R2)  → start + cable parent + fin
//   3. (R1, C1, R2)  → lien + cable parent + fin
//   4. (C1, C2, R2)  → cable parent + cable enfant + fin
//
// Tous finissent par R2 (la receptrice finale de la chaine).
//
// REFERENCE : Discussion architecture graphe, avril 2026
// =============================================================

import 'package:trialgo/domain/entities/graph_card_entity.dart';
import 'package:trialgo/domain/entities/graph_node_entity.dart';

/// Represente un noeud logique precompute, pret a etre joue.
///
/// Un noeud logique contient un trio de 3 cartes et la cle de
/// tracking unique qui permet d'eviter de le rejouer.
class LogicalNodeEntity {

  // =============================================================
  // PROPRIETE : trackingKey
  // =============================================================
  // Cle unique qui identifie ce noeud logique.
  //
  // Format selon la distance :
  //   D1 : "N01"                          (un seul noeud)
  //   D2 : "N01-N02#E1-R1-R2"             (paire + composition du trio)
  //   D3 : "N01-N02-N03#E1-R2-R3"         (chaine + composition)
  //
  // Le "#" separe les noeuds source de la composition du trio.
  // Cela permet d'avoir plusieurs noeuds logiques distincts
  // pour la meme paire/chaine de noeuds natifs.
  //
  // Exemple : pour la paire N01-N02, on a 4 trackingKeys :
  //   "N01-N02#E1-R1-R2"
  //   "N01-N02#E1-C1-R2"
  //   "N01-N02#R1-C1-R2"
  //   "N01-N02#C1-C2-R2"
  // =============================================================

  /// Cle de tracking unique du noeud logique.
  final String trackingKey;

  // =============================================================
  // PROPRIETE : distance
  // =============================================================
  // Distance de ce noeud logique : 1, 2 ou 3.
  // Determine dans quel tableau il est range.
  // =============================================================

  /// Distance du noeud logique (1, 2 ou 3).
  final int distance;

  // =============================================================
  // PROPRIETE : cardA, cardB, cardC
  // =============================================================
  // Les 3 cartes du trio jouable.
  //
  // Ce sont les 3 cartes que le joueur va voir/devoir trouver.
  // L'ordre est important :
  //   cardA : carte la plus "amont" dans la chaine
  //   cardB : carte intermediaire
  //   cardC : carte la plus "aval" (souvent la receptrice finale)
  //
  // La config (A/B/C) du niveau determine laquelle est masquee :
  //   Config A : visible cardA + cardB, masquee cardC
  //   Config B : visible cardA + cardC, masquee cardB
  //   Config C : visible cardB + cardC, masquee cardA
  // =============================================================

  /// Premiere carte du trio (la plus amont).
  final GraphCardEntity cardA;

  /// Deuxieme carte du trio (intermediaire).
  final GraphCardEntity cardB;

  /// Troisieme carte du trio (la plus aval).
  final GraphCardEntity cardC;

  // =============================================================
  // PROPRIETE : sourceNodes
  // =============================================================
  // Les noeuds natifs du graphe d'ou viennent les cartes.
  //
  // Distance 1 : 1 element  (le noeud lui-meme)
  // Distance 2 : 2 elements (parent, enfant)
  // Distance 3 : 3 elements (grand-parent, parent, enfant)
  //
  // Utile pour le debug et l'admin (savoir d'ou vient un trio).
  // =============================================================

  /// Les noeuds natifs source de ce noeud logique.
  final List<GraphNodeEntity> sourceNodes;

  // =============================================================
  // CONSTRUCTEUR
  // =============================================================

  /// Cree un noeud logique precompute.
  const LogicalNodeEntity({
    required this.trackingKey,
    required this.distance,
    required this.cardA,
    required this.cardB,
    required this.cardC,
    required this.sourceNodes,
  });

  // =============================================================
  // GETTER : allCards
  // =============================================================
  // Raccourci pour acceder aux 3 cartes en liste.
  // Utilise pour exclure ces cartes lors de la generation des
  // distracteurs.
  // =============================================================

  /// Les 3 cartes du trio en liste.
  List<GraphCardEntity> get allCards => [cardA, cardB, cardC];
}

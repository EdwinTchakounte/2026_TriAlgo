// =============================================================
// FICHIER : lib/presentation/widgets/user_avatar.dart
// ROLE   : Avatar du joueur (icone Material thematique)
// COUCHE : Presentation > Widgets
// =============================================================
//
// 12 AVATARS ICONES (reprise de l'ancien systeme) :
// -------------------------------------------------
//   avatar_1  -> pets           (animaux)
//   avatar_2  -> flutter_dash   (oiseau mascotte)
//   avatar_3  -> water          (eau)
//   avatar_4  -> local_fire     (feu)
//   avatar_5  -> park           (nature)
//   avatar_6  -> nightlight     (nuit)
//   avatar_7  -> bolt           (eclair)
//   avatar_8  -> ac_unit        (glace)
//   avatar_9  -> whatshot       (tendance)
//   avatar_10 -> psychology     (esprit)
//   avatar_11 -> terrain        (montagne)
//   avatar_12 -> waves          (ocean)
//
// Rendu : cercle avec gradient thematique + icone blanche au centre.
// Chaque avatar a une palette de couleurs qui lui est propre.
// =============================================================

import 'package:flutter/material.dart';

import 'package:trialgo/core/design_system/tokens/elevation.dart';


/// Table : avatar_id -> IconData.
const Map<String, IconData> _avatarIcons = {
  'avatar_1':  Icons.pets,
  'avatar_2':  Icons.flutter_dash,
  'avatar_3':  Icons.water,
  'avatar_4':  Icons.local_fire_department,
  'avatar_5':  Icons.park,
  'avatar_6':  Icons.nightlight_round,
  'avatar_7':  Icons.bolt,
  'avatar_8':  Icons.ac_unit,
  'avatar_9':  Icons.whatshot,
  'avatar_10': Icons.psychology,
  'avatar_11': Icons.terrain,
  'avatar_12': Icons.waves,
};

/// Table : avatar_id -> gradient de fond (2 couleurs).
/// Chaque gradient est en coherence thematique avec l'icone :
///   eau = bleus, feu = oranges/rouges, nature = verts, etc.
const Map<String, List<Color>> _avatarGradients = {
  'avatar_1':  [Color(0xFFFF6B35), Color(0xFFF7C948)], // animaux : orange/or (brand)
  'avatar_2':  [Color(0xFF42A5F5), Color(0xFF90CAF9)], // oiseau : bleu ciel
  'avatar_3':  [Color(0xFF00BCD4), Color(0xFF80DEEA)], // eau : cyan
  'avatar_4':  [Color(0xFFEF5350), Color(0xFFFFB74D)], // feu : rouge/orange
  'avatar_5':  [Color(0xFF66BB6A), Color(0xFFA0E7A8)], // nature : vert
  'avatar_6':  [Color(0xFF5C6BC0), Color(0xFF9FA8DA)], // nuit : indigo
  'avatar_7':  [Color(0xFFFFCA28), Color(0xFFFFE57F)], // eclair : jaune
  'avatar_8':  [Color(0xFF26C6DA), Color(0xFFB2EBF2)], // glace : cyan clair
  'avatar_9':  [Color(0xFFD81B60), Color(0xFFFF6B35)], // tendance : magenta/orange
  'avatar_10': [Color(0xFFAB7CFF), Color(0xFFD1B8FF)], // esprit : violet
  'avatar_11': [Color(0xFF8D6E63), Color(0xFFBCAAA4)], // montagne : terre
  'avatar_12': [Color(0xFF26A69A), Color(0xFF7EE7C1)], // ocean : teal/mint
};

/// Liste ordonnee des 12 IDs disponibles pour la galerie de choix.
const List<String> kAllAvatarIds = [
  'avatar_1',  'avatar_2',  'avatar_3',  'avatar_4',
  'avatar_5',  'avatar_6',  'avatar_7',  'avatar_8',
  'avatar_9',  'avatar_10', 'avatar_11', 'avatar_12',
];


/// Resout l'icone d'un avatar_id (fallback sur person si inconnu).
IconData avatarIconFor(String avatarId) {
  return _avatarIcons[avatarId] ?? Icons.person;
}

/// Resout le gradient d'un avatar_id (fallback sur avatar_1 si inconnu).
List<Color> avatarGradientFor(String avatarId) {
  return _avatarGradients[avatarId] ?? _avatarGradients['avatar_1']!;
}


/// Rend un avatar circulaire avec icone thematique + gradient.
class UserAvatar extends StatelessWidget {

  /// Identifiant de l'avatar ("avatar_1".."avatar_12").
  final String avatarId;

  /// Username - parametre garde pour compat API (non utilise pour
  /// le rendu, car les avatars sont des icones, pas des initiales).
  final String username;

  /// Diametre en pixels (default 44).
  final double size;

  /// Si true, ajoute un glow dore (halo) autour.
  final bool showHalo;

  /// Si true, ajoute une bordure blanche (selection dans galerie).
  final bool selected;

  const UserAvatar({
    super.key,
    required this.avatarId,
    required this.username,
    this.size = 44,
    this.showHalo = false,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    final gradient = avatarGradientFor(avatarId);
    final icon = avatarIconFor(avatarId);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: gradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: showHalo ? TElevation.glowGold : TElevation.subtle,
        border: selected
            ? Border.all(color: Colors.white, width: 3)
            : null,
      ),
      alignment: Alignment.center,
      child: Icon(
        icon,
        color: Colors.white,
        // Taille de l'icone ~= 55% du diametre pour un bon ratio visuel.
        size: size * 0.55,
      ),
    );
  }
}

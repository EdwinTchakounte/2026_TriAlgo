// =============================================================
// FICHIER : lib/presentation/widgets/lives_refill_timer.dart
// ROLE   : Compte a rebours "Prochaine vie dans mm:ss"
// COUCHE : Presentation > Widgets (reutilisable)
// =============================================================
//
// QU'AFFICHE CE WIDGET ?
// ----------------------
// Un petit badge "icone timer + mm:ss" avec :
//   - lives == maxLives : ne s'affiche PAS du tout (SizedBox.shrink)
//   - lives < maxLives  : countdown vers le prochain +1 vie
//   - countdown ecoule  : affiche 00:00 puis recharge le profil pour
//                         aller chercher la nouvelle valeur cote serveur
//
// POURQUOI UN WIDGET SEPARE ?
// ---------------------------
// La home avait un placeholder hardcode "12 min" qu'il fallait remplacer.
// En extrayant dans un widget :
//   - La page de jeu peut aussi afficher le compteur
//   - Un seul endroit gere le Timer.periodic et le formatage mm:ss
//
// PATTERN :
// ---------
// StatefulWidget avec Timer.periodic(1s) qui force un setState.
// Au moment du build, on lit profile.nextRefillAt et on calcule le
// restant via DateTime.now(). Pas de calcul dans le timer lui-meme.
// =============================================================

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:trialgo/presentation/providers/profile_provider.dart';


/// Compte a rebours affichant le temps avant la prochaine vie.
class LivesRefillTimer extends ConsumerStatefulWidget {

  /// Couleur du texte et de l'icone. Par defaut : rouge.
  /// Exposee pour que l'appelant puisse l'accorder a son theme.
  final Color color;

  /// Taille de la police du compteur.
  final double fontSize;

  /// Taille de l'icone timer.
  final double iconSize;

  const LivesRefillTimer({
    super.key,
    this.color = const Color(0xFFEF5350),
    this.fontSize = 9,
    this.iconSize = 11,
  });

  @override
  ConsumerState<LivesRefillTimer> createState() => _LivesRefillTimerState();
}

class _LivesRefillTimerState extends ConsumerState<LivesRefillTimer> {

  /// Timer qui tick toutes les secondes pour forcer un rebuild.
  /// Nullable car cree dans initState, annule dans dispose.
  Timer? _ticker;

  /// True si on a deja declenche un reload du profil apres que le
  /// countdown soit passe a zero. Evite de spammer la BDD : on
  /// n'appelle reload() qu'UNE seule fois par cycle d'expiration.
  bool _reloadTriggered = false;

  @override
  void initState() {
    super.initState();

    // Timer.periodic appelle le callback toutes les secondes.
    // On se contente d'un setState() pour provoquer un rebuild :
    // le calcul du restant est fait dans build() a partir de
    // DateTime.now(), donc c'est toujours a jour.
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    // Nettoyer le timer pour eviter les fuites memoire :
    // si le widget est detache de l'arbre sans cancel(), le callback
    // continuerait a appeler setState sur un state disparu.
    _ticker?.cancel();
    super.dispose();
  }

  // =============================================================
  // METHODE : _format
  // =============================================================
  // Convertit une Duration en chaine "MM:SS" (toujours 2 chiffres).
  //
  // Pour une duree de 3 min 5 sec : "03:05"
  // Pour 0 sec : "00:00"
  //
  // padLeft(2, '0') ajoute un zero devant si le nombre < 10.
  // =============================================================

  /// Formate une duree en "MM:SS".
  String _format(Duration remaining) {
    final totalSeconds = remaining.inSeconds;
    final minutes = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    // On lit le profil. Si lives == maxLives, nextRefillAt vaut null
    // et on ne doit rien afficher.
    final profile = ref.watch(profileProvider);
    final next = profile.nextRefillAt;

    // Cas 1 : pas de refill prevu (vies pleines) -> widget invisible.
    // SizedBox.shrink() = 0x0 pixel, n'occupe pas de place dans le
    // layout, contrairement a Container() qui prend l'espace dispo.
    if (next == null) {
      // On reset le flag de reload pour le cycle suivant (quand les
      // vies redescendront sous le max).
      _reloadTriggered = false;
      return const SizedBox.shrink();
    }

    // Cas 2 : calcul du temps restant.
    // DateTime.now() est en local ; next est converti en local par
    // DateTime.parse. Le .difference() donne une Duration signee.
    final remaining = next.difference(DateTime.now());

    // Cas 3 : le countdown est ecoule (remaining negatif ou nul).
    // On declenche UNE FOIS un reload du profil : les vies devraient
    // etre a jour apres le prochain cycle pg_cron cote serveur.
    // Entre-temps, on affiche "00:00" pour eviter des chiffres negatifs.
    if (remaining.isNegative || remaining.inSeconds == 0) {
      if (!_reloadTriggered) {
        _reloadTriggered = true;
        // Appel fire-and-forget : on ne bloque pas l'UI.
        // ignore: unawaited_futures
        ref.read(profileProvider.notifier).reload();
      }
      return _renderBadge('00:00');
    }

    // Cas normal : on affiche le countdown formate.
    // Reset du flag car on est dans une periode active.
    _reloadTriggered = false;
    return _renderBadge(_format(remaining));
  }

  // =============================================================
  // WIDGET : _renderBadge
  // =============================================================
  // Rendu du badge "icone + texte" utilise dans les 2 cas d'affichage.
  // Factorise pour eviter de dupliquer le style.
  // =============================================================

  /// Rend le badge final (icone + texte) avec [text] au centre.
  Widget _renderBadge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: widget.color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.timer_outlined,
              color: widget.color, size: widget.iconSize),
          const SizedBox(width: 3),
          Text(
            text,
            style: TextStyle(
              color: widget.color,
              fontSize: widget.fontSize,
              fontWeight: FontWeight.w700,
              fontFeatures: const [FontFeature.tabularFigures()],
              // tabularFigures : les chiffres ont tous la meme largeur,
              // evite le "saut" visuel quand un 1 (etroit) devient un 0.
            ),
          ),
        ],
      ),
    );
  }
}

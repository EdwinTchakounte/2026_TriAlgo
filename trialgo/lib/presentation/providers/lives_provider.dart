// =============================================================
// FICHIER : lib/presentation/providers/lives_provider.dart
// ROLE   : Fournir le nombre de vies en temps reel via Supabase Realtime
// COUCHE : Presentation > Providers
// =============================================================
//
// CE QUE FAIT CE PROVIDER :
// -------------------------
// Les vies du joueur peuvent changer de DEUX facons :
//   1. Le joueur perd une vie (mauvaise reponse / timeout)
//   2. pg_cron recharge une vie toutes les 30 minutes (cote serveur)
//
// Pour le cas 2, l'app ne sait PAS quand la recharge se produit.
// On utilise Supabase REALTIME pour etre notifie automatiquement
// quand la colonne "lives" change en base de donnees.
//
// PATTERN : StreamProvider
// ------------------------
// Un StreamProvider ecoute un FLUX de donnees continu.
// Contrairement a un FutureProvider (une seule valeur),
// un StreamProvider recoit des mises a jour en permanence.
//
// Supabase Realtime envoie un evenement chaque fois que
// la ligne user_profiles du joueur est modifiee.
//
// REFERENCE : Recueil v3.0, section 8.5
// =============================================================

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trialgo/core/network/supabase_client.dart';

// =============================================================
// PROVIDER : livesProvider
// =============================================================
// "StreamProvider<int>" :
//   - "Stream" : flux de donnees continu (pas une seule valeur)
//   - "<int>" : le type de chaque valeur emise (nombre de vies)
//
// "(ref)" : la reference Riverpod pour acceder a d'autres providers.
//
// Le stream emet un int chaque fois que la colonne "lives"
// change en base de donnees.
//
// Utilisation dans un widget :
//   final livesAsync = ref.watch(livesProvider);
//   livesAsync.when(
//     data: (lives) => Text('$lives vies'),
//     loading: () => CircularProgressIndicator(),
//     error: (e, s) => Text('Erreur'),
//   );
//
// "when()" est le pattern MATCH de Riverpod pour les AsyncValue :
//   - data  : les donnees sont disponibles
//   - loading : en cours de chargement
//   - error : une erreur s'est produite
// =============================================================

/// Provider temps reel du nombre de vies du joueur.
///
/// Ecoute la table `user_profiles` via Supabase Realtime.
/// Emet une nouvelle valeur chaque fois que "lives" change.
final livesProvider = StreamProvider<int>((ref) {
  // Recuperer l'ID de l'utilisateur connecte.
  final userId = supabase.auth.currentUser?.id;

  // Si pas connecte, retourner un stream vide.
  // "Stream.value(0)" cree un stream qui emet UNE seule valeur (0)
  // puis se termine.
  if (userId == null) return Stream.value(0);

  // --- Supabase Realtime Stream ---
  // "supabase.from('user_profiles').stream(...)" :
  //   Cree un stream qui ecoute les modifications en temps reel.
  //
  // "primaryKey: ['id']" :
  //   Indique a Supabase quelle est la cle primaire de la table.
  //   Necessaire pour que le stream sache quelle ligne observer.
  //
  // ".eq('id', userId)" :
  //   Filtre : n'observer QUE la ligne de CE joueur.
  //   Sans ce filtre, on recevrait les modifications de TOUS les joueurs.
  //
  // ".map((data) => ...)" :
  //   Transforme chaque evenement du stream.
  //   "data" est une List<Map<String, dynamic>> contenant la/les ligne(s).
  //   On extrait la valeur de "lives" de la premiere (et seule) ligne.
  //
  // "data.first['lives']" :
  //   "data.first" : la premiere ligne de la liste
  //   "['lives']" : la colonne "lives" de cette ligne
  //   "as int" : cast explicite en int (car le type est dynamic)
  return supabase
      .from('user_profiles')
      .stream(primaryKey: ['id'])
      .eq('id', userId)
      .map((data) => data.isNotEmpty ? data.first['lives'] as int : 0);
  // "data.isNotEmpty ? ... : 0" :
  //   Si des donnees sont presentes -> extraire les vies
  //   Si la liste est vide (cas rare) -> retourner 0
});

// =============================================================
// FICHIER : lib/main.dart
// ROLE   : Point d'entree de l'application TRIALGO
// =============================================================
//
// MISE A JOUR CHAPITRE 5 :
// ------------------------
// L'ecran temporaire est remplace par un SYSTEME DE NAVIGATION
// base sur l'etat d'authentification (AuthState).
//
// L'ecran affiche depend du statut :
//   - initial/loading    -> splash screen (chargement)
//   - unauthenticated    -> AuthPage (connexion/inscription)
//   - needsActivation    -> ActivationPage (saisie du code)
//   - authenticated      -> ecran principal (menu, puis jeu)
//   - error              -> AuthPage avec message d'erreur
//
// C'est le PATTERN DE NAVIGATION PAR ETAT :
// au lieu de naviguer manuellement (Navigator.push), on change
// l'etat et l'interface se reconstruit automatiquement.
// =============================================================

// --- Imports Flutter ---
import 'package:flutter/material.dart';

// --- Import Riverpod ---
import 'package:flutter_riverpod/flutter_riverpod.dart';

// --- Import du client Supabase ---
import 'package:trialgo/core/network/supabase_client.dart';

// --- Import du provider d'authentification ---
import 'package:trialgo/presentation/providers/auth_provider.dart';

// --- Import Supabase pour le type User ---
import 'package:supabase_flutter/supabase_flutter.dart';

// --- Import des pages ---
import 'package:trialgo/presentation/pages/auth_page.dart';
import 'package:trialgo/presentation/pages/activation_page.dart';
import 'package:trialgo/presentation/pages/game_page.dart';

// =============================================================
// FONCTION MAIN
// =============================================================
// Meme structure qu'au chapitre 1 :
//   1. Initialiser le binding Flutter
//   2. Connecter a Supabase
//   3. Lancer l'app avec Riverpod
// =============================================================

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initSupabase();
  runApp(
    const ProviderScope(
      child: TrialgoApp(),
    ),
  );
}

// =============================================================
// WIDGET RACINE : TrialgoApp
// =============================================================
// Configure MaterialApp avec le theme et la navigation.
// Inchange par rapport au chapitre 1 sauf le "home" qui utilise
// maintenant _AuthGate au lieu de l'ecran temporaire.
// =============================================================

/// Widget racine de l'application TRIALGO.
class TrialgoApp extends StatelessWidget {
  const TrialgoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TRIALGO',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepOrange),
        useMaterial3: true,
      ),

      // _AuthGate decide quel ecran afficher selon l'etat d'auth.
      home: const _AuthGate(),
    );
  }
}

// =============================================================
// WIDGET : _AuthGate (le gardien d'authentification)
// =============================================================
// Ce widget ECOUTE l'etat d'authentification et AFFICHE
// l'ecran correspondant. C'est le "routeur" de l'application.
//
// Il utilise ConsumerWidget (pas ConsumerStatefulWidget) car
// il n'a PAS d'etat interne. Il se contente de lire le provider
// et d'afficher le bon ecran.
//
// "ConsumerWidget" :
//   - Equivalent de StatelessWidget mais avec acces a "ref"
//   - La methode build recoit (context, ref) au lieu de (context)
//   - "ref" permet de lire les providers Riverpod
// =============================================================

/// Gardien d'authentification : affiche l'ecran selon l'etat.
///
/// Ecoute [authProvider] et navigue automatiquement :
///   - Non connecte -> [AuthPage]
///   - Connecte sans code -> [ActivationPage]
///   - Connecte avec code -> ecran principal (menu)
class _AuthGate extends ConsumerWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // --- Lire l'etat d'authentification ---
    // "ref.watch(authProvider)" :
    //   - Lit l'AuthState actuel
    //   - Reconstruit _AuthGate quand l'etat change
    //   - Quand le status passe de "loading" a "authenticated",
    //     ce widget se reconstruit et affiche le nouvel ecran
    final authState = ref.watch(authProvider);

    // --- Choisir l'ecran selon le statut ---
    // "return switch (...)" : expression switch qui retourne une valeur.
    // Chaque cas retourne le widget a afficher.
    //
    // L'ENUM AuthStatus garantit que TOUS les cas sont geres.
    // Si on ajoute un nouveau statut, le compilateur signale
    // qu'il n'est pas gere ici (exhaustivite).
    return switch (authState.status) {
      // --- Chargement initial ---
      // L'app vient de demarrer, on verifie la session.
      // Affiche un splash screen minimaliste.
      AuthStatus.initial || AuthStatus.loading => const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Spinner de chargement.
              CircularProgressIndicator(),
              SizedBox(height: 16),
              // Message d'attente.
              Text('Chargement...'),
            ],
          ),
        ),
      ),
      // "||" dans un pattern switch : combine plusieurs cas.
      // "initial" OU "loading" -> meme ecran.

      // --- Non connecte ---
      // Affiche la page de connexion/inscription.
      AuthStatus.unauthenticated || AuthStatus.error => const AuthPage(),
      // "error" utilise aussi AuthPage car le message d'erreur
      // est affiche via un SnackBar (gere dans AuthPage).

      // --- Connecte, pas de code ---
      // Affiche la page de saisie du code d'activation.
      AuthStatus.needsActivation => const ActivationPage(),

      // --- Connecte et active ---
      // Affiche l'ecran principal (menu).
      // Pour l'instant, un ecran temporaire.
      AuthStatus.authenticated => _TemporaryMenuScreen(
        user: authState.user,
      ),
    };
  }
}

// =============================================================
// ECRAN TEMPORAIRE : Menu principal (sera remplace au chapitre 7)
// =============================================================
// Affiche un ecran de bienvenue avec le profil du joueur
// et un bouton de deconnexion.
// =============================================================

/// Ecran temporaire du menu principal.
///
/// Sera remplace par le vrai menu avec Jouer, Galerie, Classement, Parametres.
class _TemporaryMenuScreen extends ConsumerWidget {
  /// L'utilisateur connecte (peut etre null si erreur).
  final User? user;

  const _TemporaryMenuScreen({this.user});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('TRIALGO'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          // Bouton de deconnexion.
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Se deconnecter',
            onPressed: () {
              ref.read(authProvider.notifier).signOut();
            },
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.check_circle,
              size: 80,
              color: Colors.green[600],
            ),
            const SizedBox(height: 16),
            const Text(
              'Bienvenue dans TRIALGO !',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              user?.email ?? 'Joueur',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
            const SizedBox(height: 32),
            // Bouton "Jouer" -> ouvre l'ecran de jeu.
            ElevatedButton.icon(
              onPressed: () {
                // "Navigator.of(context).push" : ajoute un ecran SUR la pile.
                // "MaterialPageRoute" : transition Material Design.
                // "(context) => GamePage(...)" : construit l'ecran de jeu.
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => GamePage(
                      level: 1,  // TODO: lire le niveau reel du profil
                      lives: 5,  // TODO: lire les vies reelles
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.play_arrow),
              label: const Text('Jouer'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Chapitres 1-5 termines.\nProchaine etape : le jeu.',
              style: TextStyle(fontSize: 12, color: Colors.grey[400]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

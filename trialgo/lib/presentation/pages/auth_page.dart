// =============================================================
// FICHIER : lib/presentation/pages/auth_page.dart
// ROLE   : Ecran de connexion et d'inscription
// COUCHE : Presentation > Pages
// =============================================================
//
// CET ECRAN AFFICHE :
// -------------------
//   1. Le logo TRIALGO en haut
//   2. Deux champs de saisie (email et mot de passe)
//   3. Un bouton "Se connecter" (connexion email)
//   4. Un bouton "Creer un compte" (inscription)
//   5. Un separateur "ou"
//   6. Un bouton "Continuer avec Google" (OAuth)
//   7. Un message d'erreur si besoin
//
// WIDGET RIVERPOD :
// -----------------
// Cette page utilise ConsumerStatefulWidget au lieu de StatefulWidget.
//
// Pourquoi ConsumerStatefulWidget ?
//   - "Consumer" : donne acces a "ref" pour lire les providers Riverpod
//   - "Stateful" : permet d'avoir un State interne (controllers de texte)
//
// Les controllers de texte (TextEditingController) ont besoin d'un
// State car ils doivent etre crees une fois et liberes a la destruction.
// C'est pourquoi on utilise Stateful et non Stateless.
//
// REFERENCE : Recueil de conception v3.0, sections 12.3 et 13.1
// =============================================================

import 'package:flutter/material.dart';
// Material.dart fournit tous les widgets Material Design :
// Scaffold, AppBar, TextField, ElevatedButton, TextButton, etc.

import 'package:flutter_riverpod/flutter_riverpod.dart';
// Pour ConsumerStatefulWidget et ConsumerState.

import 'package:trialgo/presentation/providers/auth_provider.dart';
// Pour authProvider : l'etat d'authentification.

/// Page de connexion et d'inscription de TRIALGO.
///
/// Affiche un formulaire email/mot de passe avec les options
/// de connexion, inscription et Google OAuth.
///
/// "ConsumerStatefulWidget" :
///   - "Consumer" -> acces a ref (Riverpod)
///   - "Stateful" -> peut avoir un State interne (controllers)
///   - Combine les avantages des deux
class AuthPage extends ConsumerStatefulWidget {
  // "const" : le widget peut etre cree comme constante.
  // "super.key" : cle unique pour le recycling Flutter.
  const AuthPage({super.key});

  // =============================================================
  // createState()
  // =============================================================
  // Methode obligatoire d'un StatefulWidget.
  // Elle cree l'objet State associe a ce widget.
  //
  // Flutter appelle createState() UNE SEULE FOIS quand le widget
  // est insere dans l'arbre. Le State persiste meme quand le
  // widget est reconstruit (rebuild).
  //
  // "=>" est le raccourci pour : { return _AuthPageState(); }
  // =============================================================

  @override
  ConsumerState<AuthPage> createState() => _AuthPageState();
  // "_AuthPageState" : le "_" rend la classe privee (meme fichier uniquement).
  // C'est une convention : le State n'est utilise que par son widget.
}

// =============================================================
// STATE : _AuthPageState
// =============================================================
// Contient :
//   - Les controllers de texte (email, mot de passe)
//   - Un booleen pour basculer entre connexion et inscription
//   - Un booleen pour masquer/afficher le mot de passe
//   - La methode build() qui construit l'interface
//
// "ConsumerState<AuthPage>" :
//   - "ConsumerState" : State avec acces a ref (Riverpod)
//   - "<AuthPage>" : lie ce State au widget AuthPage
// =============================================================

class _AuthPageState extends ConsumerState<AuthPage> {

  // =============================================================
  // CONTROLLERS DE TEXTE
  // =============================================================
  // "TextEditingController" : controleur pour un champ de saisie.
  //
  // Il permet de :
  //   - Lire le texte saisi : controller.text
  //   - Modifier le texte : controller.text = "nouveau texte"
  //   - Ecouter les changements : controller.addListener(...)
  //   - Effacer le texte : controller.clear()
  //
  // IMPORTANT : les controllers doivent etre LIBERES (dispose)
  // quand le widget est detruit, sinon il y a une FUITE MEMOIRE.
  // C'est pourquoi on les cree dans un StatefulWidget (qui a dispose).
  // =============================================================

  /// Controleur pour le champ email.
  /// Stocke et fournit le texte saisi par l'utilisateur.
  final _emailController = TextEditingController();

  /// Controleur pour le champ mot de passe.
  final _passwordController = TextEditingController();

  // =============================================================
  // VARIABLES D'ETAT LOCAL
  // =============================================================
  // Ces variables controlent l'apparence du formulaire.
  // Elles sont dans le STATE (pas dans le provider) car elles
  // ne concernent que CET ecran, pas le reste de l'application.
  // =============================================================

  /// `true` si on est en mode inscription, `false` si connexion.
  /// Bascule quand l'utilisateur tape sur "Creer un compte" / "Se connecter".
  bool _isSignUp = false;

  /// `true` si le mot de passe est masque (affiche des points).
  /// Bascule quand l'utilisateur tape sur l'icone oeil.
  bool _obscurePassword = true;

  // =============================================================
  // DISPOSE : liberer les ressources
  // =============================================================
  // "dispose()" est appele par Flutter quand le widget est
  // DEFINITIVEMENT supprime de l'arbre (pas juste un rebuild).
  //
  // C'est ici qu'on libere les ressources qui ne se liberent
  // pas automatiquement :
  //   - TextEditingController (ecouteurs internes)
  //   - AnimationController
  //   - StreamSubscription
  //   - Timer
  //
  // "super.dispose()" : appelle le dispose de la classe parente.
  // DOIT etre appele EN DERNIER (apres nos liberations).
  // =============================================================

  @override
  void dispose() {
    // Libere les controllers pour eviter les fuites memoire.
    _emailController.dispose();
    _passwordController.dispose();
    // Appelle le dispose parent (obligatoire).
    super.dispose();
  }

  // =============================================================
  // BUILD : construction de l'interface
  // =============================================================
  // Methode appelee par Flutter pour "dessiner" le widget.
  // Appelee :
  //   - Une premiere fois quand le widget est cree
  //   - A chaque appel de setState() (changement d'etat local)
  //   - A chaque changement de provider observe par ref.watch()
  //
  // IMPORTANT : build() doit etre RAPIDE et PURE.
  //   - Pas d'appel reseau dans build()
  //   - Pas d'effets de bord (logs, ecriture fichier)
  //   - Juste construire et retourner un arbre de widgets
  // =============================================================

  @override
  Widget build(BuildContext context) {
    // --- Lire l'etat d'authentification ---
    // "ref.watch(authProvider)" :
    //   - Lit l'AuthState actuel
    //   - Reconstruit CE widget quand l'AuthState change
    //   - Retourne un AuthState (status, user, errorMessage)
    final authState = ref.watch(authProvider);

    // --- Afficher une erreur si besoin ---
    // "ref.listen" ecoute les changements SANS reconstruire.
    // Ideal pour les effets de bord (afficher un dialog, naviguer).
    //
    // On utilise listen pour les ERREURS car on veut afficher
    // un SnackBar (notification temporaire en bas de l'ecran)
    // une seule fois, pas a chaque rebuild.
    ref.listen<AuthState>(authProvider, (previous, next) {
      // "previous" : l'ancien etat (avant le changement)
      // "next" : le nouvel etat (apres le changement)

      if (next.status == AuthStatus.error && next.errorMessage != null) {
        // Affiche un SnackBar avec le message d'erreur.
        //
        // "ScaffoldMessenger.of(context)" : acces au systeme de SnackBars
        //   du Scaffold le plus proche dans l'arbre.
        //
        // "SnackBar" : notification temporaire en bas de l'ecran.
        //   content : le contenu affiche (ici un Text)
        //   backgroundColor : couleur de fond (rouge pour les erreurs)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.errorMessage!),
            backgroundColor: Colors.red[700],
          ),
        );
        // Efface l'erreur apres l'avoir affichee.
        ref.read(authProvider.notifier).clearError();
      }
    });

    // --- Construction de l'ecran ---
    return Scaffold(
      // "backgroundColor" : couleur de fond de l'ecran.
      backgroundColor: Theme.of(context).colorScheme.surface,

      // "body" : le contenu principal de l'ecran.
      // "SafeArea" : ajoute des marges pour eviter les encoches
      //   (notch iPhone, barre de statut, barre de navigation).
      body: SafeArea(
        // "Center" : centre son enfant au milieu de l'ecran.
        child: Center(
          // "SingleChildScrollView" : permet de scroller si le contenu
          //   depasse la taille de l'ecran (clavier ouvert, petit ecran).
          child: SingleChildScrollView(
            // "Padding" : ajoute des marges internes autour du contenu.
            //   "EdgeInsets.all(24)" : 24 pixels de marge de chaque cote.
            padding: const EdgeInsets.all(24),

            // "Column" : empile les enfants verticalement.
            child: Column(
              // "mainAxisAlignment" : comment aligner les enfants
              //   sur l'axe principal (vertical pour une Column).
              //   "center" : centre les enfants verticalement.
              mainAxisAlignment: MainAxisAlignment.center,

              // "children" : la liste des widgets enfants, de haut en bas.
              children: [
                // --- LOGO ---
                // Icone de cartes de jeu representant TRIALGO.
                Icon(
                  Icons.style, // Icone de cartes empilees
                  size: 80,    // 80 pixels de cote
                  color: Theme.of(context).colorScheme.primary,
                  // "Theme.of(context).colorScheme.primary" :
                  //   Recupere la couleur primaire du theme (deepOrange).
                  //   "Theme.of(context)" lit le theme defini dans MaterialApp.
                ),

                const SizedBox(height: 16),
                // "SizedBox" : boite invisible de taille fixe.
                // Utilisee comme ESPACEUR entre deux widgets.
                // Plus lisible qu'un Padding ou un margin.

                // --- TITRE ---
                Text(
                  'TRIALGO',
                  style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  // "Theme.of(context).textTheme.headlineLarge" :
                  //   Style de texte predefini (grande taille).
                  // "?.copyWith(...)" : modifie le style (gras + couleur).
                  //   "?." : appel conditionnel (si le style est null, on ne modifie rien).
                ),

                const SizedBox(height: 8),

                // --- SOUS-TITRE ---
                Text(
                  _isSignUp ? 'Creer un compte' : 'Se connecter',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),

                const SizedBox(height: 32),

                // --- CHAMP EMAIL ---
                // "TextField" : champ de saisie de texte.
                TextField(
                  // "controller" : lie le champ au controller.
                  // Chaque caractere tape est stocke dans _emailController.text.
                  controller: _emailController,

                  // "decoration" : apparence du champ (placeholder, icone, bordure).
                  decoration: const InputDecoration(
                    labelText: 'Email',            // Label flottant au-dessus
                    hintText: 'joueur@example.com', // Texte grise de suggestion
                    prefixIcon: Icon(Icons.email),  // Icone a gauche
                    border: OutlineInputBorder(),    // Bordure rectangulaire
                  ),

                  // "keyboardType" : type de clavier affiche.
                  // "emailAddress" : clavier avec @ et .com facilement accessibles.
                  keyboardType: TextInputType.emailAddress,

                  // "textInputAction" : bouton d'action du clavier.
                  // "next" : affiche un bouton "Suivant" qui passe au champ suivant.
                  textInputAction: TextInputAction.next,
                ),

                const SizedBox(height: 16),

                // --- CHAMP MOT DE PASSE ---
                TextField(
                  controller: _passwordController,
                  decoration: InputDecoration(
                    labelText: 'Mot de passe',
                    hintText: 'Minimum 8 caracteres',
                    prefixIcon: const Icon(Icons.lock),
                    border: const OutlineInputBorder(),

                    // "suffixIcon" : icone a DROITE du champ.
                    // Ici, un bouton oeil pour afficher/masquer le mot de passe.
                    suffixIcon: IconButton(
                      // "icon" : l'icone affichee (oeil ouvert ou barre).
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off // Oeil barre (mdp masque)
                            : Icons.visibility,    // Oeil ouvert (mdp visible)
                      ),
                      // "onPressed" : appele quand on tape sur l'icone.
                      onPressed: () {
                        // "setState" : signale a Flutter que l'etat local a change.
                        // Flutter reconstruira CE widget (pas les autres).
                        //
                        // "() { ... }" est la CALLBACK : le code execute dans setState.
                        // On inverse le booleen : masque -> visible -> masque -> ...
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                          // "!" inverse un booleen : true -> false, false -> true
                        });
                      },
                    ),
                  ),

                  // "obscureText" : si true, les caracteres sont remplaces par des points.
                  // Lie a _obscurePassword pour basculer dynamiquement.
                  obscureText: _obscurePassword,

                  // "textInputAction.done" : bouton "Termine" sur le clavier.
                  textInputAction: TextInputAction.done,
                ),

                const SizedBox(height: 24),

                // --- BOUTON PRINCIPAL (Connexion ou Inscription) ---
                // "SizedBox" avec width: double.infinity :
                //   Force le bouton a prendre toute la largeur disponible.
                //   "double.infinity" = la plus grande valeur possible.
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    // "onPressed" : callback appele quand on tape le bouton.
                    //
                    // Si l'etat est "loading" (requete en cours), on passe null.
                    // Un ElevatedButton avec onPressed = null est DESACTIVE
                    // (grise, non cliquable). Empeche le double-tap.
                    onPressed: authState.status == AuthStatus.loading
                        ? null  // Bouton desactive pendant le chargement
                        : _onSubmit, // Sinon, appelle notre methode
                    child: authState.status == AuthStatus.loading
                        // Si chargement : affiche un spinner dans le bouton.
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        // Sinon : affiche le texte du bouton.
                        : Text(_isSignUp ? 'Creer un compte' : 'Se connecter'),
                  ),
                ),

                const SizedBox(height: 12),

                // --- LIEN BASCULE (Inscription <-> Connexion) ---
                // "TextButton" : bouton texte sans fond (juste le texte cliquable).
                TextButton(
                  onPressed: () {
                    setState(() {
                      _isSignUp = !_isSignUp; // Bascule entre les modes
                    });
                  },
                  child: Text(
                    _isSignUp
                        ? 'Deja un compte ? Se connecter'
                        : 'Pas de compte ? Creer un compte',
                  ),
                ),

                const SizedBox(height: 16),

                // --- SEPARATEUR "OU" ---
                // Une ligne horizontale avec "ou" au milieu.
                Row(
                  children: [
                    // "Expanded" : prend tout l'espace disponible.
                    // Ici, la ligne s'etend a gauche et a droite du "ou".
                    const Expanded(child: Divider()),
                    // "Divider" : ligne horizontale grise.

                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      // "symmetric" : marge horizontale de 16px de chaque cote.
                      child: Text(
                        'ou',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ),
                    const Expanded(child: Divider()),
                  ],
                ),

                const SizedBox(height: 16),

                // --- BOUTON GOOGLE ---
                // "OutlinedButton" : bouton avec bordure, sans fond.
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    // ".icon" : variante qui ajoute une icone a gauche du texte.
                    onPressed: authState.status == AuthStatus.loading
                        ? null
                        : () {
                            // Appelle la methode signInWithGoogle du notifier.
                            ref.read(authProvider.notifier).signInWithGoogle();
                          },
                    icon: const Icon(Icons.g_mobiledata, size: 24),
                    // Icons.g_mobiledata : icone "G" (pas le vrai logo Google
                    // car il est soumis a copyright — on utilise un placeholder).
                    label: const Text('Continuer avec Google'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // =============================================================
  // METHODE PRIVEE : _onSubmit
  // =============================================================
  // Appelee quand l'utilisateur tape le bouton principal.
  // Valide les champs puis appelle signUp ou signIn selon le mode.
  // =============================================================

  /// Valide les champs et lance la connexion ou l'inscription.
  void _onSubmit() {
    // ".trim()" : supprime les espaces au debut et a la fin.
    // Evite les erreurs dues a un espace accidentel.
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    // --- Validation locale ---
    // On verifie les champs AVANT d'envoyer une requete reseau.
    // C'est plus rapide et evite un appel inutile.
    //
    // "email.isEmpty" : true si la chaine est vide (aucun caractere).
    if (email.isEmpty || password.isEmpty) {
      // Affiche un SnackBar d'avertissement.
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez remplir tous les champs')),
      );
      return; // Sort de la methode (pas d'appel reseau).
    }

    // Validation du mot de passe (minimum 8 caracteres).
    if (password.length < 8) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Minimum 8 caracteres pour le mot de passe')),
      );
      return;
    }

    // --- Appel au provider ---
    // "ref.read(authProvider.notifier)" : acces aux methodes du notifier.
    // On utilise "read" et non "watch" car on est dans un callback
    // (pas dans build). "watch" ne doit etre utilise que dans build.
    if (_isSignUp) {
      ref.read(authProvider.notifier).signUp(email, password);
    } else {
      ref.read(authProvider.notifier).signIn(email, password);
    }
  }
}

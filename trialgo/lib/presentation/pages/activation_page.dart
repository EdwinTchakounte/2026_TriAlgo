// =============================================================
// FICHIER : lib/presentation/pages/activation_page.dart
// ROLE   : Ecran de saisie du code d'activation physique
// COUCHE : Presentation > Pages
// =============================================================
//
// CET ECRAN S'AFFICHE QUAND :
// ---------------------------
// L'utilisateur est connecte (Supabase Auth) mais n'a pas encore
// saisi de code d'activation. C'est l'ecran OBLIGATOIRE entre
// la connexion et le menu principal.
//
// FONCTIONNEMENT :
// ----------------
//   1. L'utilisateur saisit le code imprime dans sa boite de jeu
//      (format : "TRLG-4X9K-2M7P", 16 caracteres alphanumeriques)
//   2. L'app recupere le Device ID (identifiant unique du telephone)
//   3. L'app envoie le code + user_id + device_id a l'Edge Function
//   4. Le serveur verifie et active le code
//   5. Si succes -> redirection vers le menu principal
//
// REFERENCE : Recueil de conception v3.0, sections 10 et 12.4
// =============================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Import du usecase d'activation.
import 'package:trialgo/domain/usecases/activate_code_usecase.dart';

// Import du client Supabase pour obtenir le user ID.
import 'package:trialgo/core/network/supabase_client.dart';

// Import des erreurs structurees.
import 'package:trialgo/core/error/failures.dart';

// Import du provider d'authentification pour la redirection.
import 'package:trialgo/presentation/providers/auth_provider.dart';

/// Page de saisie du code d'activation physique.
///
/// L'utilisateur doit saisir le code imprime dans la boite du jeu.
/// Le code est verifie cote serveur (Edge Function) et lie
/// a l'appareil de l'utilisateur.
class ActivationPage extends ConsumerStatefulWidget {
  const ActivationPage({super.key});

  @override
  ConsumerState<ActivationPage> createState() => _ActivationPageState();
}

class _ActivationPageState extends ConsumerState<ActivationPage> {
  /// Controller pour le champ de saisie du code.
  final _codeController = TextEditingController();

  /// Indique si une requete d'activation est en cours.
  /// Utilise pour afficher un spinner et desactiver le bouton.
  bool _isLoading = false;

  /// Message d'erreur a afficher sous le champ de saisie.
  /// Null si pas d'erreur.
  String? _errorMessage;

  /// Message de succes a afficher.
  /// Null si pas encore active.
  String? _successMessage;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // --- Barre du haut ---
      appBar: AppBar(
        title: const Text('Activation du jeu'),
        // Pas de bouton retour : l'utilisateur DOIT activer un code.
        // "automaticallyImplyLeading: false" empeche Flutter d'ajouter
        // automatiquement un bouton retour.
        automaticallyImplyLeading: false,

        // Bouton de deconnexion a droite.
        // "actions" : liste de widgets affiches a droite dans l'AppBar.
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            // "tooltip" : texte affiche quand on maintient le bouton.
            tooltip: 'Se deconnecter',
            onPressed: () {
              // Deconnecte l'utilisateur et retourne a l'ecran de connexion.
              ref.read(authProvider.notifier).signOut();
            },
          ),
        ],
      ),

      // --- Corps de l'ecran ---
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            // "crossAxisAlignment" : alignement sur l'axe SECONDAIRE.
            // Pour une Column (axe principal = vertical),
            // l'axe secondaire est HORIZONTAL.
            // "stretch" : etire les enfants sur toute la largeur.
            crossAxisAlignment: CrossAxisAlignment.stretch,

            children: [
              const SizedBox(height: 40),

              // --- Icone ---
              Icon(
                Icons.vpn_key, // Icone de cle
                size: 64,
                color: Theme.of(context).colorScheme.primary,
              ),

              const SizedBox(height: 24),

              // --- Titre ---
              Text(
                'Entrez votre code de jeu',
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
                // "textAlign" : alignement du texte dans son espace.
                // "center" : centre le texte horizontalement.
              ),

              const SizedBox(height: 8),

              // --- Description ---
              Text(
                'Le code se trouve a l\'interieur de votre boite de jeu TRIALGO.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
                // "l\'" : le "\" est un caractere d'ECHAPPEMENT.
                // Il permet d'inclure une apostrophe dans une chaine
                // delimitee par des apostrophes.
                // Sans le "\", Dart penserait que la chaine se termine a "l'".
              ),

              const SizedBox(height: 32),

              // --- Champ de saisie du code ---
              TextField(
                controller: _codeController,
                decoration: InputDecoration(
                  labelText: 'Code d\'activation',
                  hintText: 'TRLG-4X9K-2M7P',
                  prefixIcon: const Icon(Icons.confirmation_number),
                  border: const OutlineInputBorder(),
                  // "errorText" : affiche un texte d'erreur SOUS le champ.
                  // Si null, rien n'est affiche.
                  // Si non-null, le champ passe en rouge avec le message.
                  errorText: _errorMessage,
                ),
                // "textCapitalization" : met automatiquement en majuscules.
                // "characters" : chaque caractere est mis en majuscule.
                // Les codes d'activation sont en majuscules (A-Z, 0-9).
                textCapitalization: TextCapitalization.characters,
                // "maxLength" : nombre maximum de caracteres autorise.
                // 16 = longueur du code (incluant les tirets).
                maxLength: 16,
                textInputAction: TextInputAction.done,
              ),

              const SizedBox(height: 16),

              // --- Message de succes ---
              // Affiche un message vert si l'activation a reussi.
              if (_successMessage != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle, color: Colors.green),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _successMessage!,
                          style: const TextStyle(color: Colors.green),
                        ),
                      ),
                    ],
                  ),
                ),
              // "if (...) Widget" : affichage CONDITIONNEL dans une liste.
              // Dart permet d'utiliser if directement dans la liste children.
              // Si la condition est false, le widget n'est PAS ajoute a la liste.
              // C'est plus propre que d'utiliser Visibility ou Offstage.

              const SizedBox(height: 24),

              // --- Bouton d'activation ---
              ElevatedButton(
                onPressed: _isLoading ? null : _onActivate,
                // null si chargement -> bouton desactive (grise).
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  // "styleFrom" : cree un style personnalise.
                  // "padding" : espace interieur du bouton.
                  // "symmetric(vertical: 16)" : 16px en haut et en bas.
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Activer mon code'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // =============================================================
  // METHODE : _onActivate
  // =============================================================
  // Appelee quand l'utilisateur tape le bouton "Activer mon code".
  //
  // Flux :
  //   1. Valide le format du code localement
  //   2. Recupere le Device ID
  //   3. Appelle le usecase ActivateCodeUseCase
  //   4. Si succes -> affiche le message + redirige
  //   5. Si erreur -> affiche le message d'erreur
  // =============================================================

  /// Lance le processus d'activation du code.
  Future<void> _onActivate() async {
    // --- Recuperer et nettoyer le code saisi ---
    // ".trim()" : supprime les espaces au debut et a la fin.
    // ".toUpperCase()" : convertit en majuscules (les codes sont en majuscules).
    final code = _codeController.text.trim().toUpperCase();

    // --- Validation basique ---
    if (code.isEmpty) {
      setState(() {
        _errorMessage = 'Veuillez saisir votre code';
      });
      return;
    }

    // --- Demarrer le chargement ---
    setState(() {
      _isLoading = true;
      _errorMessage = null;      // Efface l'erreur precedente
      _successMessage = null;    // Efface le message de succes
    });

    try {
      // --- Recuperer le User ID ---
      // "supabase.auth.currentUser!.id" :
      //   - currentUser : l'utilisateur connecte (User?)
      //   - "!" : affirme qu'il n'est pas null (on est connecte)
      //   - .id : l'UUID de l'utilisateur
      final userId = supabase.auth.currentUser!.id;

      // --- Recuperer le Device ID ---
      // Pour l'instant, on utilise un placeholder.
      // L'implementation reelle utilise device_info_plus
      // pour obtenir l'identifiant unique de l'appareil.
      //
      // Android : androidId
      // iOS     : identifierForVendor
      final deviceId = 'device-${DateTime.now().millisecondsSinceEpoch}';
      // TODO: Remplacer par le vrai Device ID (device_info_plus)

      // --- Appeler le usecase ---
      // Cree une instance du usecase et l'appelle.
      // Le usecase :
      //   1. Valide le format du code (regex)
      //   2. Appelle l'Edge Function activate-code
      //   3. Retourne un ActivationResult ou leve une Failure
      final usecase = ActivateCodeUseCase();
      final result = await usecase.call(
        codeValue: code,
        userId: userId,
        deviceId: deviceId,
      );

      // --- Succes ---
      if (result.success) {
        setState(() {
          _successMessage = result.message;
          _isLoading = false;
        });

        // Attendre 1.5 secondes pour que l'utilisateur voie le message.
        // "Future.delayed" cree un Future qui se complete apres le delai.
        // "Duration(milliseconds: 1500)" : 1.5 secondes.
        await Future.delayed(const Duration(milliseconds: 1500));

        // Rediriger : forcer la re-verification de l'authentification.
        // Le _checkActivation va passer l'etat en "authenticated".
        if (mounted) {
          // "mounted" : propriete du State qui vaut true si le widget
          // est encore dans l'arbre. Si l'utilisateur a quitte l'ecran
          // pendant le delai, mounted = false et on ne fait rien.
          // C'est une SECURITE : modifier le state d'un widget dispose
          // cause une exception.
          ref.read(authProvider.notifier).signIn(
            supabase.auth.currentUser!.email!,
            '', // Le password n'est pas necessaire ici car la session est deja active
          );
        }
      }

    } on ActivationFailure catch (e) {
      // Erreur specifique a l'activation (code invalide, autre appareil).
      setState(() {
        _errorMessage = e.message;
        _isLoading = false;
      });
    } on Failure catch (e) {
      // Erreur generique (reseau, serveur).
      setState(() {
        _errorMessage = e.message;
        _isLoading = false;
      });
    } catch (e) {
      // Erreur imprevue.
      setState(() {
        _errorMessage = 'Erreur inattendue. Veuillez reessayer.';
        _isLoading = false;
      });
    }
  }
}

// =============================================================
// FICHIER : lib/presentation/wireframes/t_locale.dart
// ROLE   : Systeme d'internationalisation FR/EN pour le wireframe
// COUCHE : Presentation > Wireframes (sera migre dans Core)
// =============================================================
//
// POURQUOI CE FICHIER ?
// ---------------------
// TRIALGO doit supporter au minimum 2 langues :
//   - Francais (FR) : langue par defaut
//   - Anglais (EN)  : pour l'audience internationale
//
// ARCHITECTURE :
// --------------
// On utilise un pattern simple de Map<String, String> par locale.
// Chaque cle est un identifiant unique (ex: 'home.play').
// La valeur est la traduction dans la langue cible.
//
// Ce pattern sera remplace par flutter_localizations + intl
// avec generation ARB dans la version finale. Pour le wireframe,
// cette approche legere suffit et respecte le principe de
// separation des preoccupations de la Clean Architecture.
//
// USAGE :
//   final tr = TLocale.of(context);
//   Text(tr('home.play'))  // -> "JOUER" ou "PLAY"
// =============================================================

import 'package:flutter/material.dart';

/// Enumeration des langues supportees.
///
/// Chaque valeur correspond a un code ISO 639-1 :
///   fr = francais, en = anglais.
enum AppLanguage {
  /// Francais (langue par defaut).
  fr,
  /// Anglais.
  en,
}

/// Systeme de traduction du wireframe TRIALGO.
///
/// Fournit toutes les chaines de caracteres traduites
/// accessibles via une cle unique.
///
/// PATTERN D'ACCES :
/// ```dart
/// // Depuis n'importe quel widget :
/// final tr = TLocale.of(context);
/// Text(tr('home.play'))  // "JOUER" en FR, "PLAY" en EN
/// ```
class TLocale extends InheritedWidget {
  /// Langue courante de l'application.
  final AppLanguage language;

  const TLocale({
    required this.language,
    required super.child,
    super.key,
  });

  /// Recupere l'instance TLocale depuis le contexte.
  ///
  /// Utilisation : `TLocale.of(context)` retourne une fonction
  /// de traduction : `String Function(String key)`
  ///
  /// Exemple :
  /// ```dart
  /// final tr = TLocale.of(context);
  /// Text(tr('home.play'))
  /// ```
  static String Function(String key) of(BuildContext context) {
    final locale = context.dependOnInheritedWidgetOfExactType<TLocale>()!;
    final strings = locale.language == AppLanguage.fr ? _fr : _en;
    return (String key) => strings[key] ?? key;
    // Si la cle n'est pas trouvee, on retourne la cle elle-meme.
    // Cela evite les crashes et facilite le debug.
  }

  /// Recupere la langue courante depuis le contexte.
  static AppLanguage languageOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<TLocale>()!.language;
  }

  @override
  bool updateShouldNotify(TLocale oldWidget) {
    return language != oldWidget.language;
    // Reconstruit les widgets enfants seulement si la langue change.
  }

  // ---------------------------------------------------------------
  // TRADUCTIONS FRANCAISES
  // ---------------------------------------------------------------
  static const Map<String, String> _fr = {
    // --- Splash ---
    'splash.subtitle': 'LE JEU DES TRANSFORMATIONS VISUELLES',
    'splash.loading': 'Chargement',

    // --- Auth ---
    'auth.welcome_back': 'Bon retour parmi nous !',
    'auth.join': 'Rejoignez l\'aventure',
    'auth.email': 'Email',
    'auth.password': 'Mot de passe',
    'auth.login': 'Se connecter',
    'auth.signup': 'Creer mon compte',
    'auth.or': 'ou',
    'auth.google': 'Continuer avec Google',
    'auth.no_account': 'Pas de compte ? ',
    'auth.has_account': 'Deja un compte ? ',
    'auth.signup_link': 'S\'inscrire',
    'auth.login_link': 'Se connecter',

    // --- Activation ---
    'activation.title': 'Activez votre jeu',
    'activation.desc': 'Entrez le code unique qui se trouve\ndans votre boite de jeu TRIALGO',
    'activation.hint': 'TRLG-XXXX-XXXX-XXXX',
    'activation.format': 'Format : TRLG-XXXX-XXXX-XXXX',
    'activation.button': 'Activer mon jeu',
    'activation.success': 'Jeu active avec succes !',

    // --- Home ---
    'home.play': 'JOUER',
    'home.tagline_small': 'TRIALGO',
    'home.tagline_big': 'Observe. Deduis. Gagne.',
    'home.tutorial': 'Tutoriel',
    'home.tutorial_desc': 'Apprendre',
    'home.gallery': 'Galerie',
    'home.gallery_desc': 'cartes',
    'home.leaderboard': 'Classement',
    'home.leaderboard_desc': 'mondial',
    'home.profile': 'Profil',
    'home.games': 'Parties',
    'home.accuracy': 'Precision',
    'home.streak': 'Serie',
    'home.next_life': '+1 dans',
    'home.min': 'min',
    'home.instr_observe': 'Observe les cartes du trio',
    'home.instr_find': 'Trouve la carte manquante',
    'home.instr_tap': 'Tap la carte du jeu pour commencer',
    'home.instr_zoom': 'Double-tap pour zoomer une carte',

    // --- Onboarding (premier login) ---
    'onb.skip': 'Passer',
    'onb.next': 'Suivant',
    'onb.start': 'Commencer',
    'onb.1_title': 'Bienvenue sur TRIALGO',
    'onb.1_body': 'Le jeu d\'observation ou chaque carte compte. Prouve ta logique.',
    'onb.2_title': 'Le trio magique',
    'onb.2_body': 'Emettrice + Cable = Receptrice. Trouve la carte manquante pour gagner.',
    'onb.3_title': 'Observe et deduis',
    'onb.3_body': 'Tap une carte pour repondre. Double-tap pour la voir en grand.',
    'onb.4_title': 'Pret a jouer ?',
    'onb.4_body': 'Gagne des points, debloque de nouveaux niveaux. L\'aventure commence.',

    // --- Game ---
    'game.question': 'Quelle image complete ce trio ?',
    'game.choose': 'Choisissez la bonne image',
    'game.scroll': 'Defiler',
    'game.correct': 'Correct !',
    'game.incorrect': 'Incorrect...',
    'game.timeout': 'Temps ecoule !',
    'game.question_of': 'Question',
    'game.streak_label': 'Serie',
    'game.quit_title': 'Quitter la partie ?',
    'game.quit_desc': 'Votre progression sur ce niveau sera perdue.',
    'game.continue': 'Continuer',
    'game.quit': 'Quitter',
    'game.trio': 'TRIO',
    'game.emettrice': 'Emettrice',
    'game.cable': 'Cable',
    'game.receptrice': 'Receptrice',

    // --- Results ---
    'result.success': 'Niveau reussi !',
    'result.failed': 'Niveau echoue',
    'result.congrats': 'Bravo ! Continuez votre progression.',
    'result.retry_msg': 'Courage, reessayez !',
    'result.score': 'Score',
    'result.correct': 'Bonnes reponses',
    'result.accuracy': 'Precision',
    'result.max_streak': 'Serie max',
    'result.next_level': 'Niveau suivant',
    'result.retry': 'Reessayer',
    'result.home': 'Retour au menu',

    // --- Settings ---
    'settings.title': 'Parametres',
    'settings.audio': 'AUDIO',
    'settings.sounds': 'Effets sonores',
    'settings.sounds_desc': 'Sons d\'interaction',
    'settings.music': 'Musique',
    'settings.music_desc': 'Musique de fond',
    'settings.notif': 'NOTIFICATIONS',
    'settings.notif_lives': 'Recharge de vies',
    'settings.notif_desc': 'Alertes quand vies rechargees',
    'settings.account': 'COMPTE',
    'settings.edit_pseudo': 'Modifier le pseudo',
    'settings.edit_avatar': 'Changer l\'avatar',
    'settings.no_avatar': 'Aucun configure',
    'settings.about': 'A PROPOS',
    'settings.version': 'Version',
    'settings.legal': 'Mentions legales',
    'settings.legal_desc': 'CGU & confidentialite',
    'settings.help': 'Aide & FAQ',
    'settings.help_desc': 'Comment jouer',
    'settings.logout': 'Se deconnecter',
    'settings.logout_confirm': 'Vous devrez vous reconnecter pour jouer.',
    'settings.logout_action': 'Deconnexion',
    'settings.cancel': 'Annuler',
    'settings.delete_account': 'Supprimer mon compte',
    'settings.language': 'LANGUE',
    'settings.lang_fr': 'Francais',
    'settings.lang_en': 'English',
    'settings.theme': 'APPARENCE',
    'settings.dark_mode': 'Mode sombre',
    'settings.light_mode': 'Mode clair',

    // --- Tutorial ---
    'tuto.title': 'Tutoriel',
    'tuto.next': 'Suivant',
    'tuto.done': 'Compris !',
    'tuto.principle': 'Le principe fondamental',
    'tuto.card_types': 'Les 3 types de cartes',
    'tuto.how_to_play': 'Comment jouer ?',
    'tuto.progress': 'Progressez !',

    // --- Gallery ---
    'gallery.title': 'Galerie',
    'gallery.unlocked': 'de la collection debloquee',

    // --- Leaderboard ---
    'leaderboard.title': 'Classement',

    // --- Profile ---
    'profile.title': 'Profil',
    'profile.victories': 'Victoires',
    'profile.score': 'Score',
    'profile.max_streak': 'Serie max',
    'profile.history': 'Historique',

    // --- Levels ---
    'levels.title': 'Niveaux',

    // --- Avatar ---
    'avatar.title': 'Choisir un avatar',
    'avatar.none': 'Aucun avatar',
    'avatar.choose': 'Selectionnez votre avatar',
    'avatar.save': 'Sauvegarder',
    'avatar.saved': 'Avatar sauvegarde !',

    // --- Help / FAQ ---
    'help.title': 'Aide & FAQ',
    'help.contact': 'Contacter le support',
    'help.q1': 'C\'est quoi TRIALGO ?',
    'help.a1': 'TRIALGO est un jeu de cartes base sur les transformations visuelles. Vous devez trouver l\'image manquante dans un trio E + C = R.',
    'help.q2': 'Qu\'est-ce qu\'une Emettrice ?',
    'help.a2': 'L\'Emettrice (E) est l\'image de base, le point de depart d\'un trio. Exemple : un dessin de lion.',
    'help.q3': 'Qu\'est-ce qu\'un Cable ?',
    'help.a3': 'Le Cable (C) est une IMAGE-ALGORITHME. Le dessin lui-meme represente la transformation a appliquer (miroir, rotation, couleur...).',
    'help.q4': 'Comment fonctionnent les vies ?',
    'help.a4': 'Vous avez 5 vies maximum. Chaque mauvaise reponse peut en couter une. Les vies se rechargent automatiquement toutes les 30 minutes.',
    'help.q5': 'Comment gagner des points ?',
    'help.a5': 'Points = base x distance x bonus temps. Plus vous repondez vite, plus vous gagnez. Enchainez les bonnes reponses pour des bonus de serie !',
    'help.q6': 'Comment activer mon jeu ?',
    'help.a6': 'Entrez le code de 16 caracteres qui se trouve dans votre boite de jeu TRIALGO. Le code est lie a un seul appareil.',
    'help.q7': 'Comment progresser dans les niveaux ?',
    'help.a7': 'Reussissez le seuil de bonnes reponses pour debloquer le niveau suivant. Les niveaux avances utilisent des distances plus grandes (D2, D3) et des configurations plus difficiles.',
    'help.q8': 'Comment jouer au quotidien ?',
    'help.a8': 'Trouvez la carte manquante parmi les choix proposes. Vous pouvez double-tapper une carte pour la zoomer et mieux observer les details.',

    // --- Edit username ---
    'edit_username.title': 'Modifier le pseudo',
    'edit_username.label': 'PSEUDO',
    'edit_username.chars': 'caracteres',
    'edit_username.rules': 'Lettres, chiffres, underscores',
    'edit_username.save': 'Sauvegarder',
    'edit_username.saved': 'Pseudo modifie !',

    // --- Legal ---
    'legal.title': 'Mentions legales',

    // --- Common ---
    'common.level': 'Niv.',
    'common.pts': 'pts',
    'common.soon': 'Bientot disponible',
  };

  // ---------------------------------------------------------------
  // TRADUCTIONS ANGLAISES
  // ---------------------------------------------------------------
  static const Map<String, String> _en = {
    // --- Splash ---
    'splash.subtitle': 'THE VISUAL TRANSFORMATIONS GAME',
    'splash.loading': 'Loading',

    // --- Auth ---
    'auth.welcome_back': 'Welcome back!',
    'auth.join': 'Join the adventure',
    'auth.email': 'Email',
    'auth.password': 'Password',
    'auth.login': 'Sign in',
    'auth.signup': 'Create account',
    'auth.or': 'or',
    'auth.google': 'Continue with Google',
    'auth.no_account': 'No account? ',
    'auth.has_account': 'Already have an account? ',
    'auth.signup_link': 'Sign up',
    'auth.login_link': 'Sign in',

    // --- Activation ---
    'activation.title': 'Activate your game',
    'activation.desc': 'Enter the unique code found\nin your TRIALGO game box',
    'activation.hint': 'TRLG-XXXX-XXXX-XXXX',
    'activation.format': 'Format: TRLG-XXXX-XXXX-XXXX',
    'activation.button': 'Activate my game',
    'activation.success': 'Game activated successfully!',

    // --- Home ---
    'home.play': 'PLAY',
    'home.tagline_small': 'TRIALGO',
    'home.tagline_big': 'Observe. Deduce. Win.',
    'home.tutorial': 'Tutorial',
    'home.tutorial_desc': 'Learn',
    'home.gallery': 'Gallery',
    'home.gallery_desc': 'cards',
    'home.leaderboard': 'Leaderboard',
    'home.leaderboard_desc': 'worldwide',
    'home.profile': 'Profile',
    'home.games': 'Games',
    'home.accuracy': 'Accuracy',
    'home.streak': 'Streak',
    'home.next_life': '+1 in',
    'home.min': 'min',
    'home.instr_observe': 'Observe the trio cards',
    'home.instr_find': 'Find the missing card',
    'home.instr_tap': 'Tap the game card to begin',
    'home.instr_zoom': 'Double-tap to zoom a card',

    // --- Onboarding (first login) ---
    'onb.skip': 'Skip',
    'onb.next': 'Next',
    'onb.start': 'Start',
    'onb.1_title': 'Welcome to TRIALGO',
    'onb.1_body': 'The observation game where every card matters. Prove your logic.',
    'onb.2_title': 'The magic trio',
    'onb.2_body': 'Emitter + Cable = Receiver. Find the missing card to win.',
    'onb.3_title': 'Observe and deduce',
    'onb.3_body': 'Tap a card to answer. Double-tap to see it full screen.',
    'onb.4_title': 'Ready to play?',
    'onb.4_body': 'Earn points, unlock new levels. The adventure begins.',

    // --- Game ---
    'game.question': 'Which image completes this trio?',
    'game.choose': 'Choose the correct image',
    'game.scroll': 'Scroll',
    'game.correct': 'Correct!',
    'game.incorrect': 'Incorrect...',
    'game.timeout': 'Time\'s up!',
    'game.question_of': 'Question',
    'game.streak_label': 'Streak',
    'game.quit_title': 'Quit game?',
    'game.quit_desc': 'Your progress on this level will be lost.',
    'game.continue': 'Continue',
    'game.quit': 'Quit',
    'game.trio': 'TRIO',
    'game.emettrice': 'Emitter',
    'game.cable': 'Cable',
    'game.receptrice': 'Receiver',

    // --- Results ---
    'result.success': 'Level complete!',
    'result.failed': 'Level failed',
    'result.congrats': 'Well done! Keep progressing.',
    'result.retry_msg': 'Keep trying!',
    'result.score': 'Score',
    'result.correct': 'Correct answers',
    'result.accuracy': 'Accuracy',
    'result.max_streak': 'Max streak',
    'result.next_level': 'Next level',
    'result.retry': 'Retry',
    'result.home': 'Back to menu',

    // --- Settings ---
    'settings.title': 'Settings',
    'settings.audio': 'AUDIO',
    'settings.sounds': 'Sound effects',
    'settings.sounds_desc': 'Interaction sounds',
    'settings.music': 'Music',
    'settings.music_desc': 'Background music',
    'settings.notif': 'NOTIFICATIONS',
    'settings.notif_lives': 'Lives refill',
    'settings.notif_desc': 'Alerts when lives are recharged',
    'settings.account': 'ACCOUNT',
    'settings.edit_pseudo': 'Edit username',
    'settings.edit_avatar': 'Change avatar',
    'settings.no_avatar': 'None configured',
    'settings.about': 'ABOUT',
    'settings.version': 'Version',
    'settings.legal': 'Legal notice',
    'settings.legal_desc': 'Terms & privacy',
    'settings.help': 'Help & FAQ',
    'settings.help_desc': 'How to play',
    'settings.logout': 'Sign out',
    'settings.logout_confirm': 'You will need to sign in again to play.',
    'settings.logout_action': 'Sign out',
    'settings.cancel': 'Cancel',
    'settings.delete_account': 'Delete my account',
    'settings.language': 'LANGUAGE',
    'settings.lang_fr': 'Francais',
    'settings.lang_en': 'English',
    'settings.theme': 'APPEARANCE',
    'settings.dark_mode': 'Dark mode',
    'settings.light_mode': 'Light mode',

    // --- Tutorial ---
    'tuto.title': 'Tutorial',
    'tuto.next': 'Next',
    'tuto.done': 'Got it!',
    'tuto.principle': 'The fundamental principle',
    'tuto.card_types': 'The 3 card types',
    'tuto.how_to_play': 'How to play?',
    'tuto.progress': 'Progress!',

    // --- Gallery ---
    'gallery.title': 'Gallery',
    'gallery.unlocked': 'of collection unlocked',

    // --- Leaderboard ---
    'leaderboard.title': 'Leaderboard',

    // --- Profile ---
    'profile.title': 'Profile',
    'profile.victories': 'Victories',
    'profile.score': 'Score',
    'profile.max_streak': 'Max streak',
    'profile.history': 'History',

    // --- Levels ---
    'levels.title': 'Levels',

    // --- Common ---
    'common.level': 'Lv.',
    'common.pts': 'pts',
    // --- Avatar ---
    'avatar.title': 'Choose an avatar',
    'avatar.none': 'No avatar',
    'avatar.choose': 'Select your avatar',
    'avatar.save': 'Save',
    'avatar.saved': 'Avatar saved!',

    // --- Help / FAQ ---
    'help.title': 'Help & FAQ',
    'help.contact': 'Contact support',
    'help.q1': 'What is TRIALGO?',
    'help.a1': 'TRIALGO is a card game based on visual transformations. You must find the missing image in a trio E + C = R.',
    'help.q2': 'What is an Emitter?',
    'help.a2': 'The Emitter (E) is the base image, the starting point of a trio. Example: a lion drawing.',
    'help.q3': 'What is a Cable?',
    'help.a3': 'The Cable (C) is an IMAGE-ALGORITHM. The drawing itself represents the transformation to apply (mirror, rotation, color...).',
    'help.q4': 'How do lives work?',
    'help.a4': 'You have 5 maximum lives. Each wrong answer may cost one. Lives recharge automatically every 30 minutes.',
    'help.q5': 'How to earn points?',
    'help.a5': 'Points = base x distance x time bonus. The faster you answer, the more you earn. Chain correct answers for streak bonuses!',
    'help.q6': 'How to activate my game?',
    'help.a6': 'Enter the 16-character code found in your TRIALGO game box. The code is linked to a single device.',
    'help.q7': 'How to progress through levels?',
    'help.a7': 'Reach the correct answer threshold to unlock the next level. Advanced levels use greater distances (D2, D3) and harder configurations.',
    'help.q8': 'How to play daily?',
    'help.a8': 'Find the missing card among the choices. You can double-tap a card to zoom in and observe the details more closely.',

    // --- Edit username ---
    'edit_username.title': 'Edit username',
    'edit_username.label': 'USERNAME',
    'edit_username.chars': 'characters',
    'edit_username.rules': 'Letters, numbers, underscores',
    'edit_username.save': 'Save',
    'edit_username.saved': 'Username changed!',

    // --- Legal ---
    'legal.title': 'Legal notice',
  };
}

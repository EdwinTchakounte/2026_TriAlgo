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
    'auth.no_account': 'Pas de compte ? ',
    'auth.has_account': 'Deja un compte ? ',
    'auth.signup_link': 'S\'inscrire',
    'auth.login_link': 'Se connecter',
    'auth.forgot_password': 'Mot de passe oublie ?',

    // --- Forgot password ---
    'forgot.title': 'Mot de passe oublie',
    'forgot.desc': 'Entrez votre email, nous vous enverrons un lien pour le reinitialiser.',
    'forgot.send': 'Envoyer le lien',
    'forgot.sent_title': 'Email envoye',
    'forgot.sent_desc': 'Consultez votre boite mail et cliquez sur le lien pour choisir un nouveau mot de passe.',
    'forgot.back_to_login': 'Retour a la connexion',

    // --- New password ---
    'newpwd.title': 'Nouveau mot de passe',
    'newpwd.desc': 'Choisissez un nouveau mot de passe pour votre compte.',
    'newpwd.new': 'Nouveau mot de passe',
    'newpwd.confirm': 'Confirmer le mot de passe',
    'newpwd.submit': 'Enregistrer',
    'newpwd.success': 'Mot de passe mis a jour !',
    'newpwd.mismatch': 'Les deux mots de passe ne correspondent pas',

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
    'game.no_lives_snack': 'Plus de vies ! Attends ou echange des etoiles.',

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

    // =============================================================
    // REFONTE V1 - CLES AJOUTEES POUR FR/EN GLOBAL
    // =============================================================

    // --- Settings (refonte, nouvelles cles uniquement) ---
    // settings.title, settings.music, settings.help, settings.legal
    // existent deja plus haut et sont reutilises tels quels.
    'settings.section_appearance': 'APPARENCE',
    'settings.section_audio': 'AUDIO',
    'settings.section_language': 'LANGUE',
    'settings.section_tools': 'OUTILS',
    'settings.section_info': 'INFOS ET AIDE',
    'settings.section_account': 'COMPTE',
    'settings.theme_light': 'Clair',
    'settings.theme_dark': 'Sombre',
    'settings.theme_system': 'Auto',
    'settings.language_fr': 'Francais',
    'settings.language_en': 'English',
    'settings.sfx': 'Effets sonores',
    'settings.collective_mode': 'Mode collectif (verificateur)',
    'settings.how_to_play': 'Comment jouer',
    'settings.sign_out': 'Se deconnecter',
    'settings.sign_out_confirm_title': 'Se deconnecter ?',
    'settings.sign_out_confirm_body': 'Tu pourras te reconnecter a tout moment avec ton email.',

    // --- Home (refonte) ---
    'home.play_button': 'JOUER',
    'home.discover': 'DECOUVRE',
    'home.last_game_section': 'DERNIERE PARTIE',
    'home.stat_level': 'Niveau',
    'home.stat_points': 'Points',
    'home.stat_cards': 'Cartes',
    'home.stat_stars': 'Etoiles',
    'home.stat_lives': 'Vies',
    'home.exchange_title': 'Echanger des etoiles',
    'home.exchange_ratio': '10 etoiles = 1 vie',
    'home.exchange_cta': 'Echanger',
    'home.exchange_cancel': 'Annuler',
    'home.exchange_err_stars': "Pas assez d'etoiles pour echanger.",
    'home.exchange_err_lives_max': 'Tu as deja le maximum de vies.',
    'home.exchange_err_no_game': 'Aucun jeu actif selectionne.',
    'home.exchange_err_network': 'Erreur reseau. Reessaie.',
    'home.exchange_err_unknown': "Echange impossible pour l'instant.",
    'home.streak_day': 'jour',
    'home.streak_days': 'jours',
    'home.streak_start': 'Commence ta serie !',
    'home.no_streak': 'Pas de serie',
    'home.card_deck': 'Mon deck',
    'home.card_deck_count': 'cartes',
    'home.card_ranking': 'Classement',
    'home.card_ranking_value': 'Top 10',
    'home.card_collective': 'Collectif',
    'home.card_collective_sub': 'Verifier trio',
    'home.collective_coming': 'Mode collectif bientot disponible',
    'home.questions': 'questions',
    'home.turn_seconds': 's/tour',
    'home.threshold': 'seuil',
    'home.remaining_many': 'Encore {n} parties avant D{d}',
    'home.remaining_one': 'Encore 1 partie avant D{d}',
    'home.next_is_distance': 'Prochaine partie : D{d}',

    // --- Auth (refonte) ---
    'auth.welcome_back_hero': 'Content de te revoir !',
    'auth.welcome_new_hero': 'Bienvenue chez TRIALGO !',
    'auth.welcome_back_sub': 'Connecte-toi pour continuer ta partie.',
    'auth.welcome_new_sub': "Creons ton compte pour commencer l'aventure.",
    'auth.tab_signin': 'SE CONNECTER',
    'auth.tab_signup': 'S\'INSCRIRE',
    'auth.email_hint': 'tu@exemple.com',
    'auth.password_hint_signin': '••••••••',
    'auth.password_hint_signup': 'Minimum 6 caracteres',
    'auth.email_empty': 'Entre ton email',
    'auth.email_invalid': 'Email invalide',
    'auth.password_empty': 'Entre un mot de passe',
    'auth.password_min': 'Minimum 6 caracteres',
    'auth.cta_signin': 'SE CONNECTER',
    'auth.cta_signup': 'CREER MON COMPTE',
    'auth.strength_weak': 'Faible',
    'auth.strength_medium': 'Moyen',
    'auth.strength_good': 'Bon',
    'auth.strength_strong': 'Fort',
    'auth.error_taken': 'Cet email est deja utilise',
    'auth.error_invalid': 'Email ou mot de passe incorrect',
    'auth.error_unconfirmed': 'Email non confirme. Verifie ta boite mail.',
    'auth.error_weak': 'Mot de passe trop faible',
    'auth.error_network': 'Erreur reseau. Reessaie.',

    // --- Onboarding (refonte) ---
    'onb.slide1_title': 'Bienvenue dans TRIALGO',
    'onb.slide1_body': "L'aventure des trios visuels commence ici.\nPrepare-toi a observer, deduire et gagner.",
    'onb.slide2_title': 'Le trio magique',
    'onb.slide2_body': 'Chaque partie, tu dois trouver la carte qui\ncomplete un trio : Emettrice + Cable = Receptrice.',
    'onb.slide3_title': 'Observe et touche',
    'onb.slide3_body': 'Choisis la bonne image parmi celles proposees.\nPlus tu es rapide, plus tu gagnes de points.',
    'onb.slide4_title': 'Pret a jouer ?',
    'onb.slide4_body': "Des centaines de cartes et de trios t'attendent.\nLet's go !",
    'onb.skip_btn': 'Passer',
    'onb.next_btn': 'SUIVANT',
    'onb.start_btn': "COMMENCER L'AVENTURE",

    // --- Common (batch refonte) ---
    'common.cancel': 'Annuler',
    'common.loading': 'Chargement...',
    'common.error': 'Erreur',
    'common.retry': 'Reessayer',
    'common.back': 'Retour',

    // --- Activation (refonte unboxing, activation.title existe deja) ---
    'activation.locked_title': 'Ta boite est verrouillee',
    'activation.locked_body': "Entre le code magique qui se trouve\ndans ta boite TRIALGO pour l'ouvrir.",
    'activation.code_empty': 'Entre ton code pour ouvrir la boite',
    'activation.cta_open': 'OUVRIR LA BOITE',
    'activation.cta_back_games': 'Retour a mes jeux',
    'activation.already_open_title': 'Ta boite est deja ouverte !',
    'activation.cta_continue': 'CONTINUER MON AVENTURE',
    'activation.cta_add_another': 'Activer une autre boite',
    'activation.success_title': 'TA BOITE EST OUVERTE !',
    'activation.success_body': "Tu viens de debloquer un univers\nde cartes et de trios.",
    'activation.cta_start': "COMMENCER L'AVENTURE",

    // --- Level Map (refonte) ---
    'levelmap.title': 'Ta carte de quete',
    'levelmap.zone_d1': 'ZONE D1 · DECOUVERTE',
    'levelmap.zone_d2': 'ZONE D2 · CHAINES',
    'levelmap.zone_d3': 'ZONE D3 · MAITRISE',
    'levelmap.zone_d4': 'ZONE D4 · EXPERT',
    'levelmap.zone_d5': 'ZONE D5 · LEGENDE',
    'levelmap.unlock_hint': "Termine d'abord le niveau {n}",

    // --- Profile (refonte, profile.title existe deja) ---
    'profile.section_trophies': 'TES TROPHEES',
    'profile.section_recent': 'DERNIERES PARTIES',
    'profile.section_account': 'PARAMETRES DU COMPTE',
    'profile.trophy_first_title': 'Premier pas',
    'profile.trophy_first_hint': 'Niveau 2',
    'profile.trophy_explorer_title': 'Explorateur',
    'profile.trophy_explorer_hint': 'Niveau 10',
    'profile.trophy_streak_title': 'Serie de feu',
    'profile.trophy_streak_hint': '7 jours',
    'profile.trophy_perfect_title': 'Perfectionniste',
    'profile.trophy_perfect_hint': '3 etoiles',
    'profile.action_avatar': 'Changer mon avatar',
    'profile.action_username': 'Changer mon pseudo',
    'profile.relative_now': "a l'instant",
    'profile.relative_min': 'il y a {n} min',
    'profile.relative_h': 'il y a {n} h',
    'profile.relative_yesterday': 'hier',
    'profile.relative_days': 'il y a {n} j',

    // --- Game Result (refonte) ---
    'result.bravo': 'BRAVO !',
    'result.almost': 'Presque !',
    'result.level_passed': 'Niveau {n} valide',
    'result.level_retry': 'Niveau {n} a reprendre',
    'result.keep_going': 'Courage, tu vas y arriver !',
    'result.stat_correct': 'Correctes',
    'result.stat_accuracy': 'Precision',
    'result.stat_combo': 'Combo',
    'result.cta_next_level': 'NIVEAU SUIVANT',
    'result.cta_retry': 'REESSAYER',
    'result.cta_home': "Retour a l'accueil",
    'result.score_label': 'SCORE',

    // --- Forgot / New Password (refonte) ---
    'forgot.title_refonte': 'Mot de passe oublie',
    'forgot.hero_title': 'Pas de souci !',
    'forgot.hero_body': "On te renvoie un lien par mail\npour choisir un nouveau mot de passe.",
    'forgot.email_hint': 'tu@exemple.com',
    'forgot.invalid_email': 'Email invalide',
    'forgot.error_network': 'Erreur reseau. Reessaie.',
    'forgot.cta_send': 'ENVOYER LE LIEN',
    // forgot.sent_title existe deja plus haut ("Email envoye")
    'forgot.sent_body': "Regarde dans ta boite mail et clique\nsur le lien qu'on t'a envoye.",
    'forgot.cta_back_login': 'RETOUR A LA CONNEXION',
    // newpwd.title existe deja plus haut
    'newpwd.hero_title': 'Choisis un mot de passe\nbien fort',
    'newpwd.field_new': 'Nouveau mot de passe',
    'newpwd.field_confirm': 'Confirmer le mot de passe',
    'newpwd.field_hint_new': 'Minimum 6 caracteres',
    'newpwd.field_hint_confirm': 'Retape ton nouveau mot de passe',
    'newpwd.error_min': 'Minimum 6 caracteres',
    'newpwd.error_mismatch': 'Les deux ne correspondent pas',
    'newpwd.cta_save': 'ENREGISTRER',
    'newpwd.success_snack': 'Mot de passe mis a jour !',

    // --- Gallery (refonte, gallery.title existe deja) ---
    'gallery.unlocked_count': 'Cartes debloquees',
    'gallery.chip_all': 'Toutes',
    'gallery.chip_unlocked': 'Debloquees',
    'gallery.chip_locked': 'A decouvrir',
    'gallery.chip_all_roles': 'Tous roles',
    'gallery.chip_emettrice': 'Emettrices',
    'gallery.chip_cable': 'Cables',
    'gallery.chip_receptrice': 'Receptrices',
    'gallery.empty_title': 'Rien trouve',
    'gallery.empty_body': "Essaie un autre filtre\npour voir plus de cartes.",
    'gallery.count_suffix_one': 'CARTE',
    'gallery.count_suffix_many': 'CARTES',

    // --- Leaderboard (refonte) ---
    'lb.title': 'Classement',
    'lb.no_game_selected': 'Aucun jeu selectionne',
    'lb.loading': 'Chargement du classement...',
    'lb.error_title': 'Chargement impossible',
    'lb.error_body': 'Verifie ta connexion et reessaie.',
    'lb.empty_title': 'Aucun joueur',
    'lb.empty_body': 'Sois le premier a apparaitre dans le classement !',
    'lb.cta_retry': 'REESSAYER',
    'lb.level_label': 'Niveau',
    'lb.pts': 'pts',

    // --- QR Scanner (refonte) ---
    'qr.title': 'Scanner un trio',
    'qr.scanned_count': 'Cartes scannees',
    'qr.restart': 'Recommencer',
    'qr.not_recognized': 'QR non reconnu',
    'qr.already_scanned': 'Carte deja scannee',
    'qr.not_in_game': "Cette carte n'appartient pas a ce jeu",

    // --- Tutorial (refonte, tuto.title existe deja) ---
    'tuto.hero_title': 'Le trio magique',
    'tuto.hero_body': 'Chaque trio a 3 cartes qui vont ensemble.',
    'tuto.step1_title': 'Emettrice',
    'tuto.step1_body': "L'image de depart (un animal, un objet...).",
    'tuto.step2_title': 'Cable',
    'tuto.step2_body': "La transformation qui change l'Emettrice.",
    'tuto.step3_title': 'Receptrice',
    'tuto.step3_body': 'Le resultat final : Emettrice + Cable = Receptrice.',
    'tuto.cta_ok': "J'AI COMPRIS !",

    // --- Avatar / Edit username (refonte) ---
    'avatar.title_refonte': 'Mon avatar',
    'avatar.cta_save': 'VALIDER MON AVATAR',
    'avatar.name_trio': 'Le trio',
    'avatar.name_duo': 'Le duo',
    'avatar.name_logo': 'Le logo',
    'editpseudo.title': 'Mon pseudo',
    'editpseudo.hero': "Comment on t'appelle ?",
    'editpseudo.label': 'Pseudo',
    'editpseudo.hint': 'Ton nom de joueur',
    'editpseudo.min': 'Minimum 2 caracteres',
    'editpseudo.max': 'Maximum 20 caracteres',
    'editpseudo.saved': 'Pseudo mis a jour',
    'editpseudo.error_net': 'Erreur reseau',
    'editpseudo.cta_save': "C'EST MON NOM",
    'editpseudo.cta_cancel': 'Annuler',

    // --- Help (refonte) ---
    'help.title_refonte': 'Aide',
    'help.hero_title': "Besoin d'aide ?",
    'help.hero_body': "Trouve les reponses a tes questions\nou relis le tutoriel.",
    'help.section_gameplay': 'LE JEU',
    'help.section_account': 'MON COMPTE',
    'help.section_physical': 'LA BOITE TRIALGO',
    'help.cta_tutorial': 'REVOIR LE TUTORIEL',

    // --- Legal (refonte) ---
    'legal.title_refonte': 'Mentions legales',
    'legal.tab_mentions': 'MENTIONS',
    'legal.tab_conditions': 'CONDITIONS',
    'legal.tab_credits': 'CREDITS',

    // --- Graph loading (refonte) ---
    'loading.phase1': 'Reveil du plateau...',
    'loading.phase2': 'Assemblage des cartes...',
    'loading.phase3': 'Tissage des trios...',
    'loading.ready': 'Pret !',
    'loading.error_title': 'Chargement impossible',
    'loading.error_body': 'Verifie ta connexion et reessaie.',
    'loading.cta_retry': 'REESSAYER',
    'loading.oops': 'Oups',

    // --- Home tour (refonte) ---
    'tour.step1_title': 'La carte de JEU',
    'tour.step1_body': "Le bouton JOUER au milieu te fait demarrer la partie\nde ton niveau actuel.",
    'tour.step2_title': 'Tes stats',
    'tour.step2_body': "En haut, retrouve ton niveau, tes points,\ntes vies et ta serie de jours.",
    'tour.step3_title': 'Decouvre',
    'tour.step3_body': 'Consulte ta collection de cartes,\nle classement et les defis a venir.',
    'tour.prev': 'Precedent',
    'tour.next': 'SUIVANT',
    'tour.finish': 'TERMINER',
    'tour.skip': 'Passer le tour',

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
    'auth.no_account': 'No account? ',
    'auth.has_account': 'Already have an account? ',
    'auth.signup_link': 'Sign up',
    'auth.login_link': 'Sign in',
    'auth.forgot_password': 'Forgot password?',

    // --- Forgot password ---
    'forgot.title': 'Forgot password',
    'forgot.desc': 'Enter your email, we will send you a link to reset it.',
    'forgot.send': 'Send link',
    'forgot.sent_title': 'Email sent',
    'forgot.sent_desc': 'Check your inbox and click the link to choose a new password.',
    'forgot.back_to_login': 'Back to sign in',

    // --- New password ---
    'newpwd.title': 'New password',
    'newpwd.desc': 'Pick a new password for your account.',
    'newpwd.new': 'New password',
    'newpwd.confirm': 'Confirm password',
    'newpwd.submit': 'Save',
    'newpwd.success': 'Password updated!',
    'newpwd.mismatch': 'Passwords do not match',

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
    'game.no_lives_snack': 'No lives left! Wait or exchange stars.',

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

    // =============================================================
    // REFONTE V1 - KEYS ADDED FOR FR/EN GLOBAL
    // =============================================================

    // --- Settings (refonte, new keys only) ---
    // settings.title, settings.music, settings.help, settings.legal
    // already exist above and are reused as-is.
    'settings.section_appearance': 'APPEARANCE',
    'settings.section_language': 'LANGUAGE',
    'settings.section_tools': 'TOOLS',
    'settings.section_info': 'INFO & HELP',
    'settings.section_account': 'ACCOUNT',
    'settings.theme_light': 'Light',
    'settings.theme_dark': 'Dark',
    'settings.theme_system': 'Auto',
    'settings.language_fr': 'French',
    'settings.language_en': 'English',
    'settings.sfx': 'Sound effects',
    'settings.collective_mode': 'Collective mode (verifier)',
    'settings.how_to_play': 'How to play',
    'settings.sign_out': 'Sign out',
    'settings.sign_out_confirm_title': 'Sign out?',
    'settings.sign_out_confirm_body': 'You can sign in again anytime with your email.',

    // --- Home (refonte) ---
    'home.play_button': 'PLAY',
    'home.discover': 'DISCOVER',
    'home.last_game_section': 'LAST GAME',
    'home.stat_level': 'Level',
    'home.stat_points': 'Points',
    'home.stat_cards': 'Cards',
    'home.stat_stars': 'Stars',
    'home.stat_lives': 'Lives',
    'home.exchange_title': 'Exchange stars',
    'home.exchange_ratio': '10 stars = 1 life',
    'home.exchange_cta': 'Exchange',
    'home.exchange_cancel': 'Cancel',
    'home.exchange_err_stars': 'Not enough stars to exchange.',
    'home.exchange_err_lives_max': 'You already have max lives.',
    'home.exchange_err_no_game': 'No active game selected.',
    'home.exchange_err_network': 'Network error. Try again.',
    'home.exchange_err_unknown': 'Exchange not available right now.',
    'home.streak_day': 'day',
    'home.streak_days': 'days',
    'home.streak_start': 'Start your streak!',
    'home.no_streak': 'No streak',
    'home.card_deck': 'My deck',
    'home.card_deck_count': 'cards',
    'home.card_ranking': 'Ranking',
    'home.card_ranking_value': 'Top 10',
    'home.card_collective': 'Collective',
    'home.card_collective_sub': 'Verify trio',
    'home.collective_coming': 'Collective mode coming soon',
    'home.questions': 'questions',
    'home.turn_seconds': 's/turn',
    'home.threshold': 'threshold',
    'home.remaining_many': '{n} games left before D{d}',
    'home.remaining_one': '1 game left before D{d}',
    'home.next_is_distance': 'Next game: D{d}',

    // --- Auth (refonte) ---
    'auth.welcome_back_hero': 'Nice to see you again!',
    'auth.welcome_new_hero': 'Welcome to TRIALGO!',
    'auth.welcome_back_sub': 'Sign in to continue your game.',
    'auth.welcome_new_sub': "Let's create your account to start the adventure.",
    'auth.tab_signin': 'SIGN IN',
    'auth.tab_signup': 'SIGN UP',
    'auth.email_hint': 'you@example.com',
    'auth.password_hint_signin': '••••••••',
    'auth.password_hint_signup': 'Minimum 6 characters',
    'auth.email_empty': 'Enter your email',
    'auth.email_invalid': 'Invalid email',
    'auth.password_empty': 'Enter a password',
    'auth.password_min': 'Minimum 6 characters',
    'auth.cta_signin': 'SIGN IN',
    'auth.cta_signup': 'CREATE MY ACCOUNT',
    'auth.strength_weak': 'Weak',
    'auth.strength_medium': 'Medium',
    'auth.strength_good': 'Good',
    'auth.strength_strong': 'Strong',
    'auth.error_taken': 'This email is already taken',
    'auth.error_invalid': 'Invalid email or password',
    'auth.error_unconfirmed': 'Email not confirmed. Check your inbox.',
    'auth.error_weak': 'Password too weak',
    'auth.error_network': 'Network error. Try again.',

    // --- Onboarding (refonte) ---
    'onb.slide1_title': 'Welcome to TRIALGO',
    'onb.slide1_body': 'The visual trio adventure starts here.\nGet ready to observe, deduce and win.',
    'onb.slide2_title': 'The magic trio',
    'onb.slide2_body': 'Each game, find the card that\ncompletes a trio: Emitter + Cable = Receiver.',
    'onb.slide3_title': 'Observe and tap',
    'onb.slide3_body': 'Pick the right image among the choices.\nThe faster you are, the more points you earn.',
    'onb.slide4_title': 'Ready to play?',
    'onb.slide4_body': "Hundreds of cards and trios await you.\nLet's go!",
    'onb.skip_btn': 'Skip',
    'onb.next_btn': 'NEXT',
    'onb.start_btn': 'START THE ADVENTURE',

    // --- Common (batch refonte) ---
    'common.cancel': 'Cancel',
    'common.loading': 'Loading...',
    'common.error': 'Error',
    'common.retry': 'Retry',
    'common.back': 'Back',

    // --- Activation (activation.title already exists) ---
    'activation.locked_title': 'Your box is locked',
    'activation.locked_body': 'Enter the magic code from your\nTRIALGO box to open it.',
    'activation.code_empty': 'Enter your code to open the box',
    'activation.cta_open': 'OPEN THE BOX',
    'activation.cta_back_games': 'Back to my games',
    'activation.already_open_title': 'Your box is already open!',
    'activation.cta_continue': 'CONTINUE MY ADVENTURE',
    'activation.cta_add_another': 'Activate another box',
    'activation.success_title': 'YOUR BOX IS OPEN!',
    'activation.success_body': 'You just unlocked a universe\nof cards and trios.',
    'activation.cta_start': 'START THE ADVENTURE',

    // --- Level Map ---
    'levelmap.title': 'Your quest map',
    'levelmap.zone_d1': 'ZONE D1 · DISCOVERY',
    'levelmap.zone_d2': 'ZONE D2 · CHAINS',
    'levelmap.zone_d3': 'ZONE D3 · MASTERY',
    'levelmap.zone_d4': 'ZONE D4 · EXPERT',
    'levelmap.zone_d5': 'ZONE D5 · LEGEND',
    'levelmap.unlock_hint': 'Finish level {n} first',

    // --- Profile (profile.title already exists) ---
    'profile.section_trophies': 'YOUR TROPHIES',
    'profile.section_recent': 'RECENT GAMES',
    'profile.section_account': 'ACCOUNT SETTINGS',
    'profile.trophy_first_title': 'First step',
    'profile.trophy_first_hint': 'Level 2',
    'profile.trophy_explorer_title': 'Explorer',
    'profile.trophy_explorer_hint': 'Level 10',
    'profile.trophy_streak_title': 'Fire streak',
    'profile.trophy_streak_hint': '7 days',
    'profile.trophy_perfect_title': 'Perfectionist',
    'profile.trophy_perfect_hint': '3 stars',
    'profile.action_avatar': 'Change my avatar',
    'profile.action_username': 'Change my username',
    'profile.relative_now': 'just now',
    'profile.relative_min': '{n} min ago',
    'profile.relative_h': '{n} h ago',
    'profile.relative_yesterday': 'yesterday',
    'profile.relative_days': '{n} d ago',

    // --- Game Result ---
    'result.bravo': 'BRAVO!',
    'result.almost': 'So close!',
    'result.level_passed': 'Level {n} passed',
    'result.level_retry': 'Level {n} to retry',
    'result.keep_going': "Don't give up, you'll make it!",
    'result.stat_correct': 'Correct',
    'result.stat_accuracy': 'Accuracy',
    'result.stat_combo': 'Combo',
    'result.cta_next_level': 'NEXT LEVEL',
    'result.cta_retry': 'RETRY',
    'result.cta_home': 'Back to home',
    'result.score_label': 'SCORE',

    // --- Forgot / New Password ---
    'forgot.title_refonte': 'Forgot password',
    'forgot.hero_title': 'No worries!',
    'forgot.hero_body': "We'll send you a link to\nchoose a new password.",
    'forgot.email_hint': 'you@example.com',
    'forgot.invalid_email': 'Invalid email',
    'forgot.error_network': 'Network error. Try again.',
    'forgot.cta_send': 'SEND THE LINK',
    // forgot.sent_title already exists above
    'forgot.sent_body': 'Check your inbox and click\nthe link we sent you.',
    'forgot.cta_back_login': 'BACK TO SIGN IN',
    // newpwd.title already exists above
    'newpwd.hero_title': 'Choose a strong\npassword',
    'newpwd.field_new': 'New password',
    'newpwd.field_confirm': 'Confirm password',
    'newpwd.field_hint_new': 'Minimum 6 characters',
    'newpwd.field_hint_confirm': 'Retype your new password',
    'newpwd.error_min': 'Minimum 6 characters',
    'newpwd.error_mismatch': 'Passwords do not match',
    'newpwd.cta_save': 'SAVE',
    'newpwd.success_snack': 'Password updated!',

    // --- Gallery (gallery.title already exists) ---
    'gallery.unlocked_count': 'Cards unlocked',
    'gallery.chip_all': 'All',
    'gallery.chip_unlocked': 'Unlocked',
    'gallery.chip_locked': 'To discover',
    'gallery.chip_all_roles': 'All roles',
    'gallery.chip_emettrice': 'Emitters',
    'gallery.chip_cable': 'Cables',
    'gallery.chip_receptrice': 'Receivers',
    'gallery.empty_title': 'Nothing found',
    'gallery.empty_body': 'Try another filter\nto see more cards.',
    'gallery.count_suffix_one': 'CARD',
    'gallery.count_suffix_many': 'CARDS',

    // --- Leaderboard ---
    'lb.title': 'Ranking',
    'lb.no_game_selected': 'No game selected',
    'lb.loading': 'Loading leaderboard...',
    'lb.error_title': 'Unable to load',
    'lb.error_body': 'Check your connection and retry.',
    'lb.empty_title': 'No players',
    'lb.empty_body': 'Be the first to appear on the leaderboard!',
    'lb.cta_retry': 'RETRY',
    'lb.level_label': 'Level',
    'lb.pts': 'pts',

    // --- QR Scanner ---
    'qr.title': 'Scan a trio',
    'qr.scanned_count': 'Scanned cards',
    'qr.restart': 'Restart',
    'qr.not_recognized': 'QR not recognized',
    'qr.already_scanned': 'Card already scanned',
    'qr.not_in_game': "This card doesn't belong to this game",

    // --- Tutorial (tuto.title already exists) ---
    'tuto.hero_title': 'The magic trio',
    'tuto.hero_body': 'Each trio has 3 cards that go together.',
    'tuto.step1_title': 'Emitter',
    'tuto.step1_body': 'The starting image (an animal, an object...).',
    'tuto.step2_title': 'Cable',
    'tuto.step2_body': 'The transformation that changes the Emitter.',
    'tuto.step3_title': 'Receiver',
    'tuto.step3_body': 'The final result: Emitter + Cable = Receiver.',
    'tuto.cta_ok': 'GOT IT!',

    // --- Avatar / Edit username ---
    'avatar.title_refonte': 'My avatar',
    'avatar.cta_save': 'SAVE MY AVATAR',
    'avatar.name_trio': 'The trio',
    'avatar.name_duo': 'The duo',
    'avatar.name_logo': 'The logo',
    'editpseudo.title': 'My username',
    'editpseudo.hero': 'What should we call you?',
    'editpseudo.label': 'Username',
    'editpseudo.hint': 'Your player name',
    'editpseudo.min': 'Minimum 2 characters',
    'editpseudo.max': 'Maximum 20 characters',
    'editpseudo.saved': 'Username updated',
    'editpseudo.error_net': 'Network error',
    'editpseudo.cta_save': "THAT'S MY NAME",
    'editpseudo.cta_cancel': 'Cancel',

    // --- Help ---
    'help.title_refonte': 'Help',
    'help.hero_title': 'Need help?',
    'help.hero_body': 'Find answers to your questions\nor re-read the tutorial.',
    'help.section_gameplay': 'THE GAME',
    'help.section_account': 'MY ACCOUNT',
    'help.section_physical': 'THE TRIALGO BOX',
    'help.cta_tutorial': 'REVIEW TUTORIAL',

    // --- Legal ---
    'legal.title_refonte': 'Legal',
    'legal.tab_mentions': 'LEGAL',
    'legal.tab_conditions': 'TERMS',
    'legal.tab_credits': 'CREDITS',

    // --- Graph loading ---
    'loading.phase1': 'Waking the board...',
    'loading.phase2': 'Assembling cards...',
    'loading.phase3': 'Weaving trios...',
    'loading.ready': 'Ready!',
    'loading.error_title': 'Unable to load',
    'loading.error_body': 'Check your connection and retry.',
    'loading.cta_retry': 'RETRY',
    'loading.oops': 'Oops',

    // --- Home tour ---
    'tour.step1_title': 'The PLAY card',
    'tour.step1_body': 'The PLAY button in the middle starts your\ncurrent level game.',
    'tour.step2_title': 'Your stats',
    'tour.step2_body': 'At the top, find your level, points,\nlives and streak.',
    'tour.step3_title': 'Discover',
    'tour.step3_body': 'Check your card collection,\nthe ranking and upcoming challenges.',
    'tour.prev': 'Previous',
    'tour.next': 'NEXT',
    'tour.finish': 'FINISH',
    'tour.skip': 'Skip tour',
  };
}

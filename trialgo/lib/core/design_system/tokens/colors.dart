// =============================================================
// FICHIER : lib/core/design_system/tokens/colors.dart
// ROLE   : Palette de couleurs semantique (brand + surfaces theme)
// COUCHE : Core > Design System > Tokens
// =============================================================
//
// DEUX FAMILLES DE COULEURS :
// ---------------------------
// 1. BRAND (statique, memes couleurs dark/light) :
//    primary, primaryVariant, success, warning, error, info, etc.
//    -> Accessibles via TColors.primary, TColors.success, ...
//
// 2. SURFACE/TEXT (dependant du theme) :
//    bgBase, bgRaised, textPrimary, textSecondary, borderSubtle, ...
//    -> Accessibles via TColors.of(context).bgBase
//
// POURQUOI CETTE SEPARATION ?
// ---------------------------
// Les couleurs brand restent identiques dans les 2 themes (l'orange
// de TRIALGO est toujours le meme orange). Elles peuvent etre des
// constantes statiques, accessibles partout sans BuildContext.
//
// Les couleurs de surface CHANGENT selon dark/light. Elles doivent
// provenir du ThemeExtension pour etre responsives au switch.
// =============================================================

import 'package:flutter/material.dart';

// =============================================================
// BRAND COLORS (statiques, partagees dark/light)
// =============================================================

/// Couleurs brand de TRIALGO.
///
/// Ces couleurs sont IDENTIQUES dans le mode dark et le mode light :
/// elles font partie de l'identite de marque. Pas besoin de passer
/// par le theme pour les acceder.
class TColors {

  // --- Identite orange/dore ---
  /// Orange principal (boutons primaires, accents marketing).
  static const Color primary = Color(0xFFFF6B35);

  /// Dore secondaire (gradient end, etoiles, scores).
  static const Color primaryVariant = Color(0xFFF7C948);

  // --- Couleurs semantiques ---
  /// Vert succes (bonnes reponses, validations, progress).
  static const Color success = Color(0xFF66BB6A);

  /// Orange vif pour avertissements (non-bloquants).
  static const Color warning = Color(0xFFFFA726);

  /// Rouge erreur (mauvaises reponses, vies perdues).
  static const Color error = Color(0xFFEF5350);

  /// Bleu informatif (tips, neutre).
  static const Color info = Color(0xFF42A5F5);

  /// Violet douceur (emettrices, badges premium).
  static const Color purple = Color(0xFFAB7CFF);

  // --- Versions pre-alpha pour les const BoxShadow ---
  // Dart interdit les computations const (pas de withAlpha() ici),
  // donc on declare explicitement les nuances semi-transparentes
  // utilisees par les glows. Changer la brand ici modifie aussi les
  // glows : source unique de verite.

  /// Orange @ 35% : glow primary pour BoxShadow.
  static const Color primaryGlow = Color(0x59FF6B35);

  /// Dore @ 30% : glow dore pour BoxShadow.
  static const Color goldGlow = Color(0x4DF7C948);

  /// Vert @ 30% : glow success pour BoxShadow.
  static const Color successGlow = Color(0x4D66BB6A);

  /// Rouge @ 30% : glow error pour BoxShadow.
  static const Color errorGlow = Color(0x4DEF5350);

  // --- Neutres ABSOLUS (non-theme) ---
  /// Noir pur : utile pour overlays scrim, contraste max.
  static const Color black = Color(0xFF000000);

  /// Blanc pur : idem.
  static const Color white = Color(0xFFFFFFFF);

  // =============================================================
  // ACCESSEUR : couleurs dependantes du theme
  // =============================================================
  // TColors.of(context) retourne le ThemeExtension charge dans le
  // ThemeData en cours. Acces rapide depuis n'importe quel widget.
  // =============================================================

  /// Retourne les couleurs de surface/text du theme courant.
  ///
  /// Exemple :
  /// ```dart
  /// final c = TColors.of(context);
  /// Container(color: c.bgRaised, child: Text('hi', style: TextStyle(color: c.textPrimary)));
  /// ```
  static TSurfaceColors of(BuildContext context) {
    final ext = Theme.of(context).extension<TSurfaceColors>();
    // Fallback : si le theme n'a pas l'extension (theme mal configure),
    // on renvoie le palette dark par defaut pour eviter un crash.
    return ext ?? TSurfaceColors.dark;
  }
}


// =============================================================
// THEME EXTENSION : TSurfaceColors
// =============================================================
// Encapsule toutes les couleurs qui CHANGENT avec le theme :
//   - backgrounds (base, raised, sunken)
//   - surface (cartes glassmorphism)
//   - borders
//   - text (primary, secondary, tertiary, disabled)
//
// M3 ThemeExtension permet de transporter ces donnees dans le
// ThemeData et de les lerp entre dark <-> light si on voulait
// une transition animee.
// =============================================================

@immutable
class TSurfaceColors extends ThemeExtension<TSurfaceColors> {

  // --- Fonds / surfaces (3 niveaux de profondeur) ---

  /// Fond le plus profond de l'app (body de Scaffold).
  final Color bgBase;

  /// Fond surelevé (cards, panneaux, app bars opaques).
  final Color bgRaised;

  /// Fond "enfonce" (inputs, search bars, backgrounds pour champs).
  final Color bgSunken;

  /// Surface glass (cartes semi-transparentes au-dessus du bgBase).
  final Color surface;

  /// Overlay pour dialogs/modals (scrim).
  final Color scrim;

  // --- Bordures ---

  /// Bordure tres discrete (separateur de cellules).
  final Color borderSubtle;

  /// Bordure standard (cartes, inputs au repos).
  final Color borderDefault;

  /// Bordure d'emphase (input focused, carte selectionnee).
  final Color borderStrong;

  // --- Text ---

  /// Texte principal (contenu, titres).
  final Color textPrimary;

  /// Texte secondaire (description, sous-titre).
  final Color textSecondary;

  /// Texte tertiaire (meta, microcopy, timestamps).
  final Color textTertiary;

  /// Texte desactive.
  final Color textDisabled;

  /// Texte sur surface primary (boutons oranges, pastilles brand).
  /// Toujours un contraste eleve face aux couleurs brand.
  final Color textOnBrand;

  const TSurfaceColors({
    required this.bgBase,
    required this.bgRaised,
    required this.bgSunken,
    required this.surface,
    required this.scrim,
    required this.borderSubtle,
    required this.borderDefault,
    required this.borderStrong,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.textDisabled,
    required this.textOnBrand,
  });

  // =============================================================
  // TOKENS BRUTS DES FONDS (exposes pour TBrand.bgDark / bgLight)
  // =============================================================
  // Les gradients de fond definis dans tokens/brand.dart ne peuvent
  // pas acceder aux champs d'instance de `.dark` / `.light` dans
  // une expression const. On expose donc les valeurs hex comme
  // `static const Color` ici, puis on les referencie a la fois
  // dans les instances `.dark` / `.light` ET dans `TBrand`.
  //
  // Consequence : un changement de valeur ici propage partout,
  // pas de duplication de hex.
  // =============================================================

  /// Fond profond du mode dark (#0A0A1A).
  static const Color darkBgBase = Color(0xFF0A0A1A);

  /// Fond surelevé du mode dark (#1A1035).
  static const Color darkBgRaised = Color(0xFF1A1035);

  /// Fond sunken du mode dark (#0D1B2A).
  static const Color darkBgSunken = Color(0xFF0D1B2A);

  /// Fond de base du mode light (blanc casse leger).
  static const Color lightBgBase = Color(0xFFF7F8FC);

  /// Fond surelevé du mode light (blanc pur).
  static const Color lightBgRaised = Color(0xFFFFFFFF);

  /// Fond sunken du mode light (gris tres clair).
  static const Color lightBgSunken = Color(0xFFEDEFF5);

  // =============================================================
  // PALETTE DARK (mode actuel, premium gaming)
  // =============================================================

  /// Palette du mode sombre de TRIALGO.
  static const TSurfaceColors dark = TSurfaceColors(
    bgBase:       darkBgBase,
    bgRaised:     darkBgRaised,
    bgSunken:     darkBgSunken,
    // Glass : blanc tres transparent (effet frosted).
    surface:      Color(0x0DFFFFFF), // 5%
    scrim:        Color(0xBF000000), // 75% noir
    // Bordures claires sur fond sombre.
    borderSubtle: Color(0x14FFFFFF), // 8%
    borderDefault:Color(0x26FFFFFF), // 15%
    borderStrong: Color(0x4DFFFFFF), // 30%
    // Texte blanc avec hierarchie.
    textPrimary:  Color(0xFFFFFFFF),
    textSecondary:Color(0xB3FFFFFF), // 70%
    textTertiary: Color(0x73FFFFFF), // 45%
    textDisabled: Color(0x40FFFFFF), // 25%
    textOnBrand:  Color(0xFFFFFFFF),
  );

  // =============================================================
  // PALETTE LIGHT (nouveau, clean + energique)
  // =============================================================

  /// Palette du mode clair de TRIALGO.
  ///
  /// Inspire de Duolingo (clean whites + accents brand) et de
  /// l'UI light de Pokemon Go (tons chauds, pas sterile).
  static const TSurfaceColors light = TSurfaceColors(
    bgBase:       lightBgBase,
    bgRaised:     lightBgRaised,
    bgSunken:     lightBgSunken,
    // Surface glass sur fond clair : noir a tres faible opacite.
    surface:      Color(0x080D1B2A), // 3%
    scrim:        Color(0x8A000000), // 54% noir (M3 standard)
    // Bordures grises standard.
    borderSubtle: Color(0x0D0D1B2A), // 5%
    borderDefault:Color(0x1F0D1B2A), // 12%
    borderStrong: Color(0x4D0D1B2A), // 30%
    // Texte fonce avec hierarchie.
    // Base #0D1B2A = clin d'oeil au bgBase du dark theme pour signature.
    textPrimary:  Color(0xFF0D1B2A),
    textSecondary:Color(0xFF4A5568),
    textTertiary: Color(0xFF9CA3AF),
    textDisabled: Color(0xFFD1D5DB),
    textOnBrand:  Color(0xFFFFFFFF),
  );

  // =============================================================
  // METHODES REQUISES PAR ThemeExtension<T>
  // =============================================================

  @override
  TSurfaceColors copyWith({
    Color? bgBase,
    Color? bgRaised,
    Color? bgSunken,
    Color? surface,
    Color? scrim,
    Color? borderSubtle,
    Color? borderDefault,
    Color? borderStrong,
    Color? textPrimary,
    Color? textSecondary,
    Color? textTertiary,
    Color? textDisabled,
    Color? textOnBrand,
  }) {
    return TSurfaceColors(
      bgBase: bgBase ?? this.bgBase,
      bgRaised: bgRaised ?? this.bgRaised,
      bgSunken: bgSunken ?? this.bgSunken,
      surface: surface ?? this.surface,
      scrim: scrim ?? this.scrim,
      borderSubtle: borderSubtle ?? this.borderSubtle,
      borderDefault: borderDefault ?? this.borderDefault,
      borderStrong: borderStrong ?? this.borderStrong,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textTertiary: textTertiary ?? this.textTertiary,
      textDisabled: textDisabled ?? this.textDisabled,
      textOnBrand: textOnBrand ?? this.textOnBrand,
    );
  }

  @override
  TSurfaceColors lerp(ThemeExtension<TSurfaceColors>? other, double t) {
    // lerp permet a Flutter d'animer la transition dark <-> light.
    // On interpole chaque couleur lineairement entre this et other.
    if (other is! TSurfaceColors) return this;
    return TSurfaceColors(
      bgBase: Color.lerp(bgBase, other.bgBase, t)!,
      bgRaised: Color.lerp(bgRaised, other.bgRaised, t)!,
      bgSunken: Color.lerp(bgSunken, other.bgSunken, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      scrim: Color.lerp(scrim, other.scrim, t)!,
      borderSubtle: Color.lerp(borderSubtle, other.borderSubtle, t)!,
      borderDefault: Color.lerp(borderDefault, other.borderDefault, t)!,
      borderStrong: Color.lerp(borderStrong, other.borderStrong, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textTertiary: Color.lerp(textTertiary, other.textTertiary, t)!,
      textDisabled: Color.lerp(textDisabled, other.textDisabled, t)!,
      textOnBrand: Color.lerp(textOnBrand, other.textOnBrand, t)!,
    );
  }
}

// =============================================================
// FICHIER : lib/core/design_system/tokens/spacing.dart
// ROLE   : Echelle d'espacement standardisee de l'app
// COUCHE : Core > Design System > Tokens
// =============================================================
//
// POURQUOI UNE ECHELLE ?
// ----------------------
// Avoir des SizedBox(height: 12) ici, SizedBox(height: 14) la et
// SizedBox(height: 16) ailleurs casse le rythme visuel. L'oeil ne
// percoit pas une harmonie de proportions.
//
// En utilisant une echelle fixe basee sur 4pt, on obtient :
//   - Un rythme visuel regulier, "pro"
//   - Une maintenance plus simple (changer global)
//   - Des concepts clairs : "cette section a besoin de 'lg', pas de 16"
//
// REFERENCES :
//   - Material Design 3 : baseline 4dp
//   - Apple HIG : multiples de 8pt
//   - Tailwind CSS : echelle 4px/8px/...
//   - Duolingo : utilise un rythme 8pt tres strict
//
// POURQUOI 4pt ET PAS 8pt ?
// -------------------------
// 4pt permet des ajustements fins (12pt existe, entre sm=8 et md=16)
// tout en preservant le rythme. Materiaux M3 accepte les deux.
// =============================================================

/// Tokens d'espacement de TRIALGO (echelle 4pt).
///
/// Usage :
/// ```dart
/// SizedBox(height: TSpacing.md)
/// Padding(padding: EdgeInsets.all(TSpacing.lg))
/// ```
class TSpacing {

  /// Pas d'espacement. Utile pour des EdgeInsets mixtes.
  static const double none = 0;

  /// 2pt — micro-ajustement (rares cas de tassement fin).
  static const double xxs = 2;

  /// 4pt — tres serre (icones proches, annotations).
  static const double xs = 4;

  /// 8pt — serre (items d'une liste, entre labels/valeurs).
  static const double sm = 8;

  /// 12pt — standard entre elements lies (ex: label + champ).
  static const double md = 12;

  /// 16pt — padding de base des cartes, espacement entre sections internes.
  static const double lg = 16;

  /// 20pt — respiration entre sections de meme niveau.
  static const double xl = 20;

  /// 24pt — padding de page, separation forte entre blocs.
  static const double xxl = 24;

  /// 32pt — grosse respiration (avant un call-to-action isole).
  static const double xxxl = 32;

  /// 48pt — separation majeure (hero vs reste de la page).
  static const double huge = 48;

  /// 64pt — espacement de scene (splash, entre grands blocs).
  static const double gigantic = 64;
}

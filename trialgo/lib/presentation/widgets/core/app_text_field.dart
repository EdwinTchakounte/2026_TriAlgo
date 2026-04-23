// =============================================================
// FICHIER : lib/presentation/widgets/core/app_text_field.dart
// ROLE   : Champ de saisie standard (glass + label + error + icon)
// COUCHE : Presentation > Widgets > Core
// =============================================================
//
// POURQUOI CE WIDGET ?
// --------------------
// Les pages actuelles construisent chacune leur propre Container
// autour d'un TextField, avec des styles variants (radius, alpha,
// border). AppTextField factorise tout :
//   - Style glassmorphism theme-aware
//   - Label optionnel au-dessus
//   - Icone leading (optionnelle)
//   - Toggle d'affichage pour les mots de passe (obscure)
//   - Affichage d'erreur inline (message rouge sous le champ)
//   - Texte d'aide (helper) bleuté
//   - Animation de focus (bordure qui se colore)
//
// ACCESSIBILITE :
// ---------------
// Pour un jeu enfant, on choisit :
//   - Hauteur minimale 56px (confortable au doigt)
//   - Corps 15px (lisible sans lunettes)
//   - Label >= 14px, en-dessus (pas de floating qui decale le focus)
// =============================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:trialgo/core/design_system/tokens/colors.dart';
import 'package:trialgo/core/design_system/tokens/motion.dart';
import 'package:trialgo/core/design_system/tokens/radius.dart';
import 'package:trialgo/core/design_system/tokens/spacing.dart';
import 'package:trialgo/core/design_system/tokens/typography.dart';


/// Champ de saisie standard de TRIALGO.
class AppTextField extends StatefulWidget {

  /// Controleur externe. Si null, AppTextField ne conserve pas la valeur.
  /// Fortement recommande pour les vrais formulaires.
  final TextEditingController? controller;

  /// Label affiche au-dessus du champ.
  /// Null = pas de label rendu.
  final String? label;

  /// Texte d'aide (hint) affiche dans le champ quand il est vide.
  final String? hint;

  /// Texte d'aide (helper) affiche sous le champ quand pas d'erreur.
  /// Utile pour donner des contraintes ("Minimum 6 caracteres").
  final String? helper;

  /// Message d'erreur inline. Non-null = le champ passe en etat erreur
  /// (bordure rouge + message affiche sous le champ).
  final String? errorText;

  /// Icone leading (a gauche dans le champ).
  final IconData? prefixIcon;

  /// Icone trailing custom (a droite). Ignoree si obscure=true.
  final Widget? suffix;

  /// Si true, le texte est masque (mots de passe). Un bouton oeil
  /// permet a l'utilisateur de toggler la visibilite.
  final bool obscure;

  /// Type de clavier (email, numero, texte, ...).
  final TextInputType keyboardType;

  /// Action du clavier (next, done, search, ...).
  final TextInputAction? textInputAction;

  /// Formatters d'entree (ex: limiter a chiffres, uppercase).
  final List<TextInputFormatter>? inputFormatters;

  /// Longueur max de la saisie. Null = pas de limite.
  final int? maxLength;

  /// Si false, le champ est en lecture seule.
  final bool enabled;

  /// Callback au moindre changement.
  final ValueChanged<String>? onChanged;

  /// Callback a la soumission (touche entree / bouton action).
  final ValueChanged<String>? onSubmitted;

  /// Alignement du texte dans le champ.
  final TextAlign textAlign;

  /// Style de texte personnalise (override du defaut).
  /// Utile pour les champs numeriques avec gros chiffres centres.
  final TextStyle? style;

  const AppTextField({
    super.key,
    this.controller,
    this.label,
    this.hint,
    this.helper,
    this.errorText,
    this.prefixIcon,
    this.suffix,
    this.obscure = false,
    this.keyboardType = TextInputType.text,
    this.textInputAction,
    this.inputFormatters,
    this.maxLength,
    this.enabled = true,
    this.onChanged,
    this.onSubmitted,
    this.textAlign = TextAlign.start,
    this.style,
  });

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}


class _AppTextFieldState extends State<AppTextField> {

  /// Node de focus pour reagir au focus/blur et changer la bordure.
  late final FocusNode _focusNode;

  /// Etat du toggle "afficher/masquer" pour les champs obscure.
  /// Independant de widget.obscure pour que le toggle fonctionne.
  late bool _obscuredLocal;

  /// Indique si le champ a le focus (pour colorer la bordure).
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode()..addListener(_handleFocusChange);
    _obscuredLocal = widget.obscure;
  }

  @override
  void dispose() {
    _focusNode.removeListener(_handleFocusChange);
    _focusNode.dispose();
    super.dispose();
  }

  /// Met a jour l'etat local quand le focus change, pour animer la bordure.
  void _handleFocusChange() {
    if (_isFocused != _focusNode.hasFocus) {
      setState(() => _isFocused = _focusNode.hasFocus);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = TColors.of(context);
    final hasError = widget.errorText != null && widget.errorText!.isNotEmpty;

    // Couleur de bordure : rouge si erreur, orange primary si focus, defaut sinon.
    // L'ordre de priorite : error > focus > defaut.
    final Color borderColor;
    if (hasError) {
      borderColor = TColors.error;
    } else if (_isFocused) {
      borderColor = TColors.primary;
    } else {
      borderColor = colors.borderDefault;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // --- Label au-dessus ---
        // On prefere un label "static above" plutot qu'un floating
        // label Material : mieux pour des enfants et pour la
        // lisibilite immediate (pas d'animation trompe-l'oeil).
        if (widget.label != null)
          Padding(
            padding: const EdgeInsets.only(bottom: TSpacing.sm),
            child: Text(
              widget.label!,
              style: TTypography.labelLg(color: colors.textSecondary),
            ),
          ),

        // --- Conteneur du champ ---
        // AnimatedContainer pour que le changement de bordure (focus /
        // error) soit anime avec une douceur propre.
        AnimatedContainer(
          duration: TDuration.quick,
          curve: TCurve.standard,
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: TRadius.lgAll,
            border: Border.all(
              color: borderColor,
              // 2px quand focus/erreur pour que ce soit visible.
              width: (_isFocused || hasError) ? 2 : 1,
            ),
          ),
          child: TextField(
            controller: widget.controller,
            focusNode: _focusNode,
            obscureText: _obscuredLocal,
            keyboardType: widget.keyboardType,
            textInputAction: widget.textInputAction,
            inputFormatters: widget.inputFormatters,
            maxLength: widget.maxLength,
            enabled: widget.enabled,
            onChanged: widget.onChanged,
            onSubmitted: widget.onSubmitted,
            textAlign: widget.textAlign,
            style: widget.style ??
                TTypography.bodyLg(color: colors.textPrimary),
            cursorColor: TColors.primary,
            decoration: InputDecoration(
              hintText: widget.hint,
              hintStyle: TTypography.bodyLg(color: colors.textTertiary),
              // Retire le fond Material par defaut pour laisser notre
              // AnimatedContainer parent gerer l'apparence.
              filled: false,
              // counterText vide pour masquer le compteur maxLength
              // (on prefere ne pas l'afficher, il alourdit l'UI).
              counterText: '',
              contentPadding: const EdgeInsets.symmetric(
                horizontal: TSpacing.lg,
                vertical: TSpacing.lg,
              ),
              // Icone leading.
              prefixIcon: widget.prefixIcon != null
                  ? Icon(
                      widget.prefixIcon,
                      color: _isFocused
                          ? TColors.primary
                          : colors.textTertiary,
                      size: 20,
                    )
                  : null,
              // Trailing : soit le toggle oeil (si obscure), soit le
              // widget custom passe par l'appelant.
              suffixIcon: _buildSuffix(colors),
              // Retire les underline Material par defaut (on a notre
              // propre bordure via AnimatedContainer).
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              errorBorder: InputBorder.none,
              focusedErrorBorder: InputBorder.none,
              disabledBorder: InputBorder.none,
            ),
          ),
        ),

        // --- Message d'erreur ou helper sous le champ ---
        // On affiche l'erreur en priorite si elle existe.
        if (hasError)
          Padding(
            padding: const EdgeInsets.only(top: TSpacing.xs, left: TSpacing.sm),
            child: Row(
              children: [
                const Icon(Icons.error_outline,
                    size: 14, color: TColors.error),
                const SizedBox(width: TSpacing.xs),
                Expanded(
                  child: Text(
                    widget.errorText!,
                    style: TTypography.labelMd(color: TColors.error),
                  ),
                ),
              ],
            ),
          )
        else if (widget.helper != null)
          Padding(
            padding: const EdgeInsets.only(top: TSpacing.xs, left: TSpacing.sm),
            child: Text(
              widget.helper!,
              style: TTypography.labelMd(color: colors.textTertiary),
            ),
          ),
      ],
    );
  }

  // =============================================================
  // METHODE : _buildSuffix
  // =============================================================
  // Priorite : si obscure, on affiche le toggle d'oeil.
  // Sinon, on laisse l'appelant fournir son widget trailing.
  // =============================================================

  /// Retourne le widget suffix a afficher dans le champ.
  Widget? _buildSuffix(TSurfaceColors colors) {
    if (widget.obscure) {
      // Toggle afficher/masquer pour les mots de passe.
      return IconButton(
        icon: Icon(
          _obscuredLocal ? Icons.visibility_off : Icons.visibility,
          color: colors.textTertiary,
          size: 20,
        ),
        onPressed: () => setState(() => _obscuredLocal = !_obscuredLocal),
        tooltip: _obscuredLocal ? 'Afficher' : 'Masquer',
      );
    }
    return widget.suffix;
  }
}

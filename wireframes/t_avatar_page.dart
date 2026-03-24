// =============================================================
// FICHIER : lib/presentation/wireframes/t_avatar_page.dart
// ROLE   : Selection d'avatar (sous-page Parametres)
// COUCHE : Presentation > Wireframes
// =============================================================

import 'package:flutter/material.dart';
import 'package:trialgo/presentation/wireframes/t_theme.dart';
import 'package:trialgo/presentation/wireframes/t_locale.dart';

/// Page de selection d'avatar avec grille d'avatars pre-definis.
class TAvatarPage extends StatefulWidget {
  const TAvatarPage({super.key});

  @override
  State<TAvatarPage> createState() => _TAvatarPageState();
}

class _TAvatarPageState extends State<TAvatarPage> {
  int? _selectedIndex;

  // Avatars pre-definis (couleur + icone).
  static const _avatars = [
    {'icon': Icons.pets, 'color': 0xFFFF6B35, 'name': 'Lion'},
    {'icon': Icons.flutter_dash, 'color': 0xFF42A5F5, 'name': 'Aigle'},
    {'icon': Icons.water, 'color': 0xFF26C6DA, 'name': 'Requin'},
    {'icon': Icons.local_fire_department, 'color': 0xFFEF5350, 'name': 'Dragon'},
    {'icon': Icons.park, 'color': 0xFF66BB6A, 'name': 'Panda'},
    {'icon': Icons.nightlight_round, 'color': 0xFF7E57C2, 'name': 'Loup'},
    {'icon': Icons.bolt, 'color': 0xFFF7C948, 'name': 'Faucon'},
    {'icon': Icons.ac_unit, 'color': 0xFF80DEEA, 'name': 'Ours'},
    {'icon': Icons.whatshot, 'color': 0xFFFF7043, 'name': 'Renard'},
    {'icon': Icons.psychology, 'color': 0xFFAB47BC, 'name': 'Serpent'},
    {'icon': Icons.terrain, 'color': 0xFF8D6E63, 'name': 'Tortue'},
    {'icon': Icons.waves, 'color': 0xFF29B6F6, 'name': 'Dauphin'},
  ];

  @override
  Widget build(BuildContext context) {
    final tr = TLocale.of(context);

    return Scaffold(
      body: TTheme.patterned(
        child: SafeArea(
          child: Column(
            children: [
              // Header.
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 20, 0),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: Container(
                        width: 40, height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.arrow_back_rounded, color: Colors.white54, size: 20),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Text(tr('avatar.title'), style: TTheme.titleStyle(size: 20)),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Preview de l'avatar selectionne.
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: _selectedIndex != null ? TTheme.accentGradient : null,
                  border: _selectedIndex == null
                      ? Border.all(color: Colors.white.withValues(alpha: 0.15), width: 2)
                      : null,
                ),
                child: CircleAvatar(
                  radius: 44,
                  backgroundColor: _selectedIndex != null
                      ? Color(_avatars[_selectedIndex!]['color'] as int).withValues(alpha: 0.2)
                      : const Color(0xFF16163A),
                  child: _selectedIndex != null
                      ? Icon(
                          _avatars[_selectedIndex!]['icon'] as IconData,
                          size: 40,
                          color: Color(_avatars[_selectedIndex!]['color'] as int),
                        )
                      : Icon(Icons.person_rounded, size: 40, color: Colors.white.withValues(alpha: 0.2)),
                ),
              ),

              const SizedBox(height: 10),

              Text(
                _selectedIndex != null
                    ? _avatars[_selectedIndex!]['name'] as String
                    : tr('avatar.none'),
                style: TTheme.subtitleStyle(
                  size: 16,
                  color: _selectedIndex != null ? Colors.white : Colors.white38,
                ),
              ),

              const SizedBox(height: 8),

              Text(
                tr('avatar.choose'),
                style: TTheme.bodyStyle(size: 12, color: Colors.white.withValues(alpha: 0.35)),
              ),

              const SizedBox(height: 20),

              // Grille d'avatars.
              Expanded(
                child: GridView.builder(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    crossAxisSpacing: 14,
                    mainAxisSpacing: 14,
                    childAspectRatio: 0.85,
                  ),
                  itemCount: _avatars.length,
                  itemBuilder: (context, index) {
                    final avatar = _avatars[index];
                    final color = Color(avatar['color'] as int);
                    final isSelected = _selectedIndex == index;

                    return GestureDetector(
                      onTap: () => setState(() => _selectedIndex = index),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? color.withValues(alpha: 0.15)
                              : Colors.white.withValues(alpha: 0.04),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSelected ? color : Colors.white.withValues(alpha: 0.06),
                            width: isSelected ? 2 : 1,
                          ),
                          boxShadow: isSelected
                              ? [BoxShadow(color: color.withValues(alpha: 0.3), blurRadius: 10)]
                              : [],
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(avatar['icon'] as IconData, size: 28, color: color),
                            const SizedBox(height: 4),
                            Text(
                              avatar['name'] as String,
                              style: TTheme.bodyStyle(
                                size: 10,
                                weight: FontWeight.w600,
                                color: isSelected ? color : Colors.white38,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),

              // Bouton sauvegarder.
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
                child: SizedBox(
                  width: double.infinity, height: 52,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: _selectedIndex != null
                          ? const LinearGradient(colors: [TTheme.orange, TTheme.gold])
                          : null,
                      color: _selectedIndex != null ? null : Colors.white12,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: ElevatedButton(
                      onPressed: _selectedIndex != null
                          ? () {
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                content: Row(children: [
                                  const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                                  const SizedBox(width: 8),
                                  Text(tr('avatar.saved')),
                                ]),
                                backgroundColor: TTheme.green,
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                margin: const EdgeInsets.all(16),
                              ));
                              Navigator.of(context).pop();
                            }
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        disabledBackgroundColor: Colors.transparent,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: Text(tr('avatar.save'), style: TTheme.buttonStyle()),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

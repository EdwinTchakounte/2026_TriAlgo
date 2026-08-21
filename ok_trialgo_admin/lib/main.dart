// =============================================================
// FICHIER : main.dart
// ROLE    : Point d'entree de l'app TRIALGO Admin
// =============================================================
//
// Sequence de boot :
//   1. WidgetsFlutterBinding.ensureInitialized()
//      - obligatoire avant tout await dans main().
//   2. Supabase.initialize(url, anonKey)
//      - configure le SDK et restaure la session persistee
//        (Supabase stocke le JWT dans SharedPreferences).
//   3. runApp(ProviderScope(child: TrialgoAdminApp()))
//      - ProviderScope = racine de Riverpod ; tous les Provider
//        doivent etre descendants pour pouvoir etre lus.
//
// Apres ca, _AuthGate aiguille selon AuthStatus :
//   - loading    : splash (verif initiale)
//   - signedOut  : LoginPage
//   - notAdmin   : LoginPage avec banner d'erreur
//   - admin      : GamesHubPage (hub de selection/creation)
// =============================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/api/api_config.dart';
import 'core/config/supabase_config.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/app_text_styles.dart';
import 'core/theme/app_theme.dart';
import 'presentation/pages/auth/login_page.dart';
import 'presentation/pages/games/games_hub_page.dart';
import 'presentation/providers/auth_provider.dart';

Future<void> main() async {
  // Avant tout await : indispensable pour que le canal natif
  // soit pret a recevoir des appels (Supabase utilise SharedPrefs).
  WidgetsFlutterBinding.ensureInitialized();

  // Supabase SDK initialise seulement si on en a besoin (mode
  // supabase). Le SDK n'est pas leger ; en mode fake / fastapi
  // on s'en passe.
  if (ApiConfig.mode == ApiMode.supabase) {
    await Supabase.initialize(
      url: SupabaseConfig.url,
      anonKey: SupabaseConfig.anonKey,
    );
  }

  runApp(
    // ProviderScope rend disponible Riverpod a tout l'arbre.
    // Les overrides sont gerees DIRECTEMENT dans repositories_provider.dart
    // selon ApiConfig.mode, donc plus besoin d'overrides ici.
    const ProviderScope(child: TrialgoAdminApp()),
  );
}

// =============================================================
// FLAG DE BYPASS POUR LE MODE FAKE
// =============================================================
// En mode fake (offline), on saute le login pour aller direct
// sur le hub (utile pour valider l'UX sans creer de compte).
// En mode supabase / fastapi, on passe par l'ecran d'auth normal.
// =============================================================
bool get kDevBypassAuth => ApiConfig.mode == ApiMode.fake;

class TrialgoAdminApp extends StatelessWidget {
  const TrialgoAdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TRIALGO Admin',
      theme: buildAppTheme(),
      // Retire le ruban DEBUG en debug build : encombre le coin
      // superieur droit pendant les screenshots.
      debugShowCheckedModeBanner: false,
      home: const _AuthGate(),
    );
  }
}

// =============================================================
// _AuthGate : aiguilleur en fonction de AuthStatus
// =============================================================
class _AuthGate extends ConsumerWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // DEV : court-circuite l'auth pour aller direct au hub.
    if (kDevBypassAuth) {
      return const GamesHubPage();
    }

    final status = ref.watch(authProvider).status;

    switch (status) {
      case AuthStatus.loading:
        return const _SplashScreen();
      case AuthStatus.admin:
        return const GamesHubPage();
      case AuthStatus.signedOut:
      case AuthStatus.notAdmin:
        // Dans les 2 cas on montre LoginPage. Elle lit
        // authProvider.errorMessage pour afficher le motif.
        return const LoginPage();
    }
  }
}

// =============================================================
// _SplashScreen : ecran d'attente pendant verif session
// =============================================================
// On centre verticalement un bloc (logo + titre + sous-titre +
// loader). Le logo est entoure de 2 cercles concentriques pour
// donner du relief sans tomber dans le skeuomorphisme.
// =============================================================
class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Logo : 2 cercles concentriques + icone centrale.
            // L'effet "halo" se cree avec un cercle plus grand
            // peu opaque autour d'un cercle plus petit plus dense.
            SizedBox(
              width: 132,
              height: 132,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 132,
                    height: 132,
                    decoration: BoxDecoration(
                      color: AppColors.brand.withValues(alpha: 0.06),
                      shape: BoxShape.circle,
                    ),
                  ),
                  Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      color: AppColors.brand.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.auto_awesome_mosaic,
                      size: 44,
                      color: AppColors.brand,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text('TRIALGO Admin', style: AppTextStyles.hero()),
            const SizedBox(height: 6),
            Text(
              'Studio de creation de jeux',
              style: AppTextStyles.caption(),
            ),
            const SizedBox(height: 36),
            // Loader plus discret : 22px au lieu du gros par defaut.
            const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
            const SizedBox(height: 12),
            Text(
              'Chargement de votre session',
              style: AppTextStyles.caption(),
            ),
          ],
        ),
      ),
    );
  }
}

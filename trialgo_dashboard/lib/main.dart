// =============================================================
// FICHIER : main.dart
// ROLE    : Point d'entree de l'app dashboard
// =============================================================
//
// Sequence au demarrage :
//   1. WidgetsFlutterBinding.ensureInitialized()
//      -> requis avant tout appel async dans main()
//   2. Supabase.initialize(url, anonKey)
//      -> charge la session locale s'il y en a une (cache)
//   3. runApp(ProviderScope(child: TrialgoDashboardApp()))
//      -> ProviderScope active Riverpod pour toute l'app
//
// Apres ca, AuthGate decide quelle page afficher selon
// l'AuthStatus :
//   - loading   : splash
//   - signedOut : LoginPage
//   - notAdmin  : LoginPage avec message d'erreur
//   - admin     : HomePage
// =============================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/supabase_config.dart';
import 'core/theme.dart';
import 'presentation/pages/home_page.dart';
import 'presentation/pages/login_page.dart';
import 'presentation/providers/auth_provider.dart';

Future<void> main() async {
  // Indispensable AVANT tout await dans main(). Sans ca, Flutter
  // jette "Binding has not yet been initialized".
  WidgetsFlutterBinding.ensureInitialized();

  // Initialise le client Supabase. Cette etape :
  //   - configure le SDK avec URL et anon key
  //   - tente de restaurer une session persistee localement
  //     (Supabase la stocke dans SharedPreferences)
  // C'est pour cette derniere raison que AuthNotifier verifie
  // currentUser au demarrage : on peut etre deja "connecte"
  // d'une session precedente.
  await Supabase.initialize(
    url: SupabaseConfig.url,
    anonKey: SupabaseConfig.anonKey,
  );

  runApp(
    // ProviderScope = racine de Riverpod. Tous les Provider doivent
    // etre lus depuis un widget descendant de ProviderScope.
    const ProviderScope(child: TrialgoDashboardApp()),
  );
}

class TrialgoDashboardApp extends StatelessWidget {
  const TrialgoDashboardApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TRIALGO Dashboard',
      theme: buildTheme(),
      // debugShowCheckedModeBanner = false : retire le ruban "DEBUG"
      // qui pollue le coin superieur droit en debug build.
      debugShowCheckedModeBanner: false,
      home: const _AuthGate(),
    );
  }
}

// =============================================================
// _AuthGate : aiguilleur global selon l'AuthStatus
// =============================================================
class _AuthGate extends ConsumerWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);

    switch (auth.status) {
      case AuthStatus.loading:
        return const _SplashScreen();
      case AuthStatus.admin:
        return const HomePage();
      case AuthStatus.signedOut:
      case AuthStatus.notAdmin:
        // Dans les deux cas, on affiche LoginPage. Le notifier
        // expose errorMessage qui apparait si notAdmin (via la
        // LoginPage qui lit auth.errorMessage).
        return const LoginPage();
    }
  }
}

// =============================================================
// _SplashScreen : ecran d'attente pendant la restauration session
// =============================================================
class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.dashboard_customize, size: 60, color: TBrand.orange),
            SizedBox(height: 16),
            Text(
              'TRIALGO Dashboard',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            SizedBox(height: 24),
            CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}

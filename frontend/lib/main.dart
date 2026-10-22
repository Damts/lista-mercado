import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api.dart';
import 'screens/houses_page.dart';
import 'screens/list_page.dart';
import 'screens/login_page.dart';
import 'screens/profile_page.dart';
import 'screens/settings_page.dart';
import 'state.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final state = AppState(ApiClient(prefs: prefs));
  await state.bootstrap();
  runApp(ChangeNotifierProvider.value(value: state, child: const App()));
}

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final router = GoRouter(
      initialLocation: state.authenticated ? '/casas' : '/login',
      redirect: (_, location) {
        if (state.loading) return null;
        if (!state.authenticated && location.matchedLocation != '/login') {
          return '/login';
        }
        if (state.authenticated && location.matchedLocation == '/login') {
          return '/casas';
        }
        return null;
      },
      routes: [
        GoRoute(path: '/login', builder: (_, _) => const LoginPage()),
        GoRoute(path: '/casas', builder: (_, _) => const HousesPage()),
        GoRoute(path: '/lista', builder: (_, _) => const ListPage()),
        GoRoute(path: '/perfil', builder: (_, _) => const ProfilePage()),
        GoRoute(
          path: '/configuracoes',
          builder: (_, _) => const SettingsPage(),
        ),
      ],
    );
    return MaterialApp.router(
      title: 'Lista Mercado',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      routerConfig: router,
    );
  }
}

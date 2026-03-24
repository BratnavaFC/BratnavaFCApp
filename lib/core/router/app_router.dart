import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/auth/presentation/pages/register_page.dart';
import '../../features/auth/presentation/providers/account_store.dart';
import '../../features/calendar/presentation/pages/calendar_page.dart';
import '../../features/dashboard/presentation/pages/dashboard_page.dart';
import '../../features/team_colors/presentation/pages/team_colors_page.dart';
import '../../features/history/presentation/pages/history_page.dart';
import '../../features/history/presentation/pages/match_details_page.dart';
import '../../features/players/presentation/pages/players_page.dart';
import '../../features/shell/presentation/pages/shell_page.dart';

// ── Placeholder para rotas ainda não implementadas ────────────────────────────
class _PlaceholderPage extends StatelessWidget {
  final String title;
  const _PlaceholderPage(this.title);

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(title)),
        body: Center(
          child: Text(
            '$title\nem desenvolvimento',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16),
          ),
        ),
      );
}

// ── Router Provider ───────────────────────────────────────────────────────────

final routerProvider = Provider<GoRouter>((ref) {
  final authListenable = _AccountStateListenable(ref);

  return GoRouter(
    refreshListenable: authListenable,
    initialLocation:   '/login',
    redirect: (context, state) {
      final isLoggedIn = ref.read(accountStoreProvider).isLoggedIn;
      final path       = state.uri.path;
      final isAddMode  = state.uri.queryParameters['add'] == '1';

      final isAuthRoute = path == '/login' ||
          path == '/register' ||
          path.startsWith('/login');

      if (!isLoggedIn && !isAuthRoute) return '/login';
      // Permite /login?add=1 mesmo estando logado (adicionar segunda conta)
      if (isLoggedIn && isAuthRoute && !isAddMode) return '/app';
      return null;
    },
    routes: [
      // ── Auth ──────────────────────────────────────────────────────
      GoRoute(
        path:    '/login',
        builder: (_, state) => LoginPage(
          addMode: state.uri.queryParameters['add'] == '1',
        ),
      ),
      GoRoute(
        path:    '/register',
        builder: (_, __) => const RegisterPage(),
      ),

      // ── App shell ─────────────────────────────────────────────────
      ShellRoute(
        builder: (_, __, child) => ShellPage(child: child),
        routes: [
          GoRoute(
            path:    '/app',
            builder: (_, __) => const DashboardPage(),
          ),
          GoRoute(
            path:    '/app/matches',
            builder: (_, __) => const _PlaceholderPage('Partidas'),
          ),
          GoRoute(
            path:    '/app/groups',
            builder: (_, __) => const _PlaceholderPage('Grupos'),
          ),
          GoRoute(
            path:    '/app/history',
            builder: (_, __) => const HistoryPage(),
          ),
          GoRoute(
            path:    '/app/history/:groupId/:matchId',
            builder: (_, state) => MatchDetailsPage(
              groupId: state.pathParameters['groupId'] ?? '',
              matchId: state.pathParameters['matchId'] ?? '',
            ),
          ),
          GoRoute(
            path:    '/app/calendar',
            builder: (_, __) => const CalendarPage(),
          ),
          GoRoute(
            path:    '/app/team-colors',
            builder: (_, __) => const TeamColorsPage(),
          ),
          GoRoute(
            path:    '/app/visual-stats',
            builder: (_, __) => const _PlaceholderPage('Visual Stats'),
          ),
          GoRoute(
            path:    '/app/payments',
            builder: (_, __) => const _PlaceholderPage('Pagamentos'),
          ),
          GoRoute(
            path:    '/app/polls',
            builder: (_, __) => const _PlaceholderPage('Enquetes'),
          ),
          GoRoute(
            path:    '/app/birthdays',
            builder: (_, __) => const _PlaceholderPage('Aniversários'),
          ),
          GoRoute(
            path:    '/app/settings',
            builder: (_, __) => const _PlaceholderPage('Configurações'),
          ),
          GoRoute(
            path:    '/app/admin/users',
            builder: (_, __) => const PlayersPage(),
          ),
        ],
      ),
    ],
  );
});

/// Conecta o Riverpod AccountState ao sistema de refresh do GoRouter.
class _AccountStateListenable extends ChangeNotifier {
  final Ref _ref;

  _AccountStateListenable(this._ref) {
    _ref.listen<AccountState>(accountStoreProvider, (_, __) {
      notifyListeners();
    });
  }
}

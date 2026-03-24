import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/presentation/providers/account_store.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/datasources/dashboard_remote_datasource.dart';
import '../../domain/entities/current_match.dart';
import '../../domain/entities/my_player.dart';
import '../../domain/entities/recent_match.dart';

// ── DataSource ────────────────────────────────────────────────────────────────

final _dashboardDsProvider = Provider<DashboardRemoteDataSource>(
  (ref) => DashboardRemoteDataSource(ref.watch(dioProvider)),
);

// ── Jogadores do usuário ──────────────────────────────────────────────────────

final myPlayersProvider = FutureProvider.autoDispose<List<MyPlayer>>((ref) {
  // Re-fetch sempre que a conta ativa mudar.
  ref.watch(accountStoreProvider.select((s) => s.activeAccountId));
  final ds = ref.watch(_dashboardDsProvider);
  return ds.fetchMyPlayers();
});

// ── Partida atual ─────────────────────────────────────────────────────────────

final currentMatchProvider =
    FutureProvider.autoDispose.family<CurrentMatch?, String>((ref, groupId) {
  final ds = ref.watch(_dashboardDsProvider);
  return ds.fetchCurrentMatch(groupId);
});

// ── Últimas partidas do jogador ───────────────────────────────────────────────

final recentMatchesProvider =
    FutureProvider.autoDispose.family<List<RecentMatch>, ({String groupId, String playerId})>(
  (ref, args) {
    final ds = ref.watch(_dashboardDsProvider);
    return ds.fetchRecentMatches(args.groupId, args.playerId);
  },
);

// ── Jogador ativo ─────────────────────────────────────────────────────────────

/// ID do jogador selecionado atualmente no Dashboard.
final activePlayerIdProvider =
    StateProvider.autoDispose<String?>((ref) => null);

/// Jogador ativo resolvido (usa o activePlayerId do account store ou
/// o primeiro da lista).
final activePlayerProvider = Provider.autoDispose<MyPlayer?>((ref) {
  final players       = ref.watch(myPlayersProvider).valueOrNull ?? [];
  final accountActive = ref.watch(accountStoreProvider).activeAccount;
  final manualId      = ref.watch(activePlayerIdProvider);

  final targetId = manualId ??
      accountActive?.activePlayerId ??
      (players.isNotEmpty ? players.first.playerId : null);

  if (targetId == null || players.isEmpty) return null;

  try {
    return players.firstWhere(
      (p) => p.playerId == targetId,
      orElse: () => players.first,
    );
  } catch (_) {
    return null;
  }
});

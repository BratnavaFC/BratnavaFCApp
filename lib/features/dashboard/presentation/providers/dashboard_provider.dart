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

/// Não usa autoDispose — precisa sobreviver à navegação entre abas para que
/// Histórico, Replays e outras telas encontrem o grupo do jogador sem refetch.
final myPlayersProvider = FutureProvider<List<MyPlayer>>((ref) {
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

/// ID do jogador selecionado manualmente pelo usuário no Dashboard.
/// Não usa autoDispose — a seleção precisa persistir ao navegar entre abas.
final activePlayerIdProvider = StateProvider<String?>((ref) => null);

/// Jogador ativo resolvido (usa o activePlayerId do account store ou
/// o primeiro da lista). Não autoDispose pelo mesmo motivo acima.
final activePlayerProvider = Provider<MyPlayer?>((ref) {
  final playersAsync  = ref.watch(myPlayersProvider);
  final accountActive = ref.watch(accountStoreProvider).activeAccount;
  final manualId      = ref.watch(activePlayerIdProvider);

  // Enquanto re-fetch está em andamento (troca de conta), valueOrNull ainda
  // contém os jogadores da conta anterior. Retorna null para não exibir dados
  // do grupo errado no topo e no dashboard durante a transição.
  if (playersAsync.isLoading) return null;

  final players = playersAsync.valueOrNull ?? [];
  if (players.isEmpty) return null;

  final explicitId = manualId ?? accountActive?.activePlayerId;
  if (explicitId != null) {
    final matches = players.where((p) => p.playerId == explicitId);
    return matches.isEmpty ? null : matches.first;
  }

  // Sem ID explícito salvo: usa o primeiro jogador disponível.
  return players.first;
});

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/datasources/history_remote_datasource.dart';
import '../../domain/entities/history_match.dart';
import '../../domain/entities/match_details.dart';

// ── DataSource ────────────────────────────────────────────────────────────────

final _historyDsProvider = Provider<HistoryRemoteDataSource>(
  (ref) => HistoryRemoteDataSource(ref.watch(dioProvider)),
);

// ── History list ──────────────────────────────────────────────────────────────

final historyProvider =
    FutureProvider.autoDispose.family<List<HistoryMatch>, String>(
  (ref, groupId) {
    final ds = ref.watch(_historyDsProvider);
    return ds.fetchHistory(groupId);
  },
);

// ── Match details ─────────────────────────────────────────────────────────────

final matchDetailsProvider = FutureProvider.autoDispose
    .family<MatchDetails, ({String groupId, String matchId})>(
  (ref, args) {
    final ds = ref.watch(_historyDsProvider);
    return ds.fetchMatchDetails(args.groupId, args.matchId);
  },
);

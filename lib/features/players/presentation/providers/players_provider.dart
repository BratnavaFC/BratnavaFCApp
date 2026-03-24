import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/datasources/players_remote_datasource.dart';
import '../../domain/entities/app_user.dart';
import '../../domain/entities/group_player.dart';

final playersDsProvider = Provider<PlayersRemoteDataSource>(
  (ref) => PlayersRemoteDataSource(ref.watch(dioProvider)),
);

// ── Users (admin listing) ─────────────────────────────────────────────────────

final usersProvider = FutureProvider.autoDispose<List<AppUser>>((ref) {
  final ds = ref.watch(playersDsProvider);
  return ds.fetchUsers();
});

// ── Players (group) ───────────────────────────────────────────────────────────

final playersProvider =
    FutureProvider.autoDispose.family<List<GroupPlayer>, String>(
  (ref, groupId) {
    final ds = ref.watch(playersDsProvider);
    return ds.fetchGroupPlayers(groupId);
  },
);

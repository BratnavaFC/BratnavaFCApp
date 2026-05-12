import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/datasources/replays_remote_datasource.dart';
import '../../domain/entities/replay_clip.dart';

// ── DataSource ────────────────────────────────────────────────────────────────

final replaysDsProvider = Provider<ReplaysRemoteDataSource>(
  (ref) => ReplaysRemoteDataSource(ref.watch(dioProvider)),
);

// ── Tabs state notifiers ──────────────────────────────────────────────────────

/// Shared mutable list of [ReplayClip] with optimistic update helpers.
class ReplayListNotifier extends StateNotifier<AsyncValue<List<ReplayClip>>> {
  final ReplaysRemoteDataSource _ds;
  final String _groupId;
  final Future<List<ReplayClip>> Function() _fetcher;

  ReplayListNotifier({
    required ReplaysRemoteDataSource ds,
    required String groupId,
    required Future<List<ReplayClip>> Function() fetcher,
  })  : _ds = ds,
        _groupId = groupId,
        _fetcher = fetcher,
        super(const AsyncLoading()) {
    fetch();
  }

  Future<void> fetch() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_fetcher);
  }

  // ── Optimistic like toggle ────────────────────────────────────────────────

  Future<void> toggleLike(String clipId) async {
    final current = state.valueOrNull;
    if (current == null) return;

    final idx = current.indexWhere((c) => c.clipId == clipId);
    if (idx < 0) return;

    final clip       = current[idx];
    final wasLiked   = clip.isLiked;
    final optimistic = List<ReplayClip>.from(current)
      ..[idx] = clip.copyWith(
        isLiked:   !wasLiked,
        likeCount: wasLiked ? clip.likeCount - 1 : clip.likeCount + 1,
      );

    state = AsyncData(optimistic);

    try {
      final result  = await _ds.toggleLike(_groupId, clipId);
      final current2 = state.valueOrNull ?? optimistic;
      final idx2     = current2.indexWhere((c) => c.clipId == clipId);
      if (idx2 >= 0) {
        final updated = List<ReplayClip>.from(current2)
          ..[idx2] = current2[idx2].copyWith(
            isLiked:   result.isLiked,
            likeCount: result.likeCount,
          );
        state = AsyncData(updated);
      }
    } catch (_) {
      // Revert to pre-optimistic state
      final current2 = state.valueOrNull ?? optimistic;
      final idx2     = current2.indexWhere((c) => c.clipId == clipId);
      if (idx2 >= 0) {
        final reverted = List<ReplayClip>.from(current2)..[idx2] = clip;
        state = AsyncData(reverted);
      }
      rethrow;
    }
  }

  // ── Optimistic favorite toggle ────────────────────────────────────────────

  Future<void> toggleFavorite(String clipId) async {
    final current = state.valueOrNull;
    if (current == null) return;

    final idx = current.indexWhere((c) => c.clipId == clipId);
    if (idx < 0) return;

    final clip          = current[idx];
    final wasFavorited  = clip.isFavorited;
    final optimistic    = List<ReplayClip>.from(current)
      ..[idx] = clip.copyWith(isFavorited: !wasFavorited);

    state = AsyncData(optimistic);

    try {
      final isFavorited = await _ds.toggleFavorite(_groupId, clipId);
      final current2    = state.valueOrNull ?? optimistic;
      final idx2        = current2.indexWhere((c) => c.clipId == clipId);
      if (idx2 >= 0) {
        final updated = List<ReplayClip>.from(current2)
          ..[idx2] = current2[idx2].copyWith(isFavorited: isFavorited);
        state = AsyncData(updated);
      }
    } catch (_) {
      final current2 = state.valueOrNull ?? optimistic;
      final idx2     = current2.indexWhere((c) => c.clipId == clipId);
      if (idx2 >= 0) {
        final reverted = List<ReplayClip>.from(current2)..[idx2] = clip;
        state = AsyncData(reverted);
      }
      rethrow;
    }
  }

  // ── Delete ────────────────────────────────────────────────────────────────

  Future<void> deleteClip(String clipId) async {
    await _ds.deleteClip(_groupId, clipId);
    final current = state.valueOrNull;
    if (current != null) {
      state = AsyncData(current.where((c) => c.clipId != clipId).toList());
    }
  }
}

// ── Providers ─────────────────────────────────────────────────────────────────

final replaysAllProvider =
    StateNotifierProvider.autoDispose.family<ReplayListNotifier,
        AsyncValue<List<ReplayClip>>, String>(
  (ref, groupId) => ReplayListNotifier(
    ds:      ref.watch(replaysDsProvider),
    groupId: groupId,
    fetcher: () => ref.read(replaysDsProvider).fetchAll(groupId),
  ),
);

final replaysLikedProvider =
    StateNotifierProvider.autoDispose.family<ReplayListNotifier,
        AsyncValue<List<ReplayClip>>, String>(
  (ref, groupId) => ReplayListNotifier(
    ds:      ref.watch(replaysDsProvider),
    groupId: groupId,
    fetcher: () => ref.read(replaysDsProvider).fetchMyLikes(groupId),
  ),
);

final replaysFavoritesProvider =
    StateNotifierProvider.autoDispose.family<ReplayListNotifier,
        AsyncValue<List<ReplayClip>>, String>(
  (ref, groupId) => ReplayListNotifier(
    ds:      ref.watch(replaysDsProvider),
    groupId: groupId,
    fetcher: () => ref.read(replaysDsProvider).fetchMyFavorites(groupId),
  ),
);

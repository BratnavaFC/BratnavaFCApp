import 'package:dio/dio.dart';
import '../../domain/entities/replay_clip.dart';

class ReplaysRemoteDataSource {
  final Dio _dio;
  const ReplaysRemoteDataSource(this._dio);

  // ── Endpoint helpers ──────────────────────────────────────────────────────

  static String _all(String gid) =>
      '/api/matches/group/$gid/replays/all';
  static String _myLikes(String gid) =>
      '/api/matches/group/$gid/replays/my-likes';
  static String _myFavorites(String gid) =>
      '/api/matches/group/$gid/replays/my-favorites';
  static String _like(String gid, String cid) =>
      '/api/matches/group/$gid/replays/$cid/like';
  static String _favorite(String gid, String cid) =>
      '/api/matches/group/$gid/replays/$cid/favorite';
  static String _stream(String gid, String cid) =>
      '/api/matches/group/$gid/replays/$cid/stream';
  static String _delete(String gid, String cid) =>
      '/api/matches/group/$gid/replays/$cid';

  // ── Queries ───────────────────────────────────────────────────────────────

  Future<List<ReplayClip>> fetchAll(String groupId) async {
    final res = await _dio.get(_all(groupId));
    final raw = _unwrapList(res.data);
    return raw.map((e) => ReplayClip.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<ReplayClip>> fetchMyLikes(String groupId) async {
    final res = await _dio.get(_myLikes(groupId));
    final raw = _unwrapList(res.data);
    return raw.map((e) => ReplayClip.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<ReplayClip>> fetchMyFavorites(String groupId) async {
    final res = await _dio.get(_myFavorites(groupId));
    final raw = _unwrapList(res.data);
    return raw.map((e) => ReplayClip.fromJson(e as Map<String, dynamic>)).toList();
  }

  // ── Mutations ─────────────────────────────────────────────────────────────

  /// Returns the new like state and count.
  Future<({bool isLiked, int likeCount})> toggleLike(
      String groupId, String clipId) async {
    final res = await _dio.post(_like(groupId, clipId));
    final data = _unwrapMap(res.data);
    return (
      isLiked:   data['isLiked']   as bool? ?? false,
      likeCount: data['likeCount'] as int?  ?? 0,
    );
  }

  /// Returns the new favorite state.
  Future<bool> toggleFavorite(String groupId, String clipId) async {
    final res = await _dio.post(_favorite(groupId, clipId));
    final data = _unwrapMap(res.data);
    return data['isFavorited'] as bool? ?? false;
  }

  Future<void> deleteClip(String groupId, String clipId) async {
    await _dio.delete(_delete(groupId, clipId));
  }

  /// Returns the relative stream path (caller appends base URL + token).
  String streamPath(String groupId, String clipId) =>
      _stream(groupId, clipId);

  // ── Helpers ───────────────────────────────────────────────────────────────

  List<dynamic> _unwrapList(dynamic data) {
    if (data is List) return data;
    if (data is Map) {
      final inner = data['data'] ?? data['Data'];
      if (inner is List) return inner;
    }
    return const [];
  }

  Map<String, dynamic> _unwrapMap(dynamic data) {
    if (data is Map<String, dynamic>) {
      final inner = data['data'] ?? data['Data'];
      if (inner is Map<String, dynamic>) return inner;
      return data;
    }
    return const {};
  }
}

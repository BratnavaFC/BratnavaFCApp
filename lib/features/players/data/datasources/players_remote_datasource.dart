import 'package:dio/dio.dart';
import '../../../../core/api/api_constants.dart';
import '../../domain/entities/app_user.dart';
import '../../domain/entities/group_player.dart';

class PlayersRemoteDataSource {
  final Dio _dio;
  const PlayersRemoteDataSource(this._dio);

  // ── Users ────────────────────────────────────────────────────────────────────

  Future<List<AppUser>> fetchUsers() async {
    final res = await _dio.get(ApiConstants.users);
    final raw = _unwrapList(res.data);
    return raw
        .map((e) => AppUser.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ── Players (group) ───────────────────────────────────────────────────────────

  Future<List<GroupPlayer>> fetchGroupPlayers(String groupId) async {
    final res = await _dio.get(ApiConstants.groupPlayers(groupId));
    final raw = _unwrapList(res.data);
    return raw
        .map((e) => GroupPlayer.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<GroupPlayer> createPlayer(
    String groupId,
    String name,
    bool   isGoalkeeper,
    int    skillPoints,
    bool   isGuest,
  ) async {
    final res = await _dio.post(
      '/api/Players',
      data: {
        'groupId':      groupId,
        'name':         name,
        'isGoalkeeper': isGoalkeeper,
        'skillPoints':  skillPoints,
        'isGuest':      isGuest,
      },
    );
    final raw = _unwrapMap(res.data);
    return GroupPlayer.fromJson(raw);
  }

  Future<GroupPlayer> updatePlayer(
    String id,
    String groupId,
    String name,
    bool   isGoalkeeper,
    int    skillPoints,
    bool   isGuest,
  ) async {
    final res = await _dio.put(
      ApiConstants.playerOps(id),
      data: {
        'groupId':      groupId,
        'name':         name,
        'isGoalkeeper': isGoalkeeper,
        'skillPoints':  skillPoints,
        'isGuest':      isGuest,
      },
    );
    final raw = _unwrapMap(res.data);
    return GroupPlayer.fromJson(raw);
  }

  Future<void> deletePlayer(String id) async {
    await _dio.delete(ApiConstants.playerOps(id));
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────

  List<dynamic> _unwrapList(dynamic data) {
    if (data is List) return data;
    if (data is Map) {
      final d = data['data'];
      if (d is List) return d;
    }
    return [];
  }

  Map<String, dynamic> _unwrapMap(dynamic data) {
    if (data is Map<String, dynamic>) {
      if (data.containsKey('data') && data['data'] is Map<String, dynamic>) {
        return data['data'] as Map<String, dynamic>;
      }
      return data;
    }
    return {};
  }
}

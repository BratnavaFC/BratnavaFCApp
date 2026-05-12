import 'package:dio/dio.dart';
import '../../domain/entities/bet_models.dart';

class BetRemoteDataSource {
  final Dio _dio;
  const BetRemoteDataSource(this._dio);

  // ── Endpoints ─────────────────────────────────────────────────────────────

  static String _current(String gid)            => '/api/bet/group/$gid/current';
  static String _bet(String gid, String mid)    => '/api/bet/group/$gid/match/$mid';
  static String _leaderboard(String gid)        => '/api/bet/group/$gid/leaderboard';
  static String _balance(String gid)            => '/api/bet/group/$gid/balance';
  static String _history(String gid)            => '/api/bet/group/$gid/history';

  // ── Current match + my bet ────────────────────────────────────────────────

  Future<CurrentMatchBetContext?> fetchCurrent(String groupId) async {
    try {
      final res  = await _dio.get(_current(groupId));
      final data = _unwrapMap(res.data);
      if (data == null) return null;
      return CurrentMatchBetContext.fromJson(data);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      rethrow;
    }
  }

  // ── Place / update bet ────────────────────────────────────────────────────

  Future<void> placeOrUpdateBet(
      String groupId, String matchId, PlaceMatchBetDto dto) async {
    await _dio.post(_bet(groupId, matchId), data: dto.toJson());
  }

  // ── Delete my bet ─────────────────────────────────────────────────────────

  Future<void> deleteBet(String groupId, String matchId) async {
    await _dio.delete(_bet(groupId, matchId));
  }

  // ── Leaderboard ───────────────────────────────────────────────────────────

  Future<List<BetLeaderboardEntry>> fetchLeaderboard(String groupId) async {
    final res = await _dio.get(_leaderboard(groupId));
    final raw = _unwrapList(res.data);
    return raw
        .whereType<Map<String, dynamic>>()
        .map(BetLeaderboardEntry.fromJson)
        .toList();
  }

  // ── Balance ───────────────────────────────────────────────────────────────

  Future<int> fetchBalance(String groupId) async {
    final res  = await _dio.get(_balance(groupId));
    final data = _unwrapMap(res.data);
    return (data?['balance'] as num?)?.toInt() ?? 0;
  }

  // ── History ───────────────────────────────────────────────────────────────

  Future<List<MatchBetHistoryDto>> fetchHistory(String groupId) async {
    final res = await _dio.get(_history(groupId));
    final raw = _unwrapList(res.data);
    return raw
        .whereType<Map<String, dynamic>>()
        .map(MatchBetHistoryDto.fromJson)
        .toList();
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Map<String, dynamic>? _unwrapMap(dynamic data) {
    if (data is Map<String, dynamic>) {
      if (data['data'] is Map<String, dynamic>) return data['data'] as Map<String, dynamic>;
      if (data['Data'] is Map<String, dynamic>) return data['Data'] as Map<String, dynamic>;
      if (data.containsKey('success') || data.containsKey('Success')) return null;
      return data;
    }
    return null;
  }

  List<dynamic> _unwrapList(dynamic data) {
    if (data is List) return data;
    if (data is Map) {
      final inner = data['data'] ?? data['Data'];
      if (inner is List) return inner;
    }
    return [];
  }
}

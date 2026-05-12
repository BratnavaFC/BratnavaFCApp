import 'package:dio/dio.dart';
import '../../../../core/api/api_constants.dart';
import '../../domain/entities/match_models.dart';

class MatchRemoteDataSource {
  final Dio _dio;
  const MatchRemoteDataSource(this._dio);

  // ── Helpers ───────────────────────────────────────────────────────────────

  dynamic _unwrap(dynamic data) =>
      (data is Map) ? (data.containsKey('data') ? data['data'] : data.containsKey('Data') ? data['Data'] : data) : data;

  List<dynamic> _unwrapList(dynamic data) {
    final d = _unwrap(data);
    return d is List ? d : [];
  }

  Map<String, dynamic>? _unwrapMap(dynamic data) {
    final d = _unwrap(data);
    return d is Map<String, dynamic> ? d : null;
  }

  // ── Cores e configurações ─────────────────────────────────────────────────

  Future<List<TeamColorInfo>> fetchTeamColors(String groupId) async {
    final res = await _dio.get(
      ApiConstants.teamColors(groupId),
      queryParameters: {'activeOnly': true},
    );
    return _unwrapList(res.data)
        .map((e) => TeamColorInfo.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<MatchGroupSettings?> fetchGroupSettings(String groupId) async {
    final res = await _dio.get(ApiConstants.groupSettings(groupId));
    final d = _unwrapMap(res.data);
    return d != null ? MatchGroupSettings.fromJson(d) : null;
  }

  // ── Partida atual ─────────────────────────────────────────────────────────

  /// Retorna {id, status, stepKey, placeName, playedAt} da partida ativa ou null se 404.
  Future<Map<String, dynamic>?> fetchCurrentMatchStub(String groupId) async {
    final res = await _dio.get(ApiConstants.currentMatch(groupId));
    return _unwrapMap(res.data);
  }

  // ── Loaders de step ───────────────────────────────────────────────────────

  Future<Map<String, dynamic>?> fetchHeader(String groupId, String matchId) async {
    final res = await _dio.get(ApiConstants.matchHeader(groupId, matchId));
    return _unwrapMap(res.data);
  }

  Future<Map<String, dynamic>?> fetchAcceptation(String groupId, String matchId) async {
    final res = await _dio.get(ApiConstants.matchAcceptation(groupId, matchId));
    return _unwrapMap(res.data);
  }

  Future<Map<String, dynamic>?> fetchMatchmaking(String groupId, String matchId) async {
    final res = await _dio.get(ApiConstants.matchMatchmaking(groupId, matchId));
    return _unwrapMap(res.data);
  }

  Future<Map<String, dynamic>?> fetchPostgame(String groupId, String matchId) async {
    final res = await _dio.get(ApiConstants.matchPostgame(groupId, matchId));
    return _unwrapMap(res.data);
  }

  Future<List<MatchGoal>> fetchGoals(String groupId, String matchId) async {
    final res = await _dio.get(ApiConstants.matchDetails(groupId, matchId));
    final d = _unwrapMap(res.data);
    final raw = d?['goals'] ?? d?['Goals'] ?? [];
    return (raw as List)
        .map((e) => MatchGoal.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ── Criar partida ─────────────────────────────────────────────────────────

  Future<void> createMatch(String groupId, String placeName, DateTime playedAt) async {
    await _dio.post(ApiConstants.matchCreate(groupId), data: {
      'placeName': placeName,
      'playedAt': playedAt.toUtc().toIso8601String(),
    });
  }

  // ── Aceitação ─────────────────────────────────────────────────────────────

  Future<void> acceptInvite(String groupId, String matchId, String playerId) async {
    await _dio.patch(ApiConstants.matchAccept(groupId, matchId));
  }

  Future<void> rejectInvite(String groupId, String matchId, String playerId) async {
    await _dio.patch(ApiConstants.matchReject(groupId, matchId));
  }

  Future<void> goToMatchmaking(String groupId, String matchId) async {
    await _dio.post(ApiConstants.matchGoToMatchmaking(groupId, matchId));
  }

  Future<void> addGuest(
    String groupId, String matchId, String name, bool isGoalkeeper, int? starRating,
  ) async {
    await _dio.post(ApiConstants.matchGuest(groupId, matchId), data: {
      'name': name,
      'isGoalkeeper': isGoalkeeper,
      if (starRating != null) 'guestStarRating': starRating,
    });
  }

  // ── MatchMaking ───────────────────────────────────────────────────────────

  Future<List<TeamGenOption>> generateTeams({
    required List<MatchPlayerInfo> players,
    required int strategyType,
    required int playersPerTeam,
    required bool includeGoalkeepers,
  }) async {
    final dto = {
      'players': players
          .where((p) => p.playerId.isNotEmpty && p.inviteResponse == InviteResponse.accepted)
          .map((p) => {'id': p.playerId, 'name': p.playerName, 'isGoalkeeper': p.isGoalkeeper})
          .toList(),
      'strategyType':       strategyType,
      'playersPerTeam':     playersPerTeam,
      'includeGoalkeepers': includeGoalkeepers,
      'optionsCount':       3,
    };
    final res = await _dio.post(ApiConstants.teamGenGenerate, data: dto);
    final raw = _unwrap(res.data);
    final list = raw is List ? raw : (raw as Map?)?['options'] ?? [];
    return (list as List)
        .map((e) => TeamGenOption.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> assignTeams(
    String groupId, String matchId,
    List<String> teamAIds, List<String> teamBIds,
  ) async {
    await _dio.put(ApiConstants.matchTeams(groupId, matchId), data: {
      'TeamAMatchPlayerIds': teamAIds,
      'TeamBMatchPlayerIds': teamBIds,
    });
  }

  Future<void> setColors(
    String groupId, String matchId, String teamAColorId, String teamBColorId,
  ) async {
    await _dio.patch(ApiConstants.matchColors(groupId, matchId), data: {
      'teamAColorId': teamAColorId,
      'teamBColorId': teamBColorId,
    });
  }

  Future<void> swapPlayers(
    String groupId, String matchId, String playerAId, String playerBId,
  ) async {
    await _dio.put(ApiConstants.matchSwap(groupId, matchId), data: {
      'playerAId': playerAId,
      'playerBId': playerBId,
    });
  }

  Future<void> setPlayerRole(
    String groupId, String matchId, String matchPlayerId, bool isGoalkeeper,
  ) async {
    await _dio.put(
      ApiConstants.matchPlayerRole(groupId, matchId, matchPlayerId),
      data: {'isGoalkeeper': isGoalkeeper},
    );
  }

  // ── Ciclo de vida da partida ──────────────────────────────────────────────

  Future<void> startMatch(String groupId, String matchId) async {
    await _dio.post(ApiConstants.matchStart(groupId, matchId));
  }

  Future<void> endMatch(String groupId, String matchId) async {
    await _dio.post(ApiConstants.matchEnd(groupId, matchId));
  }

  Future<void> goToPostGame(String groupId, String matchId) async {
    await _dio.post(ApiConstants.matchGoToPostGame(groupId, matchId));
  }

  Future<void> finalizeMatch(String groupId, String matchId) async {
    await _dio.post(ApiConstants.matchFinalize(groupId, matchId));
  }

  Future<void> rewindStep(String groupId, String matchId) async {
    await _dio.post(ApiConstants.matchRewind(groupId, matchId));
  }

  // ── Pós-jogo ──────────────────────────────────────────────────────────────

  Future<void> addGoal(
    String groupId, String matchId, {
    required String scorerPlayerId,
    String? assistPlayerId,
    required String time,
    bool isOwnGoal = false,
  }) async {
    await _dio.post(ApiConstants.matchGoals(groupId, matchId), data: {
      'scorerPlayerId': scorerPlayerId,
      if (assistPlayerId?.isNotEmpty == true) 'assistPlayerId': assistPlayerId,
      'time':       time,
      'isOwnGoal':  isOwnGoal,
    });
  }

  Future<void> removeGoal(String groupId, String matchId, String goalId) async {
    await _dio.delete(ApiConstants.matchGoalById(groupId, matchId, goalId));
  }

  Future<void> setScore(
    String groupId, String matchId, int teamAGoals, int teamBGoals,
  ) async {
    await _dio.patch(ApiConstants.matchScore(groupId, matchId), data: {
      'teamAGoals': teamAGoals,
      'teamBGoals': teamBGoals,
    });
  }

  Future<void> voteMvp(
    String groupId, String matchId, String voterMpId, String votedMpId,
  ) async {
    await _dio.post(ApiConstants.matchVote(groupId, matchId), data: {
      'voterPlayerId': voterMpId,
      'votedPlayerId': votedMpId,
    });
  }

  // ── Extras ────────────────────────────────────────────────────────────────

  /// Bulk goals — POST /api/Matches/group/{groupId}/{matchId}/goals/bulk
  Future<void> addBulkGoals(String groupId, String matchId, List<Map<String, dynamic>> goals) async {
    await _dio.post(ApiConstants.matchBulkGoals(groupId, matchId), data: {'goals': goals});
  }

  /// Reapply MVP — POST /api/Matches/group/{groupId}/{matchId}/reapply-mvp
  Future<void> reapplyMvp(String groupId, String matchId) async {
    await _dio.post(ApiConstants.matchReapplyMvp(groupId, matchId));
  }

  /// Publish match event — POST /api/Matches/group/{groupId}/{matchId}/events
  Future<void> publishMatchEvent(String groupId, String matchId, Map<String, dynamic> eventData) async {
    await _dio.post(ApiConstants.matchPublishEvent(groupId, matchId), data: eventData);
  }

  /// Match replays — GET /api/Matches/group/{groupId}/{matchId}/replays
  Future<List<Map<String, dynamic>>> fetchMatchReplays(String groupId, String matchId) async {
    final res = await _dio.get(ApiConstants.matchReplays(groupId, matchId));
    final d = _unwrap(res.data);
    return (d is List ? d : []).cast<Map<String, dynamic>>();
  }

  /// Generate match card — POST /api/MatchCard/group/{groupId}/generate
  /// Returns base64-encoded image string
  Future<String?> generateMatchCard(String groupId, Map<String, dynamic> dto) async {
    final res = await _dio.post(ApiConstants.matchCard(groupId), data: dto);
    final d = _unwrap(res.data);
    if (d is String) return d;
    if (d is Map) return d['image'] as String? ?? d['base64'] as String?;
    return null;
  }
}

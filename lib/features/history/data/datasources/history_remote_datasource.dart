import 'package:dio/dio.dart';
import '../../../../core/api/api_constants.dart';
import '../../../../core/api/api_response.dart';
import '../../../../core/errors/app_exception.dart';
import '../../domain/entities/history_match.dart';
import '../../domain/entities/match_details.dart';
import '../../../replays/domain/entities/replay_clip.dart';

class HistoryRemoteDataSource {
  final Dio _dio;

  const HistoryRemoteDataSource(this._dio);

  Future<List<HistoryMatch>> fetchHistory(
    String groupId, {
    int take = 400,
  }) async {
    try {
      final historyRes = await _dio.get(
        ApiConstants.matchHistory(groupId),
        queryParameters: {'take': take},
      );
      final list = unwrapList(historyRes.data)
          .map((e) => HistoryMatch.fromJson(
                e as Map<String, dynamic>,
                groupId: groupId,
              ))
          .toList();

      // Try to prepend the active match if it exists and isn't in history yet.
      try {
        final currentRes = await _dio.get(ApiConstants.currentMatch(groupId));
        final current = unwrapMap(currentRes.data);
        if (current != null) {
          final activeId = (current['id'] ?? current['matchId'] ?? '').toString();
          final alreadyPresent = list.any((m) => m.id == activeId);
          if (!alreadyPresent && activeId.isNotEmpty) {
            list.insert(0, HistoryMatch.fromJson(current, groupId: groupId));
          }
        }
      } catch (_) {
        // No active match or 404 — ignore.
      }

      return list;
    } on DioException catch (e) {
      throw ServerException(extractDioError(e));
    }
  }

  Future<MatchDetails> fetchMatchDetails(
    String groupId,
    String matchId,
  ) async {
    try {
      final res  = await _dio.get(ApiConstants.matchDetails(groupId, matchId));
      final data = unwrapMap(res.data);
      if (data == null) throw const ServerException('Partida não encontrada');
      return MatchDetails.fromJson(data);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        throw const ServerException('Partida não encontrada');
      }
      throw ServerException(extractDioError(e));
    }
  }

  Future<List<ReplayClip>> fetchMatchReplays(
    String groupId,
    String matchId,
  ) async {
    try {
      final res = await _dio.get(ApiConstants.matchReplays(groupId, matchId));
      final d   = unwrapList(res.data);
      return d
          .whereType<Map<String, dynamic>>()
          .map(ReplayClip.fromJson)
          .toList();
    } on DioException catch (e) {
      throw ServerException(extractDioError(e));
    }
  }

  /// Returns the set of matchIds where the given player participated.
  /// Queries the last two calendar years for broad coverage.
  Future<Set<String>> fetchMyMatchIds(
    String groupId,
    String playerId,
  ) async {
    final ids   = <String>{};
    final years = [DateTime.now().year, DateTime.now().year - 1];
    for (final year in years) {
      try {
        final res = await _dio.get(
          ApiConstants.playerHistory(groupId),
          queryParameters: {'playerId': playerId, 'year': year},
        );
        for (final e in unwrapList(res.data)) {
          if (e is! Map) continue;
          final id = (e['matchId'] ?? e['id'])?.toString();
          if (id != null && id.isNotEmpty) ids.add(id);
        }
      } catch (_) {
        // Year may have no data — silently skip
      }
    }
    return ids;
  }

  Future<String?> generateMatchCard(
    String groupId,
    Map<String, dynamic> dto,
  ) async {
    try {
      final res = await _dio.post(ApiConstants.matchCard(groupId), data: dto);
      final d   = unwrapMap(res.data);
      if (d == null) return null;
      return d['image'] as String? ?? d['base64'] as String?;
    } on DioException catch (e) {
      throw ServerException(extractDioError(e));
    }
  }
}

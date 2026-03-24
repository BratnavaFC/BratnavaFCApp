import 'package:dio/dio.dart';
import '../../../../core/api/api_constants.dart';
import '../../../../core/api/api_response.dart';
import '../../../../core/errors/app_exception.dart';
import '../../domain/entities/history_match.dart';
import '../../domain/entities/match_details.dart';

class HistoryRemoteDataSource {
  final Dio _dio;

  const HistoryRemoteDataSource(this._dio);

  Future<List<HistoryMatch>> fetchHistory(
    String groupId, {
    int take = 400,
  }) async {
    try {
      final res = await _dio.get(
        ApiConstants.matchHistory(groupId),
        queryParameters: {'take': take},
      );
      return unwrapList(res.data)
          .map((e) => HistoryMatch.fromJson(
                e as Map<String, dynamic>,
                groupId: groupId,
              ))
          .toList();
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
}

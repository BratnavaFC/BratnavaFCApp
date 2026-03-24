import 'package:dio/dio.dart';
import '../../../../core/api/api_constants.dart';
import '../../../../core/api/api_response.dart';
import '../../../../core/errors/app_exception.dart';
import '../../domain/entities/current_match.dart';
import '../../domain/entities/my_player.dart';
import '../../domain/entities/recent_match.dart';

class DashboardRemoteDataSource {
  final Dio _dio;

  const DashboardRemoteDataSource(this._dio);

  Future<List<MyPlayer>> fetchMyPlayers() async {
    try {
      final res = await _dio.get(ApiConstants.playersMe);
      return unwrapList(res.data)
          .map((e) => MyPlayer.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw ServerException(extractDioError(e));
    }
  }

  Future<CurrentMatch?> fetchCurrentMatch(String groupId) async {
    try {
      final res  = await _dio.get(ApiConstants.currentMatch(groupId));
      final data = unwrapMap(res.data);
      if (data == null) return null;
      return CurrentMatch.fromJson(data);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      throw ServerException(extractDioError(e));
    }
  }

  Future<List<RecentMatch>> fetchRecentMatches(
    String groupId,
    String playerId, {
    int take = 3,
  }) async {
    try {
      final res = await _dio.get(
        ApiConstants.playerRecentMatches(groupId),
        queryParameters: {'playerId': playerId, 'take': take},
      );
      return unwrapList(res.data)
          .map((e) => RecentMatch.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw ServerException(extractDioError(e));
    }
  }
}

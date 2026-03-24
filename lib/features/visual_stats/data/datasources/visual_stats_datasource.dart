import 'package:dio/dio.dart';
import '../../../../core/api/api_constants.dart';
import '../../domain/entities/visual_stats_report.dart';

class VisualStatsDatasource {
  final Dio _dio;
  const VisualStatsDatasource(this._dio);

  // GET /api/TeamGeneration/visual-stats/{groupId}
  Future<PlayerVisualStatsReport> fetchVisualStats(String groupId) async {
    final res = await _dio.get(ApiConstants.visualStats(groupId));
    final body = res.data;
    // Response may be { data: { ... } } or the report directly
    if (body is Map<String, dynamic>) {
      return PlayerVisualStatsReport.fromJson(body);
    }
    throw Exception('Resposta inesperada da API');
  }
}

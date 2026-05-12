import 'package:dio/dio.dart';
import '../../domain/entities/spotlight_report.dart';

class SpotlightRemoteDataSource {
  final Dio _dio;
  const SpotlightRemoteDataSource(this._dio);

  // GET /api/teamgeneration/spotlight/{groupId}
  Future<PlayerSpotlightReport> fetchSpotlight(String groupId) async {
    final res = await _dio.get('/api/teamgeneration/spotlight/$groupId');
    final body = res.data;
    if (body is Map<String, dynamic>) {
      return PlayerSpotlightReport.fromJson(body);
    }
    throw Exception('Resposta inesperada da API de spotlight');
  }
}

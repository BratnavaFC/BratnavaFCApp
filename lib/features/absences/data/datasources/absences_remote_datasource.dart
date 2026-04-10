import 'package:dio/dio.dart';
import '../../../../core/api/api_constants.dart';
import '../../domain/entities/absence.dart';

class AbsencesRemoteDataSource {
  final Dio _dio;
  const AbsencesRemoteDataSource(this._dio);

  Future<List<AbsenceDto>> fetchMine() async {
    final res = await _dio.get(ApiConstants.absencesMine);
    final data = (res.data as Map<String, dynamic>?)?['data'];
    if (data is! List) return [];
    return data
        .whereType<Map<String, dynamic>>()
        .map(AbsenceDto.fromJson)
        .toList();
  }

  Future<AbsenceDto> create(CreateAbsenceDto dto) async {
    final res = await _dio.post(ApiConstants.absences, data: dto.toJson());
    return AbsenceDto.fromJson(
        (res.data as Map<String, dynamic>)['data'] as Map<String, dynamic>);
  }

  Future<AbsenceDto> update(String id, CreateAbsenceDto dto) async {
    final res = await _dio.put(ApiConstants.absenceById(id), data: dto.toJson());
    return AbsenceDto.fromJson(
        (res.data as Map<String, dynamic>)['data'] as Map<String, dynamic>);
  }

  Future<void> delete(String id) async {
    await _dio.delete(ApiConstants.absenceById(id));
  }
}

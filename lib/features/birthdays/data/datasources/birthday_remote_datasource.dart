import 'package:dio/dio.dart';
import '../../../../core/api/api_constants.dart';
import '../../domain/entities/birthday_status.dart';

class BirthdayRemoteDataSource {
  final Dio _dio;
  const BirthdayRemoteDataSource(this._dio);

  // GET /api/Players/group/{groupId}/birthday-status
  // Response: { data: [ { playerId, name, hasBirthday, birthDate, birthMonth, birthDay } ] }
  Future<List<BirthdayStatus>> fetchBirthdayStatus(String groupId) async {
    final res = await _dio.get(ApiConstants.birthdayStatus(groupId));
    final data = (res.data as Map<String, dynamic>?)?['data'];
    if (data is! List) return [];
    return data
        .whereType<Map<String, dynamic>>()
        .map(BirthdayStatus.fromJson)
        .toList();
  }
}

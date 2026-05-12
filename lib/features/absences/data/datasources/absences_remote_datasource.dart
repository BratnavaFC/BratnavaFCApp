import 'package:dio/dio.dart';
import '../../domain/entities/absence.dart';

class AbsencesRemoteDataSource {
  final Dio _dio;
  const AbsencesRemoteDataSource(this._dio);

  // ── Endpoint constants ────────────────────────────────────────────────────

  static const _base  = '/api/absences';
  static String _byId(String id)   => '$_base/$id';
  static String _group(String gid) => '$_base/group/$gid';

  // ── Read ──────────────────────────────────────────────────────────────────

  /// Returns all absences in the group, grouped by player.
  /// Response shape: { Data: [ { playerId, playerName, absences: [AbsenceDto] } ] }
  Future<List<Absence>> fetchByGroup(String groupId) async {
    final res = await _dio.get(_group(groupId));
    final raw = _unwrapList(res.data);

    final result = <Absence>[];
    for (final member in raw) {
      if (member is! Map<String, dynamic>) continue;
      final playerId   = member['playerId']   as String? ?? '';
      final playerName = member['playerName'] as String? ?? '';
      final absences   = member['absences']   as List?   ?? [];
      for (final a in absences) {
        if (a is! Map<String, dynamic>) continue;
        result.add(Absence.fromJson({
          ...a,
          'playerId':   playerId,
          'playerName': playerName,
        }));
      }
    }
    return result;
  }

  // ── Mutations ─────────────────────────────────────────────────────────────

  Future<void> create(CreateAbsenceDto dto) async {
    await _dio.post(_base, data: dto.toJson());
  }

  Future<void> update(String id, CreateAbsenceDto dto) async {
    await _dio.put(_byId(id), data: dto.toJson());
  }

  Future<void> delete(String id) async {
    await _dio.delete(_byId(id));
  }

  // ── Helper ────────────────────────────────────────────────────────────────

  List<dynamic> _unwrapList(dynamic data) {
    if (data is List) return data;
    if (data is Map) {
      final inner = data['data'] ?? data['Data'];
      if (inner is List) return inner;
    }
    return [];
  }
}

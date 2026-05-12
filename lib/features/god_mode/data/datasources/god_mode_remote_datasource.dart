import 'package:dio/dio.dart';
import '../../domain/entities/god_mode_models.dart';

class GodModeRemoteDataSource {
  final Dio _dio;
  const GodModeRemoteDataSource(this._dio);

  // ── Users ─────────────────────────────────────────────────────────────────

  Future<PagedResult<UserItemListDto>> fetchUsers({
    String? search,
    String? status,
    String? role,
    int page = 1,
    int pageSize = 20,
  }) async {
    final params = <String, dynamic>{
      'page': page,
      'pageSize': pageSize,
      if (search != null && search.isNotEmpty) 'search': search,
      if (status != null && status.isNotEmpty) 'status': status,
      if (role != null && role.isNotEmpty) 'role': role,
    };
    final res = await _dio.get('/api/users', queryParameters: params);
    return _parsePagedUsers(res.data);
  }

  Future<void> inactivateUser(String userId) async {
    await _dio.put('/api/users/$userId/inactivate');
  }

  Future<void> reactivateUser(String userId) async {
    await _dio.put('/api/users/$userId/reactivate');
  }

  Future<void> changeUserPassword(
    String userId, {
    required String currentPassword,
    required String newPassword,
  }) async {
    await _dio.put(
      '/api/users/$userId/password',
      data: {
        'currentPassword': currentPassword,
        'newPassword': newPassword,
      },
    );
  }

  Future<void> updateUser(String userId, Map<String, dynamic> dto) async {
    await _dio.put('/api/users/$userId', data: dto);
  }

  // ── Groups ────────────────────────────────────────────────────────────────

  Future<List<GroupDto>> fetchGroups() async {
    final res = await _dio.get('/api/groups');
    final raw = _unwrapList(res.data);
    return raw
        .map((e) => GroupDto.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> inactivateGroup(String groupId) async {
    await _dio.put('/api/groups/$groupId/inactivate');
  }

  Future<void> reactivateGroup(String groupId) async {
    await _dio.put('/api/groups/$groupId/reactivate');
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  PagedResult<UserItemListDto> _parsePagedUsers(dynamic data) {
    // Handles: { success, data: { items, totalCount, page, pageSize } }
    // or flat:  { items, totalCount, page, pageSize }
    Map<String, dynamic>? envelope;
    if (data is Map<String, dynamic>) {
      if (data['data'] ?? data['Data'] is Map<String, dynamic>) {
        envelope = data['data'] ?? data['Data'] as Map<String, dynamic>;
      } else if (data.containsKey('items')) {
        envelope = data;
      }
    }

    if (envelope == null) {
      return const PagedResult(items: [], totalCount: 0, page: 1, pageSize: 20);
    }

    final items = (envelope['items'] as List? ?? [])
        .map((e) => UserItemListDto.fromJson(e as Map<String, dynamic>))
        .toList();

    return PagedResult(
      items: items,
      totalCount: envelope['totalCount'] as int? ??
          envelope['total'] as int? ??
          items.length,
      page: envelope['page'] as int? ?? 1,
      pageSize: envelope['pageSize'] as int? ?? 20,
    );
  }

  List<dynamic> _unwrapList(dynamic data) {
    if (data is List) return data;
    if (data is Map) {
      final d = data['data'] ?? data['Data'];
      if (d is List) return d;
      if (d is Map) {
        final items = d['items'];
        if (items is List) return items;
      }
    }
    return [];
  }
}

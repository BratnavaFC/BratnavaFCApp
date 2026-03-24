import 'package:dio/dio.dart';
import '../../../../core/api/api_constants.dart';
import '../../domain/entities/group_settings.dart';

class GroupSettingsRemoteDataSource {
  final Dio _dio;
  const GroupSettingsRemoteDataSource(this._dio);

  // ── Group Settings (icons, payment, defaults) ─────────────────────────────
  // Endpoint: GET/PUT /api/GroupSettings/group/{groupId}

  Future<GroupSettings> fetchGroupSettings(String groupId) async {
    final res = await _dio.get(ApiConstants.groupSettings(groupId));
    return GroupSettings.fromJson(res.data as Map<String, dynamic>);
  }

  Future<void> updateGroupSettings(
    String groupId, {
    required int     minPlayers,
    required int     maxPlayers,
    required String? defaultPlaceName,
    required int?    defaultDayOfWeek,
    required String? defaultKickoffTime,
    required int     paymentMode,
    required double? monthlyFee,
    required String? goalIcon,
    required String? goalkeeperIcon,
    required String? assistIcon,
    required String? ownGoalIcon,
    required String? mvpIcon,
    required String? playerIcon,
  }) async {
    final body = const GroupSettings().toJson(
      minPlayers:         minPlayers,
      maxPlayers:         maxPlayers,
      defaultPlaceName:   defaultPlaceName,
      defaultDayOfWeek:   defaultDayOfWeek,
      defaultKickoffTime: defaultKickoffTime,
      paymentMode:        paymentMode,
      monthlyFee:         monthlyFee,
      goalIcon:           goalIcon,
      goalkeeperIcon:     goalkeeperIcon,
      assistIcon:         assistIcon,
      ownGoalIcon:        ownGoalIcon,
      mvpIcon:            mvpIcon,
      playerIcon:         playerIcon,
    );
    await _dio.put(ApiConstants.groupSettings(groupId), data: body);
  }

  // ── Group Detail (name, admins, financeiros) ──────────────────────────────
  // Endpoint: GET /api/Groups/{groupId}

  Future<GroupDetail> fetchGroupDetail(String groupId) async {
    final res = await _dio.get(ApiConstants.groupById(groupId));
    return GroupDetail.fromJson(res.data as Map<String, dynamic>);
  }

  // ── Admins ────────────────────────────────────────────────────────────────

  Future<void> addAdmin(String groupId, String userId) async {
    await _dio.post(ApiConstants.groupAdmins(groupId), data: {'userId': userId});
  }

  Future<void> removeAdmin(String groupId, String userId) async {
    await _dio.delete(ApiConstants.groupAdminById(groupId, userId));
  }

  // ── Financeiros ───────────────────────────────────────────────────────────

  Future<void> addFinanceiro(String groupId, String userId) async {
    await _dio.post(ApiConstants.groupFinanceiros(groupId), data: {'userId': userId});
  }

  Future<void> removeFinanceiro(String groupId, String userId) async {
    await _dio.delete(ApiConstants.groupFinanceiroById(groupId, userId));
  }

  // ── User search ───────────────────────────────────────────────────────────
  // GET /api/Users?search={q}&pageSize=8
  // Response envelope: { data: { items: [...] } }

  Future<List<GroupMember>> searchUsers(String query) async {
    if (query.trim().length < 2) return [];
    final res = await _dio.get(
      ApiConstants.users,
      queryParameters: {'search': query.trim(), 'pageSize': 8},
    );
    final envelope = res.data;
    // path: data.data.items (mirrors site: res.data.data.items)
    dynamic inner = envelope;
    if (inner is Map) inner = inner['data'];
    if (inner is Map) inner = inner['items'];
    final list = inner as List?;
    return list
            ?.whereType<Map<String, dynamic>>()
            .map(GroupMember.fromSearchResult)
            .toList() ??
        [];
  }
}

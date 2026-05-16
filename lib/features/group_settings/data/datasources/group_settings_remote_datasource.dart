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
    required int     mvpTieRule,
    int?             mvpTieMaxPlayers,
    required bool    showPlayerStats,
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
      mvpTieRule:         mvpTieRule,
      mvpTieMaxPlayers:   mvpTieMaxPlayers,
      showPlayerStats:    showPlayerStats,
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

  // ── Group players (used for admin/financeiro candidate list) ─────────────
  // Reuses GET /api/Groups/{groupId} which already returns the players array.
  // Returns only linked (non-guest) members — candidates for admin/financeiro.

  Future<List<GroupMember>> fetchGroupPlayers(String groupId) async {
    final res = await _dio.get(ApiConstants.groupById(groupId));
    dynamic body = res.data;
    if (body is Map) body = body['data'] ?? body;
    final playersRaw = (body as Map<String, dynamic>?)?['players'];
    final list = (playersRaw as List?)?.whereType<Map<String, dynamic>>() ?? [];
    return list
        .where((p) =>
            (p['userId'] as String? ?? '').isNotEmpty && p['isGuest'] != true)
        .map(GroupMember.fromPlayerJson)
        .toList();
  }
}

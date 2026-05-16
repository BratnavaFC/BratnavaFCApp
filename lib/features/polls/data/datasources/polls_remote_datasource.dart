import 'package:dio/dio.dart';
import '../../../../core/api/api_constants.dart';
import '../../domain/entities/poll_detail.dart';
import '../../domain/entities/poll_summary.dart';

class PollsRemoteDataSource {
  final Dio _dio;
  const PollsRemoteDataSource(this._dio);

  // ── List ──────────────────────────────────────────────────────────────────

  Future<List<PollSummary>> getPolls(String groupId) async {
    final res = await _dio.get(ApiConstants.polls(groupId));
    final raw = _unwrapList(res.data);
    return raw.map((e) => PollSummary.fromJson(e as Map<String, dynamic>)).toList();
  }

  // ── Detail ────────────────────────────────────────────────────────────────

  Future<PollDetail> getPoll(String groupId, String pollId) async {
    final res = await _dio.get(ApiConstants.pollById(groupId, pollId));
    return PollDetail.fromJson(_unwrapMap(res.data)!);
  }

  // ── Create ────────────────────────────────────────────────────────────────

  Future<PollDetail> createPoll(String groupId, Map<String, dynamic> dto) async {
    final res = await _dio.post(ApiConstants.polls(groupId), data: dto);
    return PollDetail.fromJson(_unwrapMap(res.data)!);
  }

  Future<PollDetail> createEventPoll(String groupId, Map<String, dynamic> dto) async {
    final res = await _dio.post(ApiConstants.createEventPoll(groupId), data: dto);
    return PollDetail.fromJson(_unwrapMap(res.data)!);
  }

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  Future<void> closePoll(String groupId, String pollId, Map<String, dynamic> dto) async {
    final res = await _dio.post(ApiConstants.closePoll(groupId, pollId), data: dto);
    _throwIfError(res.data);
  }

  Future<void> reopenPoll(String groupId, String pollId) async {
    final res = await _dio.put(ApiConstants.reopenPoll(groupId, pollId));
    _throwIfError(res.data);
  }

  Future<void> deletePoll(String groupId, String pollId) async {
    final res = await _dio.delete(ApiConstants.deletePoll(groupId, pollId));
    _throwIfError(res.data);
  }

  // ── Options ───────────────────────────────────────────────────────────────

  Future<PollDetail> addOption(String groupId, String pollId, Map<String, dynamic> dto) async {
    final res = await _dio.post(ApiConstants.pollOptions(groupId, pollId), data: dto);
    return PollDetail.fromJson(_unwrapMap(res.data)!);
  }

  Future<PollDetail> updateOption(
      String groupId, String pollId, String optId, Map<String, dynamic> dto) async {
    final res = await _dio.put(ApiConstants.pollOptionById(groupId, pollId, optId), data: dto);
    return PollDetail.fromJson(_unwrapMap(res.data)!);
  }

  Future<PollDetail> deleteOption(String groupId, String pollId, String optId) async {
    final res = await _dio.delete(ApiConstants.pollOptionById(groupId, pollId, optId));
    return PollDetail.fromJson(_unwrapMap(res.data)!);
  }

  // ── Deadline ──────────────────────────────────────────────────────────────

  Future<void> updateDeadline(
    String groupId,
    String pollId, {
    String? deadlineDate,
    String? deadlineTime,
    bool clearDeadline = false,
  }) async {
    final res = await _dio.patch(
      ApiConstants.pollDeadline(groupId, pollId),
      data: {
        'deadlineDate':  deadlineDate,
        'deadlineTime':  deadlineTime,
        'clearDeadline': clearDeadline,
      },
    );
    _throwIfError(res.data);
  }

  // ── Show-votes toggle ─────────────────────────────────────────────────────

  Future<void> toggleShowVotes(String groupId, String pollId, bool show) async {
    final res = await _dio.patch(ApiConstants.pollShowVotes(groupId, pollId), data: {'showVotes': show});
    _throwIfError(res.data);
  }

  // ── Voting ────────────────────────────────────────────────────────────────

  Future<PollDetail> castVote(String groupId, String pollId, List<String> optionIds) async {
    final res = await _dio.post(
      ApiConstants.castVote(groupId, pollId),
      data: {'optionIds': optionIds},
    );
    return PollDetail.fromJson(_unwrapMap(res.data)!);
  }

  Future<PollDetail> removeVote(String groupId, String pollId) async {
    final res = await _dio.delete(ApiConstants.castVote(groupId, pollId));
    return PollDetail.fromJson(_unwrapMap(res.data)!);
  }

  Future<PollDetail> adminCastVote(
      String groupId, String pollId, String playerId, List<String> optionIds) async {
    final res = await _dio.post(
      ApiConstants.adminVote(groupId, pollId),
      data: {'playerId': playerId, 'optionIds': optionIds},
    );
    return PollDetail.fromJson(_unwrapMap(res.data)!);
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  void _throwIfError(dynamic data) {
    if (data is Map) {
      final msg = data['error'] as String?;
      if (msg != null && msg.isNotEmpty) throw Exception(msg);
    }
  }

  List<dynamic> _unwrapList(dynamic data) {
    if (data is List) return data;
    if (data is Map) {
      final d = data['data'] ?? data['Data'];
      if (d is List) return d;
    }
    return [];
  }

  Map<String, dynamic>? _unwrapMap(dynamic data) {
    if (data is Map<String, dynamic>) {
      final d = data['data'] ?? data['Data'];
      if (d is Map<String, dynamic>) return d;
      return data;
    }
    return null;
  }
}

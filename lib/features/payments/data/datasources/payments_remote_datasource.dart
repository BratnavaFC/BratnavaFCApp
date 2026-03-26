import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import '../../../../core/api/api_constants.dart';
import '../../domain/entities/payment_entities.dart';

class PaymentsRemoteDataSource {
  final Dio _dio;
  const PaymentsRemoteDataSource(this._dio);

  // ── Helpers ───────────────────────────────────────────────────────────────

  dynamic _unwrap(dynamic data) {
    if (data is Map && data.containsKey('data')) return data['data'];
    return data;
  }

  List<dynamic> _unwrapList(dynamic data) {
    final d = _unwrap(data);
    if (d is List) return d;
    return [];
  }

  Map<String, dynamic>? _unwrapMap(dynamic data) {
    final d = _unwrap(data);
    if (d is Map<String, dynamic>) return d;
    return null;
  }

  // ── Mensalidades (admin) ──────────────────────────────────────────────────

  Future<MonthlyGrid> getMonthlyGrid(String groupId, int year) async {
    final res = await _dio.get(ApiConstants.monthlyGrid(groupId, year));
    return MonthlyGrid.fromJson(_unwrapMap(res.data)!);
  }

  Future<String?> upsertMonthly(String groupId, Map<String, dynamic> dto) async {
    final res = await _dio.put(ApiConstants.upsertMonthly(groupId), data: dto);
    return (res.data as Map?)?['message'] as String?;
  }

  Future<Map<String, dynamic>?> getMonthlyProof(
      String groupId, String playerId, int year, int month) async {
    final res = await _dio.get(
        ApiConstants.monthlyProof(groupId, playerId, year, month));
    return _unwrapMap(res.data);
  }

  // ── Mensalidades (usuário) ────────────────────────────────────────────────

  Future<PlayerRow?> getMyMonthlyRow(String groupId, int year) async {
    final res = await _dio.get(ApiConstants.myMonthlyRow(groupId, year));
    final d = _unwrapMap(res.data);
    if (d == null) return null;
    return PlayerRow.fromJson(d);
  }

  // ── Cobranças extras (admin) ──────────────────────────────────────────────

  Future<List<ExtraCharge>> getExtraCharges(String groupId) async {
    final res = await _dio.get(ApiConstants.extraCharges(groupId));
    return _unwrapList(res.data)
        .map((e) => ExtraCharge.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<String?> createExtraCharge(
      String groupId, Map<String, dynamic> dto) async {
    final res =
        await _dio.post(ApiConstants.extraCharges(groupId), data: dto);
    return (res.data as Map?)?['message'] as String?;
  }

  Future<String?> cancelExtraCharge(String groupId, String chargeId) async {
    final res =
        await _dio.delete(ApiConstants.extraChargeById(groupId, chargeId));
    return (res.data as Map?)?['message'] as String?;
  }

  Future<String?> bulkDiscountExtraCharge(
      String groupId, String chargeId, Map<String, dynamic> dto) async {
    final res = await _dio.post(
        ApiConstants.extraChargeBulkDiscount(groupId, chargeId), data: dto);
    return (res.data as Map?)?['message'] as String?;
  }

  Future<String?> upsertExtraChargePayment(
      String groupId, String chargeId, String playerId,
      Map<String, dynamic> dto) async {
    final res = await _dio.put(
        ApiConstants.extraChargePayment(groupId, chargeId, playerId),
        data: dto);
    return (res.data as Map?)?['message'] as String?;
  }

  Future<Map<String, dynamic>?> getExtraChargeProof(
      String groupId, String chargeId, String playerId) async {
    final res = await _dio.get(
        ApiConstants.extraChargeProof(groupId, chargeId, playerId));
    return _unwrapMap(res.data);
  }

  // ── Cobranças extras (usuário) ────────────────────────────────────────────

  Future<List<ExtraCharge>> getMyExtraCharges(String groupId) async {
    final res = await _dio.get(ApiConstants.myExtraCharges(groupId));
    return _unwrapList(res.data)
        .map((e) => ExtraCharge.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ── Resumo (dashboard) ────────────────────────────────────────────────────

  Future<PaymentSummary?> getMySummary(String groupId) async {
    final res = await _dio.get(ApiConstants.myPaymentSummary(groupId));
    final d = _unwrapMap(res.data);
    if (d == null) return null;
    return PaymentSummary.fromJson(d);
  }

  // ── Utilitário: converte arquivo para base64 ──────────────────────────────

  static Future<({String base64, String fileName, String mimeType})>
      fileToBase64(String path, String name) async {
    final bytes = await File(path).readAsBytes();
    final b64   = base64Encode(bytes);
    final mime  = _guessMime(name);
    return (base64: b64, fileName: name, mimeType: mime);
  }

  static String _guessMime(String name) {
    final ext = name.split('.').last.toLowerCase();
    switch (ext) {
      case 'jpg':
      case 'jpeg': return 'image/jpeg';
      case 'png':  return 'image/png';
      case 'pdf':  return 'application/pdf';
      default:     return 'image/jpeg';
    }
  }
}

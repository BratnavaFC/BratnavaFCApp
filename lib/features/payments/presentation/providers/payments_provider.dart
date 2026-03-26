import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/datasources/payments_remote_datasource.dart';
import '../../domain/entities/payment_entities.dart';

// ── Datasource ────────────────────────────────────────────────────────────────

final paymentsDsProvider = Provider<PaymentsRemoteDataSource>(
  (ref) => PaymentsRemoteDataSource(ref.watch(dioProvider)),
);

// ── Admin providers ───────────────────────────────────────────────────────────

final monthlyGridProvider =
    FutureProvider.autoDispose.family<MonthlyGrid, ({String groupId, int year})>(
  (ref, args) =>
      ref.watch(paymentsDsProvider).getMonthlyGrid(args.groupId, args.year),
);

final extraChargesProvider =
    FutureProvider.autoDispose.family<List<ExtraCharge>, String>(
  (ref, groupId) =>
      ref.watch(paymentsDsProvider).getExtraCharges(groupId),
);

// ── User providers ────────────────────────────────────────────────────────────

final myMonthlyRowProvider =
    FutureProvider.autoDispose.family<PlayerRow?, ({String groupId, int year})>(
  (ref, args) =>
      ref.watch(paymentsDsProvider).getMyMonthlyRow(args.groupId, args.year),
);

final myExtraChargesProvider =
    FutureProvider.autoDispose.family<List<ExtraCharge>, String>(
  (ref, groupId) =>
      ref.watch(paymentsDsProvider).getMyExtraCharges(groupId),
);

// ── Dashboard ─────────────────────────────────────────────────────────────────

final myPaymentSummaryProvider =
    FutureProvider.autoDispose.family<PaymentSummary?, String>(
  (ref, groupId) =>
      ref.watch(paymentsDsProvider).getMySummary(groupId),
);

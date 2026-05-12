import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/datasources/absences_remote_datasource.dart';
import '../../domain/entities/absence.dart';

// ── DataSource ────────────────────────────────────────────────────────────────

final absencesDsProvider = Provider<AbsencesRemoteDataSource>(
  (ref) => AbsencesRemoteDataSource(ref.watch(dioProvider)),
);

// ── Group absences ────────────────────────────────────────────────────────────

final groupAbsencesProvider =
    FutureProvider.autoDispose.family<List<Absence>, String>(
  (ref, groupId) => ref.watch(absencesDsProvider).fetchByGroup(groupId),
);

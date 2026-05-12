import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/datasources/absences_remote_datasource.dart';
import '../../domain/entities/absence.dart';

final absencesDsProvider = Provider<AbsencesRemoteDataSource>(
  (ref) => AbsencesRemoteDataSource(ref.watch(dioProvider)),
);

final absencesProvider = FutureProvider.autoDispose<List<AbsenceDto>>(
  (ref) => ref.watch(absencesDsProvider).fetchMine(),
);

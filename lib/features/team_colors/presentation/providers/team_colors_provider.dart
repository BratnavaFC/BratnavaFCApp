import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/datasources/team_color_remote_datasource.dart';
import '../../domain/entities/team_color.dart';

final teamColorDsProvider = Provider<TeamColorRemoteDataSource>(
  (ref) => TeamColorRemoteDataSource(ref.watch(dioProvider)),
);

final teamColorsProvider =
    FutureProvider.autoDispose.family<List<TeamColor>, String>(
  (ref, groupId) => ref.watch(teamColorDsProvider).fetchColors(groupId),
);

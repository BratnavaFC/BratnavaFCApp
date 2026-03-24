import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/datasources/calendar_remote_datasource.dart';
import '../../domain/entities/calendar_event.dart';

final calendarDsProvider = Provider<CalendarRemoteDataSource>(
  (ref) => CalendarRemoteDataSource(ref.watch(dioProvider)),
);

final calendarCategoriesProvider =
    FutureProvider.autoDispose.family<List<CalendarCategory>, String>(
  (ref, groupId) => ref.watch(calendarDsProvider).fetchCategories(groupId),
);

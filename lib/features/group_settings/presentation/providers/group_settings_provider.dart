import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/datasources/group_settings_remote_datasource.dart';
import '../../domain/entities/group_settings.dart';

final groupSettingsDsProvider = Provider<GroupSettingsRemoteDataSource>(
  (ref) => GroupSettingsRemoteDataSource(ref.watch(dioProvider)),
);

/// Group settings (icons, payment, defaults) — from /api/GroupSettings/group/{id}
final groupSettingsProvider =
    FutureProvider.autoDispose.family<GroupSettings, String>(
  (ref, groupId) {
    if (groupId.isEmpty) return Future.value(GroupSettings.defaults());
    return ref.watch(groupSettingsDsProvider).fetchGroupSettings(groupId);
  },
);

/// Group detail (name, admins, financeiros) — from /api/Groups/{id}
final groupDetailProvider =
    FutureProvider.autoDispose.family<GroupDetail, String>(
  (ref, groupId) {
    if (groupId.isEmpty) throw StateError('groupId não pode ser vazio');
    return ref.watch(groupSettingsDsProvider).fetchGroupDetail(groupId);
  },
);

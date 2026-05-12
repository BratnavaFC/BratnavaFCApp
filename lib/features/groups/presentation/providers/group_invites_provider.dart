import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/datasources/group_invites_datasource.dart';
import '../../domain/entities/group_invite.dart';

final groupInvitesDsProvider = Provider<GroupInvitesDatasource>(
  (ref) => GroupInvitesDatasource(ref.watch(dioProvider)),
);

final myGroupInvitesProvider =
    FutureProvider.autoDispose<List<GroupInvite>>((ref) {
  return ref.watch(groupInvitesDsProvider).getMyInvites();
});

final myGroupInviteCountProvider = FutureProvider.autoDispose<int>((ref) {
  return ref.watch(groupInvitesDsProvider).getMyInviteCount();
});

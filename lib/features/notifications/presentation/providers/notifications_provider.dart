import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/datasources/notifications_datasource.dart';
import '../../domain/entities/app_notification.dart';

// ── Datasource ────────────────────────────────────────────────────────────────

final notificationsDsProvider = Provider<NotificationsDatasource>(
  (ref) => NotificationsDatasource(ref.watch(dioProvider)),
);

// ── List ──────────────────────────────────────────────────────────────────────

final myNotificationsProvider =
    FutureProvider.autoDispose<List<AppNotification>>((ref) {
  return ref.watch(notificationsDsProvider).getMyNotifications();
});

// ── Unread count (used in bell badge) ─────────────────────────────────────────

final notifUnreadCountProvider = FutureProvider.autoDispose<int>((ref) {
  return ref.watch(notificationsDsProvider).getUnreadCount();
});

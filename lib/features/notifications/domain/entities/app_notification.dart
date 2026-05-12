import 'package:equatable/equatable.dart';

class AppNotification extends Equatable {
  final String  id;
  final String  type;       // 'MatchInvite', 'GroupInvite', 'Payment', 'Poll', etc.
  final String  title;
  final String  body;
  final bool    isRead;
  final String  createdAt;  // ISO-8601
  final String? actionUrl;  // optional deep-link route, e.g. '/app/matches'

  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.isRead,
    required this.createdAt,
    this.actionUrl,
  });

  factory AppNotification.fromJson(Map<String, dynamic> j) => AppNotification(
    id:        (j['id']        ?? j['notificationId'] ?? '') as String,
    type:      (j['type']      ?? '')  as String,
    title:     (j['title']     ?? '')  as String,
    body:      (j['body']      ?? j['message'] ?? '') as String,
    isRead:    (j['isRead']    ?? j['read'] ?? false) as bool,
    createdAt: (j['createdAt'] ?? j['sentAt'] ?? '') as String,
    actionUrl: j['actionUrl']  as String?,
  );

  AppNotification copyWith({bool? isRead}) => AppNotification(
    id:        id,
    type:      type,
    title:     title,
    body:      body,
    isRead:    isRead ?? this.isRead,
    createdAt: createdAt,
    actionUrl: actionUrl,
  );

  @override
  List<Object?> get props => [id, type, title, body, isRead, createdAt, actionUrl];
}

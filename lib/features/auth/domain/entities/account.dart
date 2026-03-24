import 'package:equatable/equatable.dart';

class Account extends Equatable {
  final String userId;
  final String name;
  final String email;
  final List<String> roles;
  final String accessToken;
  final String refreshToken;
  final String? activeGroupId;
  final String? activePlayerId;
  final List<String> groupAdminIds;
  final List<String> groupFinanceiroIds;
  final bool keepLoggedIn;

  const Account({
    required this.userId,
    required this.name,
    required this.email,
    required this.roles,
    required this.accessToken,
    required this.refreshToken,
    this.activeGroupId,
    this.activePlayerId,
    this.groupAdminIds       = const [],
    this.groupFinanceiroIds  = const [],
    this.keepLoggedIn        = true,
  });

  // ── RBAC helpers ──────────────────────────────────────────────────────────

  bool get isAdmin    => roles.any((r) => r.toLowerCase() == 'admin');

  bool isGroupAdmin(String groupId)       => groupAdminIds.contains(groupId);
  bool isGroupFinanceiro(String groupId)  => groupFinanceiroIds.contains(groupId);

  String get initials {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  // ── Serialization ─────────────────────────────────────────────────────────

  Map<String, dynamic> toJson() => {
    'userId':              userId,
    'name':                name,
    'email':               email,
    'roles':               roles,
    'accessToken':         accessToken,
    'refreshToken':        refreshToken,
    'activeGroupId':       activeGroupId,
    'activePlayerId':      activePlayerId,
    'groupAdminIds':       groupAdminIds,
    'groupFinanceiroIds':  groupFinanceiroIds,
    'keepLoggedIn':        keepLoggedIn,
  };

  factory Account.fromJson(Map<String, dynamic> json) => Account(
    userId:             json['userId']             as String,
    name:               json['name']               as String,
    email:              json['email']              as String,
    roles:              List<String>.from(json['roles'] as List? ?? []),
    accessToken:        json['accessToken']        as String,
    refreshToken:       json['refreshToken']       as String,
    activeGroupId:      json['activeGroupId']      as String?,
    activePlayerId:     json['activePlayerId']     as String?,
    groupAdminIds:      List<String>.from(json['groupAdminIds']      as List? ?? []),
    groupFinanceiroIds: List<String>.from(json['groupFinanceiroIds'] as List? ?? []),
    keepLoggedIn:       json['keepLoggedIn']       as bool? ?? true,
  );

  Account copyWith({
    String?       userId,
    String?       name,
    String?       email,
    List<String>? roles,
    String?       accessToken,
    String?       refreshToken,
    String?       activeGroupId,
    String?       activePlayerId,
    List<String>? groupAdminIds,
    List<String>? groupFinanceiroIds,
    bool?         keepLoggedIn,
  }) =>
      Account(
        userId:             userId             ?? this.userId,
        name:               name               ?? this.name,
        email:              email              ?? this.email,
        roles:              roles              ?? this.roles,
        accessToken:        accessToken        ?? this.accessToken,
        refreshToken:       refreshToken       ?? this.refreshToken,
        activeGroupId:      activeGroupId      ?? this.activeGroupId,
        activePlayerId:     activePlayerId     ?? this.activePlayerId,
        groupAdminIds:      groupAdminIds      ?? this.groupAdminIds,
        groupFinanceiroIds: groupFinanceiroIds ?? this.groupFinanceiroIds,
        keepLoggedIn:       keepLoggedIn       ?? this.keepLoggedIn,
      );

  @override
  List<Object?> get props => [
    userId, name, email, roles, accessToken, refreshToken,
    activeGroupId, activePlayerId, groupAdminIds, groupFinanceiroIds,
    keepLoggedIn,
  ];
}

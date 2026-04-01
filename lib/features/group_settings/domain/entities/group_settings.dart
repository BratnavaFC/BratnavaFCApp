// ── GroupMember ───────────────────────────────────────────────────────────────

class GroupMember {
  final String  userId;
  final String? userName;
  final String? firstName;
  final String? lastName;

  const GroupMember({
    required this.userId,
    this.userName,
    this.firstName,
    this.lastName,
  });

  /// Display name — mirrors the site: "firstName lastName" || userName || 'Admin'
  String get displayName {
    final full = '${firstName ?? ''} ${lastName ?? ''}'.trim();
    return full.isNotEmpty ? full : (userName ?? 'Admin');
  }

  /// Two-letter initials for avatar
  String get initials {
    final f = firstName?.isNotEmpty == true ? firstName![0] : '';
    final l = lastName?.isNotEmpty == true  ? lastName![0]  : '';
    if (f.isNotEmpty || l.isNotEmpty) return (f + l).toUpperCase();
    return (userName?.isNotEmpty == true ? userName![0] : '?').toUpperCase();
  }

  /// From the group detail payload (adminUsers / financeiroUsers)
  factory GroupMember.fromJson(Map<String, dynamic> j) => GroupMember(
    userId:    (j['userId'] ?? j['id'] ?? '') as String,
    userName:  j['userName']  as String?,
    firstName: j['firstName'] as String?,
    lastName:  j['lastName']  as String?,
  );

  /// From the user-search payload — top-level id field
  factory GroupMember.fromSearchResult(Map<String, dynamic> j) => GroupMember(
    userId:    (j['id'] ?? j['userId'] ?? '') as String,
    userName:  j['userName']  as String?,
    firstName: j['firstName'] as String?,
    lastName:  j['lastName']  as String?,
  );

  /// From a player object inside the group detail — has 'name' as full name
  factory GroupMember.fromPlayerJson(Map<String, dynamic> j) {
    final name   = (j['name'] as String? ?? '').trim();
    final space  = name.indexOf(' ');
    return GroupMember(
      userId:    (j['userId'] ?? '') as String,
      userName:  j['userName'] as String?,
      firstName: space > 0 ? name.substring(0, space) : name,
      lastName:  space > 0 ? name.substring(space + 1) : null,
    );
  }
}

// ── GroupDetail ───────────────────────────────────────────────────────────────
// From GET /api/Groups/{groupId}

class GroupDetail {
  final String           id;
  final String           name;
  final String?          createdByUserId;
  final List<String>     adminIds;
  final List<GroupMember> adminUsers;
  final List<String>     financeiroIds;
  final List<GroupMember> financeiroUsers;

  const GroupDetail({
    required this.id,
    required this.name,
    this.createdByUserId,
    this.adminIds       = const [],
    this.adminUsers     = const [],
    this.financeiroIds  = const [],
    this.financeiroUsers = const [],
  });

  factory GroupDetail.fromJson(Map<String, dynamic> json) {
    // Unwrap { data: { ... } } or { data: [{ ... }] } envelope
    final raw = json['data'];
    final Map<String, dynamic> j;
    if (raw is Map<String, dynamic>) {
      j = raw;
    } else if (raw is List && raw.isNotEmpty && raw.first is Map<String, dynamic>) {
      j = raw.first as Map<String, dynamic>;
    } else {
      j = json;
    }

    List<String> parseIds(dynamic v) {
      if (v is! List) return [];
      return v.whereType<String>().toList();
    }

    List<GroupMember> parseMembers(dynamic v) {
      if (v is! List) return [];
      return v.whereType<Map<String, dynamic>>().map(GroupMember.fromJson).toList();
    }

    // Build userId → GroupMember lookup from players array (API does not return
    // separate adminUsers / financeiroUsers objects — members are in players[])
    final playerByUserId = <String, GroupMember>{};
    final playersRaw = j['players'];
    if (playersRaw is List) {
      for (final p in playersRaw) {
        if (p is Map<String, dynamic>) {
          final uid = p['userId'];
          if (uid is String && uid.isNotEmpty) {
            playerByUserId[uid] = GroupMember.fromPlayerJson(p);
          }
        }
      }
    }

    final adminIds       = parseIds(j['adminIds']);
    final financeiroIds  = parseIds(j['financeiroIds']);

    // Prefer explicit adminUsers/financeiroUsers if the API ever returns them;
    // otherwise resolve from the players lookup
    var adminUsers = parseMembers(j['adminUsers']);
    if (adminUsers.isEmpty) {
      adminUsers = adminIds
          .map((id) => playerByUserId[id] ?? GroupMember(userId: id))
          .toList();
    }

    var financeiroUsers = parseMembers(j['financeiroUsers']);
    if (financeiroUsers.isEmpty) {
      financeiroUsers = financeiroIds
          .map((id) => playerByUserId[id] ?? GroupMember(userId: id))
          .toList();
    }

    return GroupDetail(
      id:              (j['id'] ?? '') as String,
      name:            (j['name'] ?? '') as String,
      createdByUserId: j['createdByUserId'] as String?,
      adminIds:        adminIds,
      adminUsers:      adminUsers,
      financeiroIds:   financeiroIds,
      financeiroUsers: financeiroUsers,
    );
  }
}

// ── GroupSettings ─────────────────────────────────────────────────────────────
// From GET/PUT /api/GroupSettings/group/{groupId}

class GroupSettings {
  // Player limits
  final int minPlayers;
  final int maxPlayers;

  // Match defaults
  final String? defaultPlaceName;
  final int?    defaultDayOfWeek;    // 0=Sun…6=Sat, null=unset
  final String? defaultKickoffTime; // "HH:mm:ss" from API; display as "HH:mm"

  // Payment
  final int     paymentMode;  // 0 = Monthly, 1 = PerGame
  final double? monthlyFee;

  // Icons — exact field names from the API
  final String? goalIcon;
  final String? goalkeeperIcon;
  final String? assistIcon;
  final String? ownGoalIcon;
  final String? mvpIcon;
  final String? playerIcon;

  // MVP tie rule — mirrors site's mvpTieRule / mvpTieMaxPlayers
  // 0 = NoMvp  · 1 = AllMvp (default)  · 2 = AllMvpUpToMax
  final int mvpTieRule;
  final int mvpTieMaxPlayers;

  // Meta
  final bool isPersisted; // false = using defaults, prompt user to save
  final bool showPlayerStats; // true = regular players can see goals/assists

  const GroupSettings({
    this.minPlayers        = 5,
    this.maxPlayers        = 6,
    this.defaultPlaceName,
    this.defaultDayOfWeek,
    this.defaultKickoffTime,
    this.paymentMode       = 0,
    this.monthlyFee,
    this.goalIcon,
    this.goalkeeperIcon,
    this.assistIcon,
    this.ownGoalIcon,
    this.mvpIcon,
    this.playerIcon,
    this.mvpTieRule        = 1,
    this.mvpTieMaxPlayers  = 2,
    this.isPersisted       = false,
    this.showPlayerStats   = false,
  });

  factory GroupSettings.defaults() => const GroupSettings();

  factory GroupSettings.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> j =
        (json['data'] is Map<String, dynamic>)
            ? json['data'] as Map<String, dynamic>
            : json;

    return GroupSettings(
      minPlayers:         (j['minPlayers']  as int?)    ?? 5,
      maxPlayers:         (j['maxPlayers']  as int?)    ?? 6,
      defaultPlaceName:   j['defaultPlaceName']         as String?,
      defaultDayOfWeek:   j['defaultDayOfWeek']         as int?,
      defaultKickoffTime: j['defaultKickoffTime']       as String?,
      paymentMode:        (j['paymentMode'] as int?)    ?? 0,
      monthlyFee:         (j['monthlyFee']  as num?)?.toDouble(),
      goalIcon:           j['goalIcon']                 as String?,
      goalkeeperIcon:     j['goalkeeperIcon']           as String?,
      assistIcon:         j['assistIcon']               as String?,
      ownGoalIcon:        j['ownGoalIcon']              as String?,
      mvpIcon:            j['mvpIcon']                  as String?,
      playerIcon:         j['playerIcon']               as String?,
      mvpTieRule:         (j['mvpTieRule']        as int?) ?? 1,
      mvpTieMaxPlayers:   (j['mvpTieMaxPlayers']  as int?) ?? 2,
      isPersisted:        (j['isPersisted'] as bool?)   ?? false,
      showPlayerStats:    (j['showPlayerStats'] as bool?) ?? false,
    );
  }

  /// Build the PUT body — mirrors GroupSettingsApi.upsert() from the site
  Map<String, dynamic> toJson({
    required int     minPlayers,
    required int     maxPlayers,
    required String? defaultPlaceName,
    required int?    defaultDayOfWeek,
    required String? defaultKickoffTime, // already "HH:mm:ss"
    required int     paymentMode,
    required double? monthlyFee,
    required String? goalIcon,
    required String? goalkeeperIcon,
    required String? assistIcon,
    required String? ownGoalIcon,
    required String? mvpIcon,
    required String? playerIcon,
    required int     mvpTieRule,
    int?             mvpTieMaxPlayers,
    required bool    showPlayerStats,
  }) =>
      {
        'minPlayers':         minPlayers,
        'maxPlayers':         maxPlayers,
        'defaultPlaceName':   defaultPlaceName,
        'defaultDayOfWeek':   defaultDayOfWeek,
        'defaultKickoffTime': defaultKickoffTime,
        'goalIcon':           goalIcon,
        'goalkeeperIcon':     goalkeeperIcon,
        'assistIcon':         assistIcon,
        'ownGoalIcon':        ownGoalIcon,
        'mvpIcon':            mvpIcon,
        'playerIcon':         playerIcon,
        'paymentMode':        paymentMode,
        // monthlyFee only sent when Monthly mode (matches site behaviour)
        'monthlyFee': paymentMode == 0 ? monthlyFee : null,
        'mvpTieRule':         mvpTieRule,
        // mvpTieMaxPlayers only sent when rule == 2 (mirrors site behaviour)
        'mvpTieMaxPlayers': mvpTieRule == 2 ? mvpTieMaxPlayers : null,
        'showPlayerStats': showPlayerStats,
      };
}

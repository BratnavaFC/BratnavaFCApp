import 'package:equatable/equatable.dart';

class TeamColor extends Equatable {
  final String id;
  final String name;
  final String hexValue;

  const TeamColor({
    required this.id,
    required this.name,
    required this.hexValue,
  });

  factory TeamColor.fromJson(Map<String, dynamic> j) => TeamColor(
    id:       j['id']       as String? ?? '',
    name:     j['name']     as String? ?? '',
    hexValue: j['hexValue'] as String? ?? '#94A3B8',
  );

  @override
  List<Object?> get props => [id, name, hexValue];
}

enum InviteResponse { pending, accepted, declined }

class MatchPlayer extends Equatable {
  final String         matchPlayerId;
  final String         playerId;
  final String         playerName;
  final bool           isGoalkeeper;
  final int            team; // 0 = unassigned, 1 = teamA, 2 = teamB
  final InviteResponse inviteResponse;

  const MatchPlayer({
    required this.matchPlayerId,
    required this.playerId,
    required this.playerName,
    required this.isGoalkeeper,
    required this.team,
    required this.inviteResponse,
  });

  factory MatchPlayer.fromJson(Map<String, dynamic> j) => MatchPlayer(
    matchPlayerId: j['matchPlayerId'] as String? ?? '',
    playerId:      j['playerId']      as String? ?? '',
    playerName:    j['playerName']    as String? ?? '',
    isGoalkeeper:  j['isGoalkeeper']  as bool?   ?? false,
    team:          j['team']          as int?     ?? 0,
    inviteResponse: _parseInvite(j['inviteResponse'] as int? ?? 1),
  );

  // 1=Pendente  2=Recusado  3=Confirmado  (igual ao site)
  static InviteResponse _parseInvite(int v) => switch (v) {
    3 => InviteResponse.accepted,
    2 => InviteResponse.declined,
    _ => InviteResponse.pending,
  };

  @override
  List<Object?> get props =>
      [matchPlayerId, playerId, playerName, isGoalkeeper, team, inviteResponse];
}

class CurrentMatch extends Equatable {
  final String     matchId;
  final String     groupId;
  final DateTime   playedAt;
  final String     placeName;
  final int        status;
  final String     statusName;
  final int        teamAGoals;
  final int        teamBGoals;
  final TeamColor? teamAColor;
  final TeamColor? teamBColor;
  final List<MatchPlayer> players;

  const CurrentMatch({
    required this.matchId,
    required this.groupId,
    required this.playedAt,
    required this.placeName,
    required this.status,
    required this.statusName,
    required this.teamAGoals,
    required this.teamBGoals,
    this.teamAColor,
    this.teamBColor,
    this.players = const [],
  });

  factory CurrentMatch.fromJson(Map<String, dynamic> j) {
    TeamColor? parseColor(dynamic c) =>
        c == null ? null : TeamColor.fromJson(c as Map<String, dynamic>);

    List<MatchPlayer> parsePlayers(dynamic raw) {
      if (raw == null) return [];
      return (raw as List)
          .map((e) => MatchPlayer.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    return CurrentMatch(
      matchId:    j['matchId']    as String? ?? '',
      groupId:    j['groupId']    as String? ?? '',
      playedAt:   _parseDate(j['playedAt'] as String?),
      placeName:  j['placeName']  as String? ?? '',
      status:     j['status']     as int?    ?? 0,
      statusName: j['statusName'] as String? ?? '',
      teamAGoals: j['teamAGoals'] as int?    ?? 0,
      teamBGoals: j['teamBGoals'] as int?    ?? 0,
      teamAColor: parseColor(j['teamAColor']),
      teamBColor: parseColor(j['teamBColor']),
      players: [
        ...parsePlayers(j['teamAPlayers']),
        ...parsePlayers(j['teamBPlayers']),
        ...parsePlayers(j['unassignedPlayers']),
      ],
    );
  }

  @override
  List<Object?> get props => [matchId, status, teamAGoals, teamBGoals];
}

/// .NET retorna UTC sem sufixo 'Z' — igual ao JavaScript, forçamos UTC antes de converter.
DateTime _parseDate(String? s) {
  if (s == null || s.isEmpty) return DateTime.now();
  final hasTimezone = s.contains('Z') || s.contains('+') ||
      RegExp(r'-\d{2}:\d{2}$').hasMatch(s);
  final normalized  = hasTimezone ? s : '${s}Z';
  return DateTime.tryParse(normalized)?.toLocal() ?? DateTime.now();
}

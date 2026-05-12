import 'package:flutter/material.dart';

// ── Passo da partida ──────────────────────────────────────────────────────────

enum MatchStep {
  create,   // sem partida / status 0
  accept,   // status 1
  teams,    // status 2
  playing,  // status 3
  ended,    // status 4
  post,     // status 5
  done;     // status 6

  static MatchStep fromStatus(int status) {
    switch (status) {
      case 1:  return accept;
      case 2:  return teams;
      case 3:  return playing;
      case 4:  return ended;
      case 5:  return post;
      case 6:  return done;
      default: return create;
    }
  }

  static MatchStep fromKey(String key) {
    switch (key) {
      case 'accept':  return accept;
      case 'teams':   return teams;
      case 'playing': return playing;
      case 'ended':   return ended;
      case 'post':    return post;
      case 'done':    return done;
      default:        return create;
    }
  }

  int get stepNumber => MatchStep.values.indexOf(this) + 1;

  String get label {
    switch (this) {
      case create:  return 'Criar';
      case accept:  return 'Aceitação';
      case teams:   return 'MatchMaking';
      case playing: return 'Jogo';
      case ended:   return 'Encerrar';
      case post:    return 'Pós-jogo';
      case done:    return 'Final';
    }
  }
}

// ── Resposta ao convite ───────────────────────────────────────────────────────

enum InviteResponse { pending, accepted, declined }

// ── Cor do time ───────────────────────────────────────────────────────────────

class TeamColorInfo {
  final String id;
  final String name;
  final String hexValue;

  const TeamColorInfo({required this.id, required this.name, required this.hexValue});

  Color get color {
    final hex = hexValue.replaceAll('#', '');
    return Color(int.parse('FF$hex', radix: 16));
  }

  factory TeamColorInfo.fromJson(Map<String, dynamic> j) => TeamColorInfo(
    id:       (j['id'] ?? j['Id'] ?? '').toString(),
    name:     j['name']     as String? ?? j['Name']     as String? ?? '',
    hexValue: j['hexValue'] as String? ?? j['HexValue'] as String? ?? '#e2e8f0',
  );
}

// ── Jogador na partida ────────────────────────────────────────────────────────

class MatchPlayerInfo {
  final String matchPlayerId;
  final String playerId;
  final String playerName;
  final bool isGoalkeeper;
  final bool isGuest;
  final int team; // 0=não atribuído, 1=timeA, 2=timeB
  final InviteResponse inviteResponse;

  /// Ausência ativa no momento da partida (null = sem ausência).
  final int?    absenceType;
  final String? absenceDescription;

  const MatchPlayerInfo({
    required this.matchPlayerId,
    required this.playerId,
    required this.playerName,
    required this.isGoalkeeper,
    required this.isGuest,
    required this.team,
    required this.inviteResponse,
    this.absenceType,
    this.absenceDescription,
  });

  static InviteResponse _parseInvite(dynamic v) {
    final n = v is int ? v : int.tryParse(v?.toString() ?? '') ?? 0;
    if (n == 1) return InviteResponse.accepted;
    if (n == 2) return InviteResponse.declined;
    return InviteResponse.pending;
  }

  factory MatchPlayerInfo.fromJson(Map<String, dynamic> j) => MatchPlayerInfo(
    matchPlayerId:      (j['matchPlayerId']      ?? j['MatchPlayerId']      ?? '').toString(),
    playerId:           (j['playerId']           ?? j['PlayerId']           ?? '').toString(),
    playerName:         j['playerName']          as String? ?? j['PlayerName']          as String? ?? '',
    isGoalkeeper:       j['isGoalkeeper']        as bool?   ?? j['IsGoalkeeper']        as bool?   ?? false,
    isGuest:            j['isGuest']             as bool?   ?? j['IsGuest']             as bool?   ?? false,
    team:               j['team']                as int?    ?? j['Team']                as int?    ?? 0,
    inviteResponse:     _parseInvite(j['inviteResponse'] ?? j['InviteResponse']),
    absenceType:        j['absenceType']         as int?    ?? j['AbsenceType']         as int?,
    absenceDescription: j['absenceDescription']  as String? ?? j['AbsenceDescription']  as String?,
  );
}

// ── Gol ──────────────────────────────────────────────────────────────────────

class MatchGoal {
  final String goalId;
  final String? scorerPlayerId;
  final String? scorerName;
  final String? assistPlayerId;
  final String? assistName;
  final String? time;
  final int team; // 1=A, 2=B
  final bool isOwnGoal;

  const MatchGoal({
    required this.goalId,
    this.scorerPlayerId,
    this.scorerName,
    this.assistPlayerId,
    this.assistName,
    this.time,
    required this.team,
    required this.isOwnGoal,
  });

  factory MatchGoal.fromJson(Map<String, dynamic> j) => MatchGoal(
    goalId:         (j['goalId']        ?? j['GoalId']        ?? j['id'] ?? '').toString(),
    scorerPlayerId: (j['scorerPlayerId'] ?? j['ScorerPlayerId'])?.toString(),
    scorerName:     j['scorerName']     as String? ?? j['ScorerName']     as String?,
    assistPlayerId: (j['assistPlayerId'] ?? j['AssistPlayerId'])?.toString(),
    assistName:     j['assistName']     as String? ?? j['AssistName']     as String?,
    time:           j['time']           as String? ?? j['Time']           as String?,
    team:           j['team']           as int?    ?? j['Team']           as int?    ?? 0,
    isOwnGoal:      j['isOwnGoal']      as bool?   ?? j['IsOwnGoal']      as bool?   ?? false,
  );
}

// ── MVP ───────────────────────────────────────────────────────────────────────

class MvpInfo {
  final String playerId;
  final String playerName;
  const MvpInfo({required this.playerId, required this.playerName});

  factory MvpInfo.fromJson(Map<String, dynamic> j) => MvpInfo(
    playerId:   (j['playerId']  ?? j['PlayerId']  ?? '').toString(),
    playerName: j['playerName'] as String? ?? j['PlayerName'] as String? ?? '',
  );
}

// ── Voto ──────────────────────────────────────────────────────────────────────

class VoteInfo {
  final String voterMatchPlayerId;
  final String votedMatchPlayerId;
  const VoteInfo({required this.voterMatchPlayerId, required this.votedMatchPlayerId});

  factory VoteInfo.fromJson(Map<String, dynamic> j) => VoteInfo(
    voterMatchPlayerId: (j['voterPlayerId'] ?? j['VoterPlayerId'] ?? '').toString(),
    votedMatchPlayerId: (j['votedPlayerId'] ?? j['VotedPlayerId'] ?? '').toString(),
  );
}

// ── Contagem de votos ─────────────────────────────────────────────────────────

class VoteCount {
  final String matchPlayerId;
  final String playerName;
  final int count;
  const VoteCount({required this.matchPlayerId, required this.playerName, required this.count});

  factory VoteCount.fromJson(Map<String, dynamic> j) => VoteCount(
    matchPlayerId: (j['matchPlayerId'] ?? j['MatchPlayerId'] ?? '').toString(),
    playerName:    j['playerName']     as String? ?? j['PlayerName']     as String? ?? '',
    count:         j['count']          as int?    ?? j['Count']          as int?    ?? 0,
  );
}

// ── Jogador para geração de times ─────────────────────────────────────────────

class TeamGenPlayer {
  final String playerId;
  final String name;
  final bool isGoalkeeper;
  final double weight;

  const TeamGenPlayer({
    required this.playerId,
    required this.name,
    required this.isGoalkeeper,
    required this.weight,
  });

  factory TeamGenPlayer.fromJson(Map<String, dynamic> j) => TeamGenPlayer(
    playerId:     (j['playerId'] ?? j['id'] ?? '').toString(),
    name:         j['name']         as String? ?? j['playerName'] as String? ?? '',
    isGoalkeeper: j['isGoalkeeper'] as bool?   ?? false,
    weight:       (j['weight']      as num?    ?? 0).toDouble(),
  );
}

// ── Opção de time gerada ──────────────────────────────────────────────────────

class TeamGenOption {
  final List<TeamGenPlayer> teamA;
  final List<TeamGenPlayer> teamB;
  final List<TeamGenPlayer> unassigned;
  final double teamAWeight;
  final double teamBWeight;
  final double balanceDiff;
  final String? explanation;

  const TeamGenOption({
    required this.teamA,
    required this.teamB,
    required this.unassigned,
    required this.teamAWeight,
    required this.teamBWeight,
    required this.balanceDiff,
    this.explanation,
  });

  factory TeamGenOption.fromJson(Map<String, dynamic> j) {
    List<TeamGenPlayer> parseList(dynamic v) =>
        (v as List? ?? []).map((e) => TeamGenPlayer.fromJson(e as Map<String, dynamic>)).toList();
    return TeamGenOption(
      teamA:       parseList(j['teamA']      ?? j['TeamA']),
      teamB:       parseList(j['teamB']      ?? j['TeamB']),
      unassigned:  parseList(j['unassigned'] ?? j['Unassigned']),
      teamAWeight: (j['teamAWeight'] as num? ?? 0).toDouble(),
      teamBWeight: (j['teamBWeight'] as num? ?? 0).toDouble(),
      balanceDiff: (j['balanceDiff'] as num? ?? 0).toDouble(),
      explanation: j['explanation'] as String? ?? j['Explanation'] as String?,
    );
  }

  TeamGenOption copyWith({
    List<TeamGenPlayer>? teamA,
    List<TeamGenPlayer>? teamB,
    List<TeamGenPlayer>? unassigned,
    double? teamAWeight,
    double? teamBWeight,
    double? balanceDiff,
  }) =>
      TeamGenOption(
        teamA:       teamA       ?? this.teamA,
        teamB:       teamB       ?? this.teamB,
        unassigned:  unassigned  ?? this.unassigned,
        teamAWeight: teamAWeight ?? this.teamAWeight,
        teamBWeight: teamBWeight ?? this.teamBWeight,
        balanceDiff: balanceDiff ?? this.balanceDiff,
        explanation: explanation,
      );
}

// ── Configurações do grupo (relevantes para partida) ──────────────────────────

class MatchGroupSettings {
  final int? minPlayers;
  final int? maxPlayers;
  final String? defaultPlaceName;
  final String? defaultKickoffTime; // formato "HH:mm:ss"

  const MatchGroupSettings({
    this.minPlayers,
    this.maxPlayers,
    this.defaultPlaceName,
    this.defaultKickoffTime,
  });

  factory MatchGroupSettings.fromJson(Map<String, dynamic> j) => MatchGroupSettings(
    minPlayers:         j['minPlayers']         as int?    ?? j['MinPlayers']         as int?,
    maxPlayers:         j['maxPlayers']         as int?    ?? j['MaxPlayers']         as int?,
    defaultPlaceName:   j['defaultPlaceName']   as String? ?? j['DefaultPlaceName']   as String?
                        ?? j['placeName']       as String? ?? j['PlaceName']          as String?,
    defaultKickoffTime: j['defaultKickoffTime'] as String? ?? j['DefaultKickoffTime'] as String?,
  );
}

// ── Estado global da partida ──────────────────────────────────────────────────

class MatchState {
  const MatchState({
    this.loading           = false,
    this.mutating          = false,
    this.error,
    this.matchId,
    this.groupId           = '',
    this.step              = MatchStep.create,
    this.playedAt,
    this.placeName,
    this.canRewind         = false,
    this.teamAColor,
    this.teamBColor,
    this.colorsLocked      = false,
    this.availableColors   = const [],
    this.acceptedPlayers   = const [],
    this.rejectedPlayers   = const [],
    this.pendingPlayers    = const [],
    this.maxPlayers        = 14,
    this.acceptedOverLimit = false,
    this.teamAPlayers      = const [],
    this.teamBPlayers      = const [],
    this.unassignedPlayers = const [],
    this.participants      = const [],
    this.teamGenOptions    = const [],
    this.selectedTeamGenIdx = 0,
    this.goals             = const [],
    this.teamAGoals,
    this.teamBGoals,
    this.computedMvps      = const [],
    this.votes             = const [],
    this.voteCounts        = const [],
    this.allVoted          = false,
    this.eligibleVoters    = const [],
    this.groupSettings,
  });

  final bool    loading;
  final bool    mutating;
  final String? error;
  final String? matchId;
  final String  groupId;
  final MatchStep step;
  final DateTime? playedAt;
  final String?   placeName;
  final bool      canRewind;

  final TeamColorInfo?      teamAColor;
  final TeamColorInfo?      teamBColor;
  final bool                colorsLocked;
  final List<TeamColorInfo> availableColors;

  final List<MatchPlayerInfo> acceptedPlayers;
  final List<MatchPlayerInfo> rejectedPlayers;
  final List<MatchPlayerInfo> pendingPlayers;
  final int  maxPlayers;
  final bool acceptedOverLimit;

  final List<MatchPlayerInfo> teamAPlayers;
  final List<MatchPlayerInfo> teamBPlayers;
  final List<MatchPlayerInfo> unassignedPlayers;
  final List<MatchPlayerInfo> participants;

  final List<TeamGenOption> teamGenOptions;
  final int selectedTeamGenIdx;

  final List<MatchGoal> goals;
  final int? teamAGoals;
  final int? teamBGoals;

  final List<MvpInfo>         computedMvps;
  final List<VoteInfo>        votes;
  final List<VoteCount>       voteCounts;
  final bool                  allVoted;
  final List<MatchPlayerInfo> eligibleVoters;

  final MatchGroupSettings? groupSettings;

  // ── Derivados ─────────────────────────────────────────────────────────────

  bool get hasMatch      => matchId != null && matchId!.isNotEmpty;
  bool get teamsAssigned => teamAPlayers.isNotEmpty && teamBPlayers.isNotEmpty;

  MatchState copyWith({
    bool? loading, bool? mutating, String? error,
    String? matchId, String? groupId, MatchStep? step,
    DateTime? playedAt, String? placeName, bool? canRewind,
    TeamColorInfo? teamAColor, TeamColorInfo? teamBColor,
    bool? colorsLocked, List<TeamColorInfo>? availableColors,
    List<MatchPlayerInfo>? acceptedPlayers, List<MatchPlayerInfo>? rejectedPlayers,
    List<MatchPlayerInfo>? pendingPlayers, int? maxPlayers, bool? acceptedOverLimit,
    List<MatchPlayerInfo>? teamAPlayers, List<MatchPlayerInfo>? teamBPlayers,
    List<MatchPlayerInfo>? unassignedPlayers, List<MatchPlayerInfo>? participants,
    List<TeamGenOption>? teamGenOptions, int? selectedTeamGenIdx,
    List<MatchGoal>? goals, int? teamAGoals, int? teamBGoals,
    List<MvpInfo>? computedMvps, List<VoteInfo>? votes, List<VoteCount>? voteCounts,
    bool? allVoted, List<MatchPlayerInfo>? eligibleVoters,
    MatchGroupSettings? groupSettings,
  }) =>
      MatchState(
        loading:            loading            ?? this.loading,
        mutating:           mutating           ?? this.mutating,
        error:              error              ?? this.error,
        matchId:            matchId            ?? this.matchId,
        groupId:            groupId            ?? this.groupId,
        step:               step               ?? this.step,
        playedAt:           playedAt           ?? this.playedAt,
        placeName:          placeName          ?? this.placeName,
        canRewind:          canRewind          ?? this.canRewind,
        teamAColor:         teamAColor         ?? this.teamAColor,
        teamBColor:         teamBColor         ?? this.teamBColor,
        colorsLocked:       colorsLocked       ?? this.colorsLocked,
        availableColors:    availableColors    ?? this.availableColors,
        acceptedPlayers:    acceptedPlayers    ?? this.acceptedPlayers,
        rejectedPlayers:    rejectedPlayers    ?? this.rejectedPlayers,
        pendingPlayers:     pendingPlayers     ?? this.pendingPlayers,
        maxPlayers:         maxPlayers         ?? this.maxPlayers,
        acceptedOverLimit:  acceptedOverLimit  ?? this.acceptedOverLimit,
        teamAPlayers:       teamAPlayers       ?? this.teamAPlayers,
        teamBPlayers:       teamBPlayers       ?? this.teamBPlayers,
        unassignedPlayers:  unassignedPlayers  ?? this.unassignedPlayers,
        participants:       participants       ?? this.participants,
        teamGenOptions:     teamGenOptions     ?? this.teamGenOptions,
        selectedTeamGenIdx: selectedTeamGenIdx ?? this.selectedTeamGenIdx,
        goals:              goals              ?? this.goals,
        teamAGoals:         teamAGoals         ?? this.teamAGoals,
        teamBGoals:         teamBGoals         ?? this.teamBGoals,
        computedMvps:       computedMvps       ?? this.computedMvps,
        votes:              votes              ?? this.votes,
        voteCounts:         voteCounts         ?? this.voteCounts,
        allVoted:           allVoted           ?? this.allVoted,
        eligibleVoters:     eligibleVoters     ?? this.eligibleVoters,
        groupSettings:      groupSettings      ?? this.groupSettings,
      );
}

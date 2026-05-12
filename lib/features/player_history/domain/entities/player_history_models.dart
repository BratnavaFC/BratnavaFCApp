import 'package:equatable/equatable.dart';

// ── Match history item (per-player view) ──────────────────────────────────────

class MatchHistoryItem extends Equatable {
  final String  matchId;
  final String  date;
  final String? place;
  final String  result;    // "win" | "loss" | "draw"
  final int     teamAScore;
  final int     teamBScore;
  final String? teamAColor;
  final String? teamBColor;
  final int     goals;
  final int     assists;
  final bool    isMvp;
  final bool    isOwnGoal;
  final int     team;      // 1 = team A, 2 = team B

  const MatchHistoryItem({
    required this.matchId,
    required this.date,
    this.place,
    required this.result,
    required this.teamAScore,
    required this.teamBScore,
    this.teamAColor,
    this.teamBColor,
    required this.goals,
    required this.assists,
    required this.isMvp,
    required this.isOwnGoal,
    required this.team,
  });

  factory MatchHistoryItem.fromJson(Map<String, dynamic> j) =>
      MatchHistoryItem(
        matchId:    (j['matchId']    ?? '') as String,
        date:       (j['date']       ?? '') as String,
        place:      j['place']       as String?,
        result:     (j['result']     ?? 'draw') as String,
        teamAScore: (j['teamAScore'] as num?)?.toInt() ?? 0,
        teamBScore: (j['teamBScore'] as num?)?.toInt() ?? 0,
        teamAColor: j['teamAColor']  as String?,
        teamBColor: j['teamBColor']  as String?,
        goals:      (j['goals']      as num?)?.toInt() ?? 0,
        assists:    (j['assists']    as num?)?.toInt() ?? 0,
        isMvp:      (j['isMvp']      as bool?) ?? false,
        isOwnGoal:  (j['isOwnGoal']  as bool?) ?? false,
        team:       (j['team']       as num?)?.toInt() ?? 0,
      );

  bool get isWin  => result.toLowerCase() == 'win';
  bool get isLoss => result.toLowerCase() == 'loss';
  bool get isDraw => !isWin && !isLoss;

  @override
  List<Object?> get props => [
    matchId, date, place, result, teamAScore, teamBScore,
    teamAColor, teamBColor, goals, assists, isMvp, isOwnGoal, team,
  ];
}

// ── Stats summary computed from a list of items ───────────────────────────────

class PlayerHistorySummary {
  final int totalMatches;
  final int wins;
  final int losses;
  final int draws;
  final int totalGoals;
  final int totalAssists;
  final int totalMvps;

  const PlayerHistorySummary({
    required this.totalMatches,
    required this.wins,
    required this.losses,
    required this.draws,
    required this.totalGoals,
    required this.totalAssists,
    required this.totalMvps,
  });

  factory PlayerHistorySummary.from(List<MatchHistoryItem> items) {
    int wins = 0, losses = 0, draws = 0,
        goals = 0, assists = 0, mvps = 0;

    for (final m in items) {
      if (m.isWin)       wins++;
      else if (m.isLoss) losses++;
      else               draws++;
      goals   += m.goals;
      assists += m.assists;
      if (m.isMvp) mvps++;
    }

    return PlayerHistorySummary(
      totalMatches:  items.length,
      wins:          wins,
      losses:        losses,
      draws:         draws,
      totalGoals:    goals,
      totalAssists:  assists,
      totalMvps:     mvps,
    );
  }
}

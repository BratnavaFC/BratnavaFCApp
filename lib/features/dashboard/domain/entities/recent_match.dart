import 'package:equatable/equatable.dart';
import 'current_match.dart';

enum MatchOutcome { win, draw, loss }

class RecentMatch extends Equatable {
  final String      matchId;
  final DateTime    playedAt;
  final String      placeName;
  final int         goals;
  final int         assists;
  final MatchOutcome outcome;
  final TeamColor?  myTeamColor;
  final TeamColor?  opponentColor;
  final int         myTeamGoals;
  final int         opponentGoals;

  const RecentMatch({
    required this.matchId,
    required this.playedAt,
    required this.placeName,
    required this.goals,
    required this.assists,
    required this.outcome,
    this.myTeamColor,
    this.opponentColor,
    required this.myTeamGoals,
    required this.opponentGoals,
  });

  factory RecentMatch.fromJson(Map<String, dynamic> j) {
    // Tenta objeto aninhado; cai para campos flat (teamAColorHex / teamAColorName)
    TeamColor? parseColor(dynamic nested, String hexKey, String nameKey) {
      if (nested != null && nested is Map<String, dynamic>) {
        return TeamColor.fromJson(nested);
      }
      final hex  = j[hexKey]  as String?;
      final name = j[nameKey] as String?;
      if (hex == null && name == null) return null;
      return TeamColor(id: '', name: name ?? '', hexValue: hex ?? '');
    }

    final myTeam     = j['playerTeam'] as int? ?? 1;
    final teamAGoals = j['teamAGoals'] as int? ?? 0;
    final teamBGoals = j['teamBGoals'] as int? ?? 0;
    final myGoals    = myTeam == 1 ? teamAGoals : teamBGoals;
    final oppGoals   = myTeam == 1 ? teamBGoals : teamAGoals;

    final outcome = myGoals > oppGoals
        ? MatchOutcome.win
        : myGoals < oppGoals
            ? MatchOutcome.loss
            : MatchOutcome.draw;

    return RecentMatch(
      matchId:   j['matchId'] as String? ?? '',
      playedAt:  _parseDate(j['playedAt'] as String?),
      placeName: j['placeName'] as String? ?? '',
      // Aceita tanto playerGoals/playerAssists quanto goals/assists
      goals:   (j['playerGoals']   ?? j['goals'])   as int? ?? 0,
      assists: (j['playerAssists'] ?? j['assists']) as int? ?? 0,
      outcome: outcome,
      myTeamColor: parseColor(
        myTeam == 1 ? j['teamAColor'] : j['teamBColor'],
        myTeam == 1 ? 'teamAColorHex' : 'teamBColorHex',
        myTeam == 1 ? 'teamAColorName' : 'teamBColorName',
      ),
      opponentColor: parseColor(
        myTeam == 1 ? j['teamBColor'] : j['teamAColor'],
        myTeam == 1 ? 'teamBColorHex' : 'teamAColorHex',
        myTeam == 1 ? 'teamBColorName' : 'teamAColorName',
      ),
      myTeamGoals:   myGoals,
      opponentGoals: oppGoals,
    );
  }

  @override
  List<Object?> get props => [matchId, playedAt, outcome];
}

/// Strips timezone suffix, parses as wall-clock time, then subtracts 3 hours
/// to compensate for the backend always returning times 3 hours ahead (UTC vs UTC-3).
DateTime _parseDate(String? s) {
  if (s == null || s.isEmpty) return DateTime.now();
  final bare = s.replaceFirst(RegExp(r'Z$|[+-]\d{2}:\d{2}$'), '');
  final dt = DateTime.tryParse(bare) ?? DateTime.now();
  return dt.subtract(const Duration(hours: 3));
}

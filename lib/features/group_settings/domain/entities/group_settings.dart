import 'package:equatable/equatable.dart';

class GroupSettings extends Equatable {
  final String  id;
  final String  name;
  final String? description;
  final int?    matchDayOfWeek;  // 0=Sun … 6=Sat, nullable
  final String? matchTime;       // "HH:mm" format, nullable
  final int     matchDuration;   // minutes
  final int     playersPerTeam;
  final bool    isActive;

  const GroupSettings({
    required this.id,
    required this.name,
    this.description,
    this.matchDayOfWeek,
    this.matchTime,
    this.matchDuration  = 60,
    this.playersPerTeam = 6,
    this.isActive       = true,
  });

  // ── Deserialization ──────────────────────────────────────────────────────────

  factory GroupSettings.fromJson(Map<String, dynamic> json) {
    // Unwrap API envelope { data: { ... } } if present
    final Map<String, dynamic> j =
        (json['data'] is Map<String, dynamic>)
            ? json['data'] as Map<String, dynamic>
            : json;

    return GroupSettings(
      id:             j['id']             as String? ?? '',
      name:           j['name']           as String? ?? '',
      description:    j['description']    as String?,
      matchDayOfWeek: j['matchDayOfWeek'] as int?,
      matchTime:      j['matchTime']      as String?,
      matchDuration:  (j['matchDuration'] as int?)  ?? 60,
      playersPerTeam: (j['playersPerTeam'] as int?) ?? 6,
      isActive:       (j['isActive']      as bool?) ?? true,
    );
  }

  // ── Serialization (for save / PUT body) ──────────────────────────────────────

  Map<String, dynamic> toJson() => {
        'name':           name,
        'description':    description,
        'matchDayOfWeek': matchDayOfWeek,
        'matchTime':      matchTime,
        'matchDuration':  matchDuration,
        'playersPerTeam': playersPerTeam,
      };

  // ── copyWith ─────────────────────────────────────────────────────────────────

  GroupSettings copyWith({
    String?  id,
    String?  name,
    Object?  description    = _sentinel,
    Object?  matchDayOfWeek = _sentinel,
    Object?  matchTime      = _sentinel,
    int?     matchDuration,
    int?     playersPerTeam,
    bool?    isActive,
  }) =>
      GroupSettings(
        id:             id             ?? this.id,
        name:           name           ?? this.name,
        description:    description    == _sentinel ? this.description    : description    as String?,
        matchDayOfWeek: matchDayOfWeek == _sentinel ? this.matchDayOfWeek : matchDayOfWeek as int?,
        matchTime:      matchTime      == _sentinel ? this.matchTime      : matchTime      as String?,
        matchDuration:  matchDuration  ?? this.matchDuration,
        playersPerTeam: playersPerTeam ?? this.playersPerTeam,
        isActive:       isActive       ?? this.isActive,
      );

  static const Object _sentinel = Object();

  // ── Equatable ────────────────────────────────────────────────────────────────

  @override
  List<Object?> get props => [
        id,
        name,
        description,
        matchDayOfWeek,
        matchTime,
        matchDuration,
        playersPerTeam,
        isActive,
      ];
}

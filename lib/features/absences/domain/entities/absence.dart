import 'package:equatable/equatable.dart';

// ── AbsenceType ───────────────────────────────────────────────────────────────

enum AbsenceType {
  trip,      // 1 – Viagem
  medical,   // 2 – Departamento Médico
  personal,  // 3 – Pessoal
  other;     // 4 – Outros

  static AbsenceType fromInt(int? v) {
    switch (v) {
      case 1:  return AbsenceType.trip;
      case 2:  return AbsenceType.medical;
      case 3:  return AbsenceType.personal;
      default: return AbsenceType.other;
    }
  }

  int get value {
    switch (this) {
      case AbsenceType.trip:     return 1;
      case AbsenceType.medical:  return 2;
      case AbsenceType.personal: return 3;
      case AbsenceType.other:    return 4;
    }
  }

  String get label {
    switch (this) {
      case AbsenceType.trip:     return 'Viagem';
      case AbsenceType.medical:  return 'Departamento Médico';
      case AbsenceType.personal: return 'Pessoal';
      case AbsenceType.other:    return 'Outros';
    }
  }

  String get emoji {
    switch (this) {
      case AbsenceType.trip:     return '✈️';
      case AbsenceType.medical:  return '🏥';
      case AbsenceType.personal: return '🤝';
      case AbsenceType.other:    return '📌';
    }
  }
}

// ── Absence ───────────────────────────────────────────────────────────────────

class Absence extends Equatable {
  final String      id;
  final String      playerId;
  final String      playerName;
  final AbsenceType type;
  /// Display name returned by the server (e.g. "Departamento Médico").
  /// Falls back to [type.label] when null.
  final String?     typeName;
  final String      startDate;   // "YYYY-MM-DD"
  final String      endDate;     // "YYYY-MM-DD"
  final String?     description;

  const Absence({
    required this.id,
    required this.playerId,
    required this.playerName,
    required this.type,
    this.typeName,
    required this.startDate,
    required this.endDate,
    this.description,
  });

  String get displayTypeName => typeName ?? type.label;

  /// Use when the absence object comes from the group endpoint and
  /// playerId/playerName are injected by the datasource.
  factory Absence.fromJson(Map<String, dynamic> j) => Absence(
    id:          j['id']              as String? ?? '',
    playerId:    j['playerId']        as String? ?? '',
    playerName:  j['playerName']      as String? ?? '',
    type:        AbsenceType.fromInt(j['absenceType'] as int?),
    typeName:    j['absenceTypeName'] as String?,
    startDate:   (j['startDate']  as String? ?? '').split('T').first,
    endDate:     (j['endDate']    as String? ?? '').split('T').first,
    description: j['description'] as String?,
  );

  @override
  List<Object?> get props => [id, playerId, type, startDate, endDate];
}

// ── CreateAbsenceDto ──────────────────────────────────────────────────────────

class CreateAbsenceDto {
  final AbsenceType type;
  final String      startDate;
  final String      endDate;
  final String?     description;

  const CreateAbsenceDto({
    required this.type,
    required this.startDate,
    required this.endDate,
    this.description,
  });

  Map<String, dynamic> toJson() => {
    'absenceType': type.value,
    'startDate':   startDate,
    'endDate':     endDate,
    if (description != null && description!.isNotEmpty)
      'description': description,
  };
}

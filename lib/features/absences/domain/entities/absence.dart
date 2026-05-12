class AbsenceDto {
  final String  id;
  final String  startDate;
  final String  endDate;
  final int     absenceType;
  final String  absenceTypeName;
  final String? description;
  final String  createdAt;

  const AbsenceDto({
    required this.id,
    required this.startDate,
    required this.endDate,
    required this.absenceType,
    required this.absenceTypeName,
    this.description,
    required this.createdAt,
  });

  factory AbsenceDto.fromJson(Map<String, dynamic> json) => AbsenceDto(
    id:              json['id']              as String,
    startDate:       json['startDate']       as String,
    endDate:         json['endDate']         as String,
    absenceType:     json['absenceType']     as int,
    absenceTypeName: json['absenceTypeName'] as String,
    description:     json['description']     as String?,
    createdAt:       json['createdAt']       as String,
  );
}

class CreateAbsenceDto {
  final String  startDate;
  final String  endDate;
  final int     absenceType;
  final String? description;

  const CreateAbsenceDto({
    required this.startDate,
    required this.endDate,
    required this.absenceType,
    this.description,
  });

  Map<String, dynamic> toJson() => {
    'startDate':   startDate,
    'endDate':     endDate,
    'absenceType': absenceType,
    if (description != null && description!.isNotEmpty) 'description': description,
  };
}

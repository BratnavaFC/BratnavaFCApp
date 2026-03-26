import 'package:equatable/equatable.dart';

// ── PollOption ─────────────────────────────────────────────────────────────────

class PollOption extends Equatable {
  final String  id;
  final String  text;
  final String? description;
  final String? imageUrl;
  final int     sortOrder;
  final int     voteCount;

  const PollOption({
    required this.id,
    required this.text,
    this.description,
    this.imageUrl,
    required this.sortOrder,
    required this.voteCount,
  });

  factory PollOption.fromJson(Map<String, dynamic> j) => PollOption(
    id:          j['id']          as String? ?? '',
    text:        j['text']        as String? ?? '',
    description: j['description'] as String?,
    imageUrl:    j['imageUrl']    as String?,
    sortOrder:   j['sortOrder']   as int?    ?? 0,
    voteCount:   j['voteCount']   as int?    ?? 0,
  );

  @override
  List<Object?> get props => [id, voteCount];
}

// ── PollVote ───────────────────────────────────────────────────────────────────

class PollVote extends Equatable {
  final String optionId;
  final String playerId;
  final String playerName;

  const PollVote({
    required this.optionId,
    required this.playerId,
    required this.playerName,
  });

  factory PollVote.fromJson(Map<String, dynamic> j) => PollVote(
    optionId:   j['optionId']   as String? ?? '',
    playerId:   j['playerId']   as String? ?? '',
    playerName: j['playerName'] as String? ?? '',
  );

  @override
  List<Object?> get props => [optionId, playerId];
}

// ── PollMemberVote ─────────────────────────────────────────────────────────────

class PollMemberVote extends Equatable {
  final String       playerId;
  final String       playerName;
  final List<String> votedOptionIds;

  const PollMemberVote({
    required this.playerId,
    required this.playerName,
    required this.votedOptionIds,
  });

  factory PollMemberVote.fromJson(Map<String, dynamic> j) => PollMemberVote(
    playerId:       j['playerId']       as String? ?? '',
    playerName:     j['playerName']     as String? ?? '',
    votedOptionIds: List<String>.from(j['votedOptionIds'] as List? ?? []),
  );

  @override
  List<Object?> get props => [playerId, votedOptionIds];
}

// ── PollDetail ─────────────────────────────────────────────────────────────────

class PollDetail extends Equatable {
  final String             id;
  final String             title;
  final String?            description;
  final bool               allowMultipleVotes;
  final bool               showVotes;
  final String             status;
  final String?            deadlineDate;
  final String?            deadlineTime;
  final String             createDate;
  final String             type;
  final String?            eventDate;
  final String?            eventTime;
  final String?            eventLocation;
  final String?            eventIcon;
  final String?            costType;
  final double?            costAmount;
  final List<PollOption>   options;
  final List<PollVote>?    votes;
  final List<String>       myVotedOptionIds;
  final int                totalVoters;
  final List<PollMemberVote>? members; // admin only

  const PollDetail({
    required this.id,
    required this.title,
    this.description,
    required this.allowMultipleVotes,
    required this.showVotes,
    required this.status,
    this.deadlineDate,
    this.deadlineTime,
    required this.createDate,
    required this.type,
    this.eventDate,
    this.eventTime,
    this.eventLocation,
    this.eventIcon,
    this.costType,
    this.costAmount,
    required this.options,
    this.votes,
    required this.myVotedOptionIds,
    required this.totalVoters,
    this.members,
  });

  bool get isOpen  => status == 'open';
  bool get isEvent => type == 'event';

  bool get deadlinePassed {
    if (deadlineDate == null) return false;
    final time = deadlineTime ?? '23:59';
    final deadline = DateTime.tryParse('${deadlineDate}T$time:00');
    if (deadline == null) return false;
    return DateTime.now().isAfter(deadline);
  }

  factory PollDetail.fromJson(Map<String, dynamic> j) => PollDetail(
    id:                 j['id']                 as String? ?? '',
    title:              j['title']              as String? ?? '',
    description:        j['description']        as String?,
    allowMultipleVotes: j['allowMultipleVotes'] as bool?   ?? false,
    showVotes:          j['showVotes']          as bool?   ?? false,
    status:             j['status']             as String? ?? 'open',
    deadlineDate:       j['deadlineDate']       as String?,
    deadlineTime:       j['deadlineTime']       as String?,
    createDate:         j['createDate']         as String? ?? '',
    type:               j['type']               as String? ?? 'poll',
    eventDate:          j['eventDate']          as String?,
    eventTime:          j['eventTime']          as String?,
    eventLocation:      j['eventLocation']      as String?,
    eventIcon:          j['eventIcon']          as String?,
    costType:           j['costType']           as String?,
    costAmount:         (j['costAmount'] as num?)?.toDouble(),
    options:            (j['options'] as List? ?? [])
        .map((e) => PollOption.fromJson(e as Map<String, dynamic>))
        .toList(),
    votes:              (j['votes'] as List?)
        ?.map((e) => PollVote.fromJson(e as Map<String, dynamic>))
        .toList(),
    myVotedOptionIds:   List<String>.from(j['myVotedOptionIds'] as List? ?? []),
    totalVoters:        j['totalVoters'] as int? ?? 0,
    members:            (j['members'] as List?)
        ?.map((e) => PollMemberVote.fromJson(e as Map<String, dynamic>))
        .toList(),
  );

  PollDetail copyWith({
    List<PollOption>?      options,
    List<String>?          myVotedOptionIds,
    int?                   totalVoters,
    String?                status,
    List<PollMemberVote>?  members,
    List<PollVote>?        votes,
  }) => PollDetail(
    id:                 id,
    title:              title,
    description:        description,
    allowMultipleVotes: allowMultipleVotes,
    showVotes:          showVotes,
    status:             status ?? this.status,
    deadlineDate:       deadlineDate,
    deadlineTime:       deadlineTime,
    createDate:         createDate,
    type:               type,
    eventDate:          eventDate,
    eventTime:          eventTime,
    eventLocation:      eventLocation,
    eventIcon:          eventIcon,
    costType:           costType,
    costAmount:         costAmount,
    options:            options ?? this.options,
    votes:              votes ?? this.votes,
    myVotedOptionIds:   myVotedOptionIds ?? this.myVotedOptionIds,
    totalVoters:        totalVoters ?? this.totalVoters,
    members:            members ?? this.members,
  );

  @override
  List<Object?> get props => [id, status, myVotedOptionIds, totalVoters, options];
}

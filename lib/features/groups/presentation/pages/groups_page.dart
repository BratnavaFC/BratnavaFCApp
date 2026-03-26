import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/api/api_constants.dart';
import '../../../auth/presentation/providers/account_store.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

extension _FirstOrNullExt<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

// ─────────────────────────────────────────────────────────────────────────────
// DTOs
// ─────────────────────────────────────────────────────────────────────────────

class _PlayerDto {
  final String id;
  final String? userId;
  final String? userName;
  final String name;
  final int skillPoints;
  final bool isGoalkeeper;
  final bool isGuest;
  final int status;
  final int? guestStarRating;

  const _PlayerDto({
    required this.id,
    this.userId,
    this.userName,
    required this.name,
    required this.skillPoints,
    required this.isGoalkeeper,
    required this.isGuest,
    required this.status,
    this.guestStarRating,
  });

  factory _PlayerDto.fromJson(Map<String, dynamic> j) => _PlayerDto(
        id: j['id'] as String? ?? '',
        userId: j['userId'] as String?,
        userName: j['userName'] as String?,
        name: j['name'] as String? ?? '',
        skillPoints: j['skillPoints'] as int? ?? 0,
        isGoalkeeper: j['isGoalkeeper'] as bool? ?? false,
        isGuest: j['isGuest'] as bool? ?? false,
        status: j['status'] as int? ?? 1,
        guestStarRating: j['guestStarRating'] as int?,
      );
}

class _GroupDto {
  final String id;
  final String name;
  final List<String> adminIds;
  final List<_PlayerDto> players;
  final String createdByUserId;

  const _GroupDto({
    required this.id,
    required this.name,
    required this.adminIds,
    required this.players,
    required this.createdByUserId,
  });

  factory _GroupDto.fromJson(Map<String, dynamic> j) => _GroupDto(
        id: j['id'] as String? ?? '',
        name: j['name'] as String? ?? '',
        adminIds: List<String>.from(j['adminIds'] as List? ?? const []),
        players: ((j['players'] as List?) ?? const [])
            .map((e) => _PlayerDto.fromJson(e as Map<String, dynamic>))
            .toList(),
        createdByUserId: j['createdByUserId'] as String? ?? '',
      );
}

class _MyPlayerItem {
  final String playerId;
  final String? userId;
  final String groupId;
  final String playerName;
  final bool isGoalkeeper;
  final int skillPoints;
  final int status;
  final String groupName;
  final bool isGuest;

  const _MyPlayerItem({
    required this.playerId,
    this.userId,
    required this.groupId,
    required this.playerName,
    required this.isGoalkeeper,
    required this.skillPoints,
    required this.status,
    required this.groupName,
    required this.isGuest,
  });

  factory _MyPlayerItem.fromJson(Map<String, dynamic> j) => _MyPlayerItem(
        playerId: j['playerId'] as String? ?? '',
        userId: j['userId'] as String?,
        groupId: j['groupId'] as String? ?? '',
        playerName: j['playerName'] as String? ?? '',
        isGoalkeeper: j['isGoalkeeper'] as bool? ?? false,
        skillPoints: j['skillPoints'] as int? ?? 0,
        status: j['status'] as int? ?? 1,
        groupName: j['groupName'] as String? ?? '',
        isGuest: j['isGuest'] as bool? ?? false,
      );
}

class _UserResult {
  final String id;
  final String userName;
  final String firstName;
  final String lastName;
  final String email;

  const _UserResult({
    required this.id,
    required this.userName,
    required this.firstName,
    required this.lastName,
    required this.email,
  });

  factory _UserResult.fromJson(Map<String, dynamic> j) => _UserResult(
        id: j['id'] as String? ?? '',
        userName: j['userName'] as String? ?? '',
        firstName: j['firstName'] as String? ?? '',
        lastName: j['lastName'] as String? ?? '',
        email: j['email'] as String? ?? '',
      );

  String get fullName => '$firstName $lastName'.trim();
}

// ─────────────────────────────────────────────────────────────────────────────
// Providers
// ─────────────────────────────────────────────────────────────────────────────

final _dioProv = Provider<Dio>((ref) => ref.watch(dioProvider));

// ─────────────────────────────────────────────────────────────────────────────
// Page
// ─────────────────────────────────────────────────────────────────────────────

class GroupsPage extends ConsumerStatefulWidget {
  const GroupsPage({super.key});

  @override
  ConsumerState<GroupsPage> createState() => _GroupsPageState();
}

// payment badge record
typedef _PaymentBadge = ({int pendingMonths, int pendingExtras});

class _GroupsPageState extends ConsumerState<GroupsPage> {
  List<_MyPlayerItem> _myPlayers = [];
  bool _mineLoading = true;

  String? _expandedGroupId;
  _GroupDto? _group;
  bool _groupLoading = false;
  String? _groupError;

  // playerId → pending counts (only populated for financeiros)
  Map<String, _PaymentBadge> _paymentMap = {};

  Dio get _dio => ref.read(_dioProv);

  static dynamic _unwrap(dynamic data) {
    if (data is Map && data.containsKey('data')) return data['data'];
    return data;
  }

  List<Map<String, String>> get _myGroups {
    final seen = <String>{};
    final result = <Map<String, String>>[];
    for (final p in _myPlayers) {
      if (seen.add(p.groupId)) {
        result.add({
          'groupId': p.groupId,
          'groupName': p.groupName,
        });
      }
    }
    return result;
  }

  _MyPlayerItem? get _myPlayerInExpanded =>
      _expandedGroupId == null
          ? null
          : _myPlayers.where((p) => p.groupId == _expandedGroupId).firstOrNull;

  String get _activePlayerId => _myPlayerInExpanded?.playerId ?? '';

  bool _isGroupAdmin(String groupId) {
    final account = ref.read(accountStoreProvider).activeAccount;
    if (account == null) return false;
    return account.isAdmin || account.isGroupAdmin(groupId);
  }

  bool _isGroupFinanceiro(String groupId) {
    final account = ref.read(accountStoreProvider).activeAccount;
    if (account == null) return false;
    return account.isAdmin || account.isGroupFinanceiro(groupId);
  }

  Future<void> _loadPaymentData(String groupId) async {
    // Only financeiros/admins see payment badges
    if (!_isGroupFinanceiro(groupId)) {
      if (mounted) setState(() => _paymentMap = {});
      return;
    }

    final year = DateTime.now().year;
    final currentMonth = DateTime.now().month;

    try {
      final results = await Future.wait([
        _dio.get(ApiConstants.monthlyGrid(groupId, year)),
        _dio.get(ApiConstants.extraCharges(groupId)),
      ]);

      final gridRaw   = _unwrap(results[0].data);
      final extrasRaw = _unwrap(results[1].data) as List? ?? [];
      final grid      = gridRaw is Map<String, dynamic> ? gridRaw : <String, dynamic>{};

      final hasMonthlyFee = (grid['monthlyFee'] as num? ?? 0) > 0;
      final map = <String, _PaymentBadge>{};

      // ── monthly grid rows ──
      for (final row in (grid['players'] as List? ?? [])) {
        final r = row as Map<String, dynamic>;
        final playerId   = r['playerId'] as String? ?? '';
        final joinedYear = r['joinedYear'] as int? ?? 0;
        final joinedMonth = r['joinedMonth'] as int? ?? 1;

        int pendingMonths = 0;
        if (hasMonthlyFee) {
          for (final m in (r['months'] as List? ?? [])) {
            final month = m as Map<String, dynamic>;
            final mn = month['month'] as int? ?? 0;
            if (mn > currentMonth) continue;
            if (joinedYear == year && mn < joinedMonth) continue;
            if ((month['status'] as int? ?? 0) == 0) pendingMonths++;
          }
        }
        map[playerId] = (pendingMonths: pendingMonths, pendingExtras: 0);
      }

      // ── extra charges ──
      for (final charge in extrasRaw) {
        final c = charge as Map<String, dynamic>;
        if (c['isCancelled'] == true) continue;
        for (final payment in (c['payments'] as List? ?? [])) {
          final p = payment as Map<String, dynamic>;
          if ((p['status'] as int? ?? -1) != 0) continue;
          final pid = p['playerId'] as String? ?? '';
          final existing = map[pid];
          if (existing != null) {
            map[pid] = (pendingMonths: existing.pendingMonths, pendingExtras: existing.pendingExtras + 1);
          } else {
            map[pid] = (pendingMonths: 0, pendingExtras: 1);
          }
        }
      }

      if (mounted) setState(() => _paymentMap = map);
    } catch (_) {
      // silencioso — badges simplesmente não aparecem
      if (mounted) setState(() => _paymentMap = {});
    }
  }

  List<_PlayerDto> get _activePlayers =>
      _group?.players.where((p) => p.status == 1 && !p.isGuest).toList() ?? [];

  List<_PlayerDto> get _guestPlayers =>
      _group?.players.where((p) => p.status == 1 && p.isGuest).toList() ?? [];

  List<_PlayerDto> get _inactivePlayers {
    final account = ref.read(accountStoreProvider).activeAccount;
    if (account == null) return [];
    final isAdminHere = account.isAdmin ||
        (_expandedGroupId != null && account.isGroupAdmin(_expandedGroupId!));
    if (!isAdminHere) return [];
    return _group?.players.where((p) => p.status != 1).toList() ?? [];
  }

  List<_PlayerDto> get _sortedActivePlayers {
    final sorted = List<_PlayerDto>.from(_activePlayers);
    sorted.sort((a, b) {
      if (a.id == _activePlayerId) return -1;
      if (b.id == _activePlayerId) return 1;
      return 0;
    });
    return sorted;
  }

  Set<String> get _existingUserIds => (_group?.players ?? [])
      .where((p) => !p.isGuest && p.userId != null)
      .map((p) => p.userId!)
      .toSet();

  @override
  void initState() {
    super.initState();
    _loadMine().then((_) {
      if (_myGroups.length == 1) {
        _openGroup(_myGroups.first['groupId']!);
      }
    });
  }

  Future<void> _loadMine() async {
    setState(() => _mineLoading = true);
    try {
      final res = await _dio.get(ApiConstants.playersMe);
      final raw = _unwrap(res.data);
      setState(() {
        _myPlayers = (raw as List? ?? const [])
            .map((e) => _MyPlayerItem.fromJson(e as Map<String, dynamic>))
            .toList();
      });
    } catch (_) {
      setState(() => _myPlayers = []);
    } finally {
      if (mounted) setState(() => _mineLoading = false);
    }
  }

  Future<void> _openGroup(String groupId) async {
    setState(() {
      _expandedGroupId = groupId;
      _groupLoading = true;
      _groupError = null;
      _group = null;
    });

    try {
      final res = await _dio.get(ApiConstants.groupById(groupId));
      final raw = _unwrap(res.data);
      setState(() => _group = _GroupDto.fromJson(raw as Map<String, dynamic>));
      // Load payment badges in parallel (silently)
      _loadPaymentData(groupId);
    } catch (_) {
      setState(() {
        _groupError = 'Não foi possível carregar os dados da patota.';
      });
    } finally {
      if (mounted) setState(() => _groupLoading = false);
    }
  }

  void _toggleGroup(String groupId) {
    if (_expandedGroupId == groupId) {
      setState(() {
        _expandedGroupId = null;
        _group = null;
        _groupError = null;
        _paymentMap = {};
      });
      return;
    }
    _openGroup(groupId);
  }

  void _reloadGroup() {
    final id = _expandedGroupId;
    if (id != null) {
      _openGroup(id);
    }
  }

  Future<void> _handleLeave() async {
    if (_activePlayerId.isEmpty) return;
    try {
      await _dio.post(ApiConstants.playerLeaveGroup(_activePlayerId));
      await _loadMine();
      _reloadGroup();
    } catch (_) {}
  }

  void _showAddGuest(String groupId) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddGuestSheet(
        onSubmit: (name, isGoalkeeper, starRating) async {
          await _dio.post(
            ApiConstants.playersCreate,
            data: {
              'name': name,
              'groupId': groupId,
              'skillPoints': 0,
              'isGoalkeeper': isGoalkeeper,
              'isGuest': true,
              'status': 1,
              if (starRating != null) 'guestStarRating': starRating,
            },
          );
          _reloadGroup();
        },
      ),
    );
  }

  void _showInvite(String groupId) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _InviteSheet(
        dio: _dio,
        groupId: groupId,
        existingUserIds: _existingUserIds,
        onInvited: () async => _reloadGroup(),
      ),
    );
  }

  void _showEditPlayer(_PlayerDto player) {
    final isAdminHere =
        _expandedGroupId != null ? _isGroupAdmin(_expandedGroupId!) : false;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EditPlayerSheet(
        player: player,
        isAdmin: isAdminHere,
        onSaved: (dto) async {
          await _dio.put(ApiConstants.playerOps(player.id), data: dto);
          _reloadGroup();
        },
      ),
    );
  }

  void _showLeaveConfirm() {
    showDialog<void>(
      context: context,
      builder: (_) => _LeaveConfirmDialog(onConfirm: _handleLeave),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_mineLoading)
            _buildLoadingHeader()
          else if (_myGroups.isEmpty)
            _buildEmptyHeader()
          else if (_myGroups.length == 1)
            _buildSingleGroup(isDark)
          else
            _buildAccordion(isDark),
        ],
      ),
    );
  }

  Widget _buildLoadingHeader() {
    return const _GradientCard(
      child: Row(
        children: [
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white70),
          ),
          SizedBox(width: 12),
          Text(
            'Carregando patotas...',
            style: TextStyle(fontSize: 14, color: Colors.white70),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyHeader() {
    return const _GradientCard(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.group_outlined, size: 36, color: Colors.white38),
          SizedBox(height: 12),
          Text(
            'Você não faz parte de nenhuma patota.',
            style: TextStyle(fontSize: 14, color: Colors.white60),
          ),
        ],
      ),
    );
  }

  Widget _buildSingleGroup(bool isDark) {
    final g = _myGroups.first;
    final groupId = g['groupId']!;
    final groupName = _group?.name ?? g['groupName']!;
    final isAdminHere = _isGroupAdmin(groupId);
    final account = ref.watch(accountStoreProvider).activeAccount;
    final isCreator = _group?.createdByUserId == account?.userId;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _GradientCard(
          dotPattern: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _GroupAvatar(
                    letter: groupName.isEmpty ? 'G' : groupName.characters.first,
                    size: 48,
                    radius: 16,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          groupName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _groupLoading
                              ? 'Carregando...'
                              : _group != null
                                  ? '${_activePlayers.length} mensalista${_activePlayers.length != 1 ? 's' : ''} · ${_guestPlayers.length} convidado${_guestPlayers.length != 1 ? 's' : ''}'
                                  : '',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 13, color: Colors.white60),
                        ),
                      ],
                    ),
                  ),
                  if (_groupLoading)
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white70,
                      ),
                    ),
                ],
              ),
              if (!_groupLoading && _group != null) ...[
                const SizedBox(height: 16),
                _HeaderButtons(
                  isAdminHere: isAdminHere,
                  isCreator: isCreator,
                  myPlayer: _myPlayerInExpanded,
                  activePlayerId: _activePlayerId,
                  onAddGuest: () => _showAddGuest(groupId),
                  onInvite: () => _showInvite(groupId),
                  onLeave: _showLeaveConfirm,
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.black.withValues(alpha: 0.07),
            ),
            boxShadow: isDark
                ? null
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
          ),
          padding: const EdgeInsets.all(20),
          child: _GroupContent(
            group: _group,
            groupLoading: _groupLoading,
            groupError: _groupError,
            activePlayers: _sortedActivePlayers,
            guestPlayers: _guestPlayers,
            inactivePlayers: _inactivePlayers,
            activePlayerId: _activePlayerId,
            isAdminHere: isAdminHere,
            isFinanceiroHere: _expandedGroupId != null
                ? _isGroupFinanceiro(_expandedGroupId!)
                : false,
            paymentMap: _paymentMap,
            isDark: isDark,
            onEditPlayer: _showEditPlayer,
          ),
        ),
      ],
    );
  }

  Widget _buildAccordion(bool isDark) {
    final account = ref.watch(accountStoreProvider).activeAccount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _GradientCard(
          dotPattern: true,
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                ),
                child: const Icon(
                  Icons.group_outlined,
                  size: 22,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Minhas Patotas',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      '${_myGroups.length} patotas',
                      style: const TextStyle(fontSize: 13, color: Colors.white60),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        ..._myGroups.map((g) {
          final groupId = g['groupId']!;
          final groupName = g['groupName']!;
          final isExpanded = _expandedGroupId == groupId;
          final isAdminHere = _isGroupAdmin(groupId);
          final myPlayer =
              _myPlayers.where((p) => p.groupId == groupId).firstOrNull;
          final isCreator =
              isExpanded && _group?.createdByUserId == account?.userId;

          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _AccordionItem(
              groupName: groupName,
              isExpanded: isExpanded,
              isAdminHere: isAdminHere,
              isCreator: isCreator,
              myPlayer: myPlayer,
              isDark: isDark,
              onToggle: () => _toggleGroup(groupId),
              onAddGuest: () => _showAddGuest(groupId),
              onInvite: () => _showInvite(groupId),
              onLeave: _showLeaveConfirm,
              groupContent: isExpanded
                  ? _GroupContent(
                      group: _group,
                      groupLoading: _groupLoading,
                      groupError: _groupError,
                      activePlayers: _sortedActivePlayers,
                      guestPlayers: _guestPlayers,
                      inactivePlayers: _inactivePlayers,
                      activePlayerId: _activePlayerId,
                      isAdminHere: isAdminHere,
                      isFinanceiroHere: _isGroupFinanceiro(groupId),
                      paymentMap: _paymentMap,
                      isDark: isDark,
                      onEditPlayer: _showEditPlayer,
                    )
                  : null,
            ),
          );
        }),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Header Buttons
// ─────────────────────────────────────────────────────────────────────────────

class _HeaderButtons extends StatelessWidget {
  final bool isAdminHere;
  final bool isCreator;
  final _MyPlayerItem? myPlayer;
  final String activePlayerId;
  final VoidCallback onAddGuest;
  final VoidCallback onInvite;
  final VoidCallback onLeave;

  const _HeaderButtons({
    required this.isAdminHere,
    required this.isCreator,
    required this.myPlayer,
    required this.activePlayerId,
    required this.onAddGuest,
    required this.onInvite,
    required this.onLeave,
  });

  @override
  Widget build(BuildContext context) {
    final showLeave = !isAdminHere &&
        activePlayerId.isNotEmpty &&
        myPlayer != null &&
        !myPlayer!.isGuest;
    final showCreatorLeave = isAdminHere && isCreator;

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        if (isAdminHere) ...[
          _DarkBtn(
            label: 'Convidado',
            icon: Icons.add,
            style: _DarkBtnStyle.ghost,
            onTap: onAddGuest,
          ),
          _DarkBtn(
            label: 'Convidar',
            icon: Icons.person_add_alt_1_outlined,
            style: _DarkBtnStyle.solid,
            onTap: onInvite,
          ),
        ],
        if (showLeave || showCreatorLeave)
          _DarkBtn(
            label: 'Sair',
            icon: Icons.logout,
            style: _DarkBtnStyle.danger,
            onTap: onLeave,
          ),
      ],
    );
  }
}

enum _DarkBtnStyle { ghost, solid, danger }

class _DarkBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final _DarkBtnStyle style;
  final VoidCallback onTap;

  const _DarkBtn({
    required this.label,
    required this.icon,
    required this.style,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    late final Color bg;
    late final Color borderColor;
    late final Color textColor;

    switch (style) {
      case _DarkBtnStyle.ghost:
        bg = Colors.white.withValues(alpha: 0.10);
        borderColor = Colors.white.withValues(alpha: 0.20);
        textColor = Colors.white;
        break;
      case _DarkBtnStyle.solid:
        bg = Colors.white;
        borderColor = Colors.transparent;
        textColor = const Color(0xFF0F172A);
        break;
      case _DarkBtnStyle.danger:
        bg = const Color(0xFFEF4444).withValues(alpha: 0.20);
        borderColor = const Color(0xFFF87171).withValues(alpha: 0.35);
        textColor = const Color(0xFFFCA5A5);
        break;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15, color: textColor),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Accordion
// ─────────────────────────────────────────────────────────────────────────────

class _AccordionItem extends StatelessWidget {
  final String groupName;
  final bool isExpanded;
  final bool isAdminHere;
  final bool isCreator;
  final _MyPlayerItem? myPlayer;
  final bool isDark;
  final VoidCallback onToggle;
  final VoidCallback onAddGuest;
  final VoidCallback onInvite;
  final VoidCallback onLeave;
  final Widget? groupContent;

  const _AccordionItem({
    required this.groupName,
    required this.isExpanded,
    required this.isAdminHere,
    required this.isCreator,
    required this.myPlayer,
    required this.isDark,
    required this.onToggle,
    required this.onAddGuest,
    required this.onInvite,
    required this.onLeave,
    this.groupContent,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.06);

    final showLeave =
        !isAdminHere && myPlayer != null && !myPlayer!.isGuest && isExpanded;
    final showCreatorLeave = isAdminHere && isCreator && isExpanded;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
        boxShadow: isExpanded && !isDark
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Column(
        children: [
          InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      _MiniGroupAvatar(
                        letter: groupName.isEmpty ? 'G' : groupName.characters.first,
                        isExpanded: isExpanded,
                        isDark: isDark,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              groupName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                              ),
                            ),
                            if (isAdminHere)
                              Text(
                                'Você administra',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDark
                                      ? const Color(0xFF64748B)
                                      : const Color(0xFF94A3B8),
                                ),
                              ),
                          ],
                        ),
                      ),
                      AnimatedRotation(
                        turns: isExpanded ? 0.5 : 0.0,
                        duration: const Duration(milliseconds: 180),
                        child: Icon(
                          Icons.keyboard_arrow_down,
                          size: 20,
                          color: isDark
                              ? const Color(0xFF64748B)
                              : const Color(0xFF94A3B8),
                        ),
                      ),
                    ],
                  ),
                  if (isExpanded) ...[
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          if (isAdminHere) ...[
                            _SmallBtn(
                              label: 'Convidado',
                              icon: Icons.add,
                              variant: _SmallBtnVariant.secondary,
                              onTap: onAddGuest,
                            ),
                            _SmallBtn(
                              label: 'Convidar',
                              icon: Icons.person_add_alt_1_outlined,
                              variant: _SmallBtnVariant.primary,
                              onTap: onInvite,
                            ),
                          ],
                          if (showLeave || showCreatorLeave)
                            _SmallBtn(
                              label: 'Sair',
                              icon: Icons.logout,
                              variant: _SmallBtnVariant.danger,
                              onTap: onLeave,
                            ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (isExpanded && groupContent != null)
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: borderColor)),
              ),
              padding: const EdgeInsets.all(16),
              child: groupContent,
            ),
        ],
      ),
    );
  }
}

class _MiniGroupAvatar extends StatelessWidget {
  final String letter;
  final bool isExpanded;
  final bool isDark;

  const _MiniGroupAvatar({
    required this.letter,
    required this.isExpanded,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final bg = isExpanded
        ? (isDark ? Colors.white : const Color(0xFF0F172A))
        : (isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9));

    final fg = isExpanded
        ? (isDark ? const Color(0xFF0F172A) : Colors.white)
        : (isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569));

    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      alignment: Alignment.center,
      child: Text(
        letter.toUpperCase(),
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w900,
          color: fg,
        ),
      ),
    );
  }
}

enum _SmallBtnVariant { primary, secondary, danger }

class _SmallBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final _SmallBtnVariant variant;
  final VoidCallback onTap;

  const _SmallBtn({
    required this.label,
    required this.icon,
    required this.variant,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    late final Color bg;
    late final Color textColor;
    late final Color borderColor;

    switch (variant) {
      case _SmallBtnVariant.primary:
        bg = const Color(0xFF0F172A);
        textColor = Colors.white;
        borderColor = Colors.transparent;
        break;
      case _SmallBtnVariant.secondary:
        bg = isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9);
        textColor = isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569);
        borderColor = isDark ? const Color(0xFF475569) : const Color(0xFFE2E8F0);
        break;
      case _SmallBtnVariant.danger:
        bg = Colors.transparent;
        textColor = const Color(0xFFE11D48);
        borderColor = const Color(0xFFFDA4AF);
        break;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: borderColor),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 13, color: textColor),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: textColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Group Content
// ─────────────────────────────────────────────────────────────────────────────

class _GroupContent extends StatelessWidget {
  final _GroupDto? group;
  final bool groupLoading;
  final String? groupError;
  final List<_PlayerDto> activePlayers;
  final List<_PlayerDto> guestPlayers;
  final List<_PlayerDto> inactivePlayers;
  final String activePlayerId;
  final bool isAdminHere;
  final bool isFinanceiroHere;
  final Map<String, _PaymentBadge> paymentMap;
  final bool isDark;
  final void Function(_PlayerDto) onEditPlayer;

  const _GroupContent({
    required this.group,
    required this.groupLoading,
    required this.groupError,
    required this.activePlayers,
    required this.guestPlayers,
    required this.inactivePlayers,
    required this.activePlayerId,
    required this.isAdminHere,
    required this.isFinanceiroHere,
    required this.paymentMap,
    required this.isDark,
    required this.onEditPlayer,
  });

  @override
  Widget build(BuildContext context) {
    if (groupError != null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF1F2),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFFECACA)),
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline, size: 15, color: Color(0xFFBE123C)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                groupError!,
                style: const TextStyle(fontSize: 13, color: Color(0xFFBE123C)),
              ),
            ),
          ],
        ),
      );
    }

    if (groupLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 8),
            Text('Carregando...'),
          ],
        ),
      );
    }

    if (group == null) return const SizedBox.shrink();

    if (activePlayers.isEmpty && guestPlayers.isEmpty && inactivePlayers.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Column(
          children: [
            Icon(
              Icons.group_outlined,
              size: 32,
              color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.2),
            ),
            const SizedBox(height: 8),
            Text(
              'Nenhum jogador nesta patota.',
              style: TextStyle(
                fontSize: 14,
                color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (activePlayers.isEmpty)
          Text(
            'Nenhum mensalista ativo.',
            style: TextStyle(
              fontSize: 14,
              fontStyle: FontStyle.italic,
              color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
            ),
          )
        else
          _PlayerSection(
            label: 'Mensalistas',
            count: activePlayers.length,
            iconData: Icons.check,
            badgeBg: const Color(0xFF10B981),
            badgeTextColor: const Color(0xFF065F46),
            badgeLabelBg: const Color(0xFFD1FAE5),
            players: activePlayers,
            activePlayerId: activePlayerId,
            isAdminHere: isAdminHere,
            isFinanceiroHere: isFinanceiroHere,
            paymentMap: paymentMap,
            dim: false,
            isDark: isDark,
            onEdit: onEditPlayer,
          ),
        if (guestPlayers.isNotEmpty) ...[
          const SizedBox(height: 20),
          _PlayerSection(
            label: 'Convidados',
            count: guestPlayers.length,
            iconData: Icons.person_add_alt_1_outlined,
            badgeBg: const Color(0xFFF59E0B),
            badgeTextColor: const Color(0xFF92400E),
            badgeLabelBg: const Color(0xFFFEF3C7),
            players: guestPlayers,
            activePlayerId: activePlayerId,
            isAdminHere: isAdminHere,
            isFinanceiroHere: isFinanceiroHere,
            paymentMap: paymentMap,
            dim: false,
            isDark: isDark,
            onEdit: onEditPlayer,
          ),
        ],
        if (inactivePlayers.isNotEmpty) ...[
          const SizedBox(height: 20),
          _PlayerSection(
            label: 'Inativos',
            count: inactivePlayers.length,
            iconData: Icons.close,
            badgeBg: const Color(0xFF94A3B8),
            badgeTextColor: isDark
                ? const Color(0xFFCBD5E1)
                : const Color(0xFF64748B),
            badgeLabelBg:
                isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
            players: inactivePlayers,
            activePlayerId: activePlayerId,
            isAdminHere: isAdminHere,
            isFinanceiroHere: isFinanceiroHere,
            paymentMap: paymentMap,
            dim: true,
            isDark: isDark,
            onEdit: onEditPlayer,
          ),
        ],
      ],
    );
  }
}

class _PlayerSection extends StatelessWidget {
  final String label;
  final int count;
  final IconData iconData;
  final Color badgeBg;
  final Color badgeTextColor;
  final Color badgeLabelBg;
  final List<_PlayerDto> players;
  final String activePlayerId;
  final bool isAdminHere;
  final bool isFinanceiroHere;
  final Map<String, _PaymentBadge> paymentMap;
  final bool dim;
  final bool isDark;
  final void Function(_PlayerDto) onEdit;

  const _PlayerSection({
    required this.label,
    required this.count,
    required this.iconData,
    required this.badgeBg,
    required this.badgeTextColor,
    required this.badgeLabelBg,
    required this.players,
    required this.activePlayerId,
    required this.isAdminHere,
    required this.isFinanceiroHere,
    required this.paymentMap,
    required this.dim,
    required this.isDark,
    required this.onEdit,
  });

  int _columnsForWidth(double width) {
    if (width >= 1200) return 4;
    if (width >= 900) return 3;
    if (width >= 560) return 2;
    return 1;
    }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 8.0;
        final cols = _columnsForWidth(constraints.maxWidth);
        final cardWidth =
            (constraints.maxWidth - ((cols - 1) * spacing)) / cols;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: badgeBg,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(iconData, size: 11, color: Colors.white),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    label.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                      color: isDark
                          ? const Color(0xFF94A3B8)
                          : const Color(0xFF475569),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: badgeLabelBg,
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Text(
                    '$count',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: badgeTextColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: spacing,
              runSpacing: spacing,
              children: players
                  .map(
                    (p) => SizedBox(
                      width: cardWidth,
                      child: _PlayerCard(
                        player: p,
                        activePlayerId: activePlayerId,
                        isAdminHere: isAdminHere,
                        pmt: isFinanceiroHere ? paymentMap[p.id] : null,
                        dim: dim,
                        isDark: isDark,
                        onEdit: onEdit,
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
        );
      },
    );
  }
}

class _PlayerCard extends StatelessWidget {
  final _PlayerDto player;
  final String activePlayerId;
  final bool isAdminHere;
  final _PaymentBadge? pmt;   // null = not a financeiro or no data
  final bool dim;
  final bool isDark;
  final void Function(_PlayerDto) onEdit;

  const _PlayerCard({
    required this.player,
    required this.activePlayerId,
    required this.isAdminHere,
    required this.dim,
    required this.isDark,
    required this.onEdit,
    this.pmt,
  });

  @override
  Widget build(BuildContext context) {
    final isMe = player.id == activePlayerId;
    final canEdit = isAdminHere || isMe;

    final parts = player.name.trim().split(RegExp(r'\s+'));
    final initials = parts.take(2).map((w) => w[0]).join().toUpperCase();

    Color avatarBg;
    Color avatarFg;

    if (isMe) {
      avatarBg = const Color(0xFF059669);
      avatarFg = Colors.white;
    } else if (player.isGuest) {
      avatarBg = const Color(0xFFFEF3C7);
      avatarFg = const Color(0xFFD97706);
    } else {
      avatarBg = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
      avatarFg = isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569);
    }

    final borderColor = isMe
        ? const Color(0xFF6EE7B7)
        : (isDark
            ? Colors.white.withValues(alpha: 0.08)
            : const Color(0xFFE2E8F0));

    return Opacity(
      opacity: dim ? 0.5 : 1.0,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0F172A) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor, width: isMe ? 1.5 : 1),
          boxShadow: isDark
              ? null
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: avatarBg,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    initials,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: avatarFg,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              player.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: isDark
                                    ? Colors.white
                                    : const Color(0xFF0F172A),
                              ),
                            ),
                          ),
                          if (player.isGoalkeeper) ...[
                            const SizedBox(width: 4),
                            Icon(
                              Icons.shield_outlined,
                              size: 13,
                              color: isDark
                                  ? const Color(0xFF64748B)
                                  : const Color(0xFF94A3B8),
                            ),
                          ],
                        ],
                      ),
                      if (player.userName != null && player.userName!.isNotEmpty)
                        Text(
                          '@${player.userName}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark
                                ? const Color(0xFF64748B)
                                : const Color(0xFF94A3B8),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isMe)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: const Text(
                          'Você',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    if (canEdit) ...[
                      const SizedBox(width: 4),
                      InkWell(
                        onTap: () => onEdit(player),
                        borderRadius: BorderRadius.circular(8),
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: Icon(
                            Icons.edit_outlined,
                            size: 13,
                            color: isDark
                                ? const Color(0xFF64748B)
                                : const Color(0xFF94A3B8),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
            // ── star rating (guest + admin) ──
            if (player.isGuest &&
                player.guestStarRating != null &&
                isAdminHere) ...[
              const SizedBox(height: 8),
              _StarDisplay(value: player.guestStarRating!),
            ],
            // ── payment badge (financeiro only) ──
            if (pmt != null) ...[
              const SizedBox(height: 8),
              _PaymentBadgeWidget(pmt: pmt!),
            ],
          ],
        ),
      ),
    );
  }
}

class _PaymentBadgeWidget extends StatelessWidget {
  final _PaymentBadge pmt;
  const _PaymentBadgeWidget({required this.pmt});

  @override
  Widget build(BuildContext context) {
    final total = pmt.pendingMonths + pmt.pendingExtras;
    if (total == 0) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFECFDF5),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFBBF7D0)),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle_outline, size: 11, color: Color(0xFF10B981)),
            SizedBox(width: 4),
            Text(
              'Em dia',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: Color(0xFF065F46),
              ),
            ),
          ],
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1F2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFFECACA)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 11, color: Color(0xFFBE123C)),
          const SizedBox(width: 4),
          Text(
            '$total pendência${total != 1 ? 's' : ''}',
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: Color(0xFFBE123C),
            ),
          ),
        ],
      ),
    );
  }
}

class _StarDisplay extends StatelessWidget {
  final int value;

  const _StarDisplay({required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(
        5,
        (i) => Text(
          '★',
          style: TextStyle(
            fontSize: 13,
            color:
                i < value ? const Color(0xFFFBBF24) : const Color(0xFFE2E8F0),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared UI
// ─────────────────────────────────────────────────────────────────────────────

class _GradientCard extends StatelessWidget {
  final Widget child;
  final bool dotPattern;

  const _GradientCard({
    required this.child,
    this.dotPattern = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF1E293B), Color(0xFF0F172A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      // CustomPaint like this gives the child proper tight constraints
      // (unlike Stack which passes loose constraints to non-positioned children)
      child: dotPattern
          ? CustomPaint(painter: _DotPatternPainter(), child: child)
          : child,
    );
  }
}

class _DotPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.06)
      ..style = PaintingStyle.fill;

    const spacing = 24.0;
    for (double x = 0; x < size.width; x += spacing) {
      for (double y = 0; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), 1, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _GroupAvatar extends StatelessWidget {
  final String letter;
  final double size;
  final double radius;

  const _GroupAvatar({
    required this.letter,
    this.size = 36,
    this.radius = 12,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      alignment: Alignment.center,
      child: Text(
        letter.toUpperCase(),
        style: TextStyle(
          fontSize: size * 0.35,
          fontWeight: FontWeight.w900,
          color: Colors.white,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Modals
// ─────────────────────────────────────────────────────────────────────────────

class _ModalSheet extends StatelessWidget {
  final Widget child;
  final bool isDark;

  const _ModalSheet({required this.child, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.of(context).viewInsets;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 120),
      padding: EdgeInsets.only(bottom: viewInsets.bottom),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.92,
        ),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(top: false, child: child),
      ),
    );
  }
}

class _SheetHeader extends StatelessWidget {
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String title;
  final String subtitle;
  final bool isDark;

  const _SheetHeader({
    required this.icon,
    required this.iconBg,
    required this.title,
    required this.subtitle,
    required this.isDark,
    this.iconColor = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.06),
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 17, color: iconColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark
                        ? const Color(0xFF94A3B8)
                        : const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;
  final bool isDark;

  const _FieldLabel(this.text, {required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF374151),
      ),
    );
  }
}

class _AppInput extends StatelessWidget {
  final TextEditingController controller;
  final String? hint;
  final bool enabled;
  final bool isDark;
  final ValueChanged<String>? onSubmitted;

  const _AppInput({
    required this.controller,
    required this.enabled,
    required this.isDark,
    this.hint,
    this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      enabled: enabled,
      onSubmitted: onSubmitted,
      maxLines: 1,
      style: TextStyle(
        color: isDark ? Colors.white : const Color(0xFF0F172A),
      ),
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : const Color(0xFFE2E8F0),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : const Color(0xFFE2E8F0),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF2563EB)),
        ),
      ),
    );
  }
}

class _PrimaryBtn extends StatelessWidget {
  final String label;
  final bool loading;
  final VoidCallback onTap;

  const _PrimaryBtn({
    required this.label,
    required this.loading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 46,
      child: ElevatedButton(
        onPressed: loading ? null : onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF0F172A),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: loading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : Text(
                label,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
      ),
    );
  }
}

class _Toggle extends StatelessWidget {
  final bool value;
  final ValueChanged<bool>? onChanged;

  const _Toggle({
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Switch(value: value, onChanged: onChanged);
  }
}

class _StarRatingWidget extends StatelessWidget {
  final int? value;
  final bool disabled;
  final ValueChanged<int> onChanged;

  const _StarRatingWidget({
    required this.value,
    required this.disabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      children: List.generate(
        5,
        (index) {
          final star = index + 1;
          final selected = value != null && star <= value!;
          return InkWell(
            onTap: disabled ? null : () => onChanged(star),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.all(2),
              child: Text(
                '★',
                style: TextStyle(
                  fontSize: 24,
                  color:
                      selected ? const Color(0xFFFBBF24) : const Color(0xFFCBD5E1),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Add Guest
// ─────────────────────────────────────────────────────────────────────────────

class _AddGuestSheet extends StatefulWidget {
  final Future<void> Function(String name, bool isGoalkeeper, int? starRating)
      onSubmit;

  const _AddGuestSheet({required this.onSubmit});

  @override
  State<_AddGuestSheet> createState() => _AddGuestSheetState();
}

class _AddGuestSheetState extends State<_AddGuestSheet> {
  final _nameCtrl = TextEditingController();
  bool _isGoalkeeper = false;
  int? _starRating;
  bool _loading = false;
  String? _err;

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      setState(() => _err = 'Nome é obrigatório.');
      return;
    }

    setState(() {
      _loading = true;
      _err = null;
    });

    try {
      await widget.onSubmit(name, _isGoalkeeper, _starRating);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() => _err = _extractError(e));
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return _ModalSheet(
      isDark: isDark,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _SheetHeader(
              icon: Icons.add,
              iconBg: const Color(0xFFF59E0B),
              title: 'Adicionar convidado',
              subtitle: 'Sem conta no sistema',
              isDark: isDark,
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _FieldLabel('Nome do convidado', isDark: isDark),
                  const SizedBox(height: 6),
                  _AppInput(
                    controller: _nameCtrl,
                    hint: 'Ex: Zé da Pelada',
                    enabled: !_loading,
                    isDark: isDark,
                    onSubmitted: (_) => _submit(),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      _Toggle(
                        value: _isGoalkeeper,
                        onChanged: _loading
                            ? null
                            : (v) => setState(() => _isGoalkeeper = v),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Goleiro',
                        style: TextStyle(
                          fontSize: 14,
                          color: isDark
                              ? const Color(0xFFE2E8F0)
                              : const Color(0xFF374151),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _FieldLabel('Nível estimado (opcional)', isDark: isDark),
                  const SizedBox(height: 8),
                  _StarRatingWidget(
                    value: _starRating,
                    disabled: _loading,
                    onChanged: (v) => setState(() => _starRating = v),
                  ),
                  if (_err != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _err!,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFFEF4444),
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  _PrimaryBtn(
                    label: _loading ? 'Adicionando...' : 'Adicionar à patota',
                    loading: _loading,
                    onTap: _submit,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Edit Player
// ─────────────────────────────────────────────────────────────────────────────

class _EditPlayerSheet extends StatefulWidget {
  final _PlayerDto player;
  final bool isAdmin;
  final Future<void> Function(Map<String, dynamic>) onSaved;

  const _EditPlayerSheet({
    required this.player,
    required this.isAdmin,
    required this.onSaved,
  });

  @override
  State<_EditPlayerSheet> createState() => _EditPlayerSheetState();
}

class _EditPlayerSheetState extends State<_EditPlayerSheet> {
  late final TextEditingController _nameCtrl;
  late bool _isGuest;
  late bool _isActive;
  int? _starRating;
  bool _loading = false;
  String? _err;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.player.name);
    _isGuest = widget.player.isGuest;
    _isActive = widget.player.status == 1;
    _starRating = widget.player.guestStarRating;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();

    if (name.isEmpty) {
      setState(() => _err = 'Nome é obrigatório.');
      return;
    }

    setState(() {
      _loading = true;
      _err = null;
    });

    try {
      final dto = <String, dynamic>{
        'name': name,
      };

      if (widget.isAdmin) {
        dto['status'] = _isActive ? 1 : 2;
        dto['isGuest'] = _isGuest;
        if (_isGuest && _starRating != null) {
          dto['guestStarRating'] = _starRating;
        }
      }

      await widget.onSaved(dto);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() => _err = _extractError(e));
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return _ModalSheet(
      isDark: isDark,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _SheetHeader(
              icon: Icons.edit_outlined,
              iconBg: isDark ? Colors.white : const Color(0xFF0F172A),
              iconColor: isDark ? const Color(0xFF0F172A) : Colors.white,
              title: 'Editar jogador',
              subtitle: widget.player.name,
              isDark: isDark,
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _FieldLabel('Nome', isDark: isDark),
                  const SizedBox(height: 6),
                  _AppInput(
                    controller: _nameCtrl,
                    enabled: !_loading,
                    isDark: isDark,
                    onSubmitted: (_) => _save(),
                  ),
                  if (widget.isAdmin) ...[
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        _Toggle(
                          value: _isActive,
                          onChanged: _loading
                              ? null
                              : (v) => setState(() => _isActive = v),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Ativo',
                          style: TextStyle(
                            fontSize: 14,
                            color: isDark
                                ? const Color(0xFFE2E8F0)
                                : const Color(0xFF374151),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _Toggle(
                          value: _isGuest,
                          onChanged: _loading
                              ? null
                              : (v) => setState(() => _isGuest = v),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Convidado',
                          style: TextStyle(
                            fontSize: 14,
                            color: isDark
                                ? const Color(0xFFE2E8F0)
                                : const Color(0xFF374151),
                          ),
                        ),
                      ],
                    ),
                    if (_isGuest) ...[
                      const SizedBox(height: 16),
                      _FieldLabel('Nível estimado', isDark: isDark),
                      const SizedBox(height: 8),
                      _StarRatingWidget(
                        value: _starRating,
                        disabled: _loading,
                        onChanged: (v) => setState(() => _starRating = v),
                      ),
                    ],
                  ],
                  if (_err != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _err!,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFFEF4444),
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  _PrimaryBtn(
                    label: _loading ? 'Salvando...' : 'Salvar',
                    loading: _loading,
                    onTap: _save,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Invite
// ─────────────────────────────────────────────────────────────────────────────

class _InviteSheet extends StatefulWidget {
  final Dio dio;
  final String groupId;
  final Set<String> existingUserIds;
  final Future<void> Function() onInvited;

  const _InviteSheet({
    required this.dio,
    required this.groupId,
    required this.existingUserIds,
    required this.onInvited,
  });

  @override
  State<_InviteSheet> createState() => _InviteSheetState();
}

class _InviteSheetState extends State<_InviteSheet> {
  final _searchCtrl = TextEditingController();
  Timer? _debounce;
  bool _loading = false;
  bool _hasTried = false; // true after first search fired
  String? _err;
  List<_UserResult> _results = [];

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    _debounce?.cancel();
    final term = _searchCtrl.text.trim();
    if (term.length < 2) {
      setState(() {
        _results = [];
        _err = null;
        _hasTried = false;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 400), _search);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.removeListener(_onTextChanged);
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final term = _searchCtrl.text.trim();
    if (term.length < 2) return;

    setState(() {
      _loading = true;
      _err = null;
      _hasTried = true;
    });

    try {
      final res = await widget.dio.get(
        ApiConstants.usersListSearch(term, 20),
      );

      // Response envelope: { success, data: { page, pageSize, total, items: [...] } }
      final envelope = _GroupsPageState._unwrap(res.data);
      final items = (envelope is Map ? envelope['items'] : null) as List? ?? [];
      final list = items
          .map((e) => _UserResult.fromJson(e as Map<String, dynamic>))
          .toList();

      if (mounted) setState(() => _results = list);
    } catch (e) {
      if (mounted) setState(() => _err = _extractError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _invite(_UserResult user) async {
    setState(() {
      _loading = true;
      _err = null;
    });

    try {
      await widget.dio.post(
        ApiConstants.playersCreate,
        data: {
          'groupId': widget.groupId,
          'userId': user.id,
          'name': user.fullName.isEmpty ? user.userName : user.fullName,
          'isGuest': false,
          'status': 1,
          'skillPoints': 0,
          'isGoalkeeper': false,
        },
      );

      await widget.onInvited();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() => _err = _extractError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return _ModalSheet(
      isDark: isDark,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _SheetHeader(
            icon: Icons.person_add_alt_1_outlined,
            iconBg: const Color(0xFF0F172A),
            title: 'Convidar jogador',
            subtitle: 'Busque por nome, usuário ou email',
            isDark: isDark,
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                _AppInput(
                  controller: _searchCtrl,
                  hint: 'Pesquisar...',
                  enabled: !_loading,
                  isDark: isDark,
                ),
                if (_err != null) ...[
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      _err!,
                      style: const TextStyle(color: Color(0xFFEF4444)),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 360),
                  child: _loading
                      ? const Center(
                          child: Padding(
                            padding: EdgeInsets.all(20),
                            child: CircularProgressIndicator(),
                          ),
                        )
                      : _results.isEmpty
                          ? _hasTried
                              ? Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 20),
                                  child: Text(
                                    'Nenhum resultado.',
                                    style: TextStyle(
                                      color: isDark
                                          ? const Color(0xFF94A3B8)
                                          : const Color(0xFF64748B),
                                    ),
                                  ),
                                )
                              : const SizedBox.shrink()
                          : ListView.separated(
                              shrinkWrap: true,
                              itemCount: _results.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 8),
                              itemBuilder: (context, index) {
                                final user = _results[index];
                                final name = user.fullName.isEmpty
                                    ? user.userName
                                    : user.fullName;

                                final isMember = widget.existingUserIds.contains(user.id);
                                return Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? const Color(0xFF0F172A)
                                        : const Color(0xFFF8FAFC),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isDark
                                          ? Colors.white.withValues(alpha: 0.08)
                                          : const Color(0xFFE2E8F0),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 18,
                                        backgroundColor: isDark
                                            ? const Color(0xFF334155)
                                            : const Color(0xFFE2E8F0),
                                        child: Text(
                                          name.isEmpty ? '?' : name[0].toUpperCase(),
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            color: isDark
                                                ? Colors.white
                                                : const Color(0xFF0F172A),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              name,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontWeight: FontWeight.w600,
                                                color: isDark
                                                    ? Colors.white
                                                    : const Color(0xFF0F172A),
                                              ),
                                            ),
                                            Text(
                                              '@${user.userName}',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: isDark
                                                    ? const Color(0xFF94A3B8)
                                                    : const Color(0xFF64748B),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      if (isMember)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 6,
                                          ),
                                          decoration: BoxDecoration(
                                            color: isDark
                                                ? const Color(0xFF1E293B)
                                                : const Color(0xFFE2E8F0),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            'Membro',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w500,
                                              color: isDark
                                                  ? const Color(0xFF94A3B8)
                                                  : const Color(0xFF475569),
                                            ),
                                          ),
                                        )
                                      else
                                        ElevatedButton(
                                          onPressed: _loading ? null : () => _invite(user),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(0xFF0F172A),
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 14,
                                              vertical: 8,
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                          ),
                                          child: const Text(
                                            'Convidar',
                                            style: TextStyle(fontSize: 13),
                                          ),
                                        ),
                                    ],
                                  ),
                                );
                              },
                            ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Leave dialog
// ─────────────────────────────────────────────────────────────────────────────

class _LeaveConfirmDialog extends StatefulWidget {
  final Future<void> Function() onConfirm;

  const _LeaveConfirmDialog({
    required this.onConfirm,
  });

  @override
  State<_LeaveConfirmDialog> createState() => _LeaveConfirmDialogState();
}

class _LeaveConfirmDialogState extends State<_LeaveConfirmDialog> {
  bool _loading = false;

  Future<void> _submit() async {
    setState(() => _loading = true);
    try {
      await widget.onConfirm();
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AlertDialog(
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      title: Text(
        'Sair da patota?',
        style: TextStyle(
          color: isDark ? Colors.white : const Color(0xFF0F172A),
        ),
      ),
      content: Text(
        'Essa ação remove você da patota atual.',
        style: TextStyle(
          color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: _loading ? null : _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFE11D48),
            foregroundColor: Colors.white,
          ),
          child: _loading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('Sair'),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

String _extractError(Object e) {
  if (e is DioException) {
    final data = e.response?.data;
    if (data is Map) {
      final msg = data['message'] ?? data['error'] ?? data['title'];
      if (msg is String && msg.trim().isNotEmpty) return msg;
    }
    if (e.message != null && e.message!.trim().isNotEmpty) {
      return e.message!;
    }
  }
  return 'Ocorreu um erro. Tente novamente.';
}
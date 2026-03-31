import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../auth/presentation/providers/account_store.dart';
import '../../data/datasources/match_remote_datasource.dart';
import '../../domain/entities/match_models.dart';

// ── Datasource provider ───────────────────────────────────────────────────────

final matchDsProvider = Provider<MatchRemoteDataSource>(
  (ref) => MatchRemoteDataSource(ref.watch(dioProvider)),
);

// ── Notifier ──────────────────────────────────────────────────────────────────

class MatchNotifier extends StateNotifier<MatchState> {
  final MatchRemoteDataSource _ds;
  final String groupId;
  final bool isAdmin;
  Timer? _refreshTimer;

  MatchNotifier(this._ds, this.groupId, this.isAdmin)
      : super(const MatchState());

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  // ── Helpers internos ──────────────────────────────────────────────────────

  String _id(dynamic v) => (v ?? '').toString();

  List<MatchPlayerInfo> _parsePlayers(dynamic v) =>
      (v as List? ?? [])
          .map((e) => MatchPlayerInfo.fromJson(e as Map<String, dynamic>))
          .toList();

  List<MatchGoal> _parseGoals(dynamic v) =>
      (v as List? ?? [])
          .map((e) => MatchGoal.fromJson(e as Map<String, dynamic>))
          .toList();

  TeamColorInfo? _parseColor(dynamic v) =>
      v is Map<String, dynamic> ? TeamColorInfo.fromJson(v) : null;

  /// Aplica o payload do header ao state.
  void _applyHeader(Map<String, dynamic>? d) {
    if (d == null) return;
    final rawStep = d['stepKey'] ?? d['StepKey'];
    final rawStatus = d['status'] ?? d['Status'];
    final step = rawStep != null
        ? MatchStep.fromKey(rawStep.toString())
        : MatchStep.fromStatus((rawStatus as num?)?.toInt() ?? 0);

    final rawDate = d['playedAt'] ?? d['PlayedAt'];
    final playedAt = rawDate != null ? DateTime.tryParse(rawDate.toString()) : null;

    state = state.copyWith(
      matchId:   _id(d['matchId'] ?? d['MatchId'] ?? d['id'] ?? d['Id']).isEmpty
                   ? state.matchId : _id(d['matchId'] ?? d['MatchId'] ?? d['id'] ?? d['Id']),
      step:      step,
      placeName: d['placeName'] as String? ?? d['PlaceName'] as String? ?? state.placeName,
      playedAt:  playedAt ?? state.playedAt,
      canRewind: d['canRewind'] as bool? ?? d['CanRewind'] as bool? ?? false,
      teamAGoals: (d['teamAGoals'] ?? d['TeamAGoals']) as int? ?? state.teamAGoals,
      teamBGoals: (d['teamBGoals'] ?? d['TeamBGoals']) as int? ?? state.teamBGoals,
    );
  }

  /// Aplica o payload de aceitação ao state.
  void _applyAcceptation(Map<String, dynamic>? d) {
    if (d == null) return;
    state = state.copyWith(
      acceptedPlayers:   _parsePlayers(d['acceptedPlayers'] ?? d['AcceptedPlayers']),
      rejectedPlayers:   _parsePlayers(d['rejectedPlayers'] ?? d['RejectedPlayers']),
      pendingPlayers:    _parsePlayers(d['pendingPlayers']  ?? d['PendingPlayers']),
      maxPlayers:        (d['maxPlayers'] ?? d['MaxPlayers']) as int? ?? state.maxPlayers,
      acceptedOverLimit: d['acceptedOverLimit'] as bool? ?? d['AcceptedOverLimit'] as bool? ?? false,
    );
  }

  /// Aplica o payload de matchmaking ao state.
  void _applyMatchmaking(Map<String, dynamic>? d) {
    if (d == null) return;
    state = state.copyWith(
      teamAColor:        _parseColor(d['teamAColor'] ?? d['TeamAColor']),
      teamBColor:        _parseColor(d['teamBColor'] ?? d['TeamBColor']),
      teamAPlayers:      _parsePlayers(d['teamAPlayers']     ?? d['TeamAPlayers']),
      teamBPlayers:      _parsePlayers(d['teamBPlayers']     ?? d['TeamBPlayers']),
      unassignedPlayers: _parsePlayers(d['unassignedPlayers'] ?? d['UnassignedPlayers']),
      participants:      _parsePlayers(d['participants']      ?? d['Participants']),
      colorsLocked:      d['colorsLocked'] as bool? ?? d['ColorsLocked'] as bool? ?? false,
    );
  }

  /// Aplica o payload de pós-jogo ao state.
  void _applyPostgame(Map<String, dynamic>? d) {
    if (d == null) return;
    state = state.copyWith(
      teamAGoals:    (d['teamAGoals'] ?? d['TeamAGoals']) as int?,
      teamBGoals:    (d['teamBGoals'] ?? d['TeamBGoals']) as int?,
      goals:         _parseGoals(d['goals'] ?? d['Goals']),
      computedMvps:  ((d['computedMvps'] ?? d['ComputedMvps']) as List? ?? [])
                       .map((e) => MvpInfo.fromJson(e as Map<String, dynamic>)).toList(),
      votes:         ((d['votes'] ?? d['Votes']) as List? ?? [])
                       .map((e) => VoteInfo.fromJson(e as Map<String, dynamic>)).toList(),
      voteCounts:    ((d['voteCounts'] ?? d['VoteCounts']) as List? ?? [])
                       .map((e) => VoteCount.fromJson(e as Map<String, dynamic>)).toList(),
      allVoted:      d['allVoted'] as bool? ?? d['AllVoted'] as bool? ?? false,
      eligibleVoters: _parsePlayers(d['eligibleVoters'] ?? d['EligibleVoters']),
      participants:  _parsePlayers(d['participants'] ?? d['Participants']),
    );
  }

  // ── Carregamento por step ─────────────────────────────────────────────────

  Future<void> _loadStepPayload(String matchId, MatchStep step) async {
    final header = await _ds.fetchHeader(groupId, matchId).catchError((_) => null);
    _applyHeader(header);

    switch (step) {
      case MatchStep.accept:
        final d = await _ds.fetchAcceptation(groupId, matchId).catchError((_) => null);
        _applyAcceptation(d);
      case MatchStep.teams:
        final d = await _ds.fetchMatchmaking(groupId, matchId).catchError((_) => null);
        _applyMatchmaking(d);
      case MatchStep.playing:
        final d = await _ds.fetchMatchmaking(groupId, matchId).catchError((_) => null);
        _applyMatchmaking(d);
        final goals = await _ds.fetchGoals(groupId, matchId).catchError((_) => <MatchGoal>[]);
        state = state.copyWith(goals: goals);
      case MatchStep.post:
      case MatchStep.done:
        final d = await _ds.fetchPostgame(groupId, matchId).catchError((_) => null);
        _applyPostgame(d);
      default:
        break;
    }
  }

  // ── API pública ───────────────────────────────────────────────────────────

  /// Carrega estado inicial: cores, config e partida atual.
  Future<void> loadInitial() async {
    if (groupId.isEmpty) return;
    state = state.copyWith(loading: true, error: null);
    try {
      // Carrega cores e configurações em paralelo
      final results = await Future.wait([
        _ds.fetchTeamColors(groupId).catchError((_) => <TeamColorInfo>[]),
        _ds.fetchGroupSettings(groupId).catchError((_) => null),
        _ds.fetchCurrentMatchStub(groupId).catchError((e) {
          if (e is DioException && e.response?.statusCode == 404) return null;
          throw e;
        }),
      ]);

      final colors   = results[0] as List<TeamColorInfo>;
      final settings = results[1] as MatchGroupSettings?;
      final stub     = results[2] as Map<String, dynamic>?;

      state = state.copyWith(
        availableColors: colors,
        groupSettings:   settings,
        loading:         false,
      );

      // Pré-preenche local a partir das configurações do grupo
      if (settings != null) {
        state = state.copyWith(
          placeName: state.placeName ?? settings.defaultPlaceName,
        );
      }

      // Sem partida ativa → estado create
      if (stub == null) {
        state = state.copyWith(matchId: null, step: MatchStep.create);
        return;
      }

      final matchId = _id(stub['id'] ?? stub['matchId'] ?? stub['Id'] ?? stub['MatchId']);
      if (matchId.isEmpty) {
        state = state.copyWith(matchId: null, step: MatchStep.create);
        return;
      }

      final rawStatus = stub['status'] ?? stub['Status'] ?? 0;
      final rawKey    = stub['stepKey'] ?? stub['StepKey'];
      final step      = rawKey != null
          ? MatchStep.fromKey(rawKey.toString())
          : MatchStep.fromStatus((rawStatus as num).toInt());

      state = state.copyWith(
        matchId:  matchId,
        step:     step,
        placeName: stub['placeName'] as String? ?? stub['PlaceName'] as String?,
      );

      await _loadStepPayload(matchId, step);

      // Auto-refresh para não-admin
      if (!isAdmin) {
        _refreshTimer?.cancel();
        _refreshTimer = Timer.periodic(
          const Duration(seconds: 15),
          (_) => refresh(),
        );
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        state = state.copyWith(loading: false, matchId: null, step: MatchStep.create);
      } else {
        state = state.copyWith(loading: false, error: 'Falha ao carregar partida.');
      }
    } catch (_) {
      state = state.copyWith(loading: false, error: 'Falha ao carregar dados.');
    }
  }

  /// Recarrega apenas o step atual.
  Future<void> refresh() async {
    final matchId = state.matchId;
    if (matchId == null || matchId.isEmpty) return;
    await _loadStepPayload(matchId, state.step);
  }

  // ── Step 1 – Criar ────────────────────────────────────────────────────────

  Future<bool> createMatch(String placeName, DateTime playedAt) async {
    state = state.copyWith(mutating: true, error: null);
    try {
      await _ds.createMatch(groupId, placeName, playedAt);
      await loadInitial();
      return true;
    } catch (_) {
      state = state.copyWith(mutating: false, error: 'Falha ao criar partida.');
      return false;
    }
  }

  // ── Step 2 – Aceitação ────────────────────────────────────────────────────

  Future<void> acceptInvite(String playerId) async {
    final matchId = state.matchId;
    if (matchId == null) return;
    state = state.copyWith(mutating: true);
    try {
      await _ds.acceptInvite(groupId, matchId, playerId);
      await refresh();
    } catch (_) {
      state = state.copyWith(error: 'Falha ao aceitar convite.');
    } finally {
      state = state.copyWith(mutating: false);
    }
  }

  Future<void> rejectInvite(String playerId) async {
    final matchId = state.matchId;
    if (matchId == null) return;
    state = state.copyWith(mutating: true);
    try {
      await _ds.rejectInvite(groupId, matchId, playerId);
      await refresh();
    } catch (_) {
      state = state.copyWith(error: 'Falha ao recusar convite.');
    } finally {
      state = state.copyWith(mutating: false);
    }
  }

  Future<void> goToMatchmaking() async {
    final matchId = state.matchId;
    if (matchId == null) return;
    state = state.copyWith(mutating: true);
    try {
      await _ds.goToMatchmaking(groupId, matchId);
      await _loadStepPayload(matchId, MatchStep.teams);
    } catch (_) {
      state = state.copyWith(error: 'Falha ao avançar para matchmaking.');
    } finally {
      state = state.copyWith(mutating: false);
    }
  }

  Future<void> addGuest(String name, bool isGoalkeeper, int? starRating) async {
    final matchId = state.matchId;
    if (matchId == null) return;
    state = state.copyWith(mutating: true);
    try {
      await _ds.addGuest(groupId, matchId, name, isGoalkeeper, starRating);
      final d = await _ds.fetchAcceptation(groupId, matchId);
      _applyAcceptation(d);
    } catch (_) {
      state = state.copyWith(error: 'Falha ao adicionar convidado.');
    } finally {
      state = state.copyWith(mutating: false);
    }
  }

  // ── Step 3 – MatchMaking ──────────────────────────────────────────────────

  Future<void> generateTeams({
    required int strategyType,
    required int playersPerTeam,
    required bool includeGoalkeepers,
  }) async {
    final allPlayers = [
      ...state.acceptedPlayers,
      ...state.participants,
    ];
    state = state.copyWith(mutating: true, teamGenOptions: [], selectedTeamGenIdx: 0);
    try {
      final options = await _ds.generateTeams(
        players:           allPlayers,
        strategyType:      strategyType,
        playersPerTeam:    playersPerTeam,
        includeGoalkeepers: includeGoalkeepers,
      );
      state = state.copyWith(teamGenOptions: options, mutating: false);
    } catch (_) {
      state = state.copyWith(mutating: false, error: 'Falha ao gerar times.');
    }
  }

  void selectTeamGenOption(int idx) {
    state = state.copyWith(selectedTeamGenIdx: idx);
  }

  Future<void> assignTeamsFromGenerated() async {
    final matchId = state.matchId;
    if (matchId == null || state.teamGenOptions.isEmpty) return;
    final idx = state.selectedTeamGenIdx.clamp(0, state.teamGenOptions.length - 1);
    final opt = state.teamGenOptions[idx];
    final teamAIds = opt.teamA.map((p) => p.playerId).toList();
    final teamBIds = opt.teamB.map((p) => p.playerId).toList();
    state = state.copyWith(mutating: true);
    try {
      await _ds.assignTeams(groupId, matchId, teamAIds, teamBIds);
      state = state.copyWith(teamGenOptions: [], selectedTeamGenIdx: 0);
      await refresh();
    } catch (_) {
      state = state.copyWith(error: 'Falha ao atribuir times.');
    } finally {
      state = state.copyWith(mutating: false);
    }
  }

  Future<void> setColors(String teamAColorId, String teamBColorId) async {
    final matchId = state.matchId;
    if (matchId == null) return;
    state = state.copyWith(mutating: true);
    try {
      await _ds.setColors(groupId, matchId, teamAColorId, teamBColorId);
      await refresh();
    } catch (_) {
      state = state.copyWith(error: 'Falha ao definir cores.');
    } finally {
      state = state.copyWith(mutating: false);
    }
  }

  Future<void> setColorsRandom() async {
    final colors = state.availableColors;
    if (colors.length < 2) return;
    final shuffled = [...colors]..shuffle();
    final a = shuffled[0];
    final b = shuffled.firstWhere((c) => c.id != a.id, orElse: () => shuffled[1]);
    await setColors(a.id, b.id);
  }

  Future<void> movePlayerToOtherTeam(String playerId, bool fromTeamA) async {
    final matchId = state.matchId;
    if (matchId == null) return;
    final aIds = state.teamAPlayers.map((p) => p.playerId).toList();
    final bIds = state.teamBPlayers.map((p) => p.playerId).toList();
    final newA = fromTeamA ? (aIds..remove(playerId)) : [...aIds, playerId];
    final newB = fromTeamA ? [...bIds, playerId]      : (bIds..remove(playerId));
    state = state.copyWith(mutating: true);
    try {
      await _ds.assignTeams(groupId, matchId, newA, newB);
      await refresh();
    } catch (_) {
      state = state.copyWith(error: 'Falha ao mover jogador.');
    } finally {
      state = state.copyWith(mutating: false);
    }
  }

  Future<void> assignUnassigned(String playerId, bool toTeamA) async {
    final matchId = state.matchId;
    if (matchId == null) return;
    final aIds = state.teamAPlayers.map((p) => p.playerId).toList();
    final bIds = state.teamBPlayers.map((p) => p.playerId).toList();
    final newA = toTeamA ? [...aIds, playerId] : aIds;
    final newB = toTeamA ? bIds : [...bIds, playerId];
    state = state.copyWith(mutating: true);
    try {
      await _ds.assignTeams(groupId, matchId, newA, newB);
      await refresh();
    } catch (_) {
      state = state.copyWith(error: 'Falha ao atribuir jogador.');
    } finally {
      state = state.copyWith(mutating: false);
    }
  }

  Future<void> swapPlayers(String playerAId, String playerBId) async {
    final matchId = state.matchId;
    if (matchId == null) return;
    state = state.copyWith(mutating: true);
    try {
      await _ds.swapPlayers(groupId, matchId, playerAId, playerBId);
      await refresh();
    } catch (_) {
      state = state.copyWith(error: 'Falha ao trocar jogadores.');
    } finally {
      state = state.copyWith(mutating: false);
    }
  }

  Future<void> setPlayerRole(String matchPlayerId, bool isGoalkeeper) async {
    final matchId = state.matchId;
    if (matchId == null) return;
    state = state.copyWith(mutating: true);
    try {
      await _ds.setPlayerRole(groupId, matchId, matchPlayerId, isGoalkeeper);
      await refresh();
    } catch (_) {
      state = state.copyWith(error: 'Falha ao alterar função do jogador.');
    } finally {
      state = state.copyWith(mutating: false);
    }
  }

  // ── Step 4 – Jogo ─────────────────────────────────────────────────────────

  Future<void> startMatch() async {
    final matchId = state.matchId;
    if (matchId == null) return;
    state = state.copyWith(mutating: true);
    try {
      await _ds.startMatch(groupId, matchId);
      await _loadStepPayload(matchId, MatchStep.playing);
    } catch (_) {
      state = state.copyWith(error: 'Falha ao iniciar partida.');
    } finally {
      state = state.copyWith(mutating: false);
    }
  }

  Future<void> addGoal({
    required String scorerPlayerId,
    String? assistPlayerId,
    required String time,
    bool isOwnGoal = false,
  }) async {
    final matchId = state.matchId;
    if (matchId == null) return;
    state = state.copyWith(mutating: true);
    try {
      await _ds.addGoal(groupId, matchId,
        scorerPlayerId: scorerPlayerId,
        assistPlayerId: assistPlayerId,
        time:           time,
        isOwnGoal:      isOwnGoal,
      );
      await refresh();
    } catch (_) {
      state = state.copyWith(error: 'Falha ao adicionar gol.');
    } finally {
      state = state.copyWith(mutating: false);
    }
  }

  Future<void> removeGoal(String goalId) async {
    final matchId = state.matchId;
    if (matchId == null) return;
    state = state.copyWith(mutating: true);
    try {
      await _ds.removeGoal(groupId, matchId, goalId);
      await refresh();
    } catch (_) {
      state = state.copyWith(error: 'Falha ao remover gol.');
    } finally {
      state = state.copyWith(mutating: false);
    }
  }

  Future<bool> endMatch() async {
    final matchId = state.matchId;
    if (matchId == null) return false;
    state = state.copyWith(mutating: true);
    try {
      await _ds.endMatch(groupId, matchId);
      await _loadStepPayload(matchId, MatchStep.ended);
      return true;
    } catch (_) {
      state = state.copyWith(error: 'Falha ao encerrar partida.');
      return false;
    } finally {
      state = state.copyWith(mutating: false);
    }
  }

  // ── Step 5 – Encerrar ─────────────────────────────────────────────────────

  Future<bool> goToPostGame() async {
    final matchId = state.matchId;
    if (matchId == null) return false;
    state = state.copyWith(mutating: true);
    try {
      await _ds.goToPostGame(groupId, matchId);
      await _loadStepPayload(matchId, MatchStep.post);
      return true;
    } catch (_) {
      state = state.copyWith(error: 'Falha ao ir para pós-jogo.');
      return false;
    } finally {
      state = state.copyWith(mutating: false);
    }
  }

  // ── Step 6 – Pós-jogo ─────────────────────────────────────────────────────

  Future<void> setScore(int teamAGoals, int teamBGoals) async {
    final matchId = state.matchId;
    if (matchId == null) return;
    state = state.copyWith(mutating: true);
    try {
      await _ds.setScore(groupId, matchId, teamAGoals, teamBGoals);
      await refresh();
    } catch (_) {
      state = state.copyWith(error: 'Falha ao registrar placar.');
    } finally {
      state = state.copyWith(mutating: false);
    }
  }

  Future<void> voteMvp(String voterMpId, String votedMpId) async {
    final matchId = state.matchId;
    if (matchId == null) return;
    state = state.copyWith(mutating: true);
    try {
      await _ds.voteMvp(groupId, matchId, voterMpId, votedMpId);
      await refresh();
    } catch (_) {
      state = state.copyWith(error: 'Falha ao registrar voto.');
    } finally {
      state = state.copyWith(mutating: false);
    }
  }

  Future<bool> finalizeMatch() async {
    final matchId = state.matchId;
    if (matchId == null) return false;
    state = state.copyWith(mutating: true);
    try {
      await _ds.finalizeMatch(groupId, matchId);
      await _loadStepPayload(matchId, MatchStep.done);
      return true;
    } catch (_) {
      state = state.copyWith(error: 'Falha ao finalizar partida.');
      return false;
    } finally {
      state = state.copyWith(mutating: false);
    }
  }

  // ── Admin – voltar etapa ──────────────────────────────────────────────────

  Future<void> rewindStep() async {
    final matchId = state.matchId;
    if (matchId == null) return;
    state = state.copyWith(mutating: true);
    try {
      await _ds.rewindStep(groupId, matchId);
      await refresh();
    } catch (_) {
      state = state.copyWith(error: 'Falha ao voltar etapa.');
    } finally {
      state = state.copyWith(mutating: false);
    }
  }

  /// Limpa o erro exibido.
  void clearError() => state = state.copyWith(error: null);
}

// ── Provider ──────────────────────────────────────────────────────────────────

final matchNotifierProvider =
    StateNotifierProvider.autoDispose<MatchNotifier, MatchState>((ref) {
  final acc     = ref.read(accountStoreProvider).activeAccount;
  final groupId = acc?.activeGroupId ?? '';
  final isAdmin = groupId.isNotEmpty && (acc?.isGroupAdmin(groupId) ?? false);
  return MatchNotifier(ref.read(matchDsProvider), groupId, isAdmin);
});

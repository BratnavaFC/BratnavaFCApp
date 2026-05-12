import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../auth/presentation/providers/account_store.dart';
import '../../domain/entities/match_models.dart';
import '../providers/match_provider.dart';
import '../widgets/goal_entry_row.dart';

class Step4JogoPage extends ConsumerStatefulWidget {
  const Step4JogoPage({super.key});

  @override
  ConsumerState<Step4JogoPage> createState() => _Step4State();
}

class _Step4State extends ConsumerState<Step4JogoPage> {
  // ── GoalTracker inline state ──────────────────────────────────────────────
  bool    _showGoalForm = false;
  int     _goalMinute   = 0;
  String? _scorerMpId;
  String? _assistMpId;
  bool    _isOwnGoal    = false;

  bool get _isAdmin {
    final acc = ref.read(accountStoreProvider).activeAccount;
    final gid = acc?.activeGroupId ?? '';
    return (acc?.isAdmin ?? false) || (gid.isNotEmpty && (acc?.isGroupAdmin(gid) ?? false));
  }

  void _resetGoalForm() {
    setState(() {
      _showGoalForm = false;
      _goalMinute   = 0;
      _scorerMpId   = null;
      _assistMpId   = null;
      _isOwnGoal    = false;
    });
  }

  Future<void> _endMatch() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Encerrar partida?'),
        content: const Text('A partida será encerrada. Você poderá registrar o placar e MVP no pós-jogo.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.rose500),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Encerrar'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    await ref.read(matchNotifierProvider.notifier).endMatch();
  }

  Future<void> _saveGoal(List<MatchPlayerInfo> players) async {
    if (_scorerMpId == null) return;
    await ref.read(matchNotifierProvider.notifier).addGoal(
      scorerPlayerId: _scorerMpId!,
      assistPlayerId: _assistMpId,
      time: '$_goalMinute',
      isOwnGoal: _isOwnGoal,
    );
    _resetGoalForm();
  }

  @override
  Widget build(BuildContext context) {
    final s       = ref.watch(matchNotifierProvider);
    final fmt     = DateFormat('dd/MM/yyyy HH:mm', 'pt_BR');
    final dateStr = s.playedAt != null ? fmt.format(s.playedAt!.toLocal()) : '—';

    final allPlayers = s.participants.isNotEmpty
        ? s.participants
        : [...s.teamAPlayers, ...s.teamBPlayers];

    return Column(
      children: [
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => ref.read(matchNotifierProvider.notifier).refresh(),
            child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ── Status card ──────────────────────────────────────────
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _PulsingDot(),
                                const SizedBox(width: 8),
                                const Text('Em Jogo', style: TextStyle(
                                  fontWeight: FontWeight.w700, fontSize: 15,
                                  color: AppColors.emerald500,
                                )),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(dateStr, style: const TextStyle(fontSize: 13, color: AppColors.slate500)),
                            Text(s.placeName ?? '—', style: const TextStyle(fontSize: 13, color: AppColors.slate500)),
                            if (s.teamAColor != null || s.teamBColor != null) ...[
                              const SizedBox(height: 12),
                              _ScoreDisplay(
                                teamAName: s.teamAColor?.name ?? 'Time A',
                                teamBName: s.teamBColor?.name ?? 'Time B',
                                teamAColor: s.teamAColor?.color,
                                teamBColor: s.teamBColor?.color,
                                goalsA: s.goals.where((g) => g.team == 1).length,
                                goalsB: s.goals.where((g) => g.team == 2).length,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ── GoalTracker inline ───────────────────────────────────
                    _InlineGoalTracker(
                      show:       _showGoalForm,
                      minute:     _goalMinute,
                      scorerMpId: _scorerMpId,
                      assistMpId: _assistMpId,
                      isOwnGoal:  _isOwnGoal,
                      teamAPlayers: s.teamAPlayers.isNotEmpty ? s.teamAPlayers : allPlayers,
                      teamBPlayers: s.teamBPlayers,
                      teamAName:  s.teamAColor?.name ?? 'Time A',
                      teamBName:  s.teamBColor?.name ?? 'Time B',
                      teamAColor: s.teamAColor?.color,
                      teamBColor: s.teamBColor?.color,
                      mutating:   s.mutating,
                      onToggle: () => setState(() {
                        _showGoalForm = !_showGoalForm;
                        if (!_showGoalForm) {
                          _scorerMpId = null;
                          _assistMpId = null;
                          _isOwnGoal  = false;
                          _goalMinute = 0;
                        }
                      }),
                      onMinuteChanged: (v) => setState(() => _goalMinute = v),
                      onScorerChanged: (id) => setState(() {
                        _scorerMpId = id;
                        _assistMpId = null;
                      }),
                      onAssistChanged: (id) => setState(() => _assistMpId = id),
                      onOwnGoalChanged: (v) => setState(() => _isOwnGoal = v),
                      onSave: () => _saveGoal(allPlayers),
                      onCancel: _resetGoalForm,
                    ),
                    const SizedBox(height: 8),

                    // ── Lista de gols ────────────────────────────────────────
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Gols da Partida (${s.goals.length})',
                            style: Theme.of(context).textTheme.titleSmall),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (s.goals.isEmpty)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 24),
                          child: Text('Nenhum gol registrado', style: TextStyle(color: AppColors.slate400)),
                        ),
                      )
                    else
                      ...s.goals.map((g) => GoalEntryRow(
                        goal:      g,
                        teamAName: s.teamAColor?.name ?? 'Time A',
                        teamBName: s.teamBColor?.name ?? 'Time B',
                        teamAColor: s.teamAColor?.color,
                        teamBColor: s.teamBColor?.color,
                        isAdmin:   _isAdmin,
                        onRemove:  _isAdmin
                            ? () => ref.read(matchNotifierProvider.notifier).removeGoal(g.goalId)
                            : null,
                      )),
                    const SizedBox(height: 80),
                  ],
                ),
              ),
            ),
          ),
          // ── Encerrar partida (admin) ──────────────────────────────────────
          if (_isAdmin)
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: AppColors.rose500),
                    onPressed: s.mutating ? null : _endMatch,
                    icon: s.mutating
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.stop_circle_outlined),
                    label: const Text('⏹ Encerrar Partida'),
                  ),
                ),
              ),
            ),
        ],
    );
  }
}

// ── Inline GoalTracker ────────────────────────────────────────────────────────

class _InlineGoalTracker extends StatelessWidget {
  final bool    show;
  final int     minute;
  final String? scorerMpId;
  final String? assistMpId;
  final bool    isOwnGoal;
  final List<MatchPlayerInfo> teamAPlayers;
  final List<MatchPlayerInfo> teamBPlayers;
  final String  teamAName;
  final String  teamBName;
  final Color?  teamAColor;
  final Color?  teamBColor;
  final bool    mutating;
  final VoidCallback onToggle;
  final ValueChanged<int>     onMinuteChanged;
  final ValueChanged<String?> onScorerChanged;
  final ValueChanged<String?> onAssistChanged;
  final ValueChanged<bool>    onOwnGoalChanged;
  final VoidCallback onSave;
  final VoidCallback onCancel;

  const _InlineGoalTracker({
    required this.show,
    required this.minute,
    required this.scorerMpId,
    required this.assistMpId,
    required this.isOwnGoal,
    required this.teamAPlayers,
    required this.teamBPlayers,
    required this.teamAName,
    required this.teamBName,
    this.teamAColor,
    this.teamBColor,
    required this.mutating,
    required this.onToggle,
    required this.onMinuteChanged,
    required this.onScorerChanged,
    required this.onAssistChanged,
    required this.onOwnGoalChanged,
    required this.onSave,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Header / toggle ────────────────────────────────────────────
          InkWell(
            onTap: onToggle,
            borderRadius: show
                ? const BorderRadius.vertical(top: Radius.circular(12))
                : BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  const Icon(Icons.sports_soccer, size: 18, color: AppColors.slate500),
                  const SizedBox(width: 8),
                  const Text(
                    'Registrar Gol',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                  const Spacer(),
                  Icon(
                    show ? Icons.keyboard_arrow_up : Icons.add_circle_outline,
                    color: show ? AppColors.slate400 : Theme.of(context).colorScheme.primary,
                  ),
                ],
              ),
            ),
          ),

          if (show) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Minuto ──────────────────────────────────────────────
                  Row(
                    children: [
                      const Text('Minuto:', style: TextStyle(fontSize: 13, color: AppColors.slate600)),
                      const SizedBox(width: 12),
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline, size: 20),
                        onPressed: minute > 0 ? () => onMinuteChanged(minute - 1) : null,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                      ),
                      SizedBox(
                        width: 44,
                        child: Text(
                          '$minute\'',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline, size: 20),
                        onPressed: () => onMinuteChanged(minute + 1),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // ── Seleção de goleador (2 colunas) ─────────────────────
                  const Text(
                    'GOLEADOR',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
                        letterSpacing: 0.8, color: AppColors.slate400),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: _PlayerColumn(
                        label:     teamAName,
                        color:     teamAColor,
                        players:   teamAPlayers,
                        selectedId: scorerMpId,
                        onTap:     onScorerChanged,
                      )),
                      const SizedBox(width: 8),
                      if (teamBPlayers.isNotEmpty)
                        Expanded(child: _PlayerColumn(
                          label:     teamBName,
                          color:     teamBColor,
                          players:   teamBPlayers,
                          selectedId: scorerMpId,
                          onTap:     onScorerChanged,
                        )),
                    ],
                  ),

                  if (scorerMpId != null) ...[
                    const SizedBox(height: 12),
                    const Divider(),
                    const SizedBox(height: 8),

                    // ── Gol contra ──────────────────────────────────────
                    Row(
                      children: [
                        Checkbox(
                          value: isOwnGoal,
                          onChanged: (v) => onOwnGoalChanged(v ?? false),
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        const Text('Gol contra', style: TextStyle(fontSize: 13)),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // ── Assistência ─────────────────────────────────────
                    const Text(
                      'ASSISTÊNCIA (opcional)',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
                          letterSpacing: 0.8, color: AppColors.slate400),
                    ),
                    const SizedBox(height: 8),
                    _AssistGrid(
                      allPlayers: [...teamAPlayers, ...teamBPlayers],
                      scorerMpId: scorerMpId!,
                      assistMpId: assistMpId,
                      onTap:     onAssistChanged,
                    ),
                    const SizedBox(height: 12),

                    // ── Botões ──────────────────────────────────────────
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: onCancel,
                            child: const Text('Cancelar'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: FilledButton(
                            onPressed: mutating ? null : onSave,
                            child: mutating
                                ? const SizedBox(width: 16, height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : const Text('Salvar Gol'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Coluna de jogadores (seleção goleador) ────────────────────────────────────

class _PlayerColumn extends StatelessWidget {
  final String  label;
  final Color?  color;
  final List<MatchPlayerInfo> players;
  final String? selectedId;
  final ValueChanged<String?> onTap;

  const _PlayerColumn({
    required this.label,
    this.color,
    required this.players,
    required this.selectedId,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final teamColor = color ?? AppColors.slate400;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(children: [
          Container(width: 8, height: 8,
              decoration: BoxDecoration(shape: BoxShape.circle, color: teamColor)),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: teamColor)),
        ]),
        const SizedBox(height: 4),
        ...players.map((p) {
          final isSel = p.matchPlayerId == selectedId;
          return GestureDetector(
            onTap: () => onTap(isSel ? null : p.matchPlayerId),
            child: Container(
              margin: const EdgeInsets.only(bottom: 4),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: isSel ? teamColor : AppColors.slate200),
                color: isSel ? teamColor.withValues(alpha: 0.1) : AppColors.slate50,
              ),
              child: Row(children: [
                if (p.isGoalkeeper)
                  const Icon(Icons.sports_handball, size: 12, color: AppColors.slate400),
                if (p.isGoalkeeper) const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    p.playerName,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isSel ? FontWeight.w700 : FontWeight.w400,
                      color: isSel ? teamColor : AppColors.slate800,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (isSel) Icon(Icons.check_circle, size: 14, color: teamColor),
              ]),
            ),
          );
        }),
      ],
    );
  }
}

// ── Grid de assistência ───────────────────────────────────────────────────────

class _AssistGrid extends StatelessWidget {
  final List<MatchPlayerInfo> allPlayers;
  final String  scorerMpId;
  final String? assistMpId;
  final ValueChanged<String?> onTap;

  const _AssistGrid({
    required this.allPlayers,
    required this.scorerMpId,
    required this.assistMpId,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final candidates = allPlayers.where((p) => p.matchPlayerId != scorerMpId).toList();
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        // Nenhuma assistência
        GestureDetector(
          onTap: () => onTap(null),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: assistMpId == null ? AppColors.slate500 : AppColors.slate200),
              color: assistMpId == null ? AppColors.slate100 : Colors.transparent,
            ),
            child: const Text('—', style: TextStyle(fontSize: 12)),
          ),
        ),
        ...candidates.map((p) {
          final isSel = p.matchPlayerId == assistMpId;
          return GestureDetector(
            onTap: () => onTap(isSel ? null : p.matchPlayerId),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: isSel ? AppColors.blue500 : AppColors.slate200),
                color: isSel ? AppColors.blue200.withValues(alpha: 0.3) : Colors.transparent,
              ),
              child: Text(
                p.playerName,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSel ? FontWeight.w600 : FontWeight.w400,
                  color: isSel ? AppColors.blue600 : AppColors.slate700,
                ),
              ),
            ),
          );
        }),
      ],
    );
  }
}

// ── Dot pulsante ──────────────────────────────────────────────────────────────

class _PulsingDot extends StatefulWidget {
  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 1))
      ..repeat(reverse: true);
    _anim = Tween(begin: 0.4, end: 1.0).animate(_ctrl);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: _anim,
    child: const Icon(Icons.circle, size: 10, color: AppColors.emerald500),
  );
}

// ── Placar ────────────────────────────────────────────────────────────────────

class _ScoreDisplay extends StatelessWidget {
  final String teamAName, teamBName;
  final Color? teamAColor, teamBColor;
  final int goalsA, goalsB;

  const _ScoreDisplay({
    required this.teamAName, required this.teamBName,
    this.teamAColor, this.teamBColor,
    required this.goalsA, required this.goalsB,
  });

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      _TeamScore(name: teamAName, goals: goalsA, color: teamAColor),
      const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16),
        child: Text('×', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w300)),
      ),
      _TeamScore(name: teamBName, goals: goalsB, color: teamBColor),
    ],
  );
}

class _TeamScore extends StatelessWidget {
  final String name;
  final int goals;
  final Color? color;
  const _TeamScore({required this.name, required this.goals, this.color});

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Container(
        width: 12, height: 12,
        decoration: BoxDecoration(shape: BoxShape.circle, color: color ?? AppColors.slate300),
      ),
      Text('$goals', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700)),
      Text(name, style: const TextStyle(fontSize: 11, color: AppColors.slate500)),
    ],
  );
}

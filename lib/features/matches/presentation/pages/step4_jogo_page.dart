import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../auth/presentation/providers/account_store.dart';
import '../../domain/entities/match_models.dart';
import '../providers/match_provider.dart';
import '../widgets/match_stepper_header.dart';
import '../widgets/goal_entry_row.dart';
import 'step5_encerrar_page.dart';

class Step4JogoPage extends ConsumerStatefulWidget {
  const Step4JogoPage({super.key});

  @override
  ConsumerState<Step4JogoPage> createState() => _Step4State();
}

class _Step4State extends ConsumerState<Step4JogoPage> {
  bool get _isAdmin {
    final acc = ref.read(accountStoreProvider).activeAccount;
    final gid = acc?.activeGroupId ?? '';
    return gid.isNotEmpty && (acc?.isGroupAdmin(gid) ?? false);
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
    final ok = await ref.read(matchNotifierProvider.notifier).endMatch();
    if (ok && mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const Step5EncerrarPage()),
      );
    }
  }

  Future<void> _showAddGoalSheet() async {
    final s = ref.read(matchNotifierProvider);
    final players = s.participants.isNotEmpty ? s.participants : [...s.teamAPlayers, ...s.teamBPlayers];
    if (players.isEmpty) return;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => _AddGoalSheet(players: players),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s       = ref.watch(matchNotifierProvider);
    final fmt     = DateFormat('dd/MM/yyyy HH:mm', 'pt_BR');
    final dateStr = s.playedAt != null ? fmt.format(s.playedAt!.toLocal()) : '—';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Jogo'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.read(matchNotifierProvider.notifier).refresh(),
          ),
        ],
      ),
      body: Column(
        children: [
          MatchStepperHeader(currentStep: MatchStep.playing),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => ref.read(matchNotifierProvider.notifier).refresh(),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ── Status card ───────────────────────────────────────
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
                            // Placar dos times
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
                    // ── Gols ─────────────────────────────────────────────
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Gols da Partida', style: Theme.of(context).textTheme.titleSmall),
                        if (_isAdmin || true) // qualquer jogador pode registrar
                          TextButton.icon(
                            onPressed: _showAddGoalSheet,
                            icon: const Icon(Icons.add, size: 18),
                            label: const Text('+ Gol'),
                          ),
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
          // ── Encerrar partida (admin) ───────────────────────────────────
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
      ),
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

// ── Bottom Sheet: adicionar gol ───────────────────────────────────────────────

class _AddGoalSheet extends ConsumerStatefulWidget {
  final List<MatchPlayerInfo> players;
  const _AddGoalSheet({required this.players});

  @override
  ConsumerState<_AddGoalSheet> createState() => _AddGoalSheetState();
}

class _AddGoalSheetState extends ConsumerState<_AddGoalSheet> {
  String? _scorerMpId;
  String? _assistMpId;
  final _timeCtrl = TextEditingController(text: '0');
  bool _isOwnGoal = false;

  @override
  void dispose() { _timeCtrl.dispose(); super.dispose(); }

  Future<void> _save() async {
    if (_scorerMpId == null) return;
    final scorer = widget.players.firstWhere((p) => p.matchPlayerId == _scorerMpId);
    final assist = _assistMpId != null
        ? widget.players.firstWhere((p) => p.matchPlayerId == _assistMpId, orElse: () => widget.players.first)
        : null;
    await ref.read(matchNotifierProvider.notifier).addGoal(
      scorerPlayerId: scorer.matchPlayerId,
      assistPlayerId: assist?.matchPlayerId,
      time: _timeCtrl.text.trim().isEmpty ? '0' : _timeCtrl.text.trim(),
      isOwnGoal: _isOwnGoal,
    );
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(context).viewInsets.bottom + 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Registrar Gol', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: _scorerMpId,
            decoration: const InputDecoration(labelText: 'Goleador *', border: OutlineInputBorder()),
            items: widget.players.map((p) => DropdownMenuItem(value: p.matchPlayerId, child: Text(p.playerName))).toList(),
            onChanged: (v) => setState(() { _scorerMpId = v; if (v == _assistMpId) _assistMpId = null; }),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _assistMpId,
            decoration: const InputDecoration(labelText: 'Assistência (opcional)', border: OutlineInputBorder()),
            items: [
              const DropdownMenuItem(value: null, child: Text('—')),
              ...widget.players
                  .where((p) => p.matchPlayerId != _scorerMpId)
                  .map((p) => DropdownMenuItem(value: p.matchPlayerId, child: Text(p.playerName))),
            ],
            onChanged: (v) => setState(() => _assistMpId = v),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _timeCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Minuto', prefixIcon: Icon(Icons.timer_outlined), border: OutlineInputBorder()),
          ),
          const SizedBox(height: 8),
          CheckboxListTile(
            value: _isOwnGoal,
            onChanged: (v) => setState(() => _isOwnGoal = v ?? false),
            title: const Text('Gol contra'),
            controlAffinity: ListTileControlAffinity.leading,
            dense: true,
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _scorerMpId == null ? null : _save,
            child: const Text('Salvar Gol'),
          ),
        ],
      ),
    );
  }
}

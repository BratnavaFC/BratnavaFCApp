import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../auth/presentation/providers/account_store.dart';
import '../../domain/entities/match_models.dart';
import '../providers/match_provider.dart';
import '../widgets/match_stepper_header.dart';
import '../widgets/goal_entry_row.dart';
import 'step7_final_page.dart';

class Step6PosJogoPage extends ConsumerStatefulWidget {
  const Step6PosJogoPage({super.key});

  @override
  ConsumerState<Step6PosJogoPage> createState() => _Step6State();
}

class _Step6State extends ConsumerState<Step6PosJogoPage> {
  final _scoreACtrl = TextEditingController();
  final _scoreBCtrl = TextEditingController();
  String? _voterMpId;
  String? _votedMpId;
  bool _scoreInited = false;

  bool get _isAdmin {
    final acc = ref.read(accountStoreProvider).activeAccount;
    final gid = acc?.activeGroupId ?? '';
    return gid.isNotEmpty && (acc?.isGroupAdmin(gid) ?? false);
  }

  String get _myPlayerId =>
      ref.read(accountStoreProvider).activeAccount?.activePlayerId ?? '';

  @override
  void dispose() {
    _scoreACtrl.dispose();
    _scoreBCtrl.dispose();
    super.dispose();
  }

  void _initScoreFields(MatchState s) {
    if (_scoreInited) return;
    _scoreInited = true;
    if (s.teamAGoals != null) _scoreACtrl.text = '${s.teamAGoals}';
    if (s.teamBGoals != null) _scoreBCtrl.text = '${s.teamBGoals}';
    // Pré-seleciona voter do usuário atual
    final eligible = s.eligibleVoters;
    final myMp = eligible.where((p) => p.playerId == _myPlayerId).firstOrNull;
    if (myMp != null && !_isAdmin) _voterMpId = myMp.matchPlayerId;
  }

  Future<void> _saveScore() async {
    final a = int.tryParse(_scoreACtrl.text);
    final b = int.tryParse(_scoreBCtrl.text);
    if (a == null || b == null || a < 0 || b < 0) return;
    await ref.read(matchNotifierProvider.notifier).setScore(a, b);
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Placar salvo!')));
  }

  Future<void> _vote() async {
    if (_voterMpId == null || _votedMpId == null) return;
    await ref.read(matchNotifierProvider.notifier).voteMvp(_voterMpId!, _votedMpId!);
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Voto registrado!')));
  }

  Future<void> _finalize() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Finalizar partida?'),
        content: const Text('Os dados não poderão ser alterados após a finalização.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Finalizar')),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    final ok = await ref.read(matchNotifierProvider.notifier).finalizeMatch();
    if (ok && mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const Step7FinalPage()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(matchNotifierProvider);
    if (!_scoreInited && !s.loading) _initScoreFields(s);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pós-jogo'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.read(matchNotifierProvider.notifier).refresh(),
          ),
        ],
      ),
      body: Column(
        children: [
          MatchStepperHeader(currentStep: MatchStep.post),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => ref.read(matchNotifierProvider.notifier).refresh(),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ── 1. Votar MVP ──────────────────────────────────────
                    _SectionCard(
                      title: 'Votar MVP',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (s.computedMvps.isNotEmpty) ...[
                            Row(children: [
                              const Icon(Icons.emoji_events, color: AppColors.amber400),
                              const SizedBox(width: 6),
                              Text(
                                'MVP: ${s.computedMvps.map((m) => m.playerName).join(', ')}',
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                            ]),
                            const SizedBox(height: 12),
                          ],
                          // Quem vota (admin pode escolher, user é fixo)
                          if (_isAdmin)
                            DropdownButtonFormField<String>(
                              value: _voterMpId,
                              decoration: const InputDecoration(labelText: 'Quem vota', border: OutlineInputBorder()),
                              items: s.eligibleVoters
                                  .map((p) => DropdownMenuItem(value: p.matchPlayerId, child: Text(p.playerName)))
                                  .toList(),
                              onChanged: (v) => setState(() => _voterMpId = v),
                            )
                          else if (_voterMpId != null)
                            Text(
                              'Votando como: ${s.eligibleVoters.firstWhere((p) => p.matchPlayerId == _voterMpId, orElse: () => s.eligibleVoters.first).playerName}',
                              style: const TextStyle(color: AppColors.slate500),
                            ),
                          const SizedBox(height: 10),
                          // Votado
                          DropdownButtonFormField<String>(
                            value: _votedMpId,
                            decoration: const InputDecoration(labelText: 'Votado', border: OutlineInputBorder()),
                            items: s.participants
                                .map((p) => DropdownMenuItem(value: p.matchPlayerId, child: Text(p.playerName)))
                                .toList(),
                            onChanged: (v) => setState(() => _votedMpId = v),
                          ),
                          const SizedBox(height: 10),
                          // Contagem de votos
                          if (s.voteCounts.isNotEmpty) ...[
                            const Text('Votos:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                            ...s.voteCounts.map((vc) => Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Row(children: [
                                Expanded(child: Text(vc.playerName, style: const TextStyle(fontSize: 13))),
                                Text('${vc.count}', style: const TextStyle(fontWeight: FontWeight.w600)),
                              ]),
                            )),
                            const SizedBox(height: 8),
                          ],
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton(
                              onPressed: (_voterMpId == null || _votedMpId == null || s.mutating) ? null : _vote,
                              child: const Text('Votar'),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // ── 2. Placar ─────────────────────────────────────────
                    if (_isAdmin)
                      _SectionCard(
                        title: 'Placar',
                        child: Column(
                          children: [
                            Row(children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _scoreACtrl,
                                  keyboardType: TextInputType.number,
                                  decoration: InputDecoration(
                                    labelText: s.teamAColor?.name ?? 'Time A',
                                    border: const OutlineInputBorder(),
                                  ),
                                ),
                              ),
                              const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 12),
                                child: Text('×', style: TextStyle(fontSize: 20)),
                              ),
                              Expanded(
                                child: TextFormField(
                                  controller: _scoreBCtrl,
                                  keyboardType: TextInputType.number,
                                  decoration: InputDecoration(
                                    labelText: s.teamBColor?.name ?? 'Time B',
                                    border: const OutlineInputBorder(),
                                  ),
                                ),
                              ),
                            ]),
                            const SizedBox(height: 8),
                            if (s.teamAGoals != null && s.teamBGoals != null)
                              Text(
                                'Atual: ${s.teamAGoals} × ${s.teamBGoals}',
                                style: const TextStyle(color: AppColors.slate500, fontSize: 13),
                              ),
                            const SizedBox(height: 10),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton(
                                onPressed: s.mutating ? null : _saveScore,
                                child: const Text('Salvar Placar'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 12),

                    // ── 3. Gols ───────────────────────────────────────────
                    _SectionCard(
                      title: 'Gols da Partida',
                      child: s.goals.isEmpty
                          ? const Text('Nenhum gol registrado.', style: TextStyle(color: AppColors.slate400))
                          : Column(
                              children: s.goals.map((g) => GoalEntryRow(
                                goal:      g,
                                teamAName: s.teamAColor?.name ?? 'Time A',
                                teamBName: s.teamBColor?.name ?? 'Time B',
                                teamAColor: s.teamAColor?.color,
                                teamBColor: s.teamBColor?.color,
                                isAdmin:   _isAdmin,
                                onRemove:  _isAdmin
                                    ? () => ref.read(matchNotifierProvider.notifier).removeGoal(g.goalId)
                                    : null,
                              )).toList(),
                            ),
                    ),
                    const SizedBox(height: 80),
                  ],
                ),
              ),
            ),
          ),
          // ── Finalizar ─────────────────────────────────────────────────
          if (_isAdmin)
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: s.mutating ? null : _finalize,
                    icon: s.mutating
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.check_circle_outline),
                    label: const Text('Finalizar →'),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Card de seção ─────────────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;
  const _SectionCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) => Card(
    elevation: 1,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
          const Divider(height: 16),
          child,
        ],
      ),
    ),
  );
}

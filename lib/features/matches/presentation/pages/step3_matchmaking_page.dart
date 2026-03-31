import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../auth/presentation/providers/account_store.dart';
import '../../domain/entities/match_models.dart';
import '../providers/match_provider.dart';
import '../widgets/match_stepper_header.dart';
import '../widgets/team_column_card.dart';
import 'step4_jogo_page.dart';

const _kStrategies = [
  (id: 1, label: 'Manual'),
  (id: 2, label: 'Aleatório'),
  (id: 3, label: 'Algoritmo'),
  (id: 4, label: 'Por Vitórias'),
];

class Step3MatchmakingPage extends ConsumerStatefulWidget {
  const Step3MatchmakingPage({super.key});

  @override
  ConsumerState<Step3MatchmakingPage> createState() => _Step3State();
}

class _Step3State extends ConsumerState<Step3MatchmakingPage> {
  int _strategyType       = 3;
  int _playersPerTeam     = 6;
  bool _includeGoalkeepers = true;
  String? _selectedTeamAColorId;
  String? _selectedTeamBColorId;

  bool get _isAdmin {
    final acc = ref.read(accountStoreProvider).activeAccount;
    final gid = acc?.activeGroupId ?? '';
    return gid.isNotEmpty && (acc?.isGroupAdmin(gid) ?? false);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final s = ref.read(matchNotifierProvider);
      _selectedTeamAColorId = s.teamAColor?.id;
      _selectedTeamBColorId = s.teamBColor?.id;
      if (_selectedTeamAColorId == null && s.availableColors.isNotEmpty) {
        _selectedTeamAColorId = s.availableColors[0].id;
        _selectedTeamBColorId = s.availableColors.length > 1
            ? s.availableColors[1].id
            : s.availableColors[0].id;
      }
    });
  }

  Future<void> _confirmTeams() async {
    if (!_isAdmin) return;
    final s = ref.read(matchNotifierProvider);
    if (!s.teamsAssigned) return;

    await ref.read(matchNotifierProvider.notifier).startMatch();
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const Step4JogoPage()),
      );
    }
  }

  Future<void> _applyColors() async {
    if (_selectedTeamAColorId == null || _selectedTeamBColorId == null) return;
    await ref.read(matchNotifierProvider.notifier)
        .setColors(_selectedTeamAColorId!, _selectedTeamBColorId!);
  }

  @override
  Widget build(BuildContext context) {
    final s       = ref.watch(matchNotifierProvider);
    final colors  = s.availableColors;

    return Scaffold(
      appBar: AppBar(
        title: const Text('MatchMaking'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.read(matchNotifierProvider.notifier).refresh(),
          ),
        ],
      ),
      body: Column(
        children: [
          MatchStepperHeader(currentStep: MatchStep.teams),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => ref.read(matchNotifierProvider.notifier).refresh(),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_isAdmin) ...[
                      // ── Configurações de geração ──────────────────────────
                      _SectionCard(
                        title: 'Configurações',
                        child: Column(
                          children: [
                            DropdownButtonFormField<int>(
                              value: _strategyType,
                              decoration: const InputDecoration(labelText: 'Algoritmo', border: OutlineInputBorder()),
                              items: _kStrategies.map((s) => DropdownMenuItem(value: s.id, child: Text(s.label))).toList(),
                              onChanged: (v) => setState(() => _strategyType = v ?? 3),
                            ),
                            const SizedBox(height: 12),
                            Row(children: [
                              const Text('Players/Time:'),
                              const SizedBox(width: 12),
                              IconButton(
                                icon: const Icon(Icons.remove_circle_outline),
                                onPressed: _playersPerTeam > 1
                                    ? () => setState(() => _playersPerTeam--)
                                    : null,
                              ),
                              Text('$_playersPerTeam', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
                              IconButton(
                                icon: const Icon(Icons.add_circle_outline),
                                onPressed: () => setState(() => _playersPerTeam++),
                              ),
                              const Spacer(),
                              const Text('Goleiros'),
                              Switch(
                                value: _includeGoalkeepers,
                                onChanged: (v) => setState(() => _includeGoalkeepers = v),
                              ),
                            ]),
                            const SizedBox(height: 8),
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton.icon(
                                onPressed: s.mutating ? null : () =>
                                    ref.read(matchNotifierProvider.notifier).generateTeams(
                                      strategyType:       _strategyType,
                                      playersPerTeam:     _playersPerTeam,
                                      includeGoalkeepers: _includeGoalkeepers,
                                    ),
                                icon: const Icon(Icons.auto_awesome),
                                label: const Text('Gerar Times'),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      // ── Seleção de cores ──────────────────────────────────
                      if (colors.isNotEmpty)
                        _SectionCard(
                          title: 'Cores dos Times',
                          child: Row(
                            children: [
                              Expanded(child: _ColorPicker(
                                label: 'Time A',
                                colors: colors,
                                selectedId: _selectedTeamAColorId,
                                onChanged: (id) => setState(() => _selectedTeamAColorId = id),
                              )),
                              const SizedBox(width: 12),
                              Expanded(child: _ColorPicker(
                                label: 'Time B',
                                colors: colors,
                                selectedId: _selectedTeamBColorId,
                                onChanged: (id) => setState(() => _selectedTeamBColorId = id),
                              )),
                            ],
                          ),
                        ),
                      const SizedBox(height: 8),
                      Row(children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => ref.read(matchNotifierProvider.notifier).setColorsRandom(),
                            icon: const Icon(Icons.shuffle, size: 16),
                            label: const Text('Aleatório'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: FilledButton.tonal(
                            onPressed: _applyColors,
                            child: const Text('Aplicar Cores'),
                          ),
                        ),
                      ]),
                      const SizedBox(height: 16),
                    ],

                    // ── Times gerados / atribuídos ────────────────────────
                    if (s.teamGenOptions.isNotEmpty) ...[
                      _TeamGenCarousel(
                        options: s.teamGenOptions,
                        selectedIdx: s.selectedTeamGenIdx,
                        onSelect: (i) => ref.read(matchNotifierProvider.notifier).selectTeamGenOption(i),
                        teamAColor: s.teamAColor,
                        teamBColor: s.teamBColor,
                        isAdmin: _isAdmin,
                      ),
                      const SizedBox(height: 12),
                      if (_isAdmin)
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: s.mutating ? null : () =>
                                ref.read(matchNotifierProvider.notifier).assignTeamsFromGenerated(),
                            icon: const Icon(Icons.check),
                            label: const Text('Confirmar Geração'),
                          ),
                        ),
                      const SizedBox(height: 16),
                    ] else if (s.teamsAssigned) ...[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: TeamColumnCard(
                            teamLabel: 'TIME A',
                            color: s.teamAColor,
                            players: s.teamAPlayers,
                            isAdmin: _isAdmin,
                            loading: s.mutating,
                            onMoveToOther: _isAdmin
                                ? (id) => ref.read(matchNotifierProvider.notifier).movePlayerToOtherTeam(id, true)
                                : null,
                          )),
                          const SizedBox(width: 8),
                          Expanded(child: TeamColumnCard(
                            teamLabel: 'TIME B',
                            color: s.teamBColor,
                            players: s.teamBPlayers,
                            isAdmin: _isAdmin,
                            loading: s.mutating,
                            onMoveToOther: _isAdmin
                                ? (id) => ref.read(matchNotifierProvider.notifier).movePlayerToOtherTeam(id, false)
                                : null,
                          )),
                        ],
                      ),
                    ] else ...[
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 32),
                          child: Text(
                            _isAdmin
                                ? 'Clique em "Gerar Times" para ver as opções de sorteio.'
                                : 'Aguardando o admin montar os times.',
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: AppColors.slate400),
                          ),
                        ),
                      ),
                    ],

                    // ── Jogadores sem time ─────────────────────────────────
                    if (s.unassignedPlayers.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text('Sem time (${s.unassignedPlayers.length})',
                          style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.slate500)),
                      ...s.unassignedPlayers.map((p) => ListTile(
                        dense: true,
                        title: Text(p.playerName),
                        trailing: _isAdmin ? Row(mainAxisSize: MainAxisSize.min, children: [
                          TextButton(onPressed: () => ref.read(matchNotifierProvider.notifier).assignUnassigned(p.playerId, true), child: const Text('A')),
                          TextButton(onPressed: () => ref.read(matchNotifierProvider.notifier).assignUnassigned(p.playerId, false), child: const Text('B')),
                        ]) : null,
                      )),
                    ],

                    const SizedBox(height: 80),
                  ],
                ),
              ),
            ),
          ),
          // Botão Iniciar Jogo
          if (_isAdmin && s.teamsAssigned)
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: s.mutating ? null : _confirmTeams,
                    icon: s.mutating
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.play_arrow),
                    label: const Text('Iniciar Jogo →'),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Carrossel de opções geradas ───────────────────────────────────────────────

class _TeamGenCarousel extends StatelessWidget {
  final List<TeamGenOption> options;
  final int selectedIdx;
  final void Function(int) onSelect;
  final TeamColorInfo? teamAColor;
  final TeamColorInfo? teamBColor;
  final bool isAdmin;

  const _TeamGenCarousel({
    required this.options, required this.selectedIdx, required this.onSelect,
    this.teamAColor, this.teamBColor, required this.isAdmin,
  });

  @override
  Widget build(BuildContext context) {
    final opt = options[selectedIdx.clamp(0, options.length - 1)];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          const Text('Opção:', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(width: 8),
          ...List.generate(options.length, (i) => GestureDetector(
            onTap: () => onSelect(i),
            child: Container(
              margin: const EdgeInsets.only(right: 6),
              width: 32, height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: i == selectedIdx ? Theme.of(context).colorScheme.primary : AppColors.slate200,
              ),
              child: Center(child: Text('${i + 1}', style: TextStyle(color: i == selectedIdx ? Colors.white : AppColors.slate600, fontWeight: FontWeight.w600))),
            ),
          )),
          const Spacer(),
          Text(
            'Δ ${(opt.balanceDiff * 100).toStringAsFixed(1)}%',
            style: TextStyle(
              fontSize: 12,
              color: opt.balanceDiff < 0.05 ? AppColors.emerald500 : AppColors.amber500,
            ),
          ),
        ]),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: TeamColumnCard(
              teamLabel: 'TIME A', color: teamAColor,
              players: opt.teamA.map((p) => MatchPlayerInfo(
                matchPlayerId: p.playerId, playerId: p.playerId,
                playerName: p.name, isGoalkeeper: p.isGoalkeeper,
                isGuest: false, team: 1, inviteResponse: InviteResponse.accepted,
              )).toList(),
              isAdmin: false,
            )),
            const SizedBox(width: 8),
            Expanded(child: TeamColumnCard(
              teamLabel: 'TIME B', color: teamBColor,
              players: opt.teamB.map((p) => MatchPlayerInfo(
                matchPlayerId: p.playerId, playerId: p.playerId,
                playerName: p.name, isGoalkeeper: p.isGoalkeeper,
                isGuest: false, team: 2, inviteResponse: InviteResponse.accepted,
              )).toList(),
              isAdmin: false,
            )),
          ],
        ),
      ],
    );
  }
}

// ── Seletor de cor ────────────────────────────────────────────────────────────

class _ColorPicker extends StatelessWidget {
  final String label;
  final List<TeamColorInfo> colors;
  final String? selectedId;
  final void Function(String) onChanged;

  const _ColorPicker({required this.label, required this.colors, this.selectedId, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6, runSpacing: 6,
          children: colors.take(6).map((c) {
            final isSelected = c.id == selectedId;
            return GestureDetector(
              onTap: () => onChanged(c.id),
              child: Tooltip(
                message: c.name,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 32, height: 32,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: c.color,
                        border: Border.all(
                          color: isSelected ? Colors.black : AppColors.slate300,
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                    ),
                    if (isSelected)
                      const Icon(Icons.check, size: 16, color: Colors.white),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
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
          const SizedBox(height: 12),
          child,
        ],
      ),
    ),
  );
}

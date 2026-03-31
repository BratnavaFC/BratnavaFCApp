import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../auth/presentation/providers/account_store.dart';
import '../../domain/entities/match_models.dart';
import '../providers/match_provider.dart';
import '../widgets/match_stepper_header.dart';
import '../widgets/player_list_tile.dart';
import 'step3_matchmaking_page.dart';

class Step2AceitacaoPage extends ConsumerStatefulWidget {
  const Step2AceitacaoPage({super.key});

  @override
  ConsumerState<Step2AceitacaoPage> createState() => _Step2State();
}

class _Step2State extends ConsumerState<Step2AceitacaoPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  bool get _isAdmin {
    final acc = ref.read(accountStoreProvider).activeAccount;
    final gid = acc?.activeGroupId ?? '';
    return gid.isNotEmpty && (acc?.isGroupAdmin(gid) ?? false);
  }

  String get _myPlayerId =>
      ref.read(accountStoreProvider).activeAccount?.activePlayerId ?? '';

  Future<void> _goNext() async {
    if (!_isAdmin) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Avançar para MatchMaking?'),
        content: const Text('Os jogadores aceitos serão usados para montar os times.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Avançar')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await ref.read(matchNotifierProvider.notifier).goToMatchmaking();
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const Step3MatchmakingPage()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final s         = ref.watch(matchNotifierProvider);
    final accepted  = s.acceptedPlayers;
    final rejected  = s.rejectedPlayers;
    final pending   = s.pendingPlayers;
    final pct       = s.maxPlayers > 0 ? accepted.length / s.maxPlayers : 0.0;
    final fmt       = DateFormat('dd/MM/yyyy HH:mm', 'pt_BR');
    final dateStr   = s.playedAt != null ? fmt.format(s.playedAt!.toLocal()) : '—';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Aceitação'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Recarregar',
            onPressed: () => ref.read(matchNotifierProvider.notifier).refresh(),
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          tabs: [
            Tab(text: 'Aceitos (${accepted.length})'),
            Tab(text: 'Recusados (${rejected.length})'),
            Tab(text: 'Pendentes (${pending.length})'),
          ],
        ),
      ),
      body: Column(
        children: [
          MatchStepperHeader(currentStep: MatchStep.accept),
          // Card de resumo
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Card(
              elevation: 1,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(dateStr, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                              Text(s.placeName ?? '—', style: const TextStyle(fontSize: 12, color: AppColors.slate500)),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '${accepted.length}/${s.maxPlayers}',
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                            ),
                            if (pending.isNotEmpty)
                              Text('Pendentes: ${pending.length}',
                                  style: const TextStyle(fontSize: 11, color: AppColors.amber500)),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: pct.clamp(0.0, 1.0),
                      backgroundColor: AppColors.slate200,
                      color: pct >= 1.0 ? AppColors.emerald500 : AppColors.blue500,
                      minHeight: 6,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Tabs
          Expanded(
            child: s.mutating
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(
                    controller: _tabs,
                    children: [
                      _PlayerTab(
                        players: accepted,
                        myPlayerId: _myPlayerId,
                        isAdmin: _isAdmin,
                        highlight: AppColors.emerald50,
                        onRemove: (p) => ref.read(matchNotifierProvider.notifier).rejectInvite(p.playerId),
                      ),
                      _PlayerTab(
                        players: rejected,
                        myPlayerId: _myPlayerId,
                        isAdmin: _isAdmin,
                        highlight: AppColors.rose50,
                        onAccept: (p) => ref.read(matchNotifierProvider.notifier).acceptInvite(p.playerId),
                      ),
                      _PlayerTab(
                        players: pending,
                        myPlayerId: _myPlayerId,
                        isAdmin: _isAdmin,
                        onAccept: (p) {
                          // Usuário aceita sua própria invitação
                          if (p.playerId == _myPlayerId) {
                            ref.read(matchNotifierProvider.notifier).acceptInvite(p.playerId);
                          }
                        },
                        onRemove: (p) => ref.read(matchNotifierProvider.notifier).rejectInvite(p.playerId),
                      ),
                    ],
                  ),
          ),
          // Botão Próximo (admin)
          if (_isAdmin)
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: s.mutating ? null : _goNext,
                    icon: s.mutating
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.arrow_forward),
                    label: const Text('Próximo →'),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _PlayerTab extends StatelessWidget {
  final List<MatchPlayerInfo> players;
  final String myPlayerId;
  final bool isAdmin;
  final Color? highlight;
  final void Function(MatchPlayerInfo p)? onAccept;
  final void Function(MatchPlayerInfo p)? onRemove;

  const _PlayerTab({
    required this.players,
    required this.myPlayerId,
    required this.isAdmin,
    this.highlight,
    this.onAccept,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    if (players.isEmpty) {
      return const Center(
        child: Text('Nenhum jogador nessa categoria.', style: TextStyle(color: AppColors.slate400)),
      );
    }
    return RefreshIndicator(
      onRefresh: () async {},
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        itemCount: players.length,
        itemBuilder: (_, i) {
          final p = players[i];
          final isMe = p.playerId == myPlayerId;
          return PlayerListTile(
            player:        p,
            isCurrentUser: isMe,
            isAdmin:       isAdmin,
            highlightColor: highlight?.withValues(alpha: 0.5),
            onAccept: (isMe || isAdmin) && onAccept != null ? () => onAccept!(p) : null,
            onRemove: isAdmin && onRemove != null          ? () => onRemove!(p) : null,
          );
        },
      ),
    );
  }
}

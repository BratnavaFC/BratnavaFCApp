import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/date_utils.dart';
import '../../domain/entities/bet_models.dart';
import '../providers/bet_provider.dart';
import '../../../../core/errors/app_exception.dart';

class CurrentBetTab extends ConsumerStatefulWidget {
  final String groupId;
  const CurrentBetTab({super.key, required this.groupId});

  @override
  ConsumerState<CurrentBetTab> createState() => _CurrentBetTabState();
}

class _CurrentBetTabState extends ConsumerState<CurrentBetTab> {
  CurrentMatchBetContext? _ctx;
  int?                    _balance;
  bool                    _loading          = true;
  bool                    _saving           = false;
  bool                    _deleting         = false;
  bool                    _confirmDelete    = false;
  bool                    _showPlayerStatus = false;
  String?                 _error;

  List<SelectionFormState> _selections = const [
    SelectionFormState(category: 'WinningTeam', fichasWagered: 50),
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  // ── Load ──────────────────────────────────────────────────────────────────

  Future<void> _load() async {
    if (!mounted) return;
    setState(() { _loading = true; _error = null; });

    final ds = ref.read(betDsProvider);
    try {
      final results = await Future.wait([
        ds.fetchCurrent(widget.groupId),
        ds.fetchBalance(widget.groupId),
      ]);
      if (!mounted) return;
      final ctx     = results[0] as CurrentMatchBetContext?;
      final balance = (results[1] as int?) ?? 0;
      setState(() {
        _loading = false;
        _ctx     = ctx;
        _balance = balance;
        if (ctx?.myBet?.selections.isNotEmpty == true) {
          _selections = ctx!.myBet!.selections.map(_fromDto).toList();
        } else if (ctx?.myBet == null) {
          // Reset to default when no existing bet
          _selections = const [
            SelectionFormState(category: 'WinningTeam', fichasWagered: 50),
          ];
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _loading = false; _error = extractDioError(e); });
    }
  }

  // ── Parse existing bet selections ─────────────────────────────────────────

  SelectionFormState _fromDto(BetSelectionDto s) {
    switch (s.category) {
      case 'WinningTeam':
        return SelectionFormState(
          category: s.category,
          fichasWagered: s.fichasWagered,
          winTeam: s.predictedValue,
        );
      case 'FinalScore':
        final p = s.predictedValue.split(':');
        return SelectionFormState(
          category: s.category,
          fichasWagered: s.fichasWagered,
          scoreA: int.tryParse(p.isNotEmpty ? p[0] : '0') ?? 0,
          scoreB: int.tryParse(p.length > 1  ? p[1] : '0') ?? 0,
        );
      case 'PlayerGoals':
      case 'PlayerAssists':
        final p = s.predictedValue.split('|');
        return SelectionFormState(
          category: s.category,
          fichasWagered: s.fichasWagered,
          playerMatchId: p.isNotEmpty ? p[0] : null,
          playerCount:   int.tryParse(p.length > 1 ? p[1] : '0') ?? 0,
        );
      default:
        return SelectionFormState(category: s.category, fichasWagered: s.fichasWagered);
    }
  }

  // ── Selections management ─────────────────────────────────────────────────

  void _updateSelection(int i, SelectionFormState updated) {
    setState(() {
      final list = List<SelectionFormState>.from(_selections);
      list[i] = updated;
      _selections = list;
    });
  }

  void _removeSelection(int i) {
    setState(() {
      final list = List<SelectionFormState>.from(_selections);
      list.removeAt(i);
      _selections = list;
    });
  }

  void _addCategory(String cat) {
    if (_selections.length >= 5) return;
    setState(() {
      _selections = [
        ..._selections,
        SelectionFormState(category: cat, fichasWagered: 30),
      ];
    });
  }

  // ── Submit ────────────────────────────────────────────────────────────────

  Future<void> _submit() async {
    // Validate each selection
    final invalid = _selections.indexWhere((s) => !s.isValid);
    if (invalid >= 0) {
      final cat = _selections[invalid].category;
      _showSnack(
        'Seleção incompleta: ${kCategoryLabels[cat] ?? cat}',
        error: true,
      );
      return;
    }
    // Validate total wager
    final total = _selections.fold(0, (s, sel) => s + sel.fichasWagered);
    if (total > kMaxWager) {
      _showSnack('Máximo $kMaxWager BC por partida. Total: $total', error: true);
      return;
    }

    final ctx = _ctx;
    if (ctx == null) return;

    setState(() => _saving = true);
    try {
      final dto = PlaceMatchBetDto(
        selections: _selections.map((s) => s.toDto()).toList(),
      );
      await ref.read(betDsProvider).placeOrUpdateBet(
          widget.groupId, ctx.matchId, dto);
      if (mounted) {
        _showSnack(ctx.myBet != null ? 'Aposta atualizada!' : 'Aposta registrada!');
        _load();
      }
    } catch (e) {
      if (mounted) _showSnack('Erro ao salvar: $e', error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ── Delete ────────────────────────────────────────────────────────────────

  Future<void> _delete() async {
    final ctx = _ctx;
    if (ctx == null) return;
    setState(() { _deleting = true; _confirmDelete = false; });
    try {
      await ref.read(betDsProvider).deleteBet(widget.groupId, ctx.matchId);
      if (mounted) {
        _showSnack('Aposta removida.');
        setState(() {
          _selections = const [
            SelectionFormState(category: 'WinningTeam', fichasWagered: 50),
          ];
        });
        _load();
      }
    } catch (e) {
      if (mounted) _showSnack('Erro ao remover: $e', error: true);
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  void _showSnack(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? AppColors.rose500 : null,
      behavior: SnackBarBehavior.floating,
    ));
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_loading) {
      return const Center(child: Padding(
        padding: EdgeInsets.all(48),
        child: CircularProgressIndicator(),
      ));
    }

    if (_error != null) {
      return Center(child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.error_outline, size: 40, color: AppColors.rose500),
          const SizedBox(height: 12),
          Text('Erro ao carregar apostas', style: TextStyle(
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : AppColors.slate900,
          )),
          const SizedBox(height: 6),
          Text(_error!, style: const TextStyle(color: AppColors.slate500, fontSize: 12),
              textAlign: TextAlign.center),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _load,
            icon: const Icon(Icons.refresh),
            label: const Text('Tentar novamente'),
          ),
        ]),
      ));
    }

    final ctx = _ctx;

    if (ctx == null) {
      return _EmptyMatchState(isDark: isDark);
    }

    final isLocked    = !ctx.betWindowOpen;
    final totalWager  = _selections.fold(0, (s, sel) => s + sel.fichasWagered);
    final overMax     = totalWager > kMaxWager;
    final members     = ctx.players.where((p) => !p.isGuest).toList();
    final betCount    = members.where((p) => p.hasBet).length;
    final hasExisting = ctx.myBet != null;

    // Available categories to add
    final usedCats  = _selections.map((s) => s.category).toSet();
    final availCats = <String>[];
    if (!usedCats.contains('FinalScore'))    availCats.add('FinalScore');
    if (_selections.length < 5)             availCats.addAll(['PlayerGoals', 'PlayerAssists']);

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [

          // ── Player status card ────────────────────────────────────────────
          _PlayerStatusCard(
            members:    members,
            betCount:   betCount,
            playedAt:   ctx.playedAt,
            statusName: ctx.statusName,
            balance:    _balance,
            isExpanded: _showPlayerStatus,
            onToggle:   () => setState(() => _showPlayerStatus = !_showPlayerStatus),
            isDark:     isDark,
            onRefresh:  _load,
          ),
          const SizedBox(height: 12),

          // ── Window closed warning ─────────────────────────────────────────
          if (isLocked) ...[
            _LockedBanner(isDark: isDark),
            const SizedBox(height: 12),
          ],

          if (isLocked && !hasExisting) ...[
            _NoBetLockedState(isDark: isDark),
            const SizedBox(height: 12),
          ],

          // ── Selection cards ───────────────────────────────────────────────
          if (hasExisting || !isLocked)
            for (var i = 0; i < _selections.length; i++) ...[
              _SelectionCard(
                sel:       _selections[i],
                index:     i,
                players:   ctx.players,
                locked:    isLocked,
                canRemove: !isLocked && i > 0,
                winnerHint: _selections.any((s) => s.category == 'WinningTeam')
                    ? _selections.firstWhere(
                        (s) => s.category == 'WinningTeam').winTeam
                    : null,
                isDark:    isDark,
                onUpdate:  (updated) => _updateSelection(i, updated),
                onRemove:  () => _removeSelection(i),
              ),
              const SizedBox(height: 10),
            ],

          // ── Add category buttons ──────────────────────────────────────────
          if (!isLocked && availCats.isNotEmpty && _selections.length < 5) ...[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: availCats.map((cat) => _AddCatBtn(
                label: '+ ${kCategoryLabels[cat] ?? cat}',
                isDark: isDark,
                onTap:  () => _addCategory(cat),
              )).toList(),
            ),
            const SizedBox(height: 16),
          ],

          // ── Total + submit ────────────────────────────────────────────────
          if (!isLocked) ...[
            const Divider(),
            const SizedBox(height: 8),
            Row(children: [
              Text(
                'Total: ',
                style: TextStyle(fontSize: 13,
                    color: isDark ? AppColors.slate400 : AppColors.slate500),
              ),
              Text(
                '$totalWager / $kMaxWager BC',
                style: TextStyle(
                  fontSize:   14,
                  fontWeight: FontWeight.w700,
                  color:      overMax ? AppColors.rose500
                      : (isDark ? Colors.white : AppColors.slate900),
                ),
              ),
              const Spacer(),
              // Delete / confirm-delete
              if (hasExisting)
                _confirmDelete
                    ? Row(mainAxisSize: MainAxisSize.min, children: [
                        Text('Resetar?',
                            style: const TextStyle(
                                fontSize: 12, color: AppColors.rose500)),
                        const SizedBox(width: 8),
                        _SmallBtn(
                          label: 'Não',
                          onTap: () => setState(() => _confirmDelete = false),
                          isDark: isDark,
                        ),
                        const SizedBox(width: 6),
                        _SmallBtn(
                          label: _deleting ? '…' : 'Sim',
                          onTap: _deleting ? null : _delete,
                          danger: true,
                          isDark: isDark,
                        ),
                      ])
                    : TextButton.icon(
                        onPressed: () => setState(() => _confirmDelete = true),
                        icon:  const Icon(Icons.close, size: 14,
                            color: AppColors.rose500),
                        label: const Text('Resetar',
                            style: TextStyle(
                                fontSize: 12, color: AppColors.rose500)),
                        style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4)),
                      ),
              const SizedBox(width: 8),
              // Submit
              ElevatedButton.icon(
                onPressed: (_saving || overMax) ? null : _submit,
                icon:  _saving
                    ? const SizedBox(width: 14, height: 14,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.check, size: 15),
                label: Text(hasExisting ? 'Atualizar' : 'Apostar',
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w700)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDark ? Colors.white : AppColors.slate900,
                  foregroundColor: isDark ? AppColors.slate900 : Colors.white,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ]),
            const SizedBox(height: 24),
          ],
        ],
      ),
    );
  }
}

// ── Player status card ────────────────────────────────────────────────────────

class _PlayerStatusCard extends StatelessWidget {
  final List<BetPlayer> members;
  final int             betCount;
  final String          playedAt;
  final String          statusName;
  final int?            balance;
  final bool            isExpanded;
  final VoidCallback    onToggle;
  final VoidCallback    onRefresh;
  final bool            isDark;

  const _PlayerStatusCard({
    required this.members,
    required this.betCount,
    required this.playedAt,
    required this.statusName,
    required this.balance,
    required this.isExpanded,
    required this.onToggle,
    required this.onRefresh,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = isDark ? AppColors.slate700 : AppColors.slate200;
    final bgColor     = isDark ? AppColors.slate800 : Colors.white;

    String fmtDate(String raw) {
      try {
        final d = AppDateUtils.parseOrNow(raw);
        return '${d.day.toString().padLeft(2, '0')}/'
            '${d.month.toString().padLeft(2, '0')}/'
            '${d.year}';
      } catch (_) { return raw; }
    }

    return Container(
      decoration: BoxDecoration(
        color:        bgColor,
        borderRadius: BorderRadius.circular(16),
        border:       Border.all(color: borderColor),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: [
        // Header row (tappable)
        InkWell(
          onTap: onToggle,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(children: [
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$betCount de ${members.length} jogador${members.length != 1 ? "es" : ""} já '
                    '${betCount != 1 ? "fizeram" : "fez"} sua aposta',
                    style: TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : AppColors.slate900,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${fmtDate(playedAt)} · $statusName',
                    style: TextStyle(fontSize: 11,
                        color: isDark ? AppColors.slate400 : AppColors.slate500),
                  ),
                ],
              )),
              if (balance != null) ...[
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text('Saldo', style: TextStyle(
                    fontSize: 9, letterSpacing: 0.8,
                    color: isDark ? AppColors.slate400 : AppColors.slate500,
                  )),
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.monetization_on_outlined,
                        size: 13, color: AppColors.amber400),
                    const SizedBox(width: 3),
                    Text('$balance', style: TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w700,
                      color: fichasColor(balance),
                    )),
                  ]),
                ]),
                const SizedBox(width: 8),
              ],
              IconButton(
                icon: const Icon(Icons.refresh, size: 16),
                onPressed: onRefresh,
                padding: EdgeInsets.zero,
                color: isDark ? AppColors.slate400 : AppColors.slate500,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              ),
              const SizedBox(width: 2),
              Icon(
                isExpanded
                    ? Icons.keyboard_arrow_up_rounded
                    : Icons.keyboard_arrow_down_rounded,
                size: 20,
                color: isDark ? AppColors.slate400 : AppColors.slate500,
              ),
            ]),
          ),
        ),
        // Expanded player list
        if (isExpanded) ...[
          Divider(height: 1, color: isDark ? AppColors.slate700 : AppColors.slate100),
          for (final p in members)
            Container(
              decoration: BoxDecoration(border: Border(bottom: BorderSide(
                color: isDark ? AppColors.slate700.withValues(alpha: .5)
                    : AppColors.slate50, width: 0.5))),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(children: [
                Expanded(child: Text(p.name,
                    style: TextStyle(fontSize: 13,
                        color: isDark ? AppColors.slate300 : AppColors.slate700))),
                if (p.hasBet)
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.check_rounded, size: 14,
                        color: Color(0xFF34D399)),
                    const SizedBox(width: 4),
                    Text('Apostou', style: const TextStyle(
                        fontSize: 11, fontWeight: FontWeight.w600,
                        color: Color(0xFF34D399))),
                    if (p.totalFichasWagered != null) ...[
                      Text(' · ${p.totalFichasWagered} BC',
                          style: TextStyle(fontSize: 11,
                              color: isDark ? AppColors.slate400 : AppColors.slate500)),
                    ],
                  ])
                else
                  Text('Aguardando…',
                      style: TextStyle(fontSize: 11,
                          color: isDark ? AppColors.slate500 : AppColors.slate400)),
              ]),
            ),
        ],
      ]),
    );
  }
}

// ── SelectionCard ─────────────────────────────────────────────────────────────

class _SelectionCard extends StatelessWidget {
  final SelectionFormState sel;
  final int                index;
  final List<BetPlayer>    players;
  final bool               locked;
  final bool               canRemove;
  final String?            winnerHint;
  final bool               isDark;
  final ValueChanged<SelectionFormState> onUpdate;
  final VoidCallback       onRemove;

  const _SelectionCard({
    required this.sel,
    required this.index,
    required this.players,
    required this.locked,
    required this.canRemove,
    required this.isDark,
    required this.onUpdate,
    required this.onRemove,
    this.winnerHint,
  });

  bool _scoreConsistent(String? winner, int? a, int? b) {
    if (winner == null || a == null || b == null) return true;
    if (winner == 'TeamA') return a > b;
    if (winner == 'TeamB') return b > a;
    if (winner == 'Draw')  return a == b;
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final borderColor  = isDark ? AppColors.slate700 : AppColors.slate200;
    final bgColor      = isDark ? AppColors.slate800.withValues(alpha: .5) : Colors.white;
    final labelStyle   = TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
        letterSpacing: 0.8,
        color: isDark ? AppColors.slate400 : AppColors.slate500);
    final subStyle     = TextStyle(fontSize: 10, color: isDark
        ? AppColors.slate500 : AppColors.slate400);
    final isMandatory  = sel.category == 'WinningTeam';

    return Container(
      decoration: BoxDecoration(
        color:        bgColor,
        borderRadius: BorderRadius.circular(16),
        border:       Border.all(color: borderColor),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // ── Header ─────────────────────────────────────────────────────────
        Row(children: [
          Text('#${index + 1}', style: TextStyle(fontSize: 10,
              fontWeight: FontWeight.w900, letterSpacing: 0.8,
              color: isDark ? AppColors.slate500 : AppColors.slate400)),
          const SizedBox(width: 8),
          Text(kCategoryLabels[sel.category] ?? sel.category,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : AppColors.slate900)),
          if (isMandatory) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color:        AppColors.rose500.withValues(alpha: .1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text('obrigatório',
                  style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700,
                      color: AppColors.rose500)),
            ),
          ],
          const Spacer(),
          if (canRemove)
            GestureDetector(
              onTap: onRemove,
              child: Icon(Icons.close, size: 16,
                  color: isDark ? AppColors.slate400 : AppColors.slate500),
            ),
        ]),
        const SizedBox(height: 4),
        Text(kCategoryMultipliers[sel.category] ?? '', style: subStyle),
        const SizedBox(height: 12),

        // ── Input area ─────────────────────────────────────────────────────
        if (sel.category == 'WinningTeam') _buildWinningTeam(labelStyle),
        if (sel.category == 'FinalScore')  _buildFinalScore(labelStyle),
        if (sel.category == 'PlayerGoals' ||
            sel.category == 'PlayerAssists')
          _buildPlayerCategory(labelStyle),

        // ── Wager ──────────────────────────────────────────────────────────
        const SizedBox(height: 12),
        Divider(height: 1, color: isDark ? AppColors.slate700 : AppColors.slate100),
        const SizedBox(height: 10),
        Row(children: [
          const Icon(Icons.monetization_on_outlined,
              size: 14, color: AppColors.amber400),
          const SizedBox(width: 6),
          Text('Bratnava Coins:', style: subStyle),
          const Spacer(),
          _NumberStepper(
            value:    sel.fichasWagered,
            min:      30,
            max:      kMaxWager,
            step:     10,
            disabled: locked,
            isDark:   isDark,
            onChange: (v) => onUpdate(sel.copyWith(fichasWagered: v)),
          ),
        ]),
      ]),
    );
  }

  Widget _buildWinningTeam(TextStyle labelStyle) {
    const opts = [
      ('TeamA', 'Time A'),
      ('Draw',  'Empate'),
      ('TeamB', 'Time B'),
    ];
    return Row(children: opts.map((opt) {
      final active = sel.winTeam == opt.$1;
      return Expanded(child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3),
        child: GestureDetector(
          onTap: locked ? null : () => onUpdate(sel.copyWith(winTeam: opt.$1)),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: active
                  ? (isDark ? Colors.white : AppColors.slate900)
                  : (locked
                      ? (isDark ? AppColors.slate800 : AppColors.slate50)
                      : (isDark ? AppColors.slate700 : AppColors.slate50)),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: active
                    ? (isDark ? Colors.white : AppColors.slate900)
                    : (isDark ? AppColors.slate600 : AppColors.slate200),
              ),
            ),
            child: Center(child: Text(opt.$2,
                style: TextStyle(
                  fontSize:   12,
                  fontWeight: FontWeight.w600,
                  color: active
                      ? (isDark ? AppColors.slate900 : Colors.white)
                      : (isDark ? AppColors.slate300 : AppColors.slate600),
                ))),
          ),
        ),
      ));
    }).toList());
  }

  Widget _buildFinalScore(TextStyle labelStyle) {
    final inconsistent = sel.category == 'FinalScore' &&
        !_scoreConsistent(winnerHint, sel.scoreA, sel.scoreB);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(child: Column(children: [
          Text('Time A', style: labelStyle),
          const SizedBox(height: 6),
          _NumberStepper(
            value:    sel.scoreA ?? 0,
            min:      0,
            max:      20,
            step:     1,
            size:     _StepperSize.large,
            disabled: locked,
            isDark:   isDark,
            onChange: (v) => onUpdate(sel.copyWith(scoreA: v)),
          ),
        ])),
        Padding(
          padding: const EdgeInsets.only(top: 20),
          child: Text(' × ',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900,
                  color: isDark ? AppColors.slate400 : AppColors.slate400)),
        ),
        Expanded(child: Column(children: [
          Text('Time B', style: labelStyle),
          const SizedBox(height: 6),
          _NumberStepper(
            value:    sel.scoreB ?? 0,
            min:      0,
            max:      20,
            step:     1,
            size:     _StepperSize.large,
            disabled: locked,
            isDark:   isDark,
            onChange: (v) => onUpdate(sel.copyWith(scoreB: v)),
          ),
        ])),
      ]),
      if (inconsistent) ...[
        const SizedBox(height: 8),
        Row(children: [
          const Text('⚠️', style: TextStyle(fontSize: 12)),
          const SizedBox(width: 6),
          Flexible(child: Text(
            winnerHint == 'Draw'
                ? 'Placar inconsistente: empate exige gols iguais.'
                : 'Placar inconsistente com o time vencedor.',
            style: const TextStyle(
                fontSize: 11, fontWeight: FontWeight.w600,
                color: Color(0xFFD97706)),
          )),
        ]),
      ],
    ]);
  }

  Widget _buildPlayerCategory(TextStyle labelStyle) {
    final elgPlayers = players.where((p) => p.team != 0).toList();
    final isGoals    = sel.category == 'PlayerGoals';
    final hintLabel  = isGoals ? 'Gols previstos' : 'Assistências previstas';

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Player dropdown
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color:        isDark ? AppColors.slate800 : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: isDark ? AppColors.slate600 : AppColors.slate200),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value:         sel.playerMatchId,
            isExpanded:    true,
            hint:          Text('Selecione um jogador…',
                style: TextStyle(fontSize: 13,
                    color: isDark ? AppColors.slate500 : AppColors.slate400)),
            dropdownColor: isDark ? AppColors.slate800 : Colors.white,
            onChanged: locked ? null : (v) =>
                onUpdate(sel.copyWith(playerMatchId: v)),
            items: [
              for (final p in elgPlayers)
                DropdownMenuItem(
                  value: p.matchPlayerId,
                  child: Text(
                    '${p.name} (${p.team == 1 ? "Time A" : "Time B"})',
                    style: TextStyle(fontSize: 13,
                        color: isDark ? Colors.white : AppColors.slate900),
                  ),
                ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 10),
      // Count stepper
      Row(children: [
        Text('$hintLabel:', style: TextStyle(fontSize: 12,
            color: isDark ? AppColors.slate400 : AppColors.slate500)),
        const Spacer(),
        _NumberStepper(
          value:    sel.playerCount ?? 0,
          min:      0,
          max:      20,
          step:     1,
          size:     _StepperSize.small,
          disabled: locked,
          isDark:   isDark,
          onChange: (v) => onUpdate(sel.copyWith(playerCount: v)),
        ),
      ]),
    ]);
  }
}

// ── NumberStepper ─────────────────────────────────────────────────────────────

enum _StepperSize { small, medium, large }

class _NumberStepper extends StatelessWidget {
  final int          value;
  final int          min;
  final int          max;
  final int          step;
  final bool         disabled;
  final bool         isDark;
  final ValueChanged<int> onChange;
  final _StepperSize size;

  const _NumberStepper({
    required this.value,
    required this.min,
    required this.max,
    required this.step,
    required this.disabled,
    required this.isDark,
    required this.onChange,
    this.size = _StepperSize.medium,
  });

  double get _btnSize => switch (size) {
    _StepperSize.small  => 28,
    _StepperSize.medium => 34,
    _StepperSize.large  => 40,
  };

  double get _fontSize => switch (size) {
    _StepperSize.small  => 12,
    _StepperSize.medium => 14,
    _StepperSize.large  => 18,
  };

  @override
  Widget build(BuildContext context) {
    final btnBg  = isDark ? AppColors.slate700 : AppColors.slate100;
    final txtCol = isDark ? AppColors.slate200 : AppColors.slate700;

    Widget btn(String label, bool enabled, VoidCallback fn) => SizedBox(
      width: _btnSize, height: _btnSize,
      child: Material(
        color:        enabled ? btnBg : btnBg.withValues(alpha: .4),
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: enabled && !disabled ? fn : null,
          borderRadius: BorderRadius.circular(8),
          child: Center(child: Text(label,
              style: TextStyle(fontSize: _fontSize, fontWeight: FontWeight.w700,
                  color: enabled ? txtCol : txtCol.withValues(alpha: .35)))),
        ),
      ),
    );

    return Row(mainAxisSize: MainAxisSize.min, children: [
      btn('−', value > min, () => onChange((value - step).clamp(min, max))),
      SizedBox(
        width: _btnSize + 8,
        child: Text('$value',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: _fontSize, fontWeight: FontWeight.w900,
              color: isDark ? Colors.white : AppColors.slate900),
        ),
      ),
      btn('+', value < max, () => onChange((value + step).clamp(min, max))),
    ]);
  }
}

// ── Add category button ───────────────────────────────────────────────────────

class _AddCatBtn extends StatelessWidget {
  final String   label;
  final bool     isDark;
  final VoidCallback onTap;
  const _AddCatBtn({required this.label, required this.isDark, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            style: BorderStyle.solid,
            color: isDark ? AppColors.slate600 : AppColors.slate300),
      ),
      child: Text(label, style: TextStyle(
        fontSize: 12, fontWeight: FontWeight.w600,
        color: isDark ? AppColors.slate400 : AppColors.slate500,
      )),
    ),
  );
}

// ── Small button ──────────────────────────────────────────────────────────────

class _SmallBtn extends StatelessWidget {
  final String       label;
  final VoidCallback? onTap;
  final bool         danger;
  final bool         isDark;
  const _SmallBtn({
    required this.label,
    required this.onTap,
    required this.isDark,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    final bg = danger ? AppColors.rose500
        : (isDark ? AppColors.slate700 : AppColors.slate200);
    final fg = danger ? Colors.white
        : (isDark ? AppColors.slate200 : AppColors.slate700);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color:        bg,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(label, style: TextStyle(
          fontSize: 12, fontWeight: FontWeight.w700, color: fg,
        )),
      ),
    );
  }
}

// ── Locked banner ─────────────────────────────────────────────────────────────

class _LockedBanner extends StatelessWidget {
  final bool isDark;
  const _LockedBanner({required this.isDark});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color:        isDark
          ? const Color(0xFF78350F).withValues(alpha: .2)
          : const Color(0xFFFEF3C7),
      borderRadius: BorderRadius.circular(12),
      border:       Border.all(
          color: isDark
              ? const Color(0xFF92400E)
              : const Color(0xFFFDE68A)),
    ),
    child: const Row(children: [
      Icon(Icons.lock_outline, size: 16, color: Color(0xFFD97706)),
      SizedBox(width: 8),
      Expanded(child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Janela de apostas encerrada',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                  color: Color(0xFFD97706))),
          Text('As apostas só podem ser feitas durante o matchmaking.',
              style: TextStyle(fontSize: 10,
                  color: Color(0xFFB45309))),
        ],
      )),
    ]),
  );
}

class _NoBetLockedState extends StatelessWidget {
  final bool isDark;
  const _NoBetLockedState({required this.isDark});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(16),
      border: Border.all(
          style: BorderStyle.solid,
          color: isDark ? AppColors.slate700 : AppColors.slate200),
    ),
    child: Center(child: Text(
      'Você não fez uma aposta nesta partida.',
      style: TextStyle(fontSize: 13,
          color: isDark ? AppColors.slate400 : AppColors.slate500),
    )),
  );
}

// ── Empty match state ─────────────────────────────────────────────────────────

class _EmptyMatchState extends StatelessWidget {
  final bool isDark;
  const _EmptyMatchState({required this.isDark});

  @override
  Widget build(BuildContext context) => Center(child: Padding(
    padding: const EdgeInsets.all(40),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.sports_soccer_outlined,
          size: 48, color: isDark ? AppColors.slate600 : AppColors.slate300),
      const SizedBox(height: 16),
      Text('Nenhuma partida em andamento',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600,
              color: isDark ? AppColors.slate400 : AppColors.slate500)),
      const SizedBox(height: 6),
      Text(
        'As apostas ficam disponíveis durante o matchmaking.',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 12,
            color: isDark ? AppColors.slate500 : AppColors.slate400),
      ),
    ]),
  ));
}

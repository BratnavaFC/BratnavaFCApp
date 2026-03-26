import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../auth/presentation/providers/account_store.dart';
import '../../../group_settings/presentation/providers/group_settings_provider.dart';
import '../../data/datasources/payments_remote_datasource.dart';
import '../../domain/entities/payment_entities.dart';
import '../providers/payments_provider.dart';
import '../widgets/monthly_payment_sheet.dart';
import '../widgets/extra_payment_sheet.dart';
import '../widgets/create_extra_charge_sheet.dart';
import '../widgets/bulk_discount_sheet.dart';

const _months = [
  'Jan','Fev','Mar','Abr','Mai','Jun',
  'Jul','Ago','Set','Out','Nov','Dez',
];

class PaymentsPage extends ConsumerStatefulWidget {
  const PaymentsPage({super.key});

  @override
  ConsumerState<PaymentsPage> createState() => _PaymentsPageState();
}

class _PaymentsPageState extends ConsumerState<PaymentsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  int  _year       = DateTime.now().year;
  int  _extraYear  = DateTime.now().year;
  int  _extraMonth = DateTime.now().month;
  int  _paymentMode = 0;   // 0=Monthly, 1=PerGame
  bool _loadingMode = true;

  String?  get _groupId  => ref.read(accountStoreProvider).activeAccount?.activeGroupId;
  bool get _isPaymentAdmin {
    final acc = ref.read(accountStoreProvider).activeAccount;
    final gid = _groupId;
    if (acc == null || gid == null) return false;
    return acc.isGroupAdmin(gid) || acc.isGroupFinanceiro(gid);
  }

  PaymentsRemoteDataSource get _ds => ref.read(paymentsDsProvider);

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _loadPaymentMode();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadPaymentMode() async {
    final gid = _groupId;
    if (gid == null) { setState(() => _loadingMode = false); return; }
    try {
      final ds = ref.read(groupSettingsDsProvider);
      final settings = await ds.fetchGroupSettings(gid);
      if (mounted) {
        setState(() {
          _paymentMode = settings.paymentMode;
          _loadingMode = false;
          if (_paymentMode == 1) _tabCtrl.index = 1; // PerGame → cobranças extras
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingMode = false);
    }
  }

  void _refreshMonthly() {
    final gid = _groupId;
    if (gid == null) return;
    ref.invalidate(monthlyGridProvider((groupId: gid, year: _year)));
    ref.invalidate(myMonthlyRowProvider((groupId: gid, year: _year)));
  }

  void _refreshExtra() {
    final gid = _groupId;
    if (gid == null) return;
    ref.invalidate(extraChargesProvider(gid));
    ref.invalidate(myExtraChargesProvider(gid));
  }

  // ── Abrir sheet de pagamento mensal ──────────────────────────────────────

  Future<void> _openMonthlySheet(
      BuildContext ctx, PlayerRow row, int month) async {
    final gid = _groupId;
    if (gid == null) return;
    await showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => MonthlyPaymentSheet(
        row:      row,
        month:    month,
        isAdmin:  _isPaymentAdmin,
        onSubmit: (dto) => _ds.upsertMonthly(gid, dto),
        onSaved:  _refreshMonthly,
      ),
    );
  }

  // ── Abrir sheet de cobrança extra ─────────────────────────────────────────

  Future<void> _openExtraSheet(
      BuildContext ctx, ExtraCharge charge, ExtraChargePayment payment) async {
    final gid = _groupId;
    if (gid == null) return;
    await showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ExtraPaymentSheet(
        charge:   charge,
        payment:  payment,
        isAdmin:  _isPaymentAdmin,
        onSubmit: (dto) => _ds.upsertExtraChargePayment(
            gid, charge.id, payment.playerId, dto),
        onSaved:  _refreshExtra,
      ),
    );
  }

  // ── Criar cobrança extra ──────────────────────────────────────────────────

  Future<void> _openCreateSheet(BuildContext ctx, List<PlayerRow> players) async {
    final gid = _groupId;
    if (gid == null) return;
    final playerList = players
        .map((p) => (id: p.playerId, name: p.playerName))
        .toList();
    await showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CreateExtraChargeSheet(
        players:  playerList,
        onSubmit: (dto) => _ds.createExtraCharge(gid, dto),
        onSaved:  _refreshExtra,
      ),
    );
  }

  // ── Bulk discount ─────────────────────────────────────────────────────────

  Future<void> _openBulkSheet(BuildContext ctx, ExtraCharge charge) async {
    final gid = _groupId;
    if (gid == null) return;
    await showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BulkDiscountSheet(
        charge:   charge,
        onSubmit: (dto) => _ds.bulkDiscountExtraCharge(gid, charge.id, dto),
        onSaved:  _refreshExtra,
      ),
    );
  }

  // ── Cancelar cobrança ─────────────────────────────────────────────────────

  Future<void> _cancelCharge(BuildContext ctx, String chargeId) async {
    final gid = _groupId;
    if (gid == null) return;
    final ok = await showDialog<bool>(
      context: ctx,
      builder: (_) => AlertDialog(
        title: const Text('Cancelar cobrança'),
        content: const Text('Tem certeza que deseja cancelar esta cobrança?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Não')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sim', style: TextStyle(color: AppColors.rose500)),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await _ds.cancelExtraCharge(gid, chargeId);
      _refreshExtra();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cobrança cancelada')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Erro ao cancelar: $e'),
          backgroundColor: AppColors.rose500,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark  = Theme.of(context).brightness == Brightness.dark;
    final groupId = _groupId ?? '';
    final isAdmin = _isPaymentAdmin;

    if (groupId.isEmpty) {
      return Scaffold(
        body: Center(
          child: Text(
            'Selecione uma patota para ver os pagamentos.',
            style: TextStyle(color: isDark ? AppColors.slate400 : AppColors.slate500),
          ),
        ),
      );
    }

    if (_loadingMode) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (ctx, _) => [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: _buildHeader(isDark),
            ),
          ),
        ],
        body: Column(
          children: [
            // Tab bar
            Container(
              color: isDark ? AppColors.slate900 : Colors.white,
              child: TabBar(
                controller: _tabCtrl,
                tabs: [
                  if (_paymentMode == 0)
                    const Tab(text: '📅 Mensalidades'),
                  const Tab(text: '💰 Cobranças extras'),
                ],
                labelColor:        isDark ? Colors.white : AppColors.slate900,
                unselectedLabelColor: isDark ? AppColors.slate500 : AppColors.slate400,
                indicatorColor:    isDark ? Colors.white : AppColors.slate900,
                labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabCtrl,
                children: [
                  if (_paymentMode == 0)
                    _MonthlyTab(
                      groupId: groupId, year: _year, isAdmin: isAdmin,
                      onYearChanged: (y) => setState(() => _year = y),
                      onOpenSheet:   (ctx, row, month) =>
                          _openMonthlySheet(ctx, row, month),
                    ),
                  _ExtraTab(
                    groupId:     groupId,
                    year:        _extraYear,
                    month:       _extraMonth,
                    isAdmin:     isAdmin,
                    onYearChanged: (y) => setState(() => _extraYear = y),
                    onMonthChanged: (m) => setState(() => _extraMonth = m),
                    onOpenExtraSheet: (ctx, c, p) => _openExtraSheet(ctx, c, p),
                    onCreateSheet:    (ctx, players) =>
                        _openCreateSheet(ctx, players),
                    onBulkSheet:      (ctx, c) => _openBulkSheet(ctx, c),
                    onCancel:         (ctx, id) => _cancelCharge(ctx, id),
                    onRefresh:        _refreshExtra,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF1E293B), Color(0xFF0F172A)],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color:      Colors.black.withValues(alpha: .18),
            blurRadius: 12,
            offset:     const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Row(children: [
        Container(
          width: 52, height: 52,
          decoration: BoxDecoration(
            color:        Colors.white.withValues(alpha: .1),
            borderRadius: BorderRadius.circular(14),
            border:       Border.all(color: Colors.white.withValues(alpha: .2)),
          ),
          child: const Icon(Icons.payments_outlined, size: 26, color: Colors.white),
        ),
        const SizedBox(width: 14),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Pagamentos',
              style: TextStyle(
                  color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
          Text('Mensalidades e cobranças extras',
              style: TextStyle(
                  color: Colors.white.withValues(alpha: .5), fontSize: 12)),
        ]),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// ABA MENSALIDADES
// ══════════════════════════════════════════════════════════════════════════════

class _MonthlyTab extends ConsumerWidget {
  final String  groupId;
  final int     year;
  final bool    isAdmin;
  final void Function(int) onYearChanged;
  final Future<void> Function(BuildContext, PlayerRow, int) onOpenSheet;

  const _MonthlyTab({
    required this.groupId,
    required this.year,
    required this.isAdmin,
    required this.onYearChanged,
    required this.onOpenSheet,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return isAdmin
        ? _AdminMonthlyView(
            groupId:       groupId,
            year:          year,
            isDark:        isDark,
            onYearChanged: onYearChanged,
            onOpenSheet:   onOpenSheet,
            ref:           ref,
          )
        : _UserMonthlyView(
            groupId:       groupId,
            year:          year,
            isDark:        isDark,
            onYearChanged: onYearChanged,
            onOpenSheet:   onOpenSheet,
            ref:           ref,
          );
  }
}

// ── Admin: grade completa ─────────────────────────────────────────────────────

class _AdminMonthlyView extends StatelessWidget {
  final String  groupId;
  final int     year;
  final bool    isDark;
  final void Function(int) onYearChanged;
  final Future<void> Function(BuildContext, PlayerRow, int) onOpenSheet;
  final WidgetRef ref;

  const _AdminMonthlyView({
    required this.groupId,
    required this.year,
    required this.isDark,
    required this.onYearChanged,
    required this.onOpenSheet,
    required this.ref,
  });

  @override
  Widget build(BuildContext context) {
    final gridAsync = ref.watch(
        monthlyGridProvider((groupId: groupId, year: year)));
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Seletor de ano + mensalidade
        Row(children: [
          _YearPicker(year: year, isDark: isDark, onChanged: onYearChanged),
          const SizedBox(width: 12),
          gridAsync.maybeWhen(
            data: (grid) => grid.monthlyFee != null
                ? Text(
                    'Mensalidade: R\$ ${grid.monthlyFee!.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? AppColors.slate400 : AppColors.slate500,
                    ),
                  )
                : Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color:        const Color(0xFFFFFBEB),
                      borderRadius: BorderRadius.circular(8),
                      border:       Border.all(color: const Color(0xFFFDE68A)),
                    ),
                    child: const Text(
                      'Mensalidade não configurada',
                      style: TextStyle(fontSize: 11, color: Color(0xFF92400E)),
                    ),
                  ),
            orElse: () => const SizedBox.shrink(),
          ),
        ]),
        const SizedBox(height: 16),

        gridAsync.when(
          loading: () => const Center(child: Padding(
            padding: EdgeInsets.all(40),
            child: CircularProgressIndicator(),
          )),
          error: (e, _) => _ErrorState(e.toString(), isDark: isDark),
          data: (grid) {
            if (grid.players.isEmpty) {
              return _EmptyState(
                icon:  Icons.group_outlined,
                title: 'Nenhum mensalista encontrado',
                sub:   'Jogadores sem conta vinculada ou convidados não aparecem aqui.',
                isDark: isDark,
              );
            }
            final currentMonth = year < DateTime.now().year
                ? 12
                : DateTime.now().month;
            return _MonthlyGrid(
              grid:         grid,
              currentMonth: currentMonth,
              isDark:       isDark,
              onTap:        (row, month) => onOpenSheet(context, row, month),
            );
          },
        ),
      ],
    );
  }
}

// ── User: só a linha do próprio jogador ──────────────────────────────────────

class _UserMonthlyView extends StatelessWidget {
  final String  groupId;
  final int     year;
  final bool    isDark;
  final void Function(int) onYearChanged;
  final Future<void> Function(BuildContext, PlayerRow, int) onOpenSheet;
  final WidgetRef ref;

  const _UserMonthlyView({
    required this.groupId,
    required this.year,
    required this.isDark,
    required this.onYearChanged,
    required this.onOpenSheet,
    required this.ref,
  });

  @override
  Widget build(BuildContext context) {
    final rowAsync = ref.watch(
        myMonthlyRowProvider((groupId: groupId, year: year)));

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(children: [
          Text('📅 Minhas mensalidades',
              style: TextStyle(
                fontSize: 15, fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : AppColors.slate800,
              )),
          const SizedBox(width: 12),
          _YearPicker(year: year, isDark: isDark, onChanged: onYearChanged),
        ]),
        const SizedBox(height: 16),

        rowAsync.when(
          loading: () => const Center(child: Padding(
            padding: EdgeInsets.all(40), child: CircularProgressIndicator())),
          error: (e, _) => _ErrorState(e.toString(), isDark: isDark),
          data: (row) {
            if (row == null) {
              return _EmptyState(
                icon:  Icons.person_off_outlined,
                title: 'Sem jogador vinculado',
                sub:   'Você não tem um jogador vinculado nesta patota.',
                isDark: isDark,
              );
            }
            final now = DateTime.now();
            final visibleMonths = row.months.where((c) =>
              year < now.year || c.month <= now.month).toList();

            return GridView.builder(
              shrinkWrap:  true,
              physics:     const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount:   3,
                crossAxisSpacing: 8,
                mainAxisSpacing:  8,
                childAspectRatio: 1.1,
              ),
              itemCount: visibleMonths.length,
              itemBuilder: (ctx, i) {
                final cell = visibleMonths[i];
                final paid = cell.isPaid;
                return GestureDetector(
                  onTap: () => onOpenSheet(ctx, row, cell.month),
                  child: Container(
                    decoration: BoxDecoration(
                      color:        paid
                          ? AppColors.green50
                          : const Color(0xFFFFF1F1),
                      borderRadius: BorderRadius.circular(12),
                      border:       Border.all(
                        color: paid ? AppColors.green200 : const Color(0xFFFECACA),
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(_months[cell.month - 1],
                            style: TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w700,
                              color: isDark ? AppColors.slate200 : AppColors.slate700,
                            )),
                        const SizedBox(height: 4),
                        Icon(
                          paid ? Icons.check_circle_rounded : Icons.cancel_rounded,
                          size: 20,
                          color: paid ? AppColors.green500 : AppColors.rose400,
                        ),
                        if (cell.amount > 0) ...[
                          const SizedBox(height: 2),
                          Text(
                            'R\$ ${cell.amount.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 10,
                              color: isDark ? AppColors.slate400 : AppColors.slate500,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }
}

// ── Grade tabular (admin) ─────────────────────────────────────────────────────

class _MonthlyGrid extends StatelessWidget {
  final MonthlyGrid   grid;
  final int           currentMonth;
  final bool          isDark;
  final void Function(PlayerRow, int) onTap;

  const _MonthlyGrid({
    required this.grid,
    required this.currentMonth,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final border   = isDark ? AppColors.slate700 : AppColors.slate200;
    final headerBg = isDark ? AppColors.slate800 : AppColors.slate50;
    final rowHover = isDark ? AppColors.slate800.withValues(alpha: .4) : AppColors.slate50;
    final txtMuted = isDark ? AppColors.slate500 : AppColors.slate300;

    return Container(
      decoration: BoxDecoration(
        border:       Border.all(color: border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowColor: WidgetStateProperty.all(headerBg),
            dataRowMinHeight: 38,
            dataRowMaxHeight: 38,
            columnSpacing: 8,
            horizontalMargin: 12,
            columns: [
              DataColumn(
                label: Text('Jogador',
                    style: TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w600,
                      color: isDark ? AppColors.slate400 : AppColors.slate600,
                    )),
              ),
              for (var i = 0; i < 12; i++)
                DataColumn(
                  label: Text(
                    _months[i],
                    style: TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w600,
                      color: i + 1 <= currentMonth
                          ? (isDark ? AppColors.slate400 : AppColors.slate500)
                          : txtMuted,
                    ),
                  ),
                ),
            ],
            rows: grid.players.map((row) {
              return DataRow(
                color: WidgetStateProperty.resolveWith(
                  (s) => s.contains(WidgetState.hovered) ? rowHover : null,
                ),
                cells: [
                  DataCell(
                    Text(row.playerName,
                        style: TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w500,
                          color: isDark ? AppColors.slate100 : AppColors.slate800,
                        )),
                  ),
                  for (var m = 1; m <= 12; m++) ...[
                    () {
                      final cell = row.months
                          .where((c) => c.month == m)
                          .firstOrNull;
                      if (cell == null) {
                        return DataCell(
                          Text('—',
                              style: TextStyle(fontSize: 12, color: txtMuted)),
                        );
                      }
                      final paid = cell.isPaid;
                      return DataCell(
                        GestureDetector(
                          onTap: () => onTap(row, m),
                          child: Container(
                            width: 28, height: 28,
                            decoration: BoxDecoration(
                              color: paid
                                  ? AppColors.green100
                                  : AppColors.rose50,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              paid
                                  ? Icons.check_circle_rounded
                                  : Icons.cancel_rounded,
                              size: 16,
                              color: paid
                                  ? AppColors.green700
                                  : AppColors.rose400,
                            ),
                          ),
                        ),
                      );
                    }(),
                  ],
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// ABA COBRANÇAS EXTRAS
// ══════════════════════════════════════════════════════════════════════════════

class _ExtraTab extends ConsumerWidget {
  final String  groupId;
  final int     year;
  final int     month;
  final bool    isAdmin;
  final void Function(int) onYearChanged;
  final void Function(int) onMonthChanged;
  final Future<void> Function(BuildContext, ExtraCharge, ExtraChargePayment) onOpenExtraSheet;
  final Future<void> Function(BuildContext, List<PlayerRow>) onCreateSheet;
  final Future<void> Function(BuildContext, ExtraCharge) onBulkSheet;
  final Future<void> Function(BuildContext, String) onCancel;
  final VoidCallback onRefresh;

  const _ExtraTab({
    required this.groupId,
    required this.year,
    required this.month,
    required this.isAdmin,
    required this.onYearChanged,
    required this.onMonthChanged,
    required this.onOpenExtraSheet,
    required this.onCreateSheet,
    required this.onBulkSheet,
    required this.onCancel,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (isAdmin) {
      final chargesAsync = ref.watch(extraChargesProvider(groupId));
      // Precisamos da grade mensal para obter a lista de jogadores
      final gridAsync = ref.watch(monthlyGridProvider(
          (groupId: groupId, year: DateTime.now().year)));

      return chargesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error:   (e, _) => _ErrorState(e.toString(), isDark: isDark),
        data:    (charges) {
          final players = gridAsync.valueOrNull?.players ?? [];
          return _AdminExtraView(
            groupId:       groupId,
            charges:       charges,
            players:       players,
            year:          year,
            month:         month,
            isDark:        isDark,
            onYearChanged: onYearChanged,
            onMonthChanged: onMonthChanged,
            onOpenSheet:   (ctx, c, p) => onOpenExtraSheet(ctx, c, p),
            onCreateSheet: (ctx) => onCreateSheet(ctx, players),
            onBulkSheet:   (ctx, c) => onBulkSheet(ctx, c),
            onCancel:      (ctx, id) => onCancel(ctx, id),
            onRefresh:     onRefresh,
          );
        },
      );
    } else {
      final chargesAsync = ref.watch(myExtraChargesProvider(groupId));
      return chargesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error:   (e, _) => _ErrorState(e.toString(), isDark: isDark),
        data:    (charges) => _UserExtraView(
          charges:        charges,
          year:           year,
          month:          month,
          isDark:         isDark,
          onYearChanged:  onYearChanged,
          onMonthChanged: onMonthChanged,
          onOpenSheet:    (ctx, c, p) => onOpenExtraSheet(ctx, c, p),
        ),
      );
    }
  }
}

// ── Admin: lista de cobranças ─────────────────────────────────────────────────

class _AdminExtraView extends StatefulWidget {
  final String              groupId;
  final List<ExtraCharge>   charges;
  final List<PlayerRow>     players;
  final int                 year;
  final int                 month;
  final bool                isDark;
  final void Function(int)  onYearChanged;
  final void Function(int)  onMonthChanged;
  final Future<void> Function(BuildContext, ExtraCharge, ExtraChargePayment) onOpenSheet;
  final Future<void> Function(BuildContext) onCreateSheet;
  final Future<void> Function(BuildContext, ExtraCharge) onBulkSheet;
  final Future<void> Function(BuildContext, String) onCancel;
  final VoidCallback onRefresh;

  const _AdminExtraView({
    required this.groupId,
    required this.charges,
    required this.players,
    required this.year,
    required this.month,
    required this.isDark,
    required this.onYearChanged,
    required this.onMonthChanged,
    required this.onOpenSheet,
    required this.onCreateSheet,
    required this.onBulkSheet,
    required this.onCancel,
    required this.onRefresh,
  });

  @override
  State<_AdminExtraView> createState() => _AdminExtraViewState();
}

class _AdminExtraViewState extends State<_AdminExtraView> {
  final Set<String> _expanded = {};

  List<ExtraCharge> get _filtered => widget.charges.where((c) =>
      c.year == widget.year && c.month == widget.month).toList();

  @override
  Widget build(BuildContext context) {
    final filtered   = _filtered;
    final current    = filtered.where((c) => !c.isFinalized).toList();
    final finalized  = filtered.where((c) =>  c.isFinalized).toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Toolbar: nova cobrança + seletor de ano
        Row(children: [
          ElevatedButton.icon(
            onPressed: () => widget.onCreateSheet(context),
            icon:  const Icon(Icons.add, size: 16),
            label: const Text('Nova cobrança',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            style: ElevatedButton.styleFrom(
              backgroundColor: widget.isDark ? Colors.white : AppColors.slate900,
              foregroundColor: widget.isDark ? AppColors.slate900 : Colors.white,
              padding:   const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape:     RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
          ),
          const SizedBox(width: 12),
          _YearPicker(
              year: widget.year, isDark: widget.isDark,
              onChanged: widget.onYearChanged),
        ]),
        const SizedBox(height: 12),

        // Seletor de mês
        _MonthPicker(
          charges:  widget.charges,
          year:     widget.year,
          selected: widget.month,
          isDark:   widget.isDark,
          isAdmin:  true,
          onChanged: widget.onMonthChanged,
        ),
        const SizedBox(height: 16),

        if (current.isEmpty && finalized.isEmpty)
          _EmptyState(
            icon:   Icons.monetization_on_outlined,
            title:  'Nenhuma cobrança em ${_months[widget.month - 1]}/${widget.year}',
            sub:    '',
            isDark: widget.isDark,
          )
        else ...[
          if (current.isNotEmpty) ...[
            _SectionTitle('📌 Pendentes / Ativas', widget.isDark),
            const SizedBox(height: 8),
            ...current.map((c) => _ChargeCard(
              charge:    c,
              expanded:  _expanded.contains(c.id),
              isDark:    widget.isDark,
              onToggle:  () => setState(() {
                _expanded.contains(c.id)
                    ? _expanded.remove(c.id)
                    : _expanded.add(c.id);
              }),
              onBulkDiscount: c.payments.isNotEmpty
                  ? () => widget.onBulkSheet(context, c)
                  : null,
              onCancel:  () => widget.onCancel(context, c.id),
              onEditPayment: (p) => widget.onOpenSheet(context, c, p),
            )),
          ],
          if (finalized.isNotEmpty) ...[
            const SizedBox(height: 16),
            _SectionTitle('✅ Finalizadas', widget.isDark),
            const SizedBox(height: 8),
            ...finalized.map((c) => _ChargeCard(
              charge:    c,
              expanded:  _expanded.contains(c.id),
              isDark:    widget.isDark,
              finalized: true,
              onToggle:  () => setState(() {
                _expanded.contains(c.id)
                    ? _expanded.remove(c.id)
                    : _expanded.add(c.id);
              }),
              onBulkDiscount: null,
              onCancel:  null,
              onEditPayment: (p) => widget.onOpenSheet(context, c, p),
            )),
          ],
        ],
      ],
    );
  }
}

// ── User: suas cobranças ──────────────────────────────────────────────────────

class _UserExtraView extends StatelessWidget {
  final List<ExtraCharge> charges;
  final int  year;
  final int  month;
  final bool isDark;
  final void Function(int) onYearChanged;
  final void Function(int) onMonthChanged;
  final Future<void> Function(BuildContext, ExtraCharge, ExtraChargePayment) onOpenSheet;

  const _UserExtraView({
    required this.charges,
    required this.year,
    required this.month,
    required this.isDark,
    required this.onYearChanged,
    required this.onMonthChanged,
    required this.onOpenSheet,
  });

  @override
  Widget build(BuildContext context) {
    final filtered = charges.where(
        (c) => c.year == year && c.month == month).toList();
    final pending  = filtered.where((c) {
      if (c.isCancelled) return false;
      final p = c.payments.firstOrNull;
      return p == null || !p.isPaid;
    }).toList();
    final paid = filtered.where((c) {
      if (c.isCancelled) return false;
      final p = c.payments.firstOrNull;
      return p != null && p.isPaid;
    }).toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(children: [
          _YearPicker(year: year, isDark: isDark, onChanged: onYearChanged),
        ]),
        const SizedBox(height: 12),
        _MonthPicker(
          charges:   charges,
          year:      year,
          selected:  month,
          isDark:    isDark,
          isAdmin:   false,
          onChanged: onMonthChanged,
        ),
        const SizedBox(height: 16),

        if (pending.isEmpty && paid.isEmpty)
          _EmptyState(
            icon:  Icons.monetization_on_outlined,
            title: 'Nenhuma cobrança em ${_months[month - 1]}/$year',
            sub:   '',
            isDark: isDark,
          )
        else ...[
          if (pending.isNotEmpty) ...[
            _SectionTitle('📌 Pendentes', isDark),
            const SizedBox(height: 8),
            ...pending.map((c) {
              final p = c.payments.firstOrNull;
              if (p == null) return const SizedBox.shrink();
              return _UserChargeCard(
                charge:  c,
                payment: p,
                isDark:  isDark,
                onTap:   () => onOpenSheet(context, c, p),
              );
            }),
          ],
          if (paid.isNotEmpty) ...[
            const SizedBox(height: 16),
            _SectionTitle('✅ Pagas', isDark),
            const SizedBox(height: 8),
            ...paid.map((c) {
              final p = c.payments.firstOrNull;
              if (p == null) return const SizedBox.shrink();
              return _UserChargeCard(
                charge:  c,
                payment: p,
                isDark:  isDark,
                paid:    true,
                onTap:   () => onOpenSheet(context, c, p),
              );
            }),
          ],
        ],
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// WIDGETS INTERNOS
// ══════════════════════════════════════════════════════════════════════════════

class _YearPicker extends StatelessWidget {
  final int  year;
  final bool isDark;
  final void Function(int) onChanged;

  const _YearPicker({
    required this.year,
    required this.isDark,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final bg = isDark ? AppColors.slate800 : AppColors.slate100;
    final fg = isDark ? AppColors.slate400 : AppColors.slate600;
    final txt = isDark ? AppColors.slate100 : AppColors.slate800;

    return Container(
      decoration: BoxDecoration(
        color:        bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        _ArrowBtn(
          icon:    Icons.chevron_left,
          color:   fg,
          onTap:   () => onChanged(year - 1),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text('$year',
              style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w700, color: txt)),
        ),
        _ArrowBtn(
          icon:    Icons.chevron_right,
          color:   fg,
          onTap:   () => onChanged(year + 1),
        ),
      ]),
    );
  }
}

class _ArrowBtn extends StatelessWidget {
  final IconData icon;
  final Color    color;
  final VoidCallback onTap;

  const _ArrowBtn({required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Icon(icon, size: 18, color: color),
    ),
  );
}

class _MonthPicker extends StatelessWidget {
  final List<ExtraCharge> charges;
  final int     year;
  final int     selected;
  final bool    isDark;
  final bool    isAdmin;
  final void Function(int) onChanged;

  const _MonthPicker({
    required this.charges,
    required this.year,
    required this.selected,
    required this.isDark,
    required this.isAdmin,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap:  true,
      physics:     const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount:   6,
        crossAxisSpacing: 4,
        mainAxisSpacing:  4,
        childAspectRatio: 1.3,
      ),
      itemCount: 12,
      itemBuilder: (_, i) {
        final m = i + 1;
        final mc = charges.where(
            (c) => c.year == year && c.month == m).toList();
        final active = mc.where((c) => !c.isCancelled).toList();

        final bool allPaid;
        final bool hasPending;
        if (isAdmin) {
          allPaid    = active.isNotEmpty && active.every((c) => c.isFinalized);
          hasPending = active.any((c) => !c.isFinalized);
        } else {
          allPaid = active.isNotEmpty && active.every((c) {
            final p = c.payments.firstOrNull;
            return p != null && p.isPaid;
          });
          hasPending = active.any((c) {
            final p = c.payments.firstOrNull;
            return p == null || !p.isPaid;
          });
        }

        final isSelected = m == selected;
        final hasAny     = mc.isNotEmpty;

        Color dotColor = Colors.transparent;
        if (hasAny) {
          if (allPaid) dotColor = AppColors.green400;
          else if (hasPending) dotColor = AppColors.rose400;
          else dotColor = AppColors.slate300;
        }

        return GestureDetector(
          onTap: () => onChanged(m),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            decoration: BoxDecoration(
              color:        isSelected
                  ? (isDark ? Colors.white : AppColors.slate900)
                  : (isDark ? AppColors.slate800 : AppColors.slate100),
              borderRadius: BorderRadius.circular(8),
              border:       isSelected
                  ? null
                  : Border.all(
                      color: isDark ? AppColors.slate700 : AppColors.slate200),
            ),
            child: Opacity(
              opacity: !hasAny && !isSelected ? 0.45 : 1.0,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _months[i],
                    style: TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w600,
                      color: isSelected
                          ? (isDark ? AppColors.slate900 : Colors.white)
                          : (isDark ? AppColors.slate200 : AppColors.slate700),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Container(
                    width: 6, height: 6,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isSelected
                          ? dotColor.withValues(alpha: .8)
                          : dotColor,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// ── Card de cobrança (admin) ──────────────────────────────────────────────────

class _ChargeCard extends StatelessWidget {
  final ExtraCharge charge;
  final bool        expanded;
  final bool        isDark;
  final bool        finalized;
  final VoidCallback        onToggle;
  final VoidCallback?       onBulkDiscount;
  final VoidCallback?       onCancel;
  final void Function(ExtraChargePayment) onEditPayment;

  const _ChargeCard({
    required this.charge,
    required this.expanded,
    required this.isDark,
    this.finalized = false,
    required this.onToggle,
    this.onBulkDiscount,
    this.onCancel,
    required this.onEditPayment,
  });

  @override
  Widget build(BuildContext context) {
    final paidCt = charge.payments.where((p) => p.isPaid).length;
    final pendCt = charge.payments.length - paidCt;
    final border = charge.isCancelled
        ? (isDark ? AppColors.slate700 : AppColors.slate200)
        : finalized
            ? AppColors.green200
            : (isDark ? AppColors.slate700 : AppColors.slate200);
    final bgColor = charge.isCancelled
        ? (isDark ? AppColors.slate900 : Colors.white)
        : finalized
            ? AppColors.green50.withValues(alpha: .5)
            : (isDark ? AppColors.slate900 : Colors.white);

    return Opacity(
      opacity: charge.isCancelled ? 0.6 : 1.0,
      child: Container(
        margin:     const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color:        bgColor,
          borderRadius: BorderRadius.circular(12),
          border:       Border.all(color: border),
        ),
        child: Column(children: [
          // Header
          InkWell(
            onTap:        onToggle,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Text(charge.name,
                          style: TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : AppColors.slate900,
                          )),
                      const SizedBox(width: 6),
                      if (charge.isCancelled)
                        _Badge('Cancelada',
                            bg: isDark ? AppColors.slate700 : AppColors.slate100,
                            fg: isDark ? AppColors.slate400 : AppColors.slate500),
                      if (finalized && !charge.isCancelled)
                        _Badge('Finalizada',
                            bg: AppColors.green100, fg: AppColors.green700,
                            icon: Icons.check_circle_rounded),
                    ]),
                    const SizedBox(height: 2),
                    Row(children: [
                      Text('R\$ ${charge.amount.toStringAsFixed(2)}',
                          style: TextStyle(
                              fontSize: 11,
                              color: isDark ? AppColors.slate400 : AppColors.slate500)),
                      if (charge.dueDate != null) ...[
                        const SizedBox(width: 8),
                        Text('Venc. ${_fmtDate(charge.dueDate!)}',
                            style: TextStyle(
                                fontSize: 11,
                                color: isDark ? AppColors.slate400 : AppColors.slate500)),
                      ],
                      const SizedBox(width: 8),
                      Text('$paidCt pago${paidCt != 1 ? 's' : ''}',
                          style: const TextStyle(
                              fontSize: 11, color: AppColors.green600,
                              fontWeight: FontWeight.w600)),
                      if (pendCt > 0) ...[
                        const SizedBox(width: 6),
                        Text('$pendCt pendente${pendCt != 1 ? 's' : ''}',
                            style: const TextStyle(
                                fontSize: 11, color: AppColors.rose500,
                                fontWeight: FontWeight.w600)),
                      ],
                    ]),
                  ]),
                ),
                // Actions
                if (onBulkDiscount != null)
                  _IconTextBtn(
                    icon:    Icons.monetization_on_outlined,
                    label:   'Desc.',
                    isDark:  isDark,
                    onTap:   onBulkDiscount!,
                  ),
                if (onCancel != null)
                  GestureDetector(
                    onTap: onCancel,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Icon(Icons.delete_outline,
                          size: 18,
                          color: isDark ? AppColors.slate500 : AppColors.slate400),
                    ),
                  ),
                Icon(
                  expanded ? Icons.expand_less : Icons.expand_more,
                  size: 18,
                  color: isDark ? AppColors.slate500 : AppColors.slate400,
                ),
              ]),
            ),
          ),

          // Expandido: lista de jogadores
          if (expanded) ...[
            Divider(height: 1,
                color: isDark ? AppColors.slate800 : AppColors.slate100),
            if (charge.payments.isEmpty)
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text('Nenhum jogador atribuído.',
                    style: TextStyle(
                        fontSize: 12,
                        color: isDark ? AppColors.slate400 : AppColors.slate500)),
              )
            else
              ...charge.payments.map((p) => _PaymentRow(
                payment:  p,
                isDark:   isDark,
                isCancelled: charge.isCancelled,
                onEdit:   () => onEditPayment(p),
              )),
          ],
        ]),
      ),
    );
  }

  String _fmtDate(String s) {
    try {
      final d = DateTime.parse(s);
      return '${d.day.toString().padLeft(2,'0')}/${d.month.toString().padLeft(2,'0')}/${d.year}';
    } catch (_) { return s; }
  }
}

class _PaymentRow extends StatelessWidget {
  final ExtraChargePayment payment;
  final bool isDark;
  final bool isCancelled;
  final VoidCallback onEdit;

  const _PaymentRow({
    required this.payment,
    required this.isDark,
    required this.isCancelled,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final paid = payment.isPaid;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        border: Border(
            top: BorderSide(
                color: isDark ? AppColors.slate800 : AppColors.slate50)),
      ),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(payment.playerName,
                style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w500,
                  color: isDark ? AppColors.slate100 : AppColors.slate800,
                )),
            const SizedBox(height: 2),
            Row(children: [
              Text('R\$ ${payment.finalAmount.toStringAsFixed(2)}',
                  style: TextStyle(
                      fontSize: 11,
                      color: isDark ? AppColors.slate400 : AppColors.slate500)),
              if (payment.discount > 0) ...[
                const SizedBox(width: 6),
                Text('(desc. R\$ ${payment.discount.toStringAsFixed(2)})',
                    style: const TextStyle(fontSize: 11, color: AppColors.green600)),
              ],
              if (payment.paidAt != null) ...[
                const SizedBox(width: 6),
                Text('· ${_fmtDate(payment.paidAt!)}',
                    style: TextStyle(
                        fontSize: 11,
                        color: isDark ? AppColors.slate400 : AppColors.slate500)),
              ],
            ]),
          ]),
        ),
        _StatusBadge(paid: paid),
        if (!isCancelled) ...[
          const SizedBox(width: 8),
          OutlinedButton(
            onPressed: onEdit,
            style: OutlinedButton.styleFrom(
              side:    BorderSide(color: isDark ? AppColors.slate700 : AppColors.slate200),
              foregroundColor: isDark ? AppColors.slate300 : AppColors.slate600,
              padding:  const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
              shape:    RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text('Editar'),
          ),
        ],
      ]),
    );
  }

  String _fmtDate(String s) {
    try {
      final d = DateTime.parse(s);
      return '${d.day.toString().padLeft(2,'0')}/${d.month.toString().padLeft(2,'0')}/${d.year}';
    } catch (_) { return s; }
  }
}

// ── Card de cobrança para user ────────────────────────────────────────────────

class _UserChargeCard extends StatelessWidget {
  final ExtraCharge        charge;
  final ExtraChargePayment payment;
  final bool               isDark;
  final bool               paid;
  final VoidCallback       onTap;

  const _UserChargeCard({
    required this.charge,
    required this.payment,
    required this.isDark,
    this.paid = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color:        paid
            ? AppColors.green50.withValues(alpha: .5)
            : (isDark ? AppColors.slate900 : Colors.white),
        borderRadius: BorderRadius.circular(12),
        border:       Border.all(
          color: paid ? AppColors.green100 : (isDark ? AppColors.slate700 : AppColors.slate200),
        ),
      ),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(charge.name,
                style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : AppColors.slate800,
                )),
            const SizedBox(height: 4),
            Row(children: [
              Text('R\$ ${payment.finalAmount.toStringAsFixed(2)}',
                  style: TextStyle(
                      fontSize: 12,
                      color: isDark ? AppColors.slate400 : AppColors.slate500)),
              if (payment.discount > 0) ...[
                const SizedBox(width: 8),
                Text('Desconto: R\$ ${payment.discount.toStringAsFixed(2)}',
                    style: const TextStyle(fontSize: 12, color: AppColors.green600)),
              ],
              if (charge.dueDate != null) ...[
                const SizedBox(width: 8),
                Text('Venc. ${_fmtDate(charge.dueDate!)}',
                    style: TextStyle(
                        fontSize: 12,
                        color: isDark ? AppColors.slate400 : AppColors.slate500)),
              ],
              if (payment.paidAt != null) ...[
                const SizedBox(width: 8),
                Text('Pago em ${_fmtDate(payment.paidAt!)}',
                    style: TextStyle(
                        fontSize: 12,
                        color: isDark ? AppColors.slate400 : AppColors.slate500)),
              ],
            ]),
          ]),
        ),
        _StatusBadge(paid: paid),
        const SizedBox(width: 8),
        OutlinedButton(
          onPressed: onTap,
          style: OutlinedButton.styleFrom(
            side:    BorderSide(color: isDark ? AppColors.slate700 : AppColors.slate200),
            foregroundColor: isDark ? AppColors.slate300 : AppColors.slate600,
            padding:  const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
            shape:    RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: Text(paid ? 'Ver' : 'Pagar'),
        ),
      ]),
    );
  }

  String _fmtDate(String s) {
    try {
      final d = DateTime.parse(s);
      return '${d.day.toString().padLeft(2,'0')}/${d.month.toString().padLeft(2,'0')}/${d.year}';
    } catch (_) { return s; }
  }
}

// ── Helpers de UI ─────────────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  final String text;
  final bool   isDark;
  const _SectionTitle(this.text, this.isDark);

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: TextStyle(
      fontSize: 13, fontWeight: FontWeight.w700,
      color: isDark ? AppColors.slate300 : AppColors.slate700,
    ),
  );
}

class _Badge extends StatelessWidget {
  final String  text;
  final Color   bg;
  final Color   fg;
  final IconData? icon;
  const _Badge(this.text, {required this.bg, required this.fg, this.icon});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      if (icon != null) ...[
        Icon(icon, size: 10, color: fg),
        const SizedBox(width: 2),
      ],
      Text(text, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: fg)),
    ]),
  );
}

class _StatusBadge extends StatelessWidget {
  final bool paid;
  const _StatusBadge({required this.paid});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color:        paid ? AppColors.green100 : AppColors.rose50,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(
        paid ? Icons.check_circle_rounded : Icons.cancel_rounded,
        size: 12, color: paid ? AppColors.green700 : AppColors.rose500,
      ),
      const SizedBox(width: 4),
      Text(
        paid ? 'Pago' : 'Pendente',
        style: TextStyle(
          fontSize: 11, fontWeight: FontWeight.w600,
          color: paid ? AppColors.green700 : AppColors.rose500,
        ),
      ),
    ]),
  );
}

class _IconTextBtn extends StatelessWidget {
  final IconData icon;
  final String   label;
  final bool     isDark;
  final VoidCallback onTap;

  const _IconTextBtn({
    required this.icon, required this.label,
    required this.isDark, required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        border:       Border.all(color: isDark ? AppColors.slate700 : AppColors.slate200),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 12, color: isDark ? AppColors.slate400 : AppColors.slate600),
        const SizedBox(width: 4),
        Text(label,
            style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w500,
              color: isDark ? AppColors.slate400 : AppColors.slate600,
            )),
      ]),
    ),
  );
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String   title;
  final String   sub;
  final bool     isDark;
  const _EmptyState({
    required this.icon, required this.title,
    required this.sub,  required this.isDark,
  });

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(children: [
        Icon(icon, size: 40, color: isDark ? AppColors.slate600 : AppColors.slate300),
        const SizedBox(height: 12),
        Text(title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14, fontWeight: FontWeight.w500,
              color: isDark ? AppColors.slate400 : AppColors.slate500,
            )),
        if (sub.isNotEmpty) ...[
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(sub,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 12,
                    color: isDark ? AppColors.slate500 : AppColors.slate400)),
          ),
        ],
      ]),
    ),
  );
}

class _ErrorState extends StatelessWidget {
  final String error;
  final bool   isDark;
  const _ErrorState(this.error, {required this.isDark});

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Text(
        'Erro: $error',
        style: const TextStyle(color: AppColors.rose500, fontSize: 13),
        textAlign: TextAlign.center,
      ),
    ),
  );
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../auth/presentation/providers/account_store.dart';
import '../providers/dashboard_provider.dart';
import '../widgets/current_match_card.dart';
import '../widgets/recent_match_card.dart';
import '../../../payments/presentation/providers/payments_provider.dart';

class DashboardPage extends ConsumerStatefulWidget {
  const DashboardPage({super.key});

  @override
  ConsumerState<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends ConsumerState<DashboardPage> {
  bool   _refreshingMatch  = false;
  bool   _refreshingRecent = false;
  Timer? _matchTimer;

  @override
  void initState() {
    super.initState();
    // Auto-refresh current match every 30 s so live data stays current.
    _matchTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      final groupId =
          ref.read(accountStoreProvider).activeAccount?.activeGroupId ?? '';
      if (groupId.isNotEmpty) ref.invalidate(currentMatchProvider(groupId));
    });
  }

  @override
  void dispose() {
    _matchTimer?.cancel();
    super.dispose();
  }

  Future<void> _refreshMatch(String groupId) async {
    if (_refreshingMatch) return;
    setState(() => _refreshingMatch = true);
    ref.invalidate(currentMatchProvider(groupId));
    await Future.delayed(const Duration(milliseconds: 900));
    if (mounted) setState(() => _refreshingMatch = false);
  }

  Future<void> _refreshRecent(String groupId, String playerId) async {
    if (_refreshingRecent) return;
    setState(() => _refreshingRecent = true);
    ref.invalidate(recentMatchesProvider((groupId: groupId, playerId: playerId)));
    await Future.delayed(const Duration(milliseconds: 900));
    if (mounted) setState(() => _refreshingRecent = false);
  }

  @override
  Widget build(BuildContext context) {
    final isDark      = Theme.of(context).brightness == Brightness.dark;
    final account      = ref.watch(accountStoreProvider).activeAccount;
    final activePlayer = ref.watch(activePlayerProvider);
    // Fallback: usa o groupId do player ativo se activeGroupId ainda não foi
    // persistido (race condition logo após login com múltiplos grupos)
    final groupId      = account?.activeGroupId ?? activePlayer?.groupId ?? '';

    final currentMatchAsync = groupId.isNotEmpty
        ? ref.watch(currentMatchProvider(groupId))
        : null;

    final recentAsync = (activePlayer != null && groupId.isNotEmpty)
        ? ref.watch(recentMatchesProvider((groupId: groupId, playerId: activePlayer.playerId)))
        : null;

    // Subtítulo do header — igual ao site
    final headerSubtitle = activePlayer != null
        ? activePlayer.playerName
        : groupId.isNotEmpty
            ? 'Selecione um jogador'
            : 'Selecione um grupo';

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(myPlayersProvider);
          if (groupId.isNotEmpty) {
            ref.invalidate(currentMatchProvider(groupId));
            if (activePlayer != null) {
              ref.invalidate(recentMatchesProvider(
                  (groupId: groupId, playerId: activePlayer.playerId)));
            }
          }
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [

            // ── Header gradiente ────────────────────────────────────────────
            _DashboardHeader(subtitle: headerSubtitle),
            const SizedBox(height: 16),

            // ── Partida atual ───────────────────────────────────────────────
            _SectionCard(
              isDark: isDark,
              iconBg: const Color(0xFF3B82F6).withValues(alpha: .1),
              iconColor: AppColors.blue600,
              iconData: Icons.calendar_today_rounded,
              title: 'Partida atual',
              trailing: groupId.isNotEmpty
                  ? _RefreshBtn(
                      isLoading: _refreshingMatch,
                      onTap: () => _refreshMatch(groupId),
                    )
                  : null,
              child: _buildCurrentMatchContent(
                context, isDark, groupId, currentMatchAsync),
            ),
            const SizedBox(height: 16),

            // ── Últimas partidas ────────────────────────────────────────────
            _SectionCard(
              isDark: isDark,
              iconBg: const Color(0xFF8B5CF6).withValues(alpha: .1),
              iconColor: AppColors.violet600,
              iconData: Icons.history_rounded,
              title: activePlayer != null
                  ? 'Últimas partidas · ${activePlayer.playerName}'
                  : 'Últimas partidas',
              trailing: (activePlayer != null && groupId.isNotEmpty)
                  ? _RefreshBtn(
                      isLoading: _refreshingRecent,
                      onTap: () => _refreshRecent(groupId, activePlayer.playerId),
                    )
                  : null,
              child: _buildRecentContent(context, isDark, activePlayer, recentAsync, groupId),
            ),
            const SizedBox(height: 16),

            // ── Situação financeira ─────────────────────────────────────────
            _SectionCard(
              isDark: isDark,
              iconBg: const Color(0xFF16A34A).withValues(alpha: .1),
              iconColor: AppColors.green600,
              iconData: Icons.payments_outlined,
              title: 'Situação financeira',
              child: _buildPaymentSummaryContent(context, isDark, groupId),
            ),
          ],
        ),
      ),
    );
  }

  // ── Situação financeira — conteúdo ─────────────────────────────────────────
  Widget _buildPaymentSummaryContent(
      BuildContext context, bool isDark, String groupId) {
    if (groupId.isEmpty) {
      return _CenteredMsg(
          msg: 'Selecione uma patota para ver sua situação financeira.',
          isDark: isDark);
    }
    final summaryAsync = ref.watch(myPaymentSummaryProvider(groupId));
    return summaryAsync.when(
      loading: () => const _Skeleton(height: 60),
      error:   (_, __) => _CenteredMsg(
          msg: 'Não foi possível carregar situação financeira.', isDark: isDark),
      data: (summary) {
        if (summary == null) {
          return _CenteredMsg(
              msg: 'Nenhuma informação de pagamento disponível.', isDark: isDark);
        }
        final hasPending = summary.pendingMonthlyCount > 0 ||
            summary.pendingExtraCount > 0;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!hasPending)
              Row(children: [
                Icon(Icons.check_circle_rounded,
                    size: 18, color: AppColors.green600),
                const SizedBox(width: 8),
                Text('Tudo em dia! 🎉',
                    style: TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600,
                      color: AppColors.green600,
                    )),
              ])
            else ...[
              if (summary.pendingMonthlyCount > 0)
                _PaymentSummaryRow(
                  icon:    Icons.calendar_month_outlined,
                  label:   '${summary.pendingMonthlyCount} mensalidade${summary.pendingMonthlyCount != 1 ? 's' : ''} pendente${summary.pendingMonthlyCount != 1 ? 's' : ''}',
                  isDark:  isDark,
                  isAlert: true,
                ),
              if (summary.pendingExtraCount > 0)
                _PaymentSummaryRow(
                  icon:    Icons.receipt_outlined,
                  label:   '${summary.pendingExtraCount} cobrança${summary.pendingExtraCount != 1 ? 's' : ''} extra pendente${summary.pendingExtraCount != 1 ? 's' : ''}',
                  isDark:  isDark,
                  isAlert: true,
                ),
              if (summary.totalPendingAmount > 0) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color:        AppColors.rose50,
                    borderRadius: BorderRadius.circular(8),
                    border:       Border.all(color: AppColors.rose200),
                  ),
                  child: Row(children: [
                    const Icon(Icons.warning_amber_rounded,
                        size: 14, color: AppColors.rose500),
                    const SizedBox(width: 6),
                    Text(
                      'Total pendente: R\$ ${summary.totalPendingAmount.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w600,
                        color: AppColors.rose500,
                      ),
                    ),
                  ]),
                ),
              ],
            ],
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () => context.go('/app/payments'),
              child: Text(
                'Ver pagamentos →',
                style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w600,
                  color: isDark ? AppColors.slate400 : AppColors.slate500,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // ── Partida atual — conteúdo ────────────────────────────────────────────────
  Widget _buildCurrentMatchContent(
      BuildContext context, bool isDark, String groupId, AsyncValue? async) {
    if (groupId.isEmpty) {
      return _CenteredMsg(
          msg: 'Selecione uma patota para ver a partida atual.', isDark: isDark);
    }
    if (async == null) return const SizedBox.shrink();

    return async.when(
      loading: () => const _Skeleton(height: 120),
      error:   (_, __) => _DashedEmpty(
        icon: Icons.calendar_today_outlined,
        title: 'Nenhuma partida em andamento',
        sub: 'Inicie uma partida na seção Partidas.',
        isDark: isDark,
      ),
      data: (match) => match == null
          ? _DashedEmpty(
              icon: Icons.calendar_today_outlined,
              title: 'Nenhuma partida em andamento',
              sub: 'Inicie uma partida na seção Partidas.',
              isDark: isDark,
            )
          : CurrentMatchCard(
              match:    match,
              playerId: ref.read(activePlayerProvider)?.playerId ?? '',
            ),
    );
  }

  // ── Últimas partidas — conteúdo ─────────────────────────────────────────────
  Widget _buildRecentContent(
      BuildContext context, bool isDark, dynamic activePlayer, AsyncValue? async, String groupId) {
    if (activePlayer == null) {
      return _CenteredMsg(
          msg: 'Selecione um jogador para ver suas últimas partidas.',
          isDark: isDark);
    }
    if (async == null) return const SizedBox.shrink();

    return async.when(
      loading: () => Column(
        children: List.generate(3, (_) => const _Skeleton(height: 76, bottom: 8)),
      ),
      error: (e, _) => _CenteredMsg(msg: e.toString(), isDark: isDark),
      data: (matches) {
        if (matches.isEmpty) {
          return _DashedEmpty(
            icon: Icons.calendar_today_outlined,
            title: 'Nenhuma partida encontrada',
            sub: 'As últimas partidas do jogador aparecerão aqui.',
            isDark: isDark,
          );
        }
        return Column(
          children: [
            for (int i = 0; i < matches.length; i++) ...[
              RecentMatchCard(
                match:   matches[i],
                groupId: groupId,
              ),
              if (i < matches.length - 1) const SizedBox(height: 10),
            ],
          ],
        );
      },
    );
  }
}

// ── Header gradiente ──────────────────────────────────────────────────────────

class _DashboardHeader extends StatelessWidget {
  final String subtitle;
  const _DashboardHeader({required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF1E293B), Color(0xFF0F172A)],
          begin: Alignment.topLeft,
          end:   Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color:  Colors.black.withValues(alpha: .18),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Ícone
          Container(
            width: 52, height: 52,
            decoration: BoxDecoration(
              color:        Colors.white.withValues(alpha: .1),
              borderRadius: BorderRadius.circular(14),
              border:       Border.all(color: Colors.white.withValues(alpha: .2)),
            ),
            child: const Icon(Icons.dashboard_rounded, size: 26, color: Colors.white),
          ),
          const SizedBox(width: 16),
          // Textos
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Dashboard',
                  style: TextStyle(
                    color:      Colors.white,
                    fontSize:   22,
                    fontWeight: FontWeight.w900,
                    height:     1.1,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    color:    Colors.white.withValues(alpha: .5),
                    fontSize: 13,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Section Card ──────────────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final bool    isDark;
  final Color   iconBg;
  final Color   iconColor;
  final IconData iconData;
  final String  title;
  final Widget? trailing;
  final Widget  child;

  const _SectionCard({
    required this.isDark,
    required this.iconBg,
    required this.iconColor,
    required this.iconData,
    required this.title,
    required this.child,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final cardBg     = isDark ? AppColors.slate900 : Colors.white;
    final headerBg   = isDark ? AppColors.slate800.withValues(alpha: .8) : AppColors.slate50.withValues(alpha: .9);
    final borderColor = isDark ? AppColors.slate700 : AppColors.slate200;
    final divColor    = isDark ? AppColors.slate800 : AppColors.slate100;

    return Container(
      decoration: BoxDecoration(
        color:        cardBg,
        borderRadius: BorderRadius.circular(16),
        border:       Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color:  Colors.black.withValues(alpha: .03),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: headerBg,
              borderRadius: const BorderRadius.only(
                topLeft:  Radius.circular(16),
                topRight: Radius.circular(16),
              ),
              border: Border(bottom: BorderSide(color: divColor)),
            ),
            child: Row(
              children: [
                // Icon badge
                Container(
                  width: 24, height: 24,
                  decoration: BoxDecoration(
                    color:        iconBg,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(iconData, size: 13, color: iconColor),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize:   13,
                      fontWeight: FontWeight.w600,
                      color: isDark ? AppColors.slate100 : AppColors.slate800,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (trailing != null) trailing!,
              ],
            ),
          ),
          // Content
          Padding(
            padding: const EdgeInsets.all(16),
            child: child,
          ),
        ],
      ),
    );
  }
}

// ── Botão atualizar ────────────────────────────────────────────────────────────

class _RefreshBtn extends StatelessWidget {
  final bool isLoading;
  final VoidCallback onTap;
  const _RefreshBtn({required this.isLoading, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: isLoading ? null : onTap,
      child: AnimatedOpacity(
        opacity: isLoading ? .6 : 1,
        duration: const Duration(milliseconds: 150),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color:        isDark ? AppColors.slate900 : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border:       Border.all(
              color: isDark ? AppColors.slate700 : AppColors.slate200,
            ),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: .04), blurRadius: 2),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              isLoading
                  ? SizedBox(
                      width: 11, height: 11,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.5,
                        color: isDark ? AppColors.slate400 : AppColors.slate500,
                      ),
                    )
                  : Icon(
                      Icons.refresh_rounded,
                      size: 12,
                      color: isDark ? AppColors.slate400 : AppColors.slate600,
                    ),
              const SizedBox(width: 4),
              Text(
                'Atualizar',
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? AppColors.slate400 : AppColors.slate600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Skeleton ──────────────────────────────────────────────────────────────────

class _Skeleton extends StatelessWidget {
  final double height;
  final double bottom;
  const _Skeleton({required this.height, this.bottom = 0});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Container(
        height:     height,
        decoration: BoxDecoration(
          color:        isDark ? AppColors.slate800 : AppColors.slate100,
          borderRadius: BorderRadius.circular(14),
        ),
      ),
    );
  }
}

// ── Empty state com borda tracejada ───────────────────────────────────────────

class _DashedEmpty extends StatelessWidget {
  final IconData icon;
  final String   title;
  final String   sub;
  final bool     isDark;
  const _DashedEmpty({
    required this.icon, required this.title, required this.sub, required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 32),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? AppColors.slate700 : AppColors.slate200,
        ),
      ),
      child: Column(
        children: [
          Icon(icon, size: 32, color: isDark ? AppColors.slate600 : AppColors.slate300),
          const SizedBox(height: 8),
          Text(
            title,
            style: TextStyle(
              fontSize:   13,
              fontWeight: FontWeight.w500,
              color: isDark ? AppColors.slate400 : AppColors.slate500,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              sub,
              style: TextStyle(
                fontSize: 12,
                color: isDark ? AppColors.slate500 : AppColors.slate400,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Mensagem centrada simples ──────────────────────────────────────────────────

class _CenteredMsg extends StatelessWidget {
  final String msg;
  final bool   isDark;
  const _CenteredMsg({required this.msg, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Text(
        msg,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 13,
          color: isDark ? AppColors.slate500 : AppColors.slate400,
        ),
      ),
    );
  }
}

// ── Payment summary row ───────────────────────────────────────────────────────

class _PaymentSummaryRow extends StatelessWidget {
  final IconData icon;
  final String   label;
  final bool     isDark;
  final bool     isAlert;

  const _PaymentSummaryRow({
    required this.icon,
    required this.label,
    required this.isDark,
    this.isAlert = false,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(children: [
      Icon(icon, size: 15,
          color: isAlert ? AppColors.rose500 : AppColors.green600),
      const SizedBox(width: 8),
      Text(label,
          style: TextStyle(
            fontSize: 13,
            color: isAlert
                ? AppColors.rose500
                : (isDark ? AppColors.slate300 : AppColors.slate700),
          )),
    ]),
  );
}

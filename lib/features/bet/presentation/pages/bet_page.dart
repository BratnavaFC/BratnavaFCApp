import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../auth/presentation/providers/account_store.dart';
import '../../../dashboard/presentation/providers/dashboard_provider.dart';
import '../widgets/current_bet_tab.dart';
import '../widgets/bet_history_tab.dart';
import '../widgets/bet_ranking_tab.dart';

class BetPage extends ConsumerStatefulWidget {
  const BetPage({super.key});

  @override
  ConsumerState<BetPage> createState() => _BetPageState();
}

class _BetPageState extends ConsumerState<BetPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark       = Theme.of(context).brightness == Brightness.dark;
    final account      = ref.watch(accountStoreProvider).activeAccount;
    final activePlayer = ref.watch(activePlayerProvider);
    final groupId      = account?.activeGroupId ?? activePlayer?.groupId ?? '';

    if (groupId.isEmpty) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.sports_soccer_outlined,
                  size: 44,
                  color: isDark ? AppColors.slate700 : AppColors.slate200),
              const SizedBox(height: 12),
              Text('Crie ou entre em um grupo',
                  style: TextStyle(
                      color: isDark ? AppColors.slate500 : AppColors.slate400)),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: Column(children: [
        // ── Header ─────────────────────────────────────────────────────────
        const _BetHeader(),

        // ── TabBar ─────────────────────────────────────────────────────────
        Container(
          color: isDark ? AppColors.slate900 : Colors.white,
          child: TabBar(
            controller: _tabCtrl,
            tabs: const [
              Tab(text: 'Aposta Atual'),
              Tab(text: 'Histórico'),
              Tab(text: 'Ranking'),
            ],
            labelColor:           isDark ? Colors.white : AppColors.slate900,
            unselectedLabelColor: isDark ? AppColors.slate500 : AppColors.slate400,
            indicatorColor:       isDark ? Colors.white : AppColors.slate900,
            labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ),

        // ── TabBarView ─────────────────────────────────────────────────────
        Expanded(
          child: TabBarView(
            controller: _tabCtrl,
            children: [
              CurrentBetTab(groupId: groupId),
              BetHistoryTab(groupId: groupId),
              BetRankingTab(groupId: groupId),
            ],
          ),
        ),
      ]),
    );
  }
}

// ── Header ────────────────────────────────────────────────────────────────────

class _BetHeader extends StatelessWidget {
  const _BetHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF1E293B), Color(0xFF0F172A)],
          begin:  Alignment.topLeft,
          end:    Alignment.bottomRight,
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Row(children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color:        Colors.white.withValues(alpha: .1),
                borderRadius: BorderRadius.circular(12),
                border:       Border.all(color: Colors.white.withValues(alpha: .2)),
              ),
              child: const Icon(Icons.monetization_on_outlined,
                  size: 22, color: Colors.white),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text('Bet',
                  style: TextStyle(
                    color:      Colors.white,
                    fontSize:   18,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.3,
                  )),
            ),
          ]),
        ),
      ),
    );
  }
}

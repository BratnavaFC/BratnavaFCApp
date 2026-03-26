import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../auth/presentation/providers/account_store.dart';
import '../../data/datasources/polls_remote_datasource.dart';
import '../../domain/entities/poll_detail.dart';
import '../../domain/entities/poll_summary.dart';
import '../providers/polls_provider.dart';
import '../widgets/event_card.dart';
import '../widgets/poll_card.dart';
import '../widgets/event_detail_sheet.dart';
import '../widgets/poll_detail_sheet.dart';
import '../widgets/create_event_sheet.dart';
import '../widgets/create_poll_sheet.dart';

class PollsPage extends ConsumerStatefulWidget {
  const PollsPage({super.key});

  @override
  ConsumerState<PollsPage> createState() => _PollsPageState();
}

class _PollsPageState extends ConsumerState<PollsPage> {
  _Tab _activeTab = _Tab.events;

  String? get _groupId =>
      ref.read(accountStoreProvider).activeAccount?.activeGroupId;

  bool get _isAdmin {
    final acc = ref.read(accountStoreProvider).activeAccount;
    if (acc == null || _groupId == null) return false;
    return acc.isGroupAdmin(_groupId!);
  }

  PollsRemoteDataSource get _ds => ref.read(pollsDsProvider);

  void _refresh() {
    if (_groupId != null) {
      ref.invalidate(pollsListProvider(_groupId!));
      ref.invalidate(pendingPollsCountProvider(_groupId!));
    }
  }

  Future<void> _openDetail(PollSummary summary) async {
    if (_groupId == null) return;
    try {
      final detail = await _ds.getPoll(_groupId!, summary.id);
      if (!mounted) return;
      await _showDetailSheet(detail);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao abrir: $e'), backgroundColor: AppColors.rose500),
      );
    }
  }

  Future<void> _showDetailSheet(PollDetail detail) async {
    if (_groupId == null) return;
    final sheet = detail.isEvent
        ? EventDetailSheet(
            poll: detail,
            groupId: _groupId!,
            isAdmin: _isAdmin,
            onUpdated: (_) => _refresh(),
          )
        : PollDetailSheet(
            poll: detail,
            groupId: _groupId!,
            isAdmin: _isAdmin,
            onUpdated: (_) => _refresh(),
            onDeleted: () { Navigator.of(context).pop(); _refresh(); },
          );

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => sheet,
    );
    _refresh();
  }

  Future<void> _openCreate() async {
    if (_groupId == null) return;
    final sheet = _activeTab == _Tab.events
        ? CreateEventSheet(groupId: _groupId!, onCreated: (d) { _refresh(); _showDetailSheet(d); })
        : CreatePollSheet(groupId: _groupId!, onCreated: (d) { _refresh(); _showDetailSheet(d); });

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => sheet,
    );
  }

  @override
  Widget build(BuildContext context) {
    final groupId = _groupId;
    final isDark  = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.slate950 : AppColors.slate50,
      body: groupId == null
          ? _NoGroup(isDark: isDark)
          : _Body(
              groupId:   groupId,
              activeTab: _activeTab,
              isAdmin:   _isAdmin,
              isDark:    isDark,
              onTabChange:  (t) => setState(() => _activeTab = t),
              onItemTap:    _openDetail,
              onRefresh:    _refresh,
              onCreateTap:  _openCreate,
            ),
    );
  }
}

// ── _Body ──────────────────────────────────────────────────────────────────────

class _Body extends ConsumerWidget {
  final String   groupId;
  final _Tab     activeTab;
  final bool     isAdmin;
  final bool     isDark;
  final ValueChanged<_Tab> onTabChange;
  final ValueChanged<PollSummary> onItemTap;
  final VoidCallback onRefresh;
  final VoidCallback onCreateTap;

  const _Body({
    required this.groupId,
    required this.activeTab,
    required this.isAdmin,
    required this.isDark,
    required this.onTabChange,
    required this.onItemTap,
    required this.onRefresh,
    required this.onCreateTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(pollsListProvider(groupId));

    return async.when(
      loading: () => _Layout(
        activeTab:   activeTab,
        isAdmin:     isAdmin,
        isDark:      isDark,
        onTabChange: onTabChange,
        onCreateTap: onCreateTap,
        eventCount:  0,
        pollCount:   0,
        child: _Skeleton(),
      ),
      error: (e, _) => _Layout(
        activeTab:   activeTab,
        isAdmin:     isAdmin,
        isDark:      isDark,
        onTabChange: onTabChange,
        onCreateTap: onCreateTap,
        eventCount:  0,
        pollCount:   0,
        child: _ErrorState(onRetry: onRefresh),
      ),
      data: (list) {
        final events = list.where((p) => p.isEvent).toList();
        final polls  = list.where((p) => !p.isEvent).toList();
        final tabList = activeTab == _Tab.events ? events : polls;

        return RefreshIndicator(
          onRefresh: () async => onRefresh(),
          child: _Layout(
            activeTab:   activeTab,
            isAdmin:     isAdmin,
            isDark:      isDark,
            onTabChange: onTabChange,
            onCreateTap: onCreateTap,
            eventCount:  events.length,
            pollCount:   polls.length,
            child: tabList.isEmpty
                ? _Empty(isEvents: activeTab == _Tab.events, isAdmin: isAdmin)
                : _PollList(items: tabList, isEvents: activeTab == _Tab.events, onTap: onItemTap),
          ),
        );
      },
    );
  }
}

// ── _Layout ────────────────────────────────────────────────────────────────────

class _Layout extends StatelessWidget {
  final _Tab     activeTab;
  final bool     isAdmin;
  final bool     isDark;
  final int      eventCount;
  final int      pollCount;
  final ValueChanged<_Tab> onTabChange;
  final VoidCallback       onCreateTap;
  final Widget   child;

  const _Layout({
    required this.activeTab,
    required this.isAdmin,
    required this.isDark,
    required this.eventCount,
    required this.pollCount,
    required this.onTabChange,
    required this.onCreateTap,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: _Header(
          activeTab:   activeTab,
          isAdmin:     isAdmin,
          eventCount:  eventCount,
          pollCount:   pollCount,
          onTabChange: onTabChange,
          onCreateTap: onCreateTap,
        )),
        SliverFillRemaining(
          hasScrollBody: false,
          child: child,
        ),
      ],
    );
  }
}

// ── _Header ────────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final _Tab   activeTab;
  final bool   isAdmin;
  final int    eventCount;
  final int    pollCount;
  final ValueChanged<_Tab> onTabChange;
  final VoidCallback       onCreateTap;

  const _Header({
    required this.activeTab,
    required this.isAdmin,
    required this.eventCount,
    required this.pollCount,
    required this.onTabChange,
    required this.onCreateTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF1E293B), Color(0xFF0F172A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
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
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Title row ──
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                ),
                child: Icon(
                  activeTab == _Tab.events ? Icons.calendar_today_outlined : Icons.how_to_vote_outlined,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Eventos & Votações',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      '$eventCount evento${eventCount != 1 ? 's' : ''} · $pollCount votaç${pollCount != 1 ? 'ões' : 'ão'}',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 13),
                    ),
                  ],
                ),
              ),
              if (isAdmin)
                LayoutBuilder(
                  builder: (context, constraints) {
                    final compact = MediaQuery.of(context).size.width < 380;
                    if (compact) {
                      return IconButton(
                        onPressed: onCreateTap,
                        icon: const Icon(Icons.add, color: AppColors.slate900, size: 18),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.all(8),
                        ),
                      );
                    }
                    return TextButton.icon(
                      onPressed: onCreateTap,
                      icon: const Icon(Icons.add, size: 16),
                      label: Text(activeTab == _Tab.events ? 'Novo evento' : 'Nova votação'),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.slate900,
                        backgroundColor: Colors.white,
                        textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    );
                  },
                ),
            ],
          ),
          const SizedBox(height: 14),

          // ── Tabs ──
          Row(
            children: [
              _TabBtn(
                label: 'Eventos',
                icon: Icons.calendar_today_outlined,
                count: eventCount,
                active: activeTab == _Tab.events,
                onTap: () => onTabChange(_Tab.events),
              ),
              const SizedBox(width: 8),
              _TabBtn(
                label: 'Votações',
                icon: Icons.how_to_vote_outlined,
                count: pollCount,
                active: activeTab == _Tab.polls,
                onTap: () => onTabChange(_Tab.polls),
              ),
            ],
          ),
        ],
      ),
    ));
  }
}

class _TabBtn extends StatelessWidget {
  final String   label;
  final IconData icon;
  final int      count;
  final bool     active;
  final VoidCallback onTap;

  const _TabBtn({
    required this.label,
    required this.icon,
    required this.count,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: active ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: active ? Colors.white : Colors.white.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: active ? AppColors.slate900 : Colors.white.withValues(alpha: 0.7)),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: active ? AppColors.slate900 : Colors.white.withValues(alpha: 0.7),
              ),
            ),
            if (count > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: active ? AppColors.slate900 : Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: active ? Colors.white : Colors.white,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── _PollList ──────────────────────────────────────────────────────────────────

class _PollList extends StatelessWidget {
  final List<PollSummary> items;
  final bool isEvents;
  final ValueChanged<PollSummary> onTap;

  const _PollList({required this.items, required this.isEvents, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark  = Theme.of(context).brightness == Brightness.dark;
    final open    = items.where((p) => p.isOpen).toList();
    final closed  = items.where((p) => !p.isOpen).toList();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          if (open.isNotEmpty) ...[
            _GroupCard(
              label: isEvents ? 'Abertos' : 'Abertas',
              color: Colors.green.shade500,
              icon:  Icons.lock_open_outlined,
              count: open.length,
              countColor: Colors.green.shade700,
              countBg: Colors.green.shade50,
              isDark: isDark,
              items: open,
              isEvents: isEvents,
              onTap: onTap,
            ),
            const SizedBox(height: 16),
          ],
          if (closed.isNotEmpty)
            _GroupCard(
              label: isEvents ? 'Encerrados' : 'Encerradas',
              color: AppColors.slate400,
              icon:  Icons.lock_outlined,
              count: closed.length,
              countColor: AppColors.slate600,
              countBg: AppColors.slate200,
              isDark: isDark,
              items: closed,
              isEvents: isEvents,
              onTap: onTap,
            ),
        ],
      ),
    );
  }
}

class _GroupCard extends StatelessWidget {
  final String   label;
  final Color    color;
  final IconData icon;
  final int      count;
  final Color    countColor;
  final Color    countBg;
  final bool     isDark;
  final List<PollSummary> items;
  final bool     isEvents;
  final ValueChanged<PollSummary> onTap;

  const _GroupCard({
    required this.label,
    required this.color,
    required this.icon,
    required this.count,
    required this.countColor,
    required this.countBg,
    required this.isDark,
    required this.items,
    required this.isEvents,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.slate900 : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isDark ? AppColors.slate800 : AppColors.slate100),
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: isDark ? AppColors.slate800.withValues(alpha: 0.5) : AppColors.slate50,
              ),
              child: Row(
                children: [
                  Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(6)),
                    child: Icon(icon, size: 12, color: Colors.white),
                  ),
                  const SizedBox(width: 8),
                  Text(label, style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.slate300 : AppColors.slate700,
                  )),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: countBg, borderRadius: BorderRadius.circular(10)),
                    child: Text('$count', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: countColor)),
                  ),
                ],
              ),
            ),

            // Items
            ...items.map((p) => Column(
              children: [
                Divider(height: 1, color: isDark ? AppColors.slate800 : AppColors.slate100),
                isEvents
                    ? EventCard(poll: p, onTap: () => onTap(p))
                    : PollCard(poll: p, onTap: () => onTap(p)),
              ],
            )),
          ],
        ),
      ),
    );
  }
}

// ── States ─────────────────────────────────────────────────────────────────────

class _NoGroup extends StatelessWidget {
  final bool isDark;
  const _NoGroup({required this.isDark});

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.how_to_vote_outlined, size: 40, color: isDark ? AppColors.slate700 : AppColors.slate200),
        const SizedBox(height: 12),
        Text('Selecione um grupo no Dashboard.',
          style: TextStyle(fontSize: 14, color: isDark ? AppColors.slate500 : AppColors.slate400)),
      ],
    ),
  );
}

class _Empty extends StatelessWidget {
  final bool isEvents;
  final bool isAdmin;
  const _Empty({required this.isEvents, required this.isAdmin});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isEvents ? Icons.calendar_today_outlined : Icons.how_to_vote_outlined,
            size: 40,
            color: isDark ? AppColors.slate700 : AppColors.slate200,
          ),
          const SizedBox(height: 12),
          Text(
            isEvents ? 'Nenhum evento ainda' : 'Nenhuma votação ainda',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: isDark ? AppColors.slate400 : AppColors.slate500),
          ),
          if (isAdmin) ...[
            const SizedBox(height: 4),
            Text(
              'Toque em "${isEvents ? 'Novo evento' : 'Nova votação'}" para criar.',
              style: TextStyle(fontSize: 12, color: isDark ? AppColors.slate600 : AppColors.slate400),
            ),
          ],
        ],
      ),
    );
  }
}

class _Skeleton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: List.generate(3, (i) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Container(
            height: 90,
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark
                  ? AppColors.slate800 : AppColors.slate100,
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        )),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final VoidCallback onRetry;
  const _ErrorState({required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.error_outline, size: 36, color: Colors.red),
        const SizedBox(height: 8),
        const Text('Erro ao carregar.', style: TextStyle(fontSize: 14)),
        const SizedBox(height: 12),
        TextButton(onPressed: onRetry, child: const Text('Tentar novamente')),
      ],
    ),
  );
}

enum _Tab { events, polls }

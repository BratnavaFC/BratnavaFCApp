import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../widgets/app_top_bar.dart';

class ShellPage extends StatelessWidget {
  final Widget child;

  const ShellPage({super.key, required this.child});

  static const _tabs = [
    _TabItem(icon: Icons.home_outlined,       activeIcon: Icons.home,             label: 'Dashboard', path: '/app'),
    _TabItem(icon: Icons.sports_soccer_outlined, activeIcon: Icons.sports_soccer, label: 'Partidas',  path: '/app/matches'),
    _TabItem(icon: Icons.group_outlined,      activeIcon: Icons.group,            label: 'Grupos',    path: '/app/groups'),
    _TabItem(icon: Icons.history_outlined,    activeIcon: Icons.history,          label: 'Histórico', path: '/app/history'),
    _TabItem(icon: Icons.more_horiz_outlined, activeIcon: Icons.more_horiz,       label: 'Mais',      path: ''),
  ];

  int _selectedIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    for (var i = 0; i < _tabs.length - 1; i++) {
      if (location.startsWith(_tabs[i].path)) return i;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selectedIndex(context);

    return Scaffold(
      appBar: const AppTopBar(),
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: selected,
        onDestinationSelected: (i) {
          if (_tabs[i].path.isNotEmpty) {
            context.go(_tabs[i].path);
          } else {
            _openDrawer(context);
          }
        },
        destinations: _tabs
            .map((t) => NavigationDestination(
                  icon:          Icon(t.icon),
                  selectedIcon:  Icon(t.activeIcon),
                  label:         t.label,
                ))
            .toList(),
      ),
    );
  }

  void _openDrawer(BuildContext context) {
    showModalBottomSheet(
      context:             context,
      isScrollControlled:  true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => const _MoreSheet(),
    );
  }
}

class _TabItem {
  final IconData icon;
  final IconData activeIcon;
  final String   label;
  final String   path;

  const _TabItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.path,
  });
}

class _MoreSheet extends StatelessWidget {
  const _MoreSheet();

  static const _items = [
    (Icons.calendar_month_outlined, 'Calendário',    '/app/calendar'),
    (Icons.palette_outlined,        'Cores',         '/app/team-colors'),
    (Icons.bar_chart_outlined,      'Visual Stats',  '/app/visual-stats'),
    (Icons.payments_outlined,       'Pagamentos',    '/app/payments'),
    (Icons.how_to_vote_outlined,    'Enquetes',      '/app/polls'),
    (Icons.cake_outlined,           'Aniversários',  '/app/birthdays'),
    (Icons.settings_outlined,       'Configurações', '/app/settings'),
    (Icons.manage_accounts_outlined,'Usuários',      '/app/admin/users'),
  ];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color:        AppColors.slate300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            ..._items.map(
              (item) => ListTile(
                leading:  Icon(item.$1, size: 22),
                title:    Text(item.$2,
                    style: const TextStyle(fontSize: 14)),
                onTap: () {
                  Navigator.pop(context);
                  context.go(item.$3);
                },
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/presentation/widgets/avatar_widget.dart';
import '../../../auth/domain/entities/account.dart';
import '../../../auth/presentation/providers/account_store.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../dashboard/domain/entities/my_player.dart';
import '../../../dashboard/presentation/providers/dashboard_provider.dart';

class AppTopBar extends ConsumerWidget implements PreferredSizeWidget {
  const AppTopBar({super.key});

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accountState = ref.watch(accountStoreProvider);
    final active       = accountState.activeAccount;
    final players      = ref.watch(myPlayersProvider).valueOrNull ?? [];
    final activePlayer = ref.watch(activePlayerProvider);

    // Bootstrap: igual ao site — quando players carregam e o account não tem
    // activePlayerId/activeGroupId, persiste o primeiro player automaticamente.
    ref.listen(myPlayersProvider, (_, next) {
      next.whenData((list) {
        if (list.isEmpty) return;
        final acc = ref.read(accountStoreProvider).activeAccount;
        if (acc == null) return;
        if (acc.activePlayerId != null && acc.activeGroupId != null) return;

        final first = list.first;
        ref.read(accountStoreProvider.notifier).patchActive(
          (a) => a.copyWith(
            activePlayerId: a.activePlayerId ?? first.playerId,
            activeGroupId:  a.activeGroupId  ?? first.groupId,
          ),
        );
      });
    });

    final displayName = activePlayer?.playerName
        ?? active?.name
        ?? active?.email
        ?? '—';
    final subtitle = activePlayer?.groupName;

    return AppBar(
      automaticallyImplyLeading: false,
      titleSpacing: 12,
      // ── LEFT: avatar + nome + grupo ──────────────────────────────
      title: Row(
        children: [
          AvatarWidget(name: displayName, size: 34),
          const SizedBox(width: 10),
          Flexible(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName,
                  style: const TextStyle(
                    fontSize:   14,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (subtitle != null && subtitle.isNotEmpty)
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w400,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? AppColors.slate400
                          : AppColors.slate500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
        ],
      ),
      // ── RIGHT: botão de usuário ───────────────────────────────────
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: _UserMenuButton(
            active:       active,
            accounts:     accountState.accounts,
            activeId:     accountState.activeAccountId,
            players:      players,
            activePlayer: activePlayer,
          ),
        ),
      ],
    );
  }
}

// ── Botão + menu do usuário ───────────────────────────────────────────────────

class _UserMenuButton extends ConsumerWidget {
  final Account?       active;
  final List<Account>  accounts;
  final String?        activeId;
  final List<MyPlayer> players;
  final MyPlayer?      activePlayer;

  const _UserMenuButton({
    required this.active,
    required this.accounts,
    required this.activeId,
    required this.players,
    required this.activePlayer,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark      = Theme.of(context).brightness == Brightness.dark;
    final displayName = activePlayer?.playerName
        ?? active?.name
        ?? active?.email
        ?? '—';
    final label = accounts.length > 1
        ? '${accounts.length} contas'
        : displayName;

    return GestureDetector(
      onTap: () => _openMenu(context, ref),
      child: Container(
        height:  36,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color:        isDark ? AppColors.slate800 : AppColors.slate100,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? AppColors.slate700 : AppColors.slate200,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AvatarWidget(name: displayName, size: 24),
            const SizedBox(width: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 100),
              child: Text(
                label,
                style: TextStyle(
                  fontSize:   12,
                  fontWeight: FontWeight.w500,
                  color: isDark ? AppColors.slate300 : AppColors.slate600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size:  16,
              color: isDark ? AppColors.slate400 : AppColors.slate400,
            ),
          ],
        ),
      ),
    );
  }

  void _openMenu(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context:       context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _UserMenuSheet(
        active:       active,
        accounts:     accounts,
        activeId:     activeId,
        players:      players,
        activePlayer: activePlayer,
        onAccountSwitch: (userId) {
          ref.read(accountStoreProvider.notifier).setActive(userId);
          // Reseta o jogador selecionado manualmente para não exibir
          // o jogador da conta anterior enquanto os novos dados carregam.
          ref.read(activePlayerIdProvider.notifier).state = null;
          context.go('/app');
        },
        onPlayerSwitch: (player) {
          ref.read(accountStoreProvider.notifier).patchActive(
            (a) => a.copyWith(
              activePlayerId: player.playerId,
              activeGroupId:  player.groupId,
            ),
          );
          ref.read(activePlayerIdProvider.notifier).state = player.playerId;
          context.go('/app');
        },
        onAddAccount: () {
          // Pequeno delay para garantir que o modal já fechou
          // antes de disparar a navegação do GoRouter.
          Future.microtask(() {
            if (context.mounted) context.go('/login?add=1');
          });
        },
        onLogout: () async {
          await ref.read(authNotifierProvider.notifier).logout();
          if (context.mounted) context.go('/login');
        },
      ),
    );
  }
}

// ── Bottom Sheet ──────────────────────────────────────────────────────────────

class _UserMenuSheet extends StatelessWidget {
  final Account?       active;
  final List<Account>  accounts;
  final String?        activeId;
  final List<MyPlayer> players;
  final MyPlayer?      activePlayer;
  final ValueChanged<String>   onAccountSwitch;
  final ValueChanged<MyPlayer> onPlayerSwitch;
  final VoidCallback           onAddAccount;
  final VoidCallback           onLogout;

  const _UserMenuSheet({
    required this.active,
    required this.accounts,
    required this.activeId,
    required this.players,
    required this.activePlayer,
    required this.onAccountSwitch,
    required this.onPlayerSwitch,
    required this.onAddAccount,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SafeArea(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Handle
            Center(
              child: Container(
                margin:      const EdgeInsets.only(top: 12, bottom: 8),
                width:       36,
                height:      4,
                decoration:  BoxDecoration(
                  color:        AppColors.slate300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // ── Contas ──────────────────────────────────────────────
            _sectionLabel('Contas', isDark),
            ...accounts.map((a) {
              final isActive  = a.userId == activeId;
              final name      = a.name.isNotEmpty ? a.name : a.email;
              return _AccountTile(
                name:     name,
                email:    a.email,
                isActive: isActive,
                onTap: () {
                  Navigator.pop(context);
                  onAccountSwitch(a.userId);
                },
              );
            }),

            // ── Patota (se múltiplos jogadores) ─────────────────────
            if (players.length > 1) ...[
              _divider(isDark),
              _sectionLabel('Patota', isDark),
              ...players.map((p) {
                final isActive = p.playerId == activePlayer?.playerId;
                return _PlayerTile(
                  player:   p,
                  isActive: isActive,
                  onTap: () {
                    Navigator.pop(context);
                    onPlayerSwitch(p);
                  },
                );
              }),
            ],

            _divider(isDark),

            // ── Adicionar conta ──────────────────────────────────────
            _ActionTile(
              icon:      Icons.person_add_outlined,
              label:     'Adicionar conta',
              iconColor: isDark ? AppColors.slate400 : AppColors.slate600,
              bgColor:   isDark ? AppColors.slate800 : AppColors.slate100,
              onTap: () {
                Navigator.pop(context);
                onAddAccount();
              },
            ),

            _divider(isDark),

            // ── Sair ─────────────────────────────────────────────────
            _ActionTile(
              icon:      Icons.logout_rounded,
              label:     'Sair',
              iconColor: AppColors.rose500,
              bgColor:   isDark
                  ? AppColors.rose500.withAlpha(25)
                  : AppColors.rose50,
              labelColor: AppColors.rose600,
              onTap: () {
                Navigator.pop(context);
                onLogout();
              },
            ),

            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String text, bool isDark) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
        child: Text(
          text.toUpperCase(),
          style: TextStyle(
            fontSize:      11,
            fontWeight:    FontWeight.w600,
            color:         isDark ? AppColors.slate500 : AppColors.slate400,
            letterSpacing: 0.6,
          ),
        ),
      );

  Widget _divider(bool isDark) => Divider(
        height: 8,
        indent: 16,
        endIndent: 16,
        color: isDark ? AppColors.slate800 : AppColors.slate100,
      );
}

// ── Tiles ─────────────────────────────────────────────────────────────────────

class _AccountTile extends StatelessWidget {
  final String  name;
  final String  email;
  final bool    isActive;
  final VoidCallback onTap;

  const _AccountTile({
    required this.name,
    required this.email,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListTile(
      onTap:       onTap,
      tileColor:   isActive
          ? (isDark ? AppColors.slate800 : AppColors.slate50)
          : null,
      leading:     AvatarWidget(name: name, size: 32),
      title: Text(
        name,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
      ),
      subtitle: name != email
          ? Text(email,
              style: TextStyle(
                  fontSize: 12,
                  color: isDark ? AppColors.slate500 : AppColors.slate400))
          : null,
      trailing: isActive
          ? const Icon(Icons.check_rounded,
              color: AppColors.emerald500, size: 18)
          : null,
      dense: true,
    );
  }
}

class _PlayerTile extends StatelessWidget {
  final MyPlayer player;
  final bool     isActive;
  final VoidCallback onTap;

  const _PlayerTile({
    required this.player,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListTile(
      onTap:    onTap,
      leading:  AvatarWidget(name: player.playerName, size: 32),
      title: Text(
        player.playerName,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
      ),
      subtitle: player.groupName.isNotEmpty
          ? Text(player.groupName,
              style: TextStyle(
                  fontSize: 12,
                  color: isDark ? AppColors.slate500 : AppColors.slate400))
          : null,
      trailing: isActive
          ? const Icon(Icons.check_rounded,
              color: AppColors.emerald500, size: 18)
          : null,
      dense: true,
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData  icon;
  final String    label;
  final Color     iconColor;
  final Color     bgColor;
  final Color?    labelColor;
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon,
    required this.label,
    required this.iconColor,
    required this.bgColor,
    this.labelColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListTile(
      onTap: onTap,
      leading: Container(
        width:       28,
        height:      28,
        decoration:  BoxDecoration(
          color:        bgColor,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 15, color: iconColor),
      ),
      title: Text(
        label,
        style: TextStyle(
          fontSize:   14,
          fontWeight: FontWeight.w500,
          color:      labelColor ??
              (isDark ? AppColors.slate300 : AppColors.slate700),
        ),
      ),
      dense: true,
    );
  }
}

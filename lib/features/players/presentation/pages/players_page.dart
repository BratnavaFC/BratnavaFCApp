import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/presentation/widgets/avatar_widget.dart';
import '../../domain/entities/app_user.dart';
import '../providers/players_provider.dart';

// ── Page ──────────────────────────────────────────────────────────────────────

class PlayersPage extends ConsumerStatefulWidget {
  const PlayersPage({super.key});

  @override
  ConsumerState<PlayersPage> createState() => _PlayersPageState();
}

class _PlayersPageState extends ConsumerState<PlayersPage> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark   = Theme.of(context).brightness == Brightness.dark;
    final async    = ref.watch(usersProvider);
    final allUsers = async.valueOrNull ?? [];
    final filtered = _query.isEmpty
        ? allUsers
        : allUsers.where((u) {
            final q = _query.toLowerCase();
            return u.fullName.toLowerCase().contains(q) ||
                u.email.toLowerCase().contains(q) ||
                u.userName.toLowerCase().contains(q);
          }).toList();

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(usersProvider),
      child: CustomScrollView(
        slivers: [
          // ── Header ────────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: _UsersHeader(
              count:  async.valueOrNull?.length ?? 0,
              isDark: isDark,
            ),
          ),

          // ── Search bar ────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: TextField(
                controller: _searchCtrl,
                onChanged:  (v) => setState(() => _query = v),
                style: TextStyle(
                  color: isDark ? AppColors.slate200 : AppColors.slate800,
                ),
                decoration: InputDecoration(
                  hintText:  'Pesquisar por nome ou e-mail…',
                  hintStyle: TextStyle(
                    color: isDark ? AppColors.slate500 : AppColors.slate400,
                  ),
                  prefixIcon: Icon(
                    Icons.search_rounded,
                    color: isDark ? AppColors.slate400 : AppColors.slate500,
                  ),
                  suffixIcon: _query.isNotEmpty
                      ? IconButton(
                          icon: Icon(
                            Icons.clear_rounded,
                            color: isDark ? AppColors.slate400 : AppColors.slate500,
                          ),
                          onPressed: () {
                            _searchCtrl.clear();
                            setState(() => _query = '');
                          },
                        )
                      : null,
                  filled:    true,
                  fillColor: isDark ? AppColors.slate800 : AppColors.slate100,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:   BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12,
                  ),
                ),
              ),
            ),
          ),

          // ── Body ──────────────────────────────────────────────────────
          async.when(
            loading: () => const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => SliverFillRemaining(
              child: _ErrorState(
                message: e.toString(),
                onRetry: () => ref.invalidate(usersProvider),
              ),
            ),
            data: (_) {
              if (filtered.isEmpty) {
                return SliverFillRemaining(
                  child: _EmptyState(query: _query, isDark: isDark),
                );
              }
              return SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                sliver: SliverList.separated(
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (ctx, i) => _UserTile(
                    user:   filtered[i],
                    isDark: isDark,
                    onTap:  () => _showDetail(ctx, filtered[i], isDark),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  void _showDetail(BuildContext context, AppUser user, bool isDark) {
    showModalBottomSheet(
      context:             context,
      isScrollControlled:  true,
      backgroundColor:     Colors.transparent,
      builder: (_) => _UserDetailSheet(user: user, isDark: isDark),
    );
  }
}

// ── Header ────────────────────────────────────────────────────────────────────

class _UsersHeader extends StatelessWidget {
  final int  count;
  final bool isDark;

  const _UsersHeader({required this.count, required this.isDark});

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
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
          child: Row(
            children: [
              // Icon
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color:        Colors.white.withAlpha(20),
                  borderRadius: BorderRadius.circular(12),
                  border:       Border.all(color: Colors.white.withAlpha(40)),
                ),
                child: const Icon(
                  Icons.people_rounded,
                  size:  22,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 14),
              // Title + count
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Usuários',
                      style: TextStyle(
                        color:      Colors.white,
                        fontSize:   20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (count > 0)
                      Text(
                        '$count usuário${count == 1 ? '' : 's'} cadastrado${count == 1 ? '' : 's'}',
                        style: TextStyle(
                          color:    Colors.white.withAlpha(140),
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── User Tile ─────────────────────────────────────────────────────────────────

class _UserTile extends StatelessWidget {
  final AppUser      user;
  final bool         isDark;
  final VoidCallback onTap;

  const _UserTile({
    required this.user,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color:        isDark ? AppColors.slate800 : Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap:        onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              // Avatar
              AvatarWidget(name: user.fullName, size: 44),
              const SizedBox(width: 12),

              // Name + email
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.fullName,
                      style: TextStyle(
                        fontSize:   14,
                        fontWeight: FontWeight.w600,
                        color:      isDark ? AppColors.slate100 : AppColors.slate800,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      user.email,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? AppColors.slate400 : AppColors.slate500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (user.roles.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 4,
                        children: user.roles
                            .map((r) => _RoleBadge(role: r, isDark: isDark))
                            .toList(),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(width: 8),

              // Active indicator + chevron
              Column(
                children: [
                  Container(
                    width: 8, height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: user.isActive
                          ? AppColors.emerald500
                          : AppColors.slate400,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Icon(
                    Icons.chevron_right_rounded,
                    size:  18,
                    color: isDark ? AppColors.slate600 : AppColors.slate300,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Role Badge ────────────────────────────────────────────────────────────────

class _RoleBadge extends StatelessWidget {
  final String role;
  final bool   isDark;

  const _RoleBadge({required this.role, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final Color bg;
    final Color fg;

    switch (role.toLowerCase()) {
      case 'admin':
        bg = AppColors.rose500.withAlpha(30);
        fg = AppColors.rose500;
      case 'groupadmin':
      case 'group admin':
        bg = AppColors.amber400.withAlpha(30);
        fg = AppColors.amber500;
      default:
        bg = isDark ? AppColors.slate700 : AppColors.slate100;
        fg = isDark ? AppColors.slate300 : AppColors.slate500;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color:        bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        role,
        style: TextStyle(
          fontSize:   10,
          fontWeight: FontWeight.w600,
          color:      fg,
        ),
      ),
    );
  }
}

// ── Detail Sheet ──────────────────────────────────────────────────────────────

class _UserDetailSheet extends StatelessWidget {
  final AppUser user;
  final bool    isDark;

  const _UserDetailSheet({required this.user, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color:        isDark ? AppColors.slate900 : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.only(top: 10, bottom: 4),
              width:  36, height: 4,
              decoration: BoxDecoration(
                color:        AppColors.slate400,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                  begin:  Alignment.topLeft,
                  end:    Alignment.bottomRight,
                ),
              ),
              child: Row(
                children: [
                  AvatarWidget(name: user.fullName, size: 48),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user.fullName,
                          style: const TextStyle(
                            color:      Colors.white,
                            fontSize:   16,
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '@${user.userName.isNotEmpty ? user.userName : user.email}',
                          style: TextStyle(
                            color:    Colors.white.withAlpha(160),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Status badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color:        user.isActive
                          ? AppColors.emerald500.withAlpha(40)
                          : AppColors.slate700,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: user.isActive
                            ? AppColors.emerald500.withAlpha(100)
                            : AppColors.slate600,
                      ),
                    ),
                    child: Text(
                      user.isActive ? 'Ativo' : 'Inativo',
                      style: TextStyle(
                        fontSize:   11,
                        fontWeight: FontWeight.w600,
                        color: user.isActive
                            ? AppColors.emerald500
                            : AppColors.slate400,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Body
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _DetailRow(
                    icon:  Icons.email_outlined,
                    label: 'E-mail',
                    value: user.email,
                    isDark: isDark,
                  ),
                  if (user.userName.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _DetailRow(
                      icon:  Icons.alternate_email_rounded,
                      label: 'Usuário',
                      value: user.userName,
                      isDark: isDark,
                    ),
                  ],
                  if (user.roles.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(
                      'FUNÇÕES',
                      style: TextStyle(
                        fontSize:      11,
                        fontWeight:    FontWeight.w600,
                        color:         isDark ? AppColors.slate500 : AppColors.slate400,
                        letterSpacing: 0.6,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: user.roles
                          .map((r) => _RoleBadge(role: r, isDark: isDark))
                          .toList(),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String   label;
  final String   value;
  final bool     isDark;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          icon,
          size:  16,
          color: isDark ? AppColors.slate500 : AppColors.slate400,
        ),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: TextStyle(
            fontSize: 13,
            color:    isDark ? AppColors.slate500 : AppColors.slate400,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize:   13,
              fontWeight: FontWeight.w500,
              color:      isDark ? AppColors.slate200 : AppColors.slate700,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

// ── Empty / Error states ──────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final String query;
  final bool   isDark;

  const _EmptyState({required this.query, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            query.isEmpty ? Icons.people_outline_rounded : Icons.search_off_rounded,
            size:  52,
            color: isDark ? AppColors.slate700 : AppColors.slate300,
          ),
          const SizedBox(height: 12),
          Text(
            query.isEmpty
                ? 'Nenhum usuário encontrado'
                : 'Sem resultados para "$query"',
            style: TextStyle(
              color:    isDark ? AppColors.slate400 : AppColors.slate500,
              fontSize: 15,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String       message;
  final VoidCallback onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded,
                size: 48, color: AppColors.rose500),
            const SizedBox(height: 12),
            const Text(
              'Erro ao carregar usuários',
              style: TextStyle(
                fontSize:   16,
                fontWeight: FontWeight.w600,
                color:      AppColors.slate400,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: const TextStyle(fontSize: 12, color: AppColors.slate500),
              textAlign: TextAlign.center,
              maxLines:  3,
              overflow:  TextOverflow.ellipsis,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon:  const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Tentar novamente'),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../auth/presentation/providers/account_store.dart';
import '../../../dashboard/presentation/providers/dashboard_provider.dart';
import '../../data/datasources/absences_remote_datasource.dart';
import '../../domain/entities/absence.dart';
import '../providers/absences_provider.dart';
import '../widgets/absence_card.dart';
import '../widgets/absence_form_sheet.dart';

class AbsencesPage extends ConsumerStatefulWidget {
  const AbsencesPage({super.key});

  @override
  ConsumerState<AbsencesPage> createState() => _AbsencesPageState();
}

class _AbsencesPageState extends ConsumerState<AbsencesPage> {

  // ── Getters ───────────────────────────────────────────────────────────────

  // NOTE: use ref.watch in build() for groupId and activePlayerId so the
  // page reacts when the account finishes loading (avoids empty-string groupId).

  AbsencesRemoteDataSource get _ds => ref.read(absencesDsProvider);

  // ── Refresh ───────────────────────────────────────────────────────────────

  Future<void> _refresh(String groupId) => Future.microtask(() {
        ref.invalidate(groupAbsencesProvider(groupId));
      });

  // ── Sheet helpers ─────────────────────────────────────────────────────────

  void _openCreateSheet(String groupId) {
    AbsenceFormSheet.show(
      context:    context,
      datasource: _ds,
      absence:    null,
      onSaved:    () => _refresh(groupId),
    );
  }

  void _openEditSheet(Absence absence, String groupId) {
    AbsenceFormSheet.show(
      context:    context,
      datasource: _ds,
      absence:    absence,
      onSaved:    () => _refresh(groupId),
    );
  }

  Future<void> _deleteAbsence(Absence absence, String groupId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title:   const Text('Excluir ausência'),
        content: Text(
          'Excluir ausência de ${absence.playerName} (${absence.displayTypeName})?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Excluir',
                style: TextStyle(color: AppColors.rose500)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await _ds.delete(absence.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ausência excluída.')),
        );
        _refresh(groupId);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao excluir: $e')),
        );
      }
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Watch account + players so we always have a valid groupId
    final account      = ref.watch(accountStoreProvider).activeAccount;
    final players      = ref.watch(myPlayersProvider).valueOrNull ?? [];
    final groupId      = account?.activeGroupId
        ?? (players.isNotEmpty ? players.first.groupId : '');
    final activePlayer = ref.watch(activePlayerProvider)?.playerId ?? '';

    // Don't fire the request until we have a real groupId
    final absencesAsync = groupId.isNotEmpty
        ? ref.watch(groupAbsencesProvider(groupId))
        : const AsyncLoading<List<Absence>>();

    return Scaffold(
      body: Column(
        children: [

          // ── Header ────────────────────────────────────────────────────────
          _AbsencesHeader(
            isDark:   isDark,
            count:    absencesAsync.valueOrNull?.length,
            onNewTap: absencesAsync.valueOrNull != null && groupId.isNotEmpty
                ? () => _openCreateSheet(groupId)
                : null,
          ),

          // ── Body ──────────────────────────────────────────────────────────
          Expanded(
            child: absencesAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (err, _) => _ErrorState(
                message: err.toString(),
                onRetry: () => _refresh(groupId),
              ),
              data: (absences) => absences.isEmpty
                  ? _EmptyState(isDark: isDark)
                  : RefreshIndicator(
                      onRefresh: () => _refresh(groupId),
                      child: _AbsenceList(
                        absences:       absences,
                        activePlayerId: activePlayer,
                        onEdit:  (a) => _openEditSheet(a, groupId),
                        onDelete:(a) => _deleteAbsence(a, groupId),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Grouped list ──────────────────────────────────────────────────────────────

class _AbsenceList extends StatelessWidget {
  final List<Absence>          absences;
  final String                 activePlayerId;
  final void Function(Absence) onEdit;
  final void Function(Absence) onDelete;

  const _AbsenceList({
    required this.absences,
    required this.activePlayerId,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Group by player name preserving insertion order
    final grouped = <String, List<Absence>>{};
    for (final a in absences) {
      grouped.putIfAbsent(a.playerName, () => []).add(a);
    }

    final sectionColor = isDark ? AppColors.slate300 : AppColors.slate700;
    final badgeColor   = isDark ? AppColors.slate700 : AppColors.slate100;
    final badgeText    = isDark ? AppColors.slate400  : AppColors.slate500;

    final items = <Widget>[];
    grouped.forEach((playerName, list) {
      final isSelf = list.any((a) => a.playerId == activePlayerId);

      // Section header
      items.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 16, 6),
          child: Row(
            children: [
              Text(
                playerName,
                style: TextStyle(
                  color:      sectionColor,
                  fontSize:   13,
                  fontWeight: FontWeight.w600,
                  letterSpacing: .3,
                ),
              ),
              if (isSelf) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color:        badgeColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'você',
                    style: TextStyle(
                      color:      badgeText,
                      fontSize:   10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      );

      // Cards
      for (final a in list) {
        final canEdit = a.playerId == activePlayerId;
        items.add(
          AbsenceCard(
            absence:  a,
            canEdit:  canEdit,
            onEdit:   () => onEdit(a),
            onDelete: () => onDelete(a),
          ),
        );
      }
    });

    items.add(const SizedBox(height: 24));

    return ListView(
      padding: EdgeInsets.zero,
      children: items,
    );
  }
}

// ── Header ────────────────────────────────────────────────────────────────────

class _AbsencesHeader extends StatelessWidget {
  final bool          isDark;
  final int?          count;
  final VoidCallback? onNewTap;

  const _AbsencesHeader({
    required this.isDark,
    required this.count,
    required this.onNewTap,
  });

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
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
          child: Row(
            children: [

              // Icon
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color:        Colors.white.withValues(alpha: .1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: Colors.white.withValues(alpha: .2)),
                ),
                child: const Center(
                  child: Text('🏖️', style: TextStyle(fontSize: 18)),
                ),
              ),

              const SizedBox(width: 12),

              // Title + count
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Ausências',
                      style: TextStyle(
                        color:      Colors.white,
                        fontSize:   16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    if (count != null)
                      Text(
                        '$count ${count == 1 ? 'ausência' : 'ausências'} na patota',
                        style: TextStyle(
                          color:    Colors.white.withValues(alpha: .55),
                          fontSize: 11,
                        ),
                      ),
                  ],
                ),
              ),

              // Nova ausência button
              if (onNewTap != null)
                TextButton.icon(
                  onPressed: onNewTap,
                  style: TextButton.styleFrom(
                    backgroundColor: AppColors.blue500,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                    textStyle: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  icon:  const Icon(Icons.add, size: 16),
                  label: const Text('Nova ausência'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final bool isDark;
  const _EmptyState({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('🏖️', style: TextStyle(fontSize: 48)),
          const SizedBox(height: 12),
          Text(
            'Nenhuma ausência registrada',
            style: TextStyle(
              color:      isDark ? AppColors.slate400 : AppColors.slate500,
              fontSize:   15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Toque em + Nova ausência para adicionar.',
            style: TextStyle(
              color:    isDark ? AppColors.slate600 : AppColors.slate400,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Error state ───────────────────────────────────────────────────────────────

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
            const Icon(Icons.error_outline,
                size: 44, color: AppColors.rose500),
            const SizedBox(height: 12),
            const Text(
              'Erro ao carregar ausências',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
            ),
            const SizedBox(height: 4),
            Text(
              message,
              style: const TextStyle(
                  color: AppColors.slate500, fontSize: 12),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon:      const Icon(Icons.refresh),
              label:     const Text('Tentar novamente'),
            ),
          ],
        ),
      ),
    );
  }
}

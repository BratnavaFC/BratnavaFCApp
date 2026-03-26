import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/datasources/polls_remote_datasource.dart';
import '../../domain/entities/poll_detail.dart';
import '../providers/polls_provider.dart';
import 'close_poll_sheet.dart';

class EventDetailSheet extends ConsumerStatefulWidget {
  final PollDetail   poll;
  final String       groupId;
  final bool         isAdmin;
  final ValueChanged<PollDetail> onUpdated;
  final VoidCallback? onDeleted;

  const EventDetailSheet({
    super.key,
    required this.poll,
    required this.groupId,
    required this.isAdmin,
    required this.onUpdated,
    this.onDeleted,
  });

  @override
  ConsumerState<EventDetailSheet> createState() => _EventDetailSheetState();
}

class _EventDetailSheetState extends ConsumerState<EventDetailSheet> {
  late PollDetail _poll;
  bool _saving     = false;
  bool _adminOpen  = false;

  // Admin member vote state: playerId → selected option id
  final Map<String, String?> _memberSelections = {};

  @override
  void initState() {
    super.initState();
    _poll = widget.poll;
  }

  PollsRemoteDataSource get _ds => ref.read(pollsDsProvider);

  String? get _myVote => _poll.myVotedOptionIds.isNotEmpty ? _poll.myVotedOptionIds.first : null;

  String _formatDate(String? d) {
    if (d == null) return '';
    final p = d.split('-');
    return p.length == 3 ? '${p[2]}/${p[1]}/${p[0]}' : d;
  }

  String? _formatCost() {
    if (_poll.costType == null || _poll.costType!.isEmpty) return null;
    final label = _poll.costType == 'individual' ? 'por pessoa' : 'rateio grupo';
    if (_poll.costAmount != null) return 'R\$ ${_poll.costAmount!.toStringAsFixed(2)} $label';
    return label;
  }

  Future<void> _vote(String optionId) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final updated = _myVote == optionId
          ? await _ds.removeVote(widget.groupId, _poll.id)
          : await _ds.castVote(widget.groupId, _poll.id, [optionId]);
      setState(() => _poll = updated);
      widget.onUpdated(updated);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao votar: $e'), backgroundColor: AppColors.rose500),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _adminVote(String playerId, String? optionId) async {
    if (optionId == null) return;
    setState(() => _saving = true);
    try {
      final updated = await _ds.adminCastVote(widget.groupId, _poll.id, playerId, [optionId]);
      setState(() {
        _poll = updated;
        _memberSelections[playerId] = optionId;
      });
      widget.onUpdated(updated);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $e'), backgroundColor: AppColors.rose500),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _closePoll() async {
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ClosePollSheet(pollTitle: _poll.title),
    );
    if (result == null) return;
    setState(() => _saving = true);
    try {
      await _ds.closePoll(widget.groupId, _poll.id, result);
      final updated = await _ds.getPoll(widget.groupId, _poll.id);
      setState(() => _poll = updated);
      widget.onUpdated(updated);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $e'), backgroundColor: AppColors.rose500),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _reopenPoll() async {
    setState(() => _saving = true);
    try {
      await _ds.reopenPoll(widget.groupId, _poll.id);
      final updated = await _ds.getPoll(widget.groupId, _poll.id);
      setState(() => _poll = updated);
      widget.onUpdated(updated);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $e'), backgroundColor: AppColors.rose500),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _deletePoll() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Excluir evento'),
        content: Text('Deseja excluir "${_poll.title}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Excluir', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    setState(() => _saving = true);
    try {
      await _ds.deletePoll(widget.groupId, _poll.id);
      widget.onDeleted?.call();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $e'), backgroundColor: AppColors.rose500),
        );
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final icon   = _poll.eventIcon ?? '📅';
    final cost   = _formatCost();
    final total  = _poll.totalVoters;

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      maxChildSize:     0.95,
      minChildSize:     0.5,
      builder: (_, controller) => Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.slate900 : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Handle
            const SizedBox(height: 8),
            Container(width: 36, height: 4,
              decoration: BoxDecoration(color: AppColors.slate300, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 4),

            // Content
            Expanded(
              child: ListView(
                controller: controller,
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                children: [
                  // ── Header ──
                  Row(
                    children: [
                      Text(icon, style: const TextStyle(fontSize: 32)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_poll.title, style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w800,
                              color: isDark ? Colors.white : AppColors.slate900,
                            )),
                            if (_poll.description != null)
                              Text(_poll.description!, style: TextStyle(
                                fontSize: 13, color: isDark ? AppColors.slate400 : AppColors.slate500,
                              )),
                          ],
                        ),
                      ),
                      _StatusChip(isOpen: _poll.isOpen),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // ── Meta info ──
                  Wrap(spacing: 12, runSpacing: 6, children: [
                    if (_poll.eventDate != null)
                      _InfoChip(icon: Icons.calendar_today_outlined,
                        label: '${_formatDate(_poll.eventDate)}${_poll.eventTime != null ? ' às ${_poll.eventTime}' : ''}'),
                    if (_poll.eventLocation != null)
                      _InfoChip(icon: Icons.location_on_outlined, label: _poll.eventLocation!),
                    if (cost != null)
                      _InfoChip(icon: Icons.attach_money, label: cost, color: Colors.amber.shade700),
                    if (_poll.deadlineDate != null)
                      _InfoChip(
                        icon: Icons.schedule,
                        label: 'Prazo: ${_formatDate(_poll.deadlineDate)}${_poll.deadlineTime != null ? ' às ${_poll.deadlineTime}' : ''}',
                        color: _poll.deadlinePassed ? Colors.red.shade400 : null,
                      ),
                  ]),
                  const SizedBox(height: 20),

                  // ── RSVP buttons ──
                  if (_poll.isOpen) ...[
                    Text('Sua resposta', style: TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600,
                      color: isDark ? AppColors.slate300 : AppColors.slate600,
                    )),
                    const SizedBox(height: 8),
                    Row(
                      children: _poll.options.map((opt) {
                        final isSelected = _poll.myVotedOptionIds.contains(opt.id);
                        return Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: _RsvpButton(
                              label: opt.text,
                              isSelected: isSelected,
                              saving: _saving,
                              onTap: () => _vote(opt.id),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // ── Results ──
                  Text(
                    '$total resposta${total != 1 ? 's' : ''}',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                      color: isDark ? AppColors.slate300 : AppColors.slate600),
                  ),
                  const SizedBox(height: 8),
                  ..._poll.options.map((opt) {
                    final pct = total > 0 ? opt.voteCount / total : 0.0;
                    final voters = _poll.votes?.where((v) => v.optionId == opt.id).toList() ?? [];
                    return _ResultBar(
                      label: opt.text,
                      count: opt.voteCount,
                      pct: pct,
                      showVoters: _poll.showVotes,
                      voters: voters.map((v) => v.playerName).toList(),
                      isDark: isDark,
                    );
                  }),

                  // ── Admin panel ──
                  if (widget.isAdmin) ...[
                    const SizedBox(height: 20),
                    _AdminPanel(
                      open: _adminOpen,
                      onToggle: () => setState(() => _adminOpen = !_adminOpen),
                      isDark: isDark,
                      child: _adminOpen ? _AdminContent(
                        poll: _poll,
                        saving: _saving,
                        selections: _memberSelections,
                        onVote: _adminVote,
                        onClose: _closePoll,
                        onReopen: _reopenPoll,
                        onDelete: _deletePoll,
                        isDark: isDark,
                      ) : const SizedBox.shrink(),
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

// ── Reusable sub-widgets ───────────────────────────────────────────────────────

class _RsvpButton extends StatelessWidget {
  final String label;
  final bool   isSelected;
  final bool   saving;
  final VoidCallback onTap;

  const _RsvpButton({required this.label, required this.isSelected, required this.saving, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: saving ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.slate900 : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? AppColors.slate900 : AppColors.slate200),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : AppColors.slate600,
          ),
        ),
      ),
    );
  }
}

class _ResultBar extends StatelessWidget {
  final String       label;
  final int          count;
  final double       pct;
  final bool         showVoters;
  final List<String> voters;
  final bool         isDark;

  const _ResultBar({
    required this.label,
    required this.count,
    required this.pct,
    required this.showVoters,
    required this.voters,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500,
                color: isDark ? AppColors.slate200 : AppColors.slate700))),
              Text('$count (${(pct * 100).round()}%)',
                style: TextStyle(fontSize: 12, color: isDark ? AppColors.slate400 : AppColors.slate500)),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 6,
              backgroundColor: isDark ? AppColors.slate800 : AppColors.slate100,
              valueColor: const AlwaysStoppedAnimation(AppColors.slate900),
            ),
          ),
          if (showVoters && voters.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(voters.join(', '), style: TextStyle(fontSize: 11,
              color: isDark ? AppColors.slate500 : AppColors.slate400)),
          ],
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final bool isOpen;
  const _StatusChip({required this.isOpen});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: isOpen ? Colors.green.shade50 : AppColors.slate100,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: isOpen ? Colors.green.shade200 : AppColors.slate200),
    ),
    child: Text(isOpen ? 'Aberto' : 'Encerrado',
      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
        color: isOpen ? Colors.green.shade700 : AppColors.slate500)),
  );
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String   label;
  final Color?   color;
  const _InfoChip({required this.icon, required this.label, this.color});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final c = color ?? (isDark ? AppColors.slate400 : AppColors.slate500);
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 13, color: c),
      const SizedBox(width: 4),
      Text(label, style: TextStyle(fontSize: 12, color: c)),
    ]);
  }
}

class _AdminPanel extends StatelessWidget {
  final bool open;
  final VoidCallback onToggle;
  final bool isDark;
  final Widget child;

  const _AdminPanel({required this.open, required this.onToggle, required this.isDark, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.slate800 : AppColors.slate50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? AppColors.slate700 : AppColors.slate200),
      ),
      child: Column(
        children: [
          GestureDetector(
            onTap: onToggle,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Icon(Icons.admin_panel_settings_outlined, size: 18,
                    color: isDark ? AppColors.slate300 : AppColors.slate600),
                  const SizedBox(width: 8),
                  Text('Painel Admin', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.slate200 : AppColors.slate700)),
                  const Spacer(),
                  Icon(open ? Icons.expand_less : Icons.expand_more,
                    color: isDark ? AppColors.slate400 : AppColors.slate500),
                ],
              ),
            ),
          ),
          if (open) child,
        ],
      ),
    );
  }
}

class _AdminContent extends StatelessWidget {
  final PollDetail poll;
  final bool saving;
  final Map<String, String?> selections;
  final Function(String playerId, String? optionId) onVote;
  final VoidCallback onClose;
  final VoidCallback onReopen;
  final VoidCallback onDelete;
  final bool isDark;

  const _AdminContent({
    required this.poll,
    required this.saving,
    required this.selections,
    required this.onVote,
    required this.onClose,
    required this.onReopen,
    required this.onDelete,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final members = poll.members ?? [];

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Divider(color: isDark ? AppColors.slate700 : AppColors.slate200),
          const SizedBox(height: 8),

          // Member responses
          if (members.isNotEmpty) ...[
            Text('Respostas dos membros', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
              color: isDark ? AppColors.slate300 : AppColors.slate600)),
            const SizedBox(height: 8),
            ...members.map((m) {
              final voted = m.votedOptionIds.isNotEmpty ? m.votedOptionIds.first : null;
              final current = selections[m.playerId] ?? voted;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Expanded(child: Text(m.playerName, style: TextStyle(fontSize: 13,
                      color: isDark ? AppColors.slate200 : AppColors.slate700))),
                    DropdownButton<String?>(
                      value: current,
                      hint: const Text('—', style: TextStyle(fontSize: 13)),
                      isDense: true,
                      items: poll.options.map((opt) => DropdownMenuItem(
                        value: opt.id,
                        child: Text(opt.text, style: const TextStyle(fontSize: 13)),
                      )).toList(),
                      onChanged: saving ? null : (v) => onVote(m.playerId, v),
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 12),
          ],

          // Actions
          Row(
            children: [
              if (poll.isOpen)
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: saving ? null : onClose,
                    icon: const Icon(Icons.lock_outlined, size: 15),
                    label: const Text('Encerrar', style: TextStyle(fontSize: 13)),
                    style: OutlinedButton.styleFrom(foregroundColor: Colors.orange.shade700),
                  ),
                )
              else
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: saving ? null : onReopen,
                    icon: const Icon(Icons.lock_open_outlined, size: 15),
                    label: const Text('Reabrir', style: TextStyle(fontSize: 13)),
                  ),
                ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: saving ? null : onDelete,
                icon: const Icon(Icons.delete_outline, size: 15),
                label: const Text('Excluir', style: TextStyle(fontSize: 13)),
                style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

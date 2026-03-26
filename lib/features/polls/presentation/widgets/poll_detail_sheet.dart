import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/datasources/polls_remote_datasource.dart';
import '../../domain/entities/poll_detail.dart';
import '../providers/polls_provider.dart';
import 'close_poll_sheet.dart';

class PollDetailSheet extends ConsumerStatefulWidget {
  final PollDetail   poll;
  final String       groupId;
  final bool         isAdmin;
  final ValueChanged<PollDetail> onUpdated;

  const PollDetailSheet({
    super.key,
    required this.poll,
    required this.groupId,
    required this.isAdmin,
    required this.onUpdated,
  });

  @override
  ConsumerState<PollDetailSheet> createState() => _PollDetailSheetState();
}

class _PollDetailSheetState extends ConsumerState<PollDetailSheet>
    with SingleTickerProviderStateMixin {
  late PollDetail _poll;
  bool   _saving    = false;
  bool   _adminOpen = false;
  late TabController _tabCtrl;

  // New option draft
  final _optTextCtrl = TextEditingController();
  final _optDescCtrl = TextEditingController();
  String? _optImageB64;

  // Selected option ids (for multi-vote)
  final Set<String> _selected = {};

  @override
  void initState() {
    super.initState();
    _poll     = widget.poll;
    _tabCtrl  = TabController(length: 2, vsync: this);
    _selected.addAll(_poll.myVotedOptionIds);
  }

  @override
  void dispose() {
    _optTextCtrl.dispose();
    _optDescCtrl.dispose();
    _tabCtrl.dispose();
    super.dispose();
  }

  PollsRemoteDataSource get _ds => ref.read(pollsDsProvider);

  Future<void> _toggleOption(String optId) async {
    if (!_poll.allowMultipleVotes) {
      setState(() { _selected.clear(); _selected.add(optId); });
    } else {
      setState(() {
        if (_selected.contains(optId)) { _selected.remove(optId); }
        else { _selected.add(optId); }
      });
    }
  }

  Future<void> _submitVote() async {
    if (_selected.isEmpty || _saving) return;
    setState(() => _saving = true);
    try {
      final updated = await _ds.castVote(widget.groupId, _poll.id, _selected.toList());
      setState(() => _poll = updated);
      widget.onUpdated(updated);
    } catch (e) {
      if (mounted) _showError('Erro ao votar: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _removeVote() async {
    setState(() => _saving = true);
    try {
      final updated = await _ds.removeVote(widget.groupId, _poll.id);
      setState(() { _poll = updated; _selected.clear(); });
      widget.onUpdated(updated);
    } catch (e) {
      if (mounted) _showError('Erro ao remover voto: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickImage() async {
    final src = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(leading: const Icon(Icons.photo_library_outlined),
            title: const Text('Galeria'), onTap: () => Navigator.pop(context, ImageSource.gallery)),
          ListTile(leading: const Icon(Icons.camera_alt_outlined),
            title: const Text('Câmera'), onTap: () => Navigator.pop(context, ImageSource.camera)),
        ]),
      ),
    );
    if (src == null) return;
    final file = await ImagePicker().pickImage(source: src);
    if (file == null) return;
    final compressed = await FlutterImageCompress.compressWithFile(
      file.path, minWidth: 1280, minHeight: 1280, quality: 78,
    );
    if (compressed == null) return;
    setState(() => _optImageB64 = 'data:image/jpeg;base64,${base64Encode(compressed)}');
  }

  Future<void> _addOption() async {
    if (_optTextCtrl.text.trim().isEmpty) return;
    setState(() => _saving = true);
    try {
      final updated = await _ds.addOption(widget.groupId, _poll.id, {
        'text':        _optTextCtrl.text.trim(),
        'description': _optDescCtrl.text.trim().isNotEmpty ? _optDescCtrl.text.trim() : null,
        'imageUrl':    _optImageB64,
      });
      setState(() {
        _poll = updated;
        _optTextCtrl.clear();
        _optDescCtrl.clear();
        _optImageB64 = null;
      });
      widget.onUpdated(updated);
    } catch (e) {
      if (mounted) _showError('Erro ao adicionar opção: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _deleteOption(String optId) async {
    setState(() => _saving = true);
    try {
      final updated = await _ds.deleteOption(widget.groupId, _poll.id, optId);
      setState(() => _poll = updated);
      widget.onUpdated(updated);
    } catch (e) {
      if (mounted) _showError('Erro: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _adminVote(String playerId, List<String> optionIds) async {
    setState(() => _saving = true);
    try {
      final updated = await _ds.adminCastVote(widget.groupId, _poll.id, playerId, optionIds);
      setState(() => _poll = updated);
      widget.onUpdated(updated);
    } catch (e) {
      if (mounted) _showError('Erro: $e');
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
      if (mounted) _showError('Erro: $e');
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
      if (mounted) _showError('Erro: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _deletePoll() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Excluir votação'),
        content: Text('Deseja excluir "${_poll.title}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(context, true),
            child: const Text('Excluir', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm != true) return;
    setState(() => _saving = true);
    try {
      await _ds.deletePoll(widget.groupId, _poll.id);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) { _showError('Erro: $e'); setState(() => _saving = false); }
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: AppColors.rose500),
    );
  }

  bool get _hasVoted => _poll.myVotedOptionIds.isNotEmpty;
  bool get _canVote  => _poll.isOpen && !_poll.deadlinePassed;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final total  = _poll.totalVoters;

    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      maxChildSize:     0.95,
      minChildSize:     0.5,
      builder: (_, controller) => Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.slate900 : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 8),
            Container(width: 36, height: 4,
              decoration: BoxDecoration(color: AppColors.slate300, borderRadius: BorderRadius.circular(2))),

            Expanded(
              child: ListView(
                controller: controller,
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                children: [
                  // ── Header ──
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_poll.title, style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w800,
                              color: isDark ? Colors.white : AppColors.slate900,
                            )),
                            if (_poll.description != null) ...[
                              const SizedBox(height: 2),
                              Text(_poll.description!, style: TextStyle(fontSize: 13,
                                color: isDark ? AppColors.slate400 : AppColors.slate500)),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      _StatusChip(isOpen: _poll.isOpen),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Meta
                  Wrap(spacing: 10, runSpacing: 4, children: [
                    if (_poll.allowMultipleVotes)
                      _MetaTag(icon: Icons.check_box_outlined, label: 'Múltipla escolha', isDark: isDark),
                    if (_poll.showVotes)
                      _MetaTag(icon: Icons.visibility_outlined, label: 'Votos visíveis', isDark: isDark),
                    if (_poll.deadlineDate != null) ...[
                      _MetaTag(
                        icon: Icons.schedule,
                        label: _poll.deadlinePassed ? 'Prazo encerrado' : 'Prazo: ${_poll.deadlineDate}',
                        isDark: isDark,
                        color: _poll.deadlinePassed ? Colors.red.shade400 : Colors.amber.shade600,
                      ),
                    ],
                  ]),
                  const SizedBox(height: 16),

                  // ── Options ──
                  Text('${_poll.options.length} opç${_poll.options.length != 1 ? 'ões' : 'ão'}',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                      color: isDark ? AppColors.slate300 : AppColors.slate600)),
                  const SizedBox(height: 8),

                  ..._poll.options.map((opt) {
                    final sel    = _selected.contains(opt.id);
                    final voted  = _poll.myVotedOptionIds.contains(opt.id);
                    final pct    = total > 0 ? opt.voteCount / total : 0.0;
                    final voters = _poll.votes?.where((v) => v.optionId == opt.id).map((v) => v.playerName).toList() ?? [];

                    return _OptionTile(
                      opt:       opt,
                      selected:  sel,
                      voted:     voted,
                      pct:       pct,
                      total:     total,
                      showVotes: _poll.showVotes,
                      voters:    voters,
                      canVote:   _canVote && !_hasVoted,
                      isAdmin:   widget.isAdmin,
                      saving:    _saving,
                      isDark:    isDark,
                      onTap:     _canVote && !_hasVoted ? () => _toggleOption(opt.id) : null,
                      onDelete:  widget.isAdmin ? () => _deleteOption(opt.id) : null,
                    );
                  }),

                  // Vote / Remove vote buttons
                  if (_canVote) ...[
                    const SizedBox(height: 12),
                    if (!_hasVoted)
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _selected.isEmpty || _saving ? null : _submitVote,
                          child: _saving
                              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Text('Votar'),
                        ),
                      )
                    else
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: _saving ? null : _removeVote,
                          child: const Text('Remover meu voto'),
                        ),
                      ),
                  ],

                  // ── Admin panel ──
                  if (widget.isAdmin) ...[
                    const SizedBox(height: 20),
                    _AdminPollPanel(
                      poll:       _poll,
                      open:       _adminOpen,
                      saving:     _saving,
                      tabCtrl:    _tabCtrl,
                      isDark:     isDark,
                      optTextCtrl: _optTextCtrl,
                      optDescCtrl: _optDescCtrl,
                      optImageB64: _optImageB64,
                      onToggle:   () => setState(() => _adminOpen = !_adminOpen),
                      onPickImage: _pickImage,
                      onAddOption: _addOption,
                      onAdminVote: _adminVote,
                      onClose:    _closePoll,
                      onReopen:   _reopenPoll,
                      onDelete:   _deletePoll,
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

// ── Option tile ────────────────────────────────────────────────────────────────

class _OptionTile extends StatelessWidget {
  final PollOption   opt;
  final bool         selected;
  final bool         voted;
  final double       pct;
  final int          total;
  final bool         showVotes;
  final List<String> voters;
  final bool         canVote;
  final bool         isAdmin;
  final bool         saving;
  final bool         isDark;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  const _OptionTile({
    required this.opt,
    required this.selected,
    required this.voted,
    required this.pct,
    required this.total,
    required this.showVotes,
    required this.voters,
    required this.canVote,
    required this.isAdmin,
    required this.saving,
    required this.isDark,
    this.onTap,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final active = selected || voted;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: active
                ? (isDark ? AppColors.slate700 : AppColors.slate100)
                : (isDark ? AppColors.slate800 : AppColors.slate50),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: active ? AppColors.slate900 : (isDark ? AppColors.slate700 : AppColors.slate200),
              width: active ? 1.5 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (opt.imageUrl != null) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(opt.imageUrl!, width: 44, height: 44, fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Icon(Icons.broken_image_outlined, size: 44)),
                    ),
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(opt.text, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : AppColors.slate900)),
                        if (opt.description != null)
                          Text(opt.description!, style: TextStyle(fontSize: 12,
                            color: isDark ? AppColors.slate400 : AppColors.slate500)),
                      ],
                    ),
                  ),
                  if (total > 0)
                    Text('${opt.voteCount} (${(pct * 100).round()}%)',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500,
                        color: isDark ? AppColors.slate400 : AppColors.slate500)),
                  if (isAdmin && onDelete != null)
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                      onPressed: saving ? null : onDelete,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                    ),
                ],
              ),
              if (total > 0) ...[
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: pct,
                    minHeight: 5,
                    backgroundColor: isDark ? AppColors.slate700 : AppColors.slate200,
                    valueColor: const AlwaysStoppedAnimation(AppColors.slate900),
                  ),
                ),
              ],
              if (showVotes && voters.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(voters.join(', '), style: TextStyle(fontSize: 11,
                  color: isDark ? AppColors.slate500 : AppColors.slate400)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ── Admin poll panel ───────────────────────────────────────────────────────────

class _AdminPollPanel extends StatelessWidget {
  final PollDetail  poll;
  final bool        open;
  final bool        saving;
  final TabController tabCtrl;
  final bool        isDark;
  final TextEditingController optTextCtrl;
  final TextEditingController optDescCtrl;
  final String?     optImageB64;
  final VoidCallback onToggle;
  final VoidCallback onPickImage;
  final VoidCallback onAddOption;
  final Function(String playerId, List<String> optionIds) onAdminVote;
  final VoidCallback onClose;
  final VoidCallback onReopen;
  final VoidCallback onDelete;

  const _AdminPollPanel({
    required this.poll,
    required this.open,
    required this.saving,
    required this.tabCtrl,
    required this.isDark,
    required this.optTextCtrl,
    required this.optDescCtrl,
    required this.optImageB64,
    required this.onToggle,
    required this.onPickImage,
    required this.onAddOption,
    required this.onAdminVote,
    required this.onClose,
    required this.onReopen,
    required this.onDelete,
  });

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
              child: Row(children: [
                Icon(Icons.admin_panel_settings_outlined, size: 18,
                  color: isDark ? AppColors.slate300 : AppColors.slate600),
                const SizedBox(width: 8),
                Text('Painel Admin', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                  color: isDark ? AppColors.slate200 : AppColors.slate700)),
                const Spacer(),
                Icon(open ? Icons.expand_less : Icons.expand_more,
                  color: isDark ? AppColors.slate400 : AppColors.slate500),
              ]),
            ),
          ),
          if (open) ...[
            TabBar(
              controller: tabCtrl,
              tabs: const [Tab(text: 'Opções'), Tab(text: 'Resultado')],
            ),
            SizedBox(
              height: 400,
              child: TabBarView(
                controller: tabCtrl,
                children: [
                  _OptionsTab(
                    poll: poll, saving: saving, isDark: isDark,
                    optTextCtrl: optTextCtrl, optDescCtrl: optDescCtrl,
                    optImageB64: optImageB64, onPickImage: onPickImage,
                    onAddOption: onAddOption, onClose: onClose,
                    onReopen: onReopen, onDelete: onDelete,
                  ),
                  _ResultTab(poll: poll, saving: saving, isDark: isDark, onAdminVote: onAdminVote),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _OptionsTab extends StatelessWidget {
  final PollDetail  poll;
  final bool        saving;
  final bool        isDark;
  final TextEditingController optTextCtrl;
  final TextEditingController optDescCtrl;
  final String?     optImageB64;
  final VoidCallback onPickImage;
  final VoidCallback onAddOption;
  final VoidCallback onClose;
  final VoidCallback onReopen;
  final VoidCallback onDelete;

  const _OptionsTab({
    required this.poll, required this.saving, required this.isDark,
    required this.optTextCtrl, required this.optDescCtrl, required this.optImageB64,
    required this.onPickImage, required this.onAddOption,
    required this.onClose, required this.onReopen, required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Add option form
          Text('Nova opção', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
            color: isDark ? AppColors.slate300 : AppColors.slate600)),
          const SizedBox(height: 6),
          TextFormField(
            controller: optTextCtrl,
            decoration: const InputDecoration(labelText: 'Texto *', isDense: true, contentPadding: EdgeInsets.all(10)),
          ),
          const SizedBox(height: 6),
          TextFormField(
            controller: optDescCtrl,
            decoration: const InputDecoration(labelText: 'Descrição (opcional)', isDense: true, contentPadding: EdgeInsets.all(10)),
          ),
          const SizedBox(height: 6),
          GestureDetector(
            onTap: onPickImage,
            child: Container(
              height: 52,
              decoration: BoxDecoration(
                border: Border.all(color: isDark ? AppColors.slate600 : AppColors.slate300),
                borderRadius: BorderRadius.circular(10),
                color: isDark ? AppColors.slate700 : AppColors.slate50,
              ),
              child: optImageB64 != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.memory(base64Decode(optImageB64!.split(',').last),
                        fit: BoxFit.cover, width: double.infinity))
                  : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(Icons.add_photo_alternate_outlined, size: 18,
                        color: isDark ? AppColors.slate400 : AppColors.slate500),
                      const SizedBox(width: 6),
                      Text('Adicionar imagem (opcional)',
                        style: TextStyle(fontSize: 12, color: isDark ? AppColors.slate400 : AppColors.slate500)),
                    ]),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: saving ? null : onAddOption,
              child: const Text('Adicionar opção', style: TextStyle(fontSize: 13)),
            ),
          ),
          const Divider(height: 24),
          // Actions
          Row(children: [
            if (poll.isOpen)
              Expanded(child: OutlinedButton.icon(
                onPressed: saving ? null : onClose,
                icon: const Icon(Icons.lock_outlined, size: 15),
                label: const Text('Encerrar', style: TextStyle(fontSize: 13)),
                style: OutlinedButton.styleFrom(foregroundColor: Colors.orange.shade700),
              ))
            else
              Expanded(child: OutlinedButton.icon(
                onPressed: saving ? null : onReopen,
                icon: const Icon(Icons.lock_open_outlined, size: 15),
                label: const Text('Reabrir', style: TextStyle(fontSize: 13)),
              )),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: saving ? null : onDelete,
              icon: const Icon(Icons.delete_outline, size: 15),
              label: const Text('Excluir', style: TextStyle(fontSize: 13)),
              style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
            ),
          ]),
        ],
      ),
    );
  }
}

class _ResultTab extends StatelessWidget {
  final PollDetail poll;
  final bool       saving;
  final bool       isDark;
  final Function(String playerId, List<String> optionIds) onAdminVote;

  const _ResultTab({required this.poll, required this.saving, required this.isDark, required this.onAdminVote});

  @override
  Widget build(BuildContext context) {
    final members = poll.members ?? [];
    if (members.isEmpty) {
      return Center(child: Text('Sem dados de membros.',
        style: TextStyle(color: isDark ? AppColors.slate400 : AppColors.slate500)));
    }
    return ListView.separated(
      padding: const EdgeInsets.all(14),
      itemCount: members.length,
      separatorBuilder: (_, __) => const Divider(height: 12),
      itemBuilder: (_, i) {
        final m = members[i];
        return Row(
          children: [
            Expanded(child: Text(m.playerName, style: TextStyle(fontSize: 13,
              color: isDark ? AppColors.slate200 : AppColors.slate700))),
            DropdownButton<String>(
              value: m.votedOptionIds.isNotEmpty ? m.votedOptionIds.first : null,
              hint: const Text('—', style: TextStyle(fontSize: 13)),
              isDense: true,
              items: poll.options.map((opt) => DropdownMenuItem(
                value: opt.id,
                child: Text(opt.text, style: const TextStyle(fontSize: 13)),
              )).toList(),
              onChanged: saving ? null : (v) {
                if (v != null) onAdminVote(m.playerId, [v]);
              },
            ),
          ],
        );
      },
    );
  }
}

// ── Helpers ────────────────────────────────────────────────────────────────────

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
    child: Text(isOpen ? 'Aberta' : 'Encerrada',
      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
        color: isOpen ? Colors.green.shade700 : AppColors.slate500)),
  );
}

class _MetaTag extends StatelessWidget {
  final IconData icon;
  final String   label;
  final bool     isDark;
  final Color?   color;
  const _MetaTag({required this.icon, required this.label, required this.isDark, this.color});
  @override
  Widget build(BuildContext context) {
    final c = color ?? (isDark ? AppColors.slate400 : AppColors.slate500);
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 12, color: c),
      const SizedBox(width: 4),
      Text(label, style: TextStyle(fontSize: 12, color: c)),
    ]);
  }
}

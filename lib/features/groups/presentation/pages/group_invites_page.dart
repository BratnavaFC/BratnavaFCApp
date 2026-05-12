import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/group_invite.dart';
import '../providers/group_invites_provider.dart';

class GroupInvitesPage extends ConsumerStatefulWidget {
  const GroupInvitesPage({super.key});

  @override
  ConsumerState<GroupInvitesPage> createState() => _GroupInvitesPageState();
}

class _GroupInvitesPageState extends ConsumerState<GroupInvitesPage> {
  final Set<String> _loading = {};

  Future<void> _accept(GroupInvite invite) async {
    setState(() => _loading.add(invite.id));
    try {
      await ref.read(groupInvitesDsProvider).acceptInvite(invite.id);
      ref.invalidate(myGroupInvitesProvider);
      ref.invalidate(myGroupInviteCountProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Você entrou em ${invite.groupName}!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao aceitar convite: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading.remove(invite.id));
    }
  }

  Future<void> _reject(GroupInvite invite) async {
    setState(() => _loading.add('reject_${invite.id}'));
    try {
      await ref.read(groupInvitesDsProvider).rejectInvite(invite.id);
      ref.invalidate(myGroupInvitesProvider);
      ref.invalidate(myGroupInviteCountProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Convite recusado.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao recusar convite: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading.remove('reject_${invite.id}'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final invitesAsync = ref.watch(myGroupInvitesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Convites de Grupo')),
      body: invitesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erro: $e')),
        data: (invites) {
          if (invites.isEmpty) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.mail_outline, size: 48, color: AppColors.slate400),
                  SizedBox(height: 12),
                  Text(
                    'Nenhum convite pendente',
                    style: TextStyle(color: AppColors.slate500),
                  ),
                ],
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: invites.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (_, i) => _InviteCard(
              invite:        invites[i],
              acceptLoading: _loading.contains(invites[i].id),
              rejectLoading: _loading.contains('reject_${invites[i].id}'),
              onAccept:      () => _accept(invites[i]),
              onReject:      () => _reject(invites[i]),
            ),
          );
        },
      ),
    );
  }
}

class _InviteCard extends StatelessWidget {
  final GroupInvite invite;
  final bool        acceptLoading;
  final bool        rejectLoading;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  const _InviteCard({
    required this.invite,
    required this.acceptLoading,
    required this.rejectLoading,
    required this.onAccept,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color:        isDark ? AppColors.slate800 : AppColors.slate50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppColors.slate700 : AppColors.slate200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width:  40,
                height: 40,
                decoration: BoxDecoration(
                  color:        AppColors.emerald500.withAlpha(30),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.group, color: AppColors.emerald500, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      invite.groupName,
                      style: const TextStyle(
                        fontSize:   15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (invite.invitedByName != null)
                      Text(
                        'Convidado por ${invite.invitedByName}',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? AppColors.slate400 : AppColors.slate500,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: rejectLoading ? null : onReject,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.rose500,
                    side: const BorderSide(color: AppColors.rose500),
                  ),
                  child: rejectLoading
                      ? const SizedBox(
                          width: 16, height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Recusar'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: acceptLoading ? null : onAccept,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.emerald500,
                  ),
                  child: acceptLoading
                      ? const SizedBox(
                          width: 16, height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Aceitar'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

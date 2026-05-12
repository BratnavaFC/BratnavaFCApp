import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../auth/domain/entities/account.dart';
import '../../../auth/presentation/providers/account_store.dart';
import '../../../dashboard/presentation/providers/dashboard_provider.dart';
import '../../domain/entities/match_models.dart';
import '../providers/match_provider.dart';
import '../widgets/match_stepper_header.dart';
import 'step2_aceitacao_page.dart';
import 'step3_matchmaking_page.dart';
import 'step4_jogo_page.dart';
import 'step5_encerrar_page.dart';
import 'step6_pos_jogo_page.dart';
import 'step7_final_page.dart';

class MatchesPage extends ConsumerStatefulWidget {
  const MatchesPage({super.key});

  @override
  ConsumerState<MatchesPage> createState() => _MatchesPageState();
}

class _MatchesPageState extends ConsumerState<MatchesPage> {
  // ── Formulário Step 1 ─────────────────────────────────────────────────────
  final _formKey   = GlobalKey<FormState>();
  final _placeCtrl = TextEditingController();
  DateTime _date   = DateTime.now();
  TimeOfDay _time  = TimeOfDay.now();
  bool _formInited = false;

  // ── Pré-visualização (admin) ──────────────────────────────────────────────
  MatchStep? _previewStep;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await ref.read(matchNotifierProvider.notifier).loadInitial();
    });
  }

  @override
  void dispose() {
    _placeCtrl.dispose();
    super.dispose();
  }

  // ── Pré-preenche formulário com defaults do grupo ──────────────────────────
  void _initForm(MatchState s) {
    if (_formInited) return;
    _formInited = true;
    if (s.groupSettings?.defaultPlaceName != null && _placeCtrl.text.isEmpty) {
      _placeCtrl.text = s.groupSettings!.defaultPlaceName!;
    }
    final raw = s.groupSettings?.defaultKickoffTime;
    if (raw != null) {
      final parts = raw.split(':');
      if (parts.length >= 2) {
        _time = TimeOfDay(hour: int.tryParse(parts[0]) ?? 0, minute: int.tryParse(parts[1]) ?? 0);
      }
    }
  }

  // Não usar ref.read aqui — precisa de ref.watch para reagir ao refreshRoles().
  bool _isAdmin(Account? acc, String groupId) {
    return (acc?.isAdmin ?? false) ||
        (groupId.isNotEmpty && (acc?.isGroupAdmin(groupId) ?? false));
  }

  // ── Cria partida (Step 1) ─────────────────────────────────────────────────
  Future<void> _createMatch() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final placeName = _placeCtrl.text.trim();
    final playedAt  = DateTime(_date.year, _date.month, _date.day, _time.hour, _time.minute);
    await ref.read(matchNotifierProvider.notifier).createMatch(placeName, playedAt);
    // State update drives re-render to step2 content
  }

  // ── Pickers ───────────────────────────────────────────────────────────────
  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context, initialDate: _date,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate:  DateTime.now().add(const Duration(days: 365)),
    );
    if (d != null) setState(() => _date = d);
  }

  Future<void> _pickTime() async {
    final t = await showTimePicker(context: context, initialTime: _time);
    if (t != null) setState(() => _time = t);
  }

  // ── Conteúdo por etapa ────────────────────────────────────────────────────
  Widget _buildStepContent(MatchState s, bool isAdmin) {
    if (!s.hasMatch) {
      return isAdmin
          ? _CreateMatchView(
              formKey:    _formKey,
              placeCtrl:  _placeCtrl,
              date:       _date,
              time:       _time,
              onPickDate: _pickDate,
              onPickTime: _pickTime,
              onCreate:   _createMatch,
              mutating:   s.mutating,
            )
          : const _WaitingForMatchView();
    }

    final display = _previewStep ?? s.step;
    switch (display) {
      case MatchStep.create:
        return isAdmin
            ? _CreateMatchView(
                formKey:    _formKey,
                placeCtrl:  _placeCtrl,
                date:       _date,
                time:       _time,
                onPickDate: _pickDate,
                onPickTime: _pickTime,
                onCreate:   _createMatch,
                mutating:   s.mutating,
              )
            : const _WaitingForMatchView();
      case MatchStep.accept:  return const Step2AceitacaoPage();
      case MatchStep.teams:   return const Step3MatchmakingPage();
      case MatchStep.playing: return const Step4JogoPage();
      case MatchStep.ended:   return const Step5EncerrarPage();
      case MatchStep.post:    return const Step6PosJogoPage();
      case MatchStep.done:    return const Step7FinalPage();
    }
  }

  // ── Voltar etapa (com confirmação) ───────────────────────────────────────
  Future<void> _rewindStep() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Voltar etapa'),
        content: const Text(
          'Tem certeza que deseja voltar para a etapa anterior? '
          'Esta ação não pode ser desfeita.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.amber500),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Voltar etapa'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await ref.read(matchNotifierProvider.notifier).rewindStep();
    }
  }

  // ── UI ────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final s            = ref.watch(matchNotifierProvider);
    // watch (não read) para reagir ao refreshRoles() assíncrono do startup
    final account      = ref.watch(accountStoreProvider).activeAccount;
    final activePlayer = ref.watch(activePlayerProvider);
    final groupId      = account?.activeGroupId ?? activePlayer?.groupId ?? '';
    final isAdmin      = _isAdmin(account, groupId);

    if (!s.loading && s.groupSettings != null) _initForm(s);

    if (s.loading) return const Center(child: CircularProgressIndicator());

    if (s.error != null && !s.hasMatch) {
      return _ErrorView(
        message: s.error!,
        onRetry: () => ref.read(matchNotifierProvider.notifier).loadInitial(),
      );
    }

    final currentStep = s.hasMatch ? s.step : MatchStep.create;

    return Column(
      children: [
        _MatchBanner(
          s:         s,
          isAdmin:   isAdmin,
          canRewind: isAdmin && s.hasMatch && s.canRewind,
          onRefresh: () => ref.read(matchNotifierProvider.notifier).refresh(),
          onRewind:  _rewindStep,
        ),
        MatchStepperHeader(
          currentStep: currentStep,
          previewStep: _previewStep,
          onStepTap: isAdmin && s.hasMatch
              ? (step) => setState(() {
                    _previewStep = (_previewStep == step || step == currentStep) ? null : step;
                  })
              : null,
        ),
        if (_previewStep != null && _previewStep != currentStep)
          _PreviewBanner(
            previewStep: _previewStep!,
            currentStep: currentStep,
            onDismiss:   () => setState(() => _previewStep = null),
          ),
        Expanded(
          child: _buildStepContent(s, isAdmin),
        ),
      ],
    );
  }
}

// ── Banner escuro ─────────────────────────────────────────────────────────────

class _MatchBanner extends StatelessWidget {
  final MatchState s;
  final bool isAdmin;
  final bool canRewind;
  final VoidCallback onRefresh;
  final VoidCallback onRewind;

  const _MatchBanner({
    required this.s,
    required this.isAdmin,
    required this.canRewind,
    required this.onRefresh,
    required this.onRewind,
  });

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('dd/MM HH:mm', 'pt_BR');
    return Container(
      color: AppColors.slate900,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Partidas',
                  style: TextStyle(color: AppColors.slate400, fontSize: 11, fontWeight: FontWeight.w500),
                ),
                if (s.hasMatch)
                  Text(
                    '${s.placeName ?? "—"} · ${s.playedAt != null ? fmt.format(s.playedAt!.toLocal()) : "—"}',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          // ── Botão Voltar etapa (só admin com partida ativa) ──────────────
          if (isAdmin && s.hasMatch) ...[
            Tooltip(
              message: canRewind ? 'Voltar uma etapa' : 'Não é possível voltar neste status',
              child: TextButton.icon(
                onPressed: canRewind ? onRewind : null,
                style: TextButton.styleFrom(
                  foregroundColor: canRewind ? AppColors.amber400 : AppColors.slate600,
                  backgroundColor: canRewind
                      ? AppColors.amber500.withValues(alpha: 0.15)
                      : Colors.transparent,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: BorderSide(
                      color: canRewind
                          ? AppColors.amber400.withValues(alpha: 0.4)
                          : AppColors.slate700,
                    ),
                  ),
                ),
                icon: Icon(Icons.undo_rounded, size: 15,
                    color: canRewind ? AppColors.amber400 : AppColors.slate600),
                label: Text(
                  'Voltar etapa',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: canRewind ? AppColors.amber400 : AppColors.slate600,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 4),
          ],
          // ── Refresh ──────────────────────────────────────────────────────
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white, size: 20),
            onPressed: onRefresh,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          ),
        ],
      ),
    );
  }
}

// ── Banner de pré-visualização ────────────────────────────────────────────────

class _PreviewBanner extends StatelessWidget {
  final MatchStep previewStep;
  final MatchStep currentStep;
  final VoidCallback onDismiss;
  const _PreviewBanner({required this.previewStep, required this.currentStep, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.amber200,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          const Icon(Icons.visibility_outlined, size: 14, color: AppColors.orange700),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              'Pré-visualização · etapa real: ${currentStep.label}',
              style: const TextStyle(fontSize: 12, color: AppColors.orange700, fontWeight: FontWeight.w500),
            ),
          ),
          GestureDetector(
            onTap: onDismiss,
            child: const Icon(Icons.close, size: 16, color: AppColors.orange700),
          ),
        ],
      ),
    );
  }
}

// ── Vista: criar partida (Step 1 embutido) ────────────────────────────────────

class _CreateMatchView extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController placeCtrl;
  final DateTime date;
  final TimeOfDay time;
  final VoidCallback onPickDate;
  final VoidCallback onPickTime;
  final VoidCallback onCreate;
  final bool mutating;

  const _CreateMatchView({
    required this.formKey,
    required this.placeCtrl,
    required this.date,
    required this.time,
    required this.onPickDate,
    required this.onPickTime,
    required this.onCreate,
    required this.mutating,
  });

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('dd/MM/yyyy', 'pt_BR');

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: formKey,
              child: Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Nova Partida', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 20),
                      // Local
                      TextFormField(
                        controller: placeCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Local *',
                          prefixIcon: Icon(Icons.location_on_outlined),
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) => (v?.trim().isEmpty ?? true) ? 'Informe o local' : null,
                      ),
                      const SizedBox(height: 16),
                      // Data
                      InkWell(
                        onTap: onPickDate,
                        borderRadius: BorderRadius.circular(4),
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Data *',
                            prefixIcon: Icon(Icons.calendar_today_outlined),
                            border: OutlineInputBorder(),
                          ),
                          child: Text(fmt.format(date), style: const TextStyle(fontSize: 16)),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Horário
                      InkWell(
                        onTap: onPickTime,
                        borderRadius: BorderRadius.circular(4),
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Horário *',
                            prefixIcon: Icon(Icons.access_time_outlined),
                            border: OutlineInputBorder(),
                          ),
                          child: Text(time.format(context), style: const TextStyle(fontSize: 16)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: mutating ? null : onCreate,
                icon: mutating
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.add),
                label: const Text('+ Criar Partida'),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Vista: aguardando o admin criar partida ────────────────────────────────────

class _WaitingForMatchView extends StatelessWidget {
  const _WaitingForMatchView();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          decoration: BoxDecoration(
            color:        isDark ? AppColors.slate800.withValues(alpha: 0.5) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark ? AppColors.slate700 : AppColors.slate200,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 48, height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDark ? AppColors.slate700 : AppColors.slate100,
                ),
                child: const Icon(Icons.access_time_rounded, size: 22, color: AppColors.slate400),
              ),
              const SizedBox(height: 12),
              Text(
                'Aguardando o admin criar uma partida',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                  color: isDark ? AppColors.slate100 : AppColors.slate800,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              const Text(
                'Assim que houver uma partida ativa, ela aparecerá aqui automaticamente.',
                style: TextStyle(fontSize: 13, color: AppColors.slate500),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Vista: erro ───────────────────────────────────────────────────────────────

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 48, color: AppColors.rose400),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          FilledButton(onPressed: onRetry, child: const Text('Tentar novamente')),
        ],
      ),
    ),
  );
}

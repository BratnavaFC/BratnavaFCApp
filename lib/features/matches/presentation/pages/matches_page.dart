import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
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
  final _formKey    = GlobalKey<FormState>();
  final _placeCtrl  = TextEditingController();
  DateTime _date    = DateTime.now();
  TimeOfDay _time   = TimeOfDay.now();
  bool _formInited  = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(matchNotifierProvider.notifier).loadInitial();
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

  // ── Navega para a página do step atual ────────────────────────────────────
  void _navigateToStep(MatchStep step) {
    Widget page;
    switch (step) {
      case MatchStep.accept:  page = const Step2AceitacaoPage();    break;
      case MatchStep.teams:   page = const Step3MatchmakingPage();  break;
      case MatchStep.playing: page = const Step4JogoPage();         break;
      case MatchStep.ended:   page = const Step5EncerrarPage();     break;
      case MatchStep.post:    page = const Step6PosJogoPage();      break;
      case MatchStep.done:    page = const Step7FinalPage();        break;
      default:                return;
    }
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  }

  // ── Cria partida (Step 1) ─────────────────────────────────────────────────
  Future<void> _createMatch() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final placeName = _placeCtrl.text.trim();
    final playedAt  = DateTime(_date.year, _date.month, _date.day, _time.hour, _time.minute);
    final ok = await ref.read(matchNotifierProvider.notifier).createMatch(placeName, playedAt);
    if (ok && mounted) {
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => const Step2AceitacaoPage()));
    }
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

  // ── UI ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(matchNotifierProvider);

    // Pré-preenche o form quando settings carregam
    if (!s.loading && s.groupSettings != null) _initForm(s);

    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Partidas', style: TextStyle(fontWeight: FontWeight.w700)),
            Text('MatchMaking', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w400)),
          ],
        ),
        actions: [
          if (s.hasMatch)
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Recarregar',
              onPressed: () => ref.read(matchNotifierProvider.notifier).loadInitial(),
            ),
        ],
      ),
      body: s.loading
          ? const Center(child: CircularProgressIndicator())
          : s.error != null && !s.hasMatch
              ? _ErrorView(
                  message: s.error!,
                  onRetry: () => ref.read(matchNotifierProvider.notifier).loadInitial(),
                )
              : s.hasMatch
                  ? _ActiveMatchView(s: s, onContinue: () => _navigateToStep(s.step))
                  : _CreateMatchView(
                      formKey:    _formKey,
                      placeCtrl:  _placeCtrl,
                      date:       _date,
                      time:       _time,
                      onPickDate: _pickDate,
                      onPickTime: _pickTime,
                      onCreate:   _createMatch,
                      mutating:   s.mutating,
                    ),
    );
  }
}

// ── Vista: partida ativa → "Continuar" ───────────────────────────────────────

class _ActiveMatchView extends StatelessWidget {
  final MatchState s;
  final VoidCallback onContinue;

  const _ActiveMatchView({required this.s, required this.onContinue});

  @override
  Widget build(BuildContext context) {
    final fmt      = DateFormat('dd/MM/yyyy HH:mm', 'pt_BR');
    final dateStr  = s.playedAt != null ? fmt.format(s.playedAt!.toLocal()) : '—';

    return Column(
      children: [
        MatchStepperHeader(currentStep: s.step),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      const Icon(Icons.sports_soccer, color: AppColors.violet600),
                      const SizedBox(width: 8),
                      Text('Partida em andamento', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                    ]),
                    const SizedBox(height: 16),
                    _InfoRow(icon: Icons.calendar_today, label: dateStr),
                    const SizedBox(height: 6),
                    _InfoRow(icon: Icons.location_on, label: s.placeName ?? '—'),
                    const SizedBox(height: 6),
                    _InfoRow(icon: Icons.flag, label: 'Etapa atual: ${s.step.label}'),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: onContinue,
                        icon: const Icon(Icons.arrow_forward),
                        label: Text('Continuar – ${s.step.label}'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  const _InfoRow({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) => Row(children: [
    Icon(icon, size: 16, color: AppColors.slate400),
    const SizedBox(width: 8),
    Flexible(child: Text(label, style: const TextStyle(fontSize: 14))),
  ]);
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
        MatchStepperHeader(currentStep: MatchStep.create),
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

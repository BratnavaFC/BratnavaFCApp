import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/match_models.dart';

class MatchStepperHeader extends StatelessWidget {
  final MatchStep currentStep;
  final MatchStep? previewStep;              // step being previewed (may differ from current)
  final void Function(MatchStep)? onStepTap; // null = not tappable

  const MatchStepperHeader({
    super.key,
    required this.currentStep,
    this.previewStep,
    this.onStepTap,
  });

  static const _steps = MatchStep.values;

  bool _isDone(MatchStep s)    => s.index < currentStep.index;
  bool _isViewing(MatchStep s) => s == (previewStep ?? currentStep);

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.surface,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: List.generate(_steps.length * 2 - 1, (i) {
                  if (i.isOdd) {
                    final leftStep = _steps[i ~/ 2];
                    return Container(
                      width: 28,
                      height: 2,
                      color: _isDone(leftStep) ? AppColors.emerald500 : AppColors.slate200,
                    );
                  }
                  final step = _steps[i ~/ 2];
                  return GestureDetector(
                    onTap: onStepTap != null ? () => onStepTap!(step) : null,
                    child: _StepDot(
                      step:      step,
                      isDone:    _isDone(step),
                      isViewing: _isViewing(step),
                      isCurrent: step == currentStep,
                      tappable:  onStepTap != null,
                    ),
                  );
                }),
              ),
            ),
          ),
          // Progress bar
          LinearProgressIndicator(
            value: currentStep.index / (MatchStep.values.length - 1),
            minHeight: 3,
            backgroundColor: AppColors.slate200,
            valueColor: const AlwaysStoppedAnimation<Color>(AppColors.emerald500),
          ),
        ],
      ),
    );
  }
}

class _StepDot extends StatelessWidget {
  final MatchStep step;
  final bool isDone;
  final bool isViewing; // being displayed (current or preview)
  final bool isCurrent; // the real active step
  final bool tappable;

  const _StepDot({
    required this.step,
    required this.isDone,
    required this.isViewing,
    required this.isCurrent,
    required this.tappable,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    Color dotColor;
    if (isDone) {
      dotColor = AppColors.emerald500;
    } else if (isCurrent) {
      dotColor = AppColors.slate900;
    } else {
      dotColor = AppColors.slate200;
    }

    // preview highlight: outline ring around dot
    final showPreviewRing = isViewing && !isCurrent;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: dotColor,
              border: showPreviewRing
                  ? Border.all(color: primary, width: 2)
                  : null,
            ),
            child: Center(
              child: isDone
                  ? const Icon(Icons.check, size: 16, color: Colors.white)
                  : Text(
                      '${step.stepNumber}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isCurrent ? Colors.white : AppColors.slate500,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            step.label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: (isCurrent || isViewing) ? FontWeight.w600 : FontWeight.w400,
              color: isDone
                  ? AppColors.emerald700
                  : isCurrent
                      ? AppColors.slate900
                      : AppColors.slate400,
            ),
          ),
          Text(
            _subtitle(step),
            style: const TextStyle(fontSize: 9, color: AppColors.slate400),
          ),
        ],
      ),
    );
  }

  String _subtitle(MatchStep s) {
    switch (s) {
      case MatchStep.create:  return 'Nova partida';
      case MatchStep.accept:  return 'Aceitar / Recusar';
      case MatchStep.teams:   return 'Times / cores / swap';
      case MatchStep.playing: return 'Iniciada';
      case MatchStep.ended:   return 'Fim do jogo';
      case MatchStep.post:    return 'MVP / gols / placar';
      case MatchStep.done:    return 'Finalizada';
    }
  }
}

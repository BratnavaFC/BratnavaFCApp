import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/match_models.dart';

class MatchStepperHeader extends StatelessWidget {
  final MatchStep currentStep;

  const MatchStepperHeader({super.key, required this.currentStep});

  static const _steps = MatchStep.values;

  bool _isDone(MatchStep s)   => s.index < currentStep.index;
  bool _isActive(MatchStep s) => s == currentStep;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.surface,
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: List.generate(_steps.length * 2 - 1, (i) {
            if (i.isOdd) {
              final leftStep = _steps[i ~/ 2];
              return Container(
                width: 24,
                height: 2,
                color: _isDone(leftStep) ? AppColors.emerald500 : AppColors.slate200,
              );
            }
            final step = _steps[i ~/ 2];
            return _StepDot(
              step:     step,
              isDone:   _isDone(step),
              isActive: _isActive(step),
            );
          }),
        ),
      ),
    );
  }
}

class _StepDot extends StatelessWidget {
  final MatchStep step;
  final bool isDone;
  final bool isActive;

  const _StepDot({
    required this.step,
    required this.isDone,
    required this.isActive,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isDone
                ? AppColors.emerald500
                : isActive
                    ? primary
                    : AppColors.slate200,
          ),
          child: Center(
            child: isDone
                ? const Icon(Icons.check, size: 16, color: Colors.white)
                : Text(
                    '${step.stepNumber}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isActive ? Colors.white : AppColors.slate500,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          step.label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
            color: isDone
                ? AppColors.emerald700
                : isActive
                    ? primary
                    : AppColors.slate400,
          ),
        ),
      ],
    );
  }
}

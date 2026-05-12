import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/absence.dart';

class AbsenceCard extends StatelessWidget {
  final Absence      absence;
  final bool         canEdit;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const AbsenceCard({
    super.key,
    required this.absence,
    required this.canEdit,
    required this.onEdit,
    required this.onDelete,
  });

  // ── Helpers ───────────────────────────────────────────────────────────────

  Color _typeColor() {
    switch (absence.type) {
      case AbsenceType.trip:     return AppColors.blue500;
      case AbsenceType.medical:  return AppColors.rose500;
      case AbsenceType.personal: return AppColors.amber500;
      case AbsenceType.other:    return AppColors.slate500;
    }
  }

  Color _typeBg(bool isDark) {
    switch (absence.type) {
      case AbsenceType.trip:     return isDark ? const Color(0xFF1E3A5F) : const Color(0xFFEFF6FF);
      case AbsenceType.medical:  return isDark ? const Color(0xFF3D0012) : const Color(0xFFFFF1F2);
      case AbsenceType.personal: return isDark ? const Color(0xFF3D2E00) : const Color(0xFFFFFBEB);
      case AbsenceType.other:    return isDark ? AppColors.slate800 : AppColors.slate100;
    }
  }

  String _fmtDate(String iso) {
    try {
      final parts = iso.split('T').first.split('-');
      if (parts.length != 3) return iso;
      return '${parts[2]}/${parts[1]}/${parts[0]}';
    } catch (_) {
      return iso;
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark  = Theme.of(context).brightness == Brightness.dark;
    final color   = _typeColor();
    final bgColor = _typeBg(isDark);

    final cardBg        = isDark ? AppColors.slate800 : Colors.white;
    final textPrimary   = isDark ? Colors.white       : AppColors.slate900;
    final textSecondary = isDark ? AppColors.slate400  : AppColors.slate500;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      decoration: BoxDecoration(
        color:        cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppColors.slate700 : AppColors.slate200,
        ),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color:      Colors.black.withValues(alpha: .04),
                  blurRadius: 6,
                  offset:     const Offset(0, 2),
                ),
              ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // ── Type icon ─────────────────────────────────────────────────────
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color:        bgColor,
                borderRadius: BorderRadius.circular(10),
                border:       Border.all(color: color.withValues(alpha: .3)),
              ),
              child: Center(
                child: Text(
                  absence.type.emoji,
                  style: const TextStyle(fontSize: 18),
                ),
              ),
            ),

            const SizedBox(width: 12),

            // ── Content ───────────────────────────────────────────────────────
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  // Type label
                  Text(
                    absence.displayTypeName,
                    style: TextStyle(
                      color:      textPrimary,
                      fontSize:   14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),

                  const SizedBox(height: 2),

                  // Date range
                  Text(
                    '${_fmtDate(absence.startDate)} até ${_fmtDate(absence.endDate)}',
                    style: TextStyle(
                      color:    textSecondary,
                      fontSize: 12,
                    ),
                  ),

                  // Description
                  if (absence.description != null &&
                      absence.description!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      absence.description!,
                      style: const TextStyle(
                        color:    AppColors.rose500,
                        fontSize: 12,
                        height:   1.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),

            // ── Actions menu ──────────────────────────────────────────────────
            if (canEdit)
              PopupMenuButton<String>(
                iconSize:    18,
                padding:     EdgeInsets.zero,
                icon: Icon(Icons.more_vert_rounded,
                    size: 18, color: textSecondary),
                onSelected: (v) {
                  if (v == 'edit')   onEdit();
                  if (v == 'delete') onDelete();
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit_rounded,
                            size: 16, color: AppColors.blue500),
                        SizedBox(width: 8),
                        Text('Editar'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete_rounded,
                            size: 16, color: AppColors.rose500),
                        SizedBox(width: 8),
                        Text('Excluir',
                            style: TextStyle(color: AppColors.rose500)),
                      ],
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/date_utils.dart';
import '../../data/datasources/absences_remote_datasource.dart';
import '../../domain/entities/absence.dart';

// ── PlayerOption (kept for potential future use) ───────────────────────────────

class PlayerOption {
  final String id;
  final String name;
  const PlayerOption({required this.id, required this.name});
}

// ── AbsenceFormSheet ──────────────────────────────────────────────────────────

class AbsenceFormSheet extends StatefulWidget {
  final AbsencesRemoteDataSource datasource;
  final Absence?                 absence;   // null → create mode
  final VoidCallback             onSaved;

  const AbsenceFormSheet({
    super.key,
    required this.datasource,
    this.absence,
    required this.onSaved,
  });

  static Future<void> show({
    required BuildContext             context,
    required AbsencesRemoteDataSource datasource,
    Absence?                          absence,
    required VoidCallback             onSaved,
  }) {
    return showModalBottomSheet(
      context:            context,
      isScrollControlled: true,
      backgroundColor:    Colors.transparent,
      builder: (_) => AbsenceFormSheet(
        datasource: datasource,
        absence:    absence,
        onSaved:    onSaved,
      ),
    );
  }

  @override
  State<AbsenceFormSheet> createState() => _AbsenceFormSheetState();
}

class _AbsenceFormSheetState extends State<AbsenceFormSheet> {
  final _descCtrl = TextEditingController();

  late AbsenceType _type;
  late DateTime    _startDate;
  late DateTime    _endDate;
  bool             _saving = false;

  bool get _isEdit => widget.absence != null;

  @override
  void initState() {
    super.initState();
    final a = widget.absence;
    _type      = a?.type ?? AbsenceType.trip;
    _startDate = a != null ? _parseDate(a.startDate) : DateTime.now();
    _endDate   = a != null ? _parseDate(a.endDate)   : DateTime.now();
    _descCtrl.text = a?.description ?? '';
  }

  @override
  void dispose() {
    _descCtrl.dispose();
    super.dispose();
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  DateTime _parseDate(String iso) => AppDateUtils.parseOrNow(iso);

  String _toIso(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  String _fmtDisplay(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/'
      '${d.month.toString().padLeft(2, '0')}/'
      '${d.year}';

  Future<void> _pickDate({required bool isStart}) async {
    final initial = isStart ? _startDate : _endDate;
    final first   = isStart ? DateTime(2020) : _startDate;
    final picked  = await showDatePicker(
      context:     context,
      initialDate: initial,
      firstDate:   first,
      lastDate:    DateTime(2100),
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _startDate = picked;
        if (_endDate.isBefore(_startDate)) _endDate = _startDate;
      } else {
        _endDate = picked;
      }
    });
  }

  // ── Save ──────────────────────────────────────────────────────────────────

  Future<void> _save() async {
    setState(() => _saving = true);

    final dto = CreateAbsenceDto(
      type:        _type,
      startDate:   _toIso(_startDate),
      endDate:     _toIso(_endDate),
      description: _descCtrl.text.trim().isEmpty
          ? null
          : _descCtrl.text.trim(),
    );

    try {
      if (_isEdit) {
        await widget.datasource.update(widget.absence!.id, dto);
      } else {
        await widget.datasource.create(dto);
      }
      if (mounted) {
        Navigator.pop(context);
        widget.onSaved();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao salvar: $e')),
        );
      }
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark        = Theme.of(context).brightness == Brightness.dark;
    final bg            = isDark ? AppColors.slate900 : Colors.white;
    final textPrimary   = isDark ? Colors.white       : AppColors.slate900;
    final textSecondary = isDark ? AppColors.slate400  : AppColors.slate500;
    final divColor      = isDark ? AppColors.slate700  : AppColors.slate200;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: BoxDecoration(
          color:        bg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [

              // ── Handle ────────────────────────────────────────────────────
              const SizedBox(height: 12),
              Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color:        divColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),

              // ── Title ─────────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Text(
                      _isEdit ? 'Editar Ausência' : 'Nova Ausência',
                      style: TextStyle(
                        color:      textPrimary,
                        fontSize:   18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: Icon(Icons.close, color: textSecondary),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),

              Divider(color: divColor, height: 1),
              const SizedBox(height: 16),

              // ── Form ──────────────────────────────────────────────────────
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [

                      // Type chips
                      _Label('Motivo', textSecondary),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: AbsenceType.values
                            .map((t) => _TypeChip(
                                  type:     t,
                                  selected: t == _type,
                                  isDark:   isDark,
                                  onTap:    () => setState(() => _type = t),
                                ))
                            .toList(),
                      ),
                      const SizedBox(height: 14),

                      // Date range
                      _Label('Período', textSecondary),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: _DateBtn(
                              label:  'De',
                              date:   _fmtDisplay(_startDate),
                              isDark: isDark,
                              onTap:  () => _pickDate(isStart: true),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _DateBtn(
                              label:  'Até',
                              date:   _fmtDisplay(_endDate),
                              isDark: isDark,
                              onTap:  () => _pickDate(isStart: false),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Description
                      _Label('Descrição (opcional)', textSecondary),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _descCtrl,
                        maxLines:   3,
                        style: TextStyle(color: textPrimary, fontSize: 14),
                        decoration: InputDecoration(
                          hintText:  'Ex: viagem de férias',
                          hintStyle: TextStyle(color: textSecondary),
                          filled:    true,
                          fillColor: isDark
                              ? AppColors.slate800
                              : AppColors.slate50,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide:   BorderSide(color: divColor),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide:   BorderSide(color: divColor),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                                color: AppColors.blue500, width: 2),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Save button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _saving ? null : _save,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.blue500,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: _saving
                              ? const SizedBox(
                                  width: 20, height: 20,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white),
                                )
                              : Text(
                                  _isEdit
                                      ? 'Salvar alterações'
                                      : 'Registrar ausência',
                                  style: const TextStyle(
                                    fontSize:   15,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

class _Label extends StatelessWidget {
  final String text;
  final Color  color;
  const _Label(this.text, this.color);

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: TextStyle(
          color:         color,
          fontSize:      12,
          fontWeight:    FontWeight.w600,
          letterSpacing: 0.3,
        ),
      );
}

class _TypeChip extends StatelessWidget {
  final AbsenceType  type;
  final bool         selected;
  final bool         isDark;
  final VoidCallback onTap;
  const _TypeChip({
    required this.type,
    required this.selected,
    required this.isDark,
    required this.onTap,
  });

  Color _color() {
    switch (type) {
      case AbsenceType.trip:     return AppColors.blue500;
      case AbsenceType.medical:  return AppColors.rose500;
      case AbsenceType.personal: return AppColors.amber500;
      case AbsenceType.other:    return AppColors.slate500;
    }
  }

  @override
  Widget build(BuildContext context) {
    final c  = _color();
    final bg = selected
        ? c
        : (isDark ? AppColors.slate800 : AppColors.slate100);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color:        bg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? c
                : (isDark ? AppColors.slate600 : AppColors.slate300),
            width: selected ? 2 : 1,
          ),
        ),
        child: Text(
          '${type.emoji}  ${type.label}',
          style: TextStyle(
            color: selected
                ? Colors.white
                : (isDark ? AppColors.slate300 : AppColors.slate600),
            fontSize:   13,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _DateBtn extends StatelessWidget {
  final String       label;
  final String       date;
  final bool         isDark;
  final VoidCallback onTap;
  const _DateBtn({
    required this.label,
    required this.date,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bg  = isDark ? AppColors.slate800 : AppColors.slate50;
    final bdr = isDark ? AppColors.slate700 : AppColors.slate200;
    final txt = isDark ? Colors.white       : AppColors.slate900;
    final sub = isDark ? AppColors.slate400 : AppColors.slate500;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color:        bg,
          borderRadius: BorderRadius.circular(12),
          border:       Border.all(color: bdr),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_today_rounded,
                size: 15, color: AppColors.blue500),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                        color:      sub,
                        fontSize:   10,
                        fontWeight: FontWeight.w500)),
                Text(date,
                    style: TextStyle(
                        color:      txt,
                        fontSize:   13,
                        fontWeight: FontWeight.w600)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

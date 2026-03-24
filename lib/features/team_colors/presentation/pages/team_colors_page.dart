import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../auth/presentation/providers/account_store.dart';
import '../../data/datasources/team_color_remote_datasource.dart';
import '../../domain/entities/team_color.dart';
import '../providers/team_colors_provider.dart';

// ── Page ──────────────────────────────────────────────────────────────────────

class TeamColorsPage extends ConsumerStatefulWidget {
  const TeamColorsPage({super.key});

  @override
  ConsumerState<TeamColorsPage> createState() => _TeamColorsPageState();
}

class _TeamColorsPageState extends ConsumerState<TeamColorsPage> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final account  = ref.watch(accountStoreProvider).activeAccount;
    final groupId   = account?.activeGroupId;
    final groupIdNN = groupId; // non-null alias used in closures
    final canManage = account != null &&
        groupIdNN != null &&
        (account.isAdmin || account.isGroupAdmin(groupIdNN));
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return RefreshIndicator(
      onRefresh: () async {
        if (groupIdNN != null) {
          ref.invalidate(teamColorsProvider(groupIdNN));
        }
      },
      child: CustomScrollView(
        slivers: [
          // ── Header ──────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: _Header(
              groupId:    groupId,
              isDark:     isDark,
              canManage:  canManage,
              onRefresh: groupIdNN == null
                  ? null
                  : () => ref.invalidate(teamColorsProvider(groupIdNN)),
              onAdd: canManage
                  ? () => _openEditSheet(
                        context,
                        groupId:  groupIdNN,
                        canManage: canManage,
                        isDark:   isDark,
                      )
                  : null,
            ),
          ),

          if (groupId == null) ...[
            SliverFillRemaining(
              child: _NoGroupState(isDark: isDark),
            ),
          ] else ...[
            SliverToBoxAdapter(
              child: _ColorsBody(
                groupId:       groupId,
                isDark:        isDark,
                canManage:     canManage,
                selectedIndex: _selectedIndex,
                onIndexChanged: (i) => setState(() => _selectedIndex = i),
                onOpenPreview:  (color) => _openPreview(context, color, isDark),
                onOpenEdit: (color) => _openEditSheet(
                  context,
                  groupId:   groupId,
                  canManage: canManage,
                  isDark:    isDark,
                  existing:  color,
                ),
                onActivate: (color) async {
                  final ds = ref.read(teamColorDsProvider);
                  try {
                    if (color.isActive) {
                      await ds.deactivateColor(groupId, color.id);
                    } else {
                      await ds.activateColor(groupId, color.id);
                    }
                    ref.invalidate(teamColorsProvider(groupId));
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Erro: $e')),
                      );
                    }
                  }
                },
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 32)),
          ],
        ],
      ),
    );
  }

  // ── Preview bottom sheet ───────────────────────────────────────────────────

  void _openPreview(BuildContext context, TeamColor color, bool isDark) {
    showModalBottomSheet(
      context:         context,
      backgroundColor: Colors.transparent,
      builder: (_) => _PreviewSheet(color: color, isDark: isDark),
    );
  }

  // ── Edit / Create bottom sheet ─────────────────────────────────────────────

  void _openEditSheet(
    BuildContext context, {
    required String  groupId,
    required bool    canManage,
    required bool    isDark,
    TeamColor?       existing,
  }) {
    if (!canManage) return;
    showModalBottomSheet(
      context:            context,
      isScrollControlled: true,
      backgroundColor:    Colors.transparent,
      builder: (_) => _EditSheet(
        groupId:  groupId,
        existing: existing,
        isDark:   isDark,
        onSaved: () => ref.invalidate(teamColorsProvider(groupId)),
        ds:       ref.read(teamColorDsProvider),
      ),
    );
  }
}

// ── Header ────────────────────────────────────────────────────────────────────

class _Header extends ConsumerWidget {
  final String?      groupId;
  final bool         isDark;
  final bool         canManage;
  final VoidCallback? onRefresh;
  final VoidCallback? onAdd;

  const _Header({
    required this.groupId,
    required this.isDark,
    required this.canManage,
    this.onRefresh,
    this.onAdd,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorsAsync = groupId != null
        ? ref.watch(teamColorsProvider(groupId!))
        : const AsyncValue<List<TeamColor>>.data([]);

    final isLoading = colorsAsync.isLoading;
    final count     = colorsAsync.valueOrNull?.length ?? 0;

    return Container(
      margin:  const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin:  Alignment.topLeft,
          end:    Alignment.bottomRight,
          colors: [
            Color(0xFF0f172a),
            Color(0xFF1e293b),
            Color(0xFF0f172a),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color:      Colors.black.withAlpha(40),
            blurRadius: 12,
            offset:     const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Icon box
          Container(
            width: 52, height: 52,
            decoration: BoxDecoration(
              color:        Colors.white.withAlpha(25),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withAlpha(50)),
            ),
            child: const Icon(
              Icons.palette_rounded,
              color: Colors.white,
              size:  26,
            ),
          ),
          const SizedBox(width: 16),
          // Title + subtitle
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Uniformes',
                  style: TextStyle(
                    fontSize:   22,
                    fontWeight: FontWeight.w900,
                    color:      Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                if (isLoading)
                  Row(
                    children: [
                      SizedBox(
                        width: 10, height: 10,
                        child: CircularProgressIndicator(
                          strokeWidth: 1.5,
                          color: Colors.white.withAlpha(128),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Carregando...',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withAlpha(128),
                        ),
                      ),
                    ],
                  )
                else if (groupId == null)
                  Text(
                    'Selecione um grupo',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withAlpha(128),
                    ),
                  )
                else
                  Text(
                    '$count cor${count != 1 ? 'es' : ''} cadastrada${count != 1 ? 's' : ''}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withAlpha(128),
                    ),
                  ),
              ],
            ),
          ),
          // Buttons row
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Nova cor (admin only)
              if (canManage && onAdd != null)
                GestureDetector(
                  onTap: onAdd,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color:        Colors.white.withAlpha(25),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withAlpha(50)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.add_rounded,
                          size:  14,
                          color: Colors.white.withAlpha(204),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Nova cor',
                          style: TextStyle(
                            fontSize:   12,
                            fontWeight: FontWeight.w500,
                            color:      Colors.white.withAlpha(204),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              if (canManage && onAdd != null && onRefresh != null)
                const SizedBox(width: 8),
              // Refresh
              if (onRefresh != null)
                GestureDetector(
                  onTap: isLoading ? null : onRefresh,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color:        Colors.white.withAlpha(25),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withAlpha(50)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.refresh_rounded,
                          size:  14,
                          color: Colors.white.withAlpha(204),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Atualizar',
                          style: TextStyle(
                            fontSize:   12,
                            fontWeight: FontWeight.w500,
                            color:      Colors.white.withAlpha(204),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Colors body (carousel + action bar) ──────────────────────────────────────

class _ColorsBody extends ConsumerWidget {
  final String   groupId;
  final bool     isDark;
  final bool     canManage;
  final int      selectedIndex;
  final void     Function(int)       onIndexChanged;
  final void     Function(TeamColor) onOpenPreview;
  final void     Function(TeamColor) onOpenEdit;
  final void     Function(TeamColor) onActivate;

  const _ColorsBody({
    required this.groupId,
    required this.isDark,
    required this.canManage,
    required this.selectedIndex,
    required this.onIndexChanged,
    required this.onOpenPreview,
    required this.onOpenEdit,
    required this.onActivate,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(teamColorsProvider(groupId));

    return async.when(
      loading: () => _CarouselSkeleton(isDark: isDark),
      error: (e, _) => Padding(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: Text(
            'Erro ao carregar: $e',
            style: TextStyle(
              color: isDark ? AppColors.slate400 : AppColors.slate500,
            ),
          ),
        ),
      ),
      data: (all) {
        // Non-admin sees only active colors
        final items = canManage
            ? all
            : all.where((c) => c.isActive).toList();

        if (items.isEmpty) {
          return _EmptyState(isDark: isDark);
        }

        final safeIndex = selectedIndex.clamp(0, items.length - 1);
        final selected  = items[safeIndex];

        return Column(
          children: [
            _ColorCarousel(
              items:          items,
              isDark:         isDark,
              selectedIndex:  safeIndex,
              onIndexChanged: onIndexChanged,
              onTap:          onOpenPreview,
            ),
            const SizedBox(height: 4),
            const Divider(height: 1),
            const SizedBox(height: 12),
            _ActionBar(
              selected:   selected,
              isDark:     isDark,
              canManage:  canManage,
              onPreview:  () => onOpenPreview(selected),
              onEdit:     () => onOpenEdit(selected),
              onActivate: () => onActivate(selected),
            ),
          ],
        );
      },
    );
  }
}

// ── Carousel ──────────────────────────────────────────────────────────────────

class _ColorCarousel extends StatefulWidget {
  final List<TeamColor>              items;
  final bool                         isDark;
  final int                          selectedIndex;
  final void Function(int)           onIndexChanged;
  final void Function(TeamColor)     onTap;

  const _ColorCarousel({
    required this.items,
    required this.isDark,
    required this.selectedIndex,
    required this.onIndexChanged,
    required this.onTap,
  });

  @override
  State<_ColorCarousel> createState() => _ColorCarouselState();
}

class _ColorCarouselState extends State<_ColorCarousel> {
  late PageController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = PageController(
      viewportFraction: 0.78,
      initialPage: widget.selectedIndex,
    );
  }

  @override
  void didUpdateWidget(_ColorCarousel old) {
    super.didUpdateWidget(old);
    // Sync external selection changes (e.g. activate button)
    if (old.selectedIndex != widget.selectedIndex &&
        _ctrl.hasClients &&
        _ctrl.page?.round() != widget.selectedIndex) {
      _ctrl.animateToPage(
        widget.selectedIndex,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _goLeft() {
    if (widget.selectedIndex > 0) {
      _ctrl.animateToPage(
        widget.selectedIndex - 1,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _goRight() {
    if (widget.selectedIndex < widget.items.length - 1) {
      _ctrl.animateToPage(
        widget.selectedIndex + 1,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.items;

    return Column(
      children: [
        // Carousel: PageView with clip.none so neighbour cards peek through,
        // arrows overlaid in a Stack so they don't constrain the PageView.
        SizedBox(
          height: 310,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // PageView takes full width; viewportFraction < 1 makes
              // the current card narrower, letting neighbours show.
              AnimatedBuilder(
                animation: _ctrl,
                builder: (_, __) {
                  return PageView.builder(
                    controller:    _ctrl,
                    clipBehavior:  Clip.none,
                    itemCount:     items.length,
                    onPageChanged: widget.onIndexChanged,
                    itemBuilder: (context, index) {
                      final color      = items[index];
                      final isSelected = index == widget.selectedIndex;

                      // Scale: centre = 1.0, immediate neighbours = 0.88
                      double scale = 0.88;
                      if (_ctrl.hasClients && _ctrl.position.haveDimensions) {
                        final page  = _ctrl.page ?? widget.selectedIndex.toDouble();
                        final delta = (page - index).abs().clamp(0.0, 1.0);
                        scale = 1.0 - delta * 0.12;
                      } else {
                        scale = isSelected ? 1.0 : 0.88;
                      }

                      return Transform.scale(
                        scale: scale,
                        child: GestureDetector(
                          onTap: () {
                            if (isSelected) {
                              widget.onTap(color);
                            } else {
                              _ctrl.animateToPage(
                                index,
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                              );
                            }
                          },
                          child: _ColorCard(
                            color:      color,
                            isDark:     widget.isDark,
                            isSelected: isSelected,
                          ),
                        ),
                      );
                    },
                  );
                },
              ),

              // Left arrow — overlaid, doesn't constrain PageView
              Positioned(
                left: 0,
                top:  0,
                bottom: 0,
                child: Center(
                  child: _NavArrow(
                    icon:    Icons.chevron_left_rounded,
                    enabled: widget.selectedIndex > 0,
                    isDark:  widget.isDark,
                    onTap:   _goLeft,
                  ),
                ),
              ),

              // Right arrow
              Positioned(
                right: 0,
                top:   0,
                bottom: 0,
                child: Center(
                  child: _NavArrow(
                    icon:    Icons.chevron_right_rounded,
                    enabled: widget.selectedIndex < items.length - 1,
                    isDark:  widget.isDark,
                    onTap:   _goRight,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Dot indicators
        const SizedBox(height: 12),
        _DotIndicators(
          count:    items.length,
          selected: widget.selectedIndex,
          getColor: (i) => items[i].color,
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

// ── Nav arrow ─────────────────────────────────────────────────────────────────

class _NavArrow extends StatelessWidget {
  final IconData     icon;
  final bool         enabled;
  final bool         isDark;
  final VoidCallback onTap;

  const _NavArrow({
    required this.icon,
    required this.enabled,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1.0 : 0.25,
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        child: Container(
          width:  36,
          height: 36,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: isDark ? AppColors.slate800 : Colors.white,
            shape: BoxShape.circle,
            border: Border.all(
              color: isDark ? AppColors.slate700 : AppColors.slate200,
            ),
            boxShadow: [
              BoxShadow(
                color:      Colors.black.withAlpha(20),
                blurRadius: 6,
                offset:     const Offset(0, 2),
              ),
            ],
          ),
          child: Icon(
            icon,
            size:  20,
            color: isDark ? AppColors.slate300 : AppColors.slate600,
          ),
        ),
      ),
    );
  }
}

// ── Dot indicators ────────────────────────────────────────────────────────────

class _DotIndicators extends StatelessWidget {
  final int          count;
  final int          selected;
  final Color Function(int) getColor;

  const _DotIndicators({
    required this.count,
    required this.selected,
    required this.getColor,
  });

  @override
  Widget build(BuildContext context) {
    if (count <= 1) return const SizedBox.shrink();
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (i) {
        final isSel = i == selected;
        final c     = isSel ? getColor(i) : AppColors.slate300;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve:    Curves.easeInOut,
          margin:   const EdgeInsets.symmetric(horizontal: 3),
          width:    isSel ? 20 : 6,
          height:   6,
          decoration: BoxDecoration(
            color:        c,
            borderRadius: BorderRadius.circular(3),
          ),
        );
      }),
    );
  }
}

// ── Color card ────────────────────────────────────────────────────────────────

class _ColorCard extends StatelessWidget {
  final TeamColor color;
  final bool      isDark;
  final bool      isSelected;

  const _ColorCard({
    required this.color,
    required this.isDark,
    required this.isSelected,
  });

  @override
  Widget build(BuildContext context) {
    final teamColor = color.color;

    return Container(
      decoration: BoxDecoration(
        color:        isDark ? AppColors.slate900 : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isSelected ? teamColor : (isDark ? AppColors.slate700 : AppColors.slate200),
          width: isSelected ? 2 : 1,
        ),
        boxShadow: isSelected
            ? [
                BoxShadow(
                  color:      teamColor.withAlpha(102),
                  blurRadius: 24,
                  offset:     const Offset(0, 8),
                ),
              ]
            : [
                BoxShadow(
                  color:      Colors.black.withAlpha(15),
                  blurRadius: 8,
                  offset:     const Offset(0, 2),
                ),
              ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(13),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Colored top strip
            Container(height: 4, color: teamColor),

            // Jersey stage
            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin:  Alignment.topCenter,
                    end:    Alignment.bottomCenter,
                    colors: [Colors.white, Colors.black],
                  ),
                ),
                child: Center(
                  child: FractionallySizedBox(
                    widthFactor: 0.62,
                    child: AspectRatio(
                      aspectRatio: 240 / 220,
                      child: _JerseyWidget(color: teamColor),
                    ),
                  ),
                ),
              ),
            ),

            // Info section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    color.name,
                    style: TextStyle(
                      fontSize:   14,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : AppColors.slate900,
                    ),
                    maxLines:  1,
                    overflow:  TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      // Ativo badge
                      if (color.isActive)
                        const _Badge(
                          label:   'Ativo',
                          bg:      Color(0xFFecfdf5),
                          fg:      Color(0xFF059669),
                        )
                      else
                        _Badge(
                          label:   'Inativo',
                          bg:      isDark ? AppColors.slate800 : AppColors.slate100,
                          fg:      isDark ? AppColors.slate400 : AppColors.slate500,
                        ),
                      const SizedBox(width: 6),
                      // Hex badge
                      _Badge(
                        label: color.hexValue.toUpperCase(),
                        bg:    isDark ? AppColors.slate800 : AppColors.slate100,
                        fg:    isDark ? AppColors.slate400 : AppColors.slate600,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Jersey widget (CustomPainter) ─────────────────────────────────────────────

class _JerseyWidget extends StatelessWidget {
  final Color color;
  const _JerseyWidget({required this.color});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _JerseyPainter(color: color),
    );
  }
}

class _JerseyPainter extends CustomPainter {
  final Color color;
  const _JerseyPainter({required this.color});

  // SVG viewBox: 0 0 240 220
  // Body path: M80 55 L105 40 L120 55 L135 40 L160 55 L185 70 L170 95 L160 90 L160 185 L80 185 L80 90 L70 95 L55 70 Z
  // Collar:    M105 40 L120 60 L135 40

  @override
  void paint(Canvas canvas, Size size) {
    final scaleX = size.width  / 240.0;
    final scaleY = size.height / 220.0;

    canvas.save();
    canvas.scale(scaleX, scaleY);

    // Determine if color is light to adjust stroke
    final luminance = color.computeLuminance();
    final strokeColor = luminance > 0.7
        ? const Color(0xFF334155)   // dark stroke for light jerseys
        : const Color(0xFF0f172a);  // very dark for colored jerseys

    // Jersey fill
    final bodyPath = Path()
      ..moveTo(80, 55)
      ..lineTo(105, 40)
      ..lineTo(120, 55)
      ..lineTo(135, 40)
      ..lineTo(160, 55)
      ..lineTo(185, 70)
      ..lineTo(170, 95)
      ..lineTo(160, 90)
      ..lineTo(160, 185)
      ..lineTo(80, 185)
      ..lineTo(80, 90)
      ..lineTo(70, 95)
      ..lineTo(55, 70)
      ..close();

    // Fill
    final fillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawPath(bodyPath, fillPaint);

    // Stroke (body outline)
    final strokePaint = Paint()
      ..color = strokeColor.withAlpha(180)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..strokeJoin  = StrokeJoin.round
      ..strokeCap   = StrokeCap.round;
    canvas.drawPath(bodyPath, strokePaint);

    // Collar (V-shape, stroke only)
    final collarPath = Path()
      ..moveTo(105, 40)
      ..lineTo(120, 60)
      ..lineTo(135, 40);

    final collarPaint = Paint()
      ..color = strokeColor.withAlpha(200)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeJoin  = StrokeJoin.round
      ..strokeCap   = StrokeCap.round;
    canvas.drawPath(collarPath, collarPaint);

    // Subtle inner highlight line along the shoulder seams
    final highlightPaint = Paint()
      ..color = Colors.white.withAlpha(60)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap   = StrokeCap.round;

    // Left seam highlight
    final leftSeam = Path()
      ..moveTo(80, 90)
      ..lineTo(70, 95)
      ..lineTo(55, 70)
      ..lineTo(80, 55);
    canvas.drawPath(leftSeam, highlightPaint);

    // Right seam highlight
    final rightSeam = Path()
      ..moveTo(160, 90)
      ..lineTo(170, 95)
      ..lineTo(185, 70)
      ..lineTo(160, 55);
    canvas.drawPath(rightSeam, highlightPaint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(_JerseyPainter old) => old.color != color;
}

// ── Action bar ────────────────────────────────────────────────────────────────

class _ActionBar extends StatelessWidget {
  final TeamColor    selected;
  final bool         isDark;
  final bool         canManage;
  final VoidCallback onPreview;
  final VoidCallback onEdit;
  final VoidCallback onActivate;

  const _ActionBar({
    required this.selected,
    required this.isDark,
    required this.canManage,
    required this.onPreview,
    required this.onEdit,
    required this.onActivate,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: canManage
          ? Row(
              children: [
                Expanded(
                  child: _ActionButton(
                    label:  'Editar selecionado',
                    icon:   Icons.edit_outlined,
                    isDark: isDark,
                    onTap:  onEdit,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _ActionButton(
                    label: selected.isActive ? 'Desativar' : 'Ativar',
                    icon:  selected.isActive
                        ? Icons.toggle_on_rounded
                        : Icons.toggle_off_rounded,
                    isDark:   isDark,
                    accent:   selected.isActive
                        ? const Color(0xFFef4444)
                        : const Color(0xFF22c55e),
                    onTap:    onActivate,
                  ),
                ),
              ],
            )
          : SizedBox(
              width: double.infinity,
              child: _ActionButton(
                label:  'Ver uniforme',
                icon:   Icons.visibility_outlined,
                isDark: isDark,
                onTap:  onPreview,
              ),
            ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String     label;
  final IconData   icon;
  final bool       isDark;
  final Color?     accent;
  final VoidCallback onTap;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.isDark,
    required this.onTap,
    this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final fg = accent ?? (isDark ? AppColors.slate200 : AppColors.slate700);
    final bg = accent != null
        ? accent!.withAlpha(20)
        : (isDark ? AppColors.slate800 : AppColors.slate100);
    final border = accent ?? (isDark ? AppColors.slate700 : AppColors.slate200);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color:        bg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: border.withAlpha(100)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: fg),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize:   13,
                fontWeight: FontWeight.w600,
                color:      fg,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Preview sheet ─────────────────────────────────────────────────────────────

class _PreviewSheet extends StatelessWidget {
  final TeamColor color;
  final bool      isDark;

  const _PreviewSheet({required this.color, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final teamColor = color.color;

    return Container(
      decoration: BoxDecoration(
        color:        isDark ? AppColors.slate900 : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Colored top strip
            Container(
              height:       3,
              decoration: BoxDecoration(
                color:        teamColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
            ),

            // Dark gradient header
            Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin:  Alignment.topLeft,
                  end:    Alignment.bottomRight,
                  colors: [
                    const Color(0xFF0f172a),
                    Color.lerp(const Color(0xFF1e293b), teamColor, 0.15)!,
                  ],
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Preview do uniforme',
                          style: TextStyle(
                            fontSize:   12,
                            color:      Color(0xFF94A3B8),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          color.name,
                          style: const TextStyle(
                            fontSize:   20,
                            fontWeight: FontWeight.w800,
                            color:      Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 32, height: 32,
                      decoration: BoxDecoration(
                        color:  Colors.white.withAlpha(20),
                        shape:  BoxShape.circle,
                        border: Border.all(color: Colors.white.withAlpha(40)),
                      ),
                      child: const Icon(
                        Icons.close_rounded,
                        size:  16,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Jersey stage
            Container(
              height: 220,
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.center,
                  radius: 0.85,
                  colors: [
                    Colors.white.withAlpha(isDark ? 30 : 80),
                    isDark ? AppColors.slate950 : AppColors.slate200,
                  ],
                ),
              ),
              child: Center(
                child: FractionallySizedBox(
                  widthFactor: 0.55,
                  child: AspectRatio(
                    aspectRatio: 240 / 220,
                    child: _JerseyWidget(color: teamColor),
                  ),
                ),
              ),
            ),

            // Info footer
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  // Color swatch
                  Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      color:        teamColor,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isDark ? AppColors.slate700 : AppColors.slate200,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          color.hexValue.toUpperCase(),
                          style: TextStyle(
                            fontSize:   16,
                            fontWeight: FontWeight.w700,
                            fontFamily: 'monospace',
                            color: isDark ? Colors.white : AppColors.slate900,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          color.name,
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? AppColors.slate400 : AppColors.slate500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Status badge
                  color.isActive
                      ? const _Badge(
                          label: 'Ativo',
                          bg:    Color(0xFFecfdf5),
                          fg:    Color(0xFF059669),
                        )
                      : _Badge(
                          label: 'Inativo',
                          bg:    isDark ? AppColors.slate800 : AppColors.slate100,
                          fg:    isDark ? AppColors.slate400 : AppColors.slate500,
                        ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Edit / Create sheet ───────────────────────────────────────────────────────

class _EditSheet extends StatefulWidget {
  final String                   groupId;
  final TeamColor?               existing;
  final bool                     isDark;
  final VoidCallback             onSaved;
  final TeamColorRemoteDataSource ds;

  const _EditSheet({
    required this.groupId,
    required this.isDark,
    required this.onSaved,
    required this.ds,
    this.existing,
  });

  @override
  State<_EditSheet> createState() => _EditSheetState();
}

class _EditSheetState extends State<_EditSheet> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _hexCtrl;
  bool _saving = false;

  bool get _isEdit => widget.existing != null;

  Color get _liveColor => _parseHex(_hexCtrl.text) ?? const Color(0xFFe2e8f0);

  static Color? _parseHex(String hex) {
    try {
      final h = hex.replaceAll('#', '').trim();
      if (h.length == 3) {
        final r = h[0] + h[0];
        final g = h[1] + h[1];
        final b = h[2] + h[2];
        return Color(int.parse('FF$r$g$b', radix: 16));
      }
      if (h.length == 6) return Color(int.parse('FF$h', radix: 16));
    } catch (_) {}
    return null;
  }

  /// Abre o color picker num dialog e atualiza [_hexCtrl] com a cor escolhida.
  Future<void> _openColorPicker() async {
    Color picked = _liveColor;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          titlePadding: EdgeInsets.zero,
          contentPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF0f172a), Color(0xFF1e293b)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                const Icon(Icons.colorize_rounded, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Escolher cor',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.pop(ctx, false),
                  child: const Icon(Icons.close_rounded, color: Colors.white60, size: 20),
                ),
              ],
            ),
          ),
          content: StatefulBuilder(
            builder: (ctx2, setStateInner) => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 12),
                ColorPicker(
                  pickerColor:        picked,
                  onColorChanged:     (c) { picked = c; setStateInner(() {}); },
                  enableAlpha:        false,
                  displayThumbColor:  true,
                  pickerAreaHeightPercent: 0.55,
                  hexInputBar:        true,
                  labelTypes:         const [],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Confirmar'),
            ),
          ],
        );
      },
    );

    if (confirmed == true && mounted) {
      final r = ((picked.r * 255).round()).toRadixString(16).padLeft(2, '0');
      final g = ((picked.g * 255).round()).toRadixString(16).padLeft(2, '0');
      final b = ((picked.b * 255).round()).toRadixString(16).padLeft(2, '0');
      setState(() => _hexCtrl.text = '#$r$g$b');
    }
  }

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.existing?.name ?? '');
    _hexCtrl  = TextEditingController(
      text: widget.existing?.hexValue ?? '#3b82f6',
    );
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _hexCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    final hex  = _hexCtrl.text.trim();

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nome é obrigatório')),
      );
      return;
    }
    if (_parseHex(hex) == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cor inválida. Use formato #rrggbb')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final normalizedHex = hex.startsWith('#') ? hex : '#$hex';
      if (_isEdit) {
        await widget.ds.updateColor(
            widget.groupId, widget.existing!.id, name, normalizedHex);
      } else {
        await widget.ds.createColor(widget.groupId, name, normalizedHex);
      }
      if (mounted) {
        Navigator.pop(context);
        widget.onSaved();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao salvar: $e')),
        );
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;

    return AnimatedBuilder(
      animation: Listenable.merge([_nameCtrl, _hexCtrl]),
      builder: (context, _) {
        final liveC = _liveColor;
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Container(
            decoration: BoxDecoration(
              color:        isDark ? AppColors.slate900 : Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Colored top strip
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    height:   3,
                    decoration: BoxDecoration(
                      color:        liveC,
                      borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(20)),
                    ),
                  ),

                  // Dark gradient header
                  Container(
                    padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin:  Alignment.topLeft,
                        end:    Alignment.bottomRight,
                        colors: [
                          const Color(0xFF0f172a),
                          Color.lerp(const Color(0xFF1e293b), liveC, 0.2)!,
                        ],
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 36, height: 36,
                          decoration: BoxDecoration(
                            color:        Colors.white.withAlpha(20),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.white.withAlpha(40)),
                          ),
                          child: const Icon(
                            Icons.palette_rounded,
                            size:  18,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _nameCtrl.text.isEmpty
                                ? (_isEdit ? 'Editar cor' : 'Nova cor')
                                : _nameCtrl.text,
                            style: const TextStyle(
                              fontSize:   18,
                              fontWeight: FontWeight.w800,
                              color:      Colors.white,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: Container(
                            width: 32, height: 32,
                            decoration: BoxDecoration(
                              color:  Colors.white.withAlpha(20),
                              shape:  BoxShape.circle,
                              border: Border.all(color: Colors.white.withAlpha(40)),
                            ),
                            child: const Icon(
                              Icons.close_rounded,
                              size:  16,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Scrollable body
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Mini jersey preview card
                          Container(
                            height: 130,
                            decoration: BoxDecoration(
                              color:        isDark ? AppColors.slate800 : AppColors.slate50,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isDark ? AppColors.slate700 : AppColors.slate200,
                              ),
                            ),
                            child: Row(
                              children: [
                                // Jersey stage
                                Expanded(
                                  child: Container(
                                    decoration: const BoxDecoration(
                                      gradient: LinearGradient(
                                        begin:  Alignment.topCenter,
                                        end:    Alignment.bottomCenter,
                                        colors: [Colors.white, Colors.black],
                                      ),
                                      borderRadius: BorderRadius.only(
                                        topLeft:     Radius.circular(13),
                                        bottomLeft:  Radius.circular(13),
                                      ),
                                    ),
                                    child: Center(
                                      child: FractionallySizedBox(
                                        widthFactor: 0.55,
                                        child: AspectRatio(
                                          aspectRatio: 240 / 220,
                                          child: _JerseyWidget(color: liveC),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                // Info
                                Padding(
                                  padding: const EdgeInsets.all(14),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        width: 28, height: 28,
                                        decoration: BoxDecoration(
                                          color:        liveC,
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(
                                            color: isDark ? AppColors.slate600 : AppColors.slate300,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        _hexCtrl.text.toUpperCase(),
                                        style: TextStyle(
                                          fontSize:   11,
                                          fontFamily: 'monospace',
                                          fontWeight: FontWeight.w600,
                                          color: isDark ? AppColors.slate300 : AppColors.slate700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 16),

                          // Name field
                          _label('Nome da cor', isDark),
                          const SizedBox(height: 6),
                          _field(
                            controller: _nameCtrl,
                            hint:       'Ex: Azul Royal',
                            isDark:     isDark,
                          ),

                          const SizedBox(height: 14),

                          // Hex field + color picker button
                          _label('Código Hex', isDark),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              // Tapping the swatch opens the color picker
                              Tooltip(
                                message: 'Abrir seletor de cor',
                                child: GestureDetector(
                                  onTap: _openColorPicker,
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    width:  40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color:        liveC,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: isDark ? AppColors.slate600 : AppColors.slate300,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color:      liveC.withAlpha(80),
                                          blurRadius: 8,
                                          spreadRadius: 1,
                                        ),
                                      ],
                                    ),
                                    child: Icon(
                                      Icons.colorize_rounded,
                                      size:  16,
                                      color: liveC.computeLuminance() > 0.5
                                          ? Colors.black54
                                          : Colors.white70,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _field(
                                  controller: _hexCtrl,
                                  hint:       '#rrggbb',
                                  isDark:     isDark,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 24),

                          // Buttons
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () => Navigator.pop(context),
                                  style: OutlinedButton.styleFrom(
                                    side: BorderSide(
                                      color: isDark
                                          ? AppColors.slate700
                                          : AppColors.slate200,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                  ),
                                  child: Text(
                                    'Cancelar',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: isDark
                                          ? AppColors.slate400
                                          : AppColors.slate500,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: FilledButton(
                                  onPressed: _saving ? null : _save,
                                  style: FilledButton.styleFrom(
                                    backgroundColor:
                                        isDark ? Colors.white : AppColors.slate900,
                                    foregroundColor:
                                        isDark ? AppColors.slate900 : Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                  ),
                                  child: _saving
                                      ? const SizedBox(
                                          width: 20, height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : Text(
                                          _isEdit ? 'Salvar' : 'Criar cor',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _label(String text, bool isDark) => Text(
        text,
        style: TextStyle(
          fontSize:      12,
          fontWeight:    FontWeight.w600,
          color: isDark ? AppColors.slate400 : AppColors.slate500,
          letterSpacing: .3,
        ),
      );

  Widget _field({
    required TextEditingController controller,
    required String                hint,
    required bool                  isDark,
  }) {
    return TextField(
      controller:   controller,
      style: TextStyle(
        fontSize: 14,
        color: isDark ? AppColors.slate200 : AppColors.slate800,
      ),
      decoration: InputDecoration(
        hintText:  hint,
        hintStyle: TextStyle(color: isDark ? AppColors.slate600 : AppColors.slate400),
        filled:    true,
        fillColor: isDark ? AppColors.slate800 : AppColors.slate50,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: isDark ? AppColors.slate700 : AppColors.slate200,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: isDark ? AppColors.slate700 : AppColors.slate200,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: isDark ? AppColors.slate400 : AppColors.slate500,
            width: 1.5,
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 48),
        decoration: BoxDecoration(
          color:        isDark ? AppColors.slate900 : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? AppColors.slate700 : AppColors.slate200,
            style: BorderStyle.solid,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.palette_outlined,
              size:  36,
              color: isDark ? AppColors.slate600 : AppColors.slate300,
            ),
            const SizedBox(height: 12),
            Text(
              'Nenhuma cor cadastrada.',
              style: TextStyle(
                fontSize:   14,
                fontWeight: FontWeight.w500,
                color: isDark ? AppColors.slate400 : AppColors.slate500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Adicione cores para personalizar os uniformes.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: isDark ? AppColors.slate500 : AppColors.slate400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── No group state ────────────────────────────────────────────────────────────

class _NoGroupState extends StatelessWidget {
  final bool isDark;
  const _NoGroupState({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.group_outlined,
            size:  40,
            color: isDark ? AppColors.slate600 : AppColors.slate300,
          ),
          const SizedBox(height: 12),
          Text(
            'Selecione um grupo no Dashboard.',
            style: TextStyle(
              fontSize: 14,
              color: isDark ? AppColors.slate500 : AppColors.slate400,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Carousel skeleton ─────────────────────────────────────────────────────────

class _CarouselSkeleton extends StatelessWidget {
  final bool isDark;
  const _CarouselSkeleton({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: [
          Container(
            height:       290,
            decoration: BoxDecoration(
              color:        isDark ? AppColors.slate800 : AppColors.slate100,
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              3,
              (i) => Container(
                width:  i == 1 ? 20 : 6,
                height: 6,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                decoration: BoxDecoration(
                  color:        isDark ? AppColors.slate700 : AppColors.slate200,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Badge ─────────────────────────────────────────────────────────────────────

class _Badge extends StatelessWidget {
  final String label;
  final Color  bg;
  final Color  fg;

  const _Badge({required this.label, required this.bg, required this.fg});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color:        bg,
        borderRadius: BorderRadius.circular(99),
        border:       Border.all(color: fg.withAlpha(80)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize:   10,
          fontWeight: FontWeight.w600,
          color:      fg,
        ),
      ),
    );
  }
}

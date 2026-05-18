import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../auth/presentation/providers/account_store.dart';
import '../../domain/entities/spotlight_report.dart';
import '../providers/spotlight_provider.dart';

// ── Win-rate normaliser (fraction → percent) ──────────────────────────────────

double _normalizeWR(double v) {
  if (!v.isFinite) return 0;
  final pct = v <= 1 ? v * 100 : v;
  return pct.clamp(0, 100);
}

String _pct(double v) => '${v.toStringAsFixed(0)}%';

// ── Page ──────────────────────────────────────────────────────────────────────

class PlayerSpotlightPage extends ConsumerStatefulWidget {
  const PlayerSpotlightPage({super.key});

  @override
  ConsumerState<PlayerSpotlightPage> createState() =>
      _PlayerSpotlightPageState();
}

class _PlayerSpotlightPageState extends ConsumerState<PlayerSpotlightPage> {
  @override
  Widget build(BuildContext context) {
    final account = ref.watch(accountStoreProvider).activeAccount;
    final groupId = account?.activeGroupId;

    if (groupId == null || groupId.isEmpty) {
      return const Scaffold(body: _NoGroupState());
    }

    final async = ref.watch(spotlightProvider(groupId));

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(spotlightProvider(groupId)),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(child: _buildHeader(async)),
            async.when(
              loading: () =>
                  const SliverToBoxAdapter(child: _SkeletonLoader()),
              error: (e, _) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Erro ao carregar spotlight: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                });
                return SliverToBoxAdapter(
                  child: _ErrorState(message: extractDioError(e)),
                );
              },
              data: (report) {
                if (report.isEmpty) {
                  return const SliverToBoxAdapter(child: _EmptyState());
                }
                return SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
                    child: _SpotlightContent(report: report),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(AsyncValue<PlayerSpotlightReport> async) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final report = async.valueOrNull;
    final playerCount = report?.players.length ?? 0;

    String subtitle;
    if (async.isLoading) {
      subtitle = 'Carregando...';
    } else if (async.hasError) {
      subtitle = 'Erro ao carregar';
    } else {
      subtitle = playerCount > 0
          ? '$playerCount jogadores no ranking'
          : 'Sem dados ainda';
    }

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF1E293B), Color(0xFF0F172A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(25),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withAlpha(50)),
                ),
                child: const Icon(Icons.star_rounded,
                    size: 26, color: Color(0xFFFBBF24)),
              ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Destaques',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.white.withAlpha(128),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Spotlight content ─────────────────────────────────────────────────────────

class _SpotlightContent extends StatelessWidget {
  final PlayerSpotlightReport report;
  const _SpotlightContent({required this.report});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Highlight cards ──────────────────────────────────────────
        if (report.topScorer != null ||
            report.topAssist != null ||
            report.topMvp != null ||
            report.bestWinRate != null) ...[
          _sectionLabel(isDark, 'Melhores da temporada'),
          const SizedBox(height: 10),
          if (report.topScorer != null)
            _SpotlightCard(
              icon: Icons.sports_soccer_rounded,
              iconColor: const Color(0xFF22C55E),
              title: 'Artilheiro',
              player: report.topScorer!,
              statLabel: 'gols',
              statValue: '${report.topScorer!.goals}',
              secondaryStats: [
                if (report.topScorer!.assists > 0)
                  '${report.topScorer!.assists} assist.',
                '${report.topScorer!.matchCount} jogos',
              ],
              isDark: isDark,
            ),
          if (report.topAssist != null) ...[
            const SizedBox(height: 12),
            _SpotlightCard(
              icon: Icons.assistant_rounded,
              iconColor: const Color(0xFF3B82F6),
              title: 'Garçom',
              player: report.topAssist!,
              statLabel: 'assist.',
              statValue: '${report.topAssist!.assists}',
              secondaryStats: [
                if (report.topAssist!.goals > 0)
                  '${report.topAssist!.goals} gols',
                '${report.topAssist!.matchCount} jogos',
              ],
              isDark: isDark,
            ),
          ],
          if (report.topMvp != null) ...[
            const SizedBox(height: 12),
            _SpotlightCard(
              icon: Icons.emoji_events_rounded,
              iconColor: const Color(0xFFFBBF24),
              title: 'MVP da temporada',
              player: report.topMvp!,
              statLabel: 'MVPs',
              statValue: '${report.topMvp!.mvpCount}',
              secondaryStats: [
                '${report.topMvp!.matchCount} jogos',
              ],
              isDark: isDark,
            ),
          ],
          if (report.bestWinRate != null) ...[
            const SizedBox(height: 12),
            _SpotlightCard(
              icon: Icons.trending_up_rounded,
              iconColor: const Color(0xFF8B5CF6),
              title: 'Melhor aproveitamento',
              player: report.bestWinRate!,
              statLabel: 'win rate',
              statValue: _pct(_normalizeWR(report.bestWinRate!.winRate)),
              secondaryStats: [
                '${report.bestWinRate!.matchCount} jogos',
              ],
              isDark: isDark,
            ),
          ],
          const SizedBox(height: 24),
        ],

        // ── Full player table ────────────────────────────────────────
        if (report.players.isNotEmpty) ...[
          _sectionLabel(isDark, 'Todos os jogadores'),
          const SizedBox(height: 10),
          _PlayersTable(players: report.players, isDark: isDark),
        ],
      ],
    );
  }

  Widget _sectionLabel(bool isDark, String text) => Text(
    text,
    style: TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.5,
      color: isDark ? AppColors.slate400 : AppColors.slate500,
    ),
  );
}

// ── Spotlight card ────────────────────────────────────────────────────────────

class _SpotlightCard extends StatelessWidget {
  final IconData          icon;
  final Color             iconColor;
  final String            title;
  final SpotlightPlayer   player;
  final String            statLabel;
  final String            statValue;
  final List<String>      secondaryStats;
  final bool              isDark;

  const _SpotlightCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.player,
    required this.statLabel,
    required this.statValue,
    required this.secondaryStats,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.slate800 : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? AppColors.slate700 : AppColors.slate200,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // Color accent strip
          Container(height: 3, color: iconColor),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Row(
              children: [
                // Icon badge
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: iconColor.withAlpha(30),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, size: 22, color: iconColor),
                ),
                const SizedBox(width: 14),
                // Title + player name
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                          color: isDark
                              ? AppColors.slate400
                              : AppColors.slate500,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        player.playerName,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                          color: isDark
                              ? Colors.white
                              : AppColors.slate900,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (secondaryStats.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 3),
                          child: Text(
                            secondaryStats.join(' · '),
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark
                                  ? AppColors.slate500
                                  : AppColors.slate400,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                // Stat highlight
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      statValue,
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w900,
                        color: iconColor,
                        fontFeatures: const [FontFeature.tabularFigures()],
                        height: 1,
                      ),
                    ),
                    Text(
                      statLabel,
                      style: TextStyle(
                        fontSize: 10,
                        letterSpacing: 0.5,
                        color: isDark
                            ? AppColors.slate500
                            : AppColors.slate400,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Players table ─────────────────────────────────────────────────────────────

class _PlayersTable extends StatelessWidget {
  final List<SpotlightPlayer> players;
  final bool                  isDark;

  const _PlayersTable({required this.players, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final head = TextStyle(
      fontSize: 9,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.8,
      color: isDark ? AppColors.slate500 : AppColors.slate400,
    );

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.slate800 : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? AppColors.slate700 : AppColors.slate200,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Container(
              color: isDark
                  ? AppColors.slate800.withAlpha(120)
                  : AppColors.slate50,
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  SizedBox(
                    width: 32,
                    child: Center(child: Text('#', style: head)),
                  ),
                  SizedBox(
                    width: 170,
                    child: Text('JOGADOR', style: head),
                  ),
                  SizedBox(
                    width: 44,
                    child: Center(child: Text('J', style: head)),
                  ),
                  SizedBox(
                    width: 44,
                    child: Center(
                        child: Text('GOLS', style: head)),
                  ),
                  SizedBox(
                    width: 50,
                    child: Center(
                        child: Text('ASSIST.', style: head)),
                  ),
                  SizedBox(
                    width: 44,
                    child: Center(child: Text('MVP', style: head)),
                  ),
                  SizedBox(
                    width: 70,
                    child: Center(
                        child: Text('WIN RATE', style: head)),
                  ),
                ],
              ),
            ),
            // Rows
            ...players.asMap().entries.map((e) {
              final idx = e.key;
              final p   = e.value;
              final wr  = _normalizeWR(p.winRate);
              final divColor = isDark ? AppColors.slate700 : AppColors.slate100;

              return Column(
                children: [
                  Container(
                    color: divColor,
                    height: 0.5,
                  ),
                  Row(
                    children: [
                      SizedBox(
                        width: 32,
                        child: Center(
                          child: Text(
                            '${idx + 1}',
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark
                                  ? AppColors.slate500
                                  : AppColors.slate400,
                              fontFeatures: const [
                                FontFeature.tabularFigures()
                              ],
                            ),
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 170,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: Text(
                            p.playerName,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isDark
                                  ? Colors.white
                                  : AppColors.slate900,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 44,
                        child: Center(
                          child: Text(
                            '${p.matchCount}',
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark
                                  ? AppColors.slate400
                                  : AppColors.slate500,
                              fontFeatures: const [
                                FontFeature.tabularFigures()
                              ],
                            ),
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 44,
                        child: Center(
                          child: p.goals > 0
                              ? Text(
                                  '${p.goals}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF22C55E),
                                    fontFeatures: const [
                                      FontFeature.tabularFigures()
                                    ],
                                  ),
                                )
                              : Text('—',
                                  style: TextStyle(
                                      fontSize: 11, color: divColor)),
                        ),
                      ),
                      SizedBox(
                        width: 50,
                        child: Center(
                          child: p.assists > 0
                              ? Text(
                                  '${p.assists}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF3B82F6),
                                    fontFeatures: const [
                                      FontFeature.tabularFigures()
                                    ],
                                  ),
                                )
                              : Text('—',
                                  style: TextStyle(
                                      fontSize: 11, color: divColor)),
                        ),
                      ),
                      SizedBox(
                        width: 44,
                        child: Center(
                          child: p.mvpCount > 0
                              ? Text(
                                  '${p.mvpCount}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFFFBBF24),
                                    fontFeatures: [
                                      FontFeature.tabularFigures()
                                    ],
                                  ),
                                )
                              : Text('—',
                                  style: TextStyle(
                                      fontSize: 11, color: divColor)),
                        ),
                      ),
                      SizedBox(
                        width: 70,
                        child: Center(
                          child: Text(
                            _pct(wr),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: _wrColor(wr),
                              fontFeatures: const [
                                FontFeature.tabularFigures()
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              );
            }),
          ],
        ),
      ),
    );
  }
}

Color _wrColor(double v) {
  if (v >= 60) return const Color(0xFF16A34A);
  if (v >= 45) return const Color(0xFFD97706);
  return const Color(0xFFDC2626);
}

// ── Skeleton / Empty / Error / No-group ───────────────────────────────────────

class _SkeletonLoader extends StatefulWidget {
  const _SkeletonLoader();
  @override
  State<_SkeletonLoader> createState() => _SkeletonLoaderState();
}

class _SkeletonLoaderState extends State<_SkeletonLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double>   _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.4, end: 0.9).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final base   = isDark ? AppColors.slate800 : AppColors.slate100;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: AnimatedBuilder(
        animation: _anim,
        builder: (_, __) => Opacity(
          opacity: _anim.value,
          child: Column(
            children: [
              for (int i = 0; i < 4; i++) ...[
                Container(
                  height: 80,
                  decoration: BoxDecoration(
                    color: base,
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              Container(
                height: 200,
                decoration: BoxDecoration(
                  color: base,
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.all(48),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.star_outline_rounded,
            size: 52,
            color: isDark ? AppColors.slate600 : AppColors.slate300,
          ),
          const SizedBox(height: 16),
          Text(
            'Sem destaques ainda.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: isDark ? AppColors.slate400 : AppColors.slate500,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Jogue algumas partidas para ver os destaques da temporada.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: isDark ? AppColors.slate500 : AppColors.slate400,
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  const _ErrorState({required this.message});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(24),
    child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1F2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFFCDD2)),
      ),
      child: Text(
        message,
        style: const TextStyle(fontSize: 13, color: Color(0xFF9B1239)),
      ),
    ),
  );
}

class _NoGroupState extends StatelessWidget {
  const _NoGroupState();

  @override
  Widget build(BuildContext context) => const Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.star_outline_rounded,
            size: 48, color: AppColors.slate500),
        SizedBox(height: 12),
        Text(
          'Crie ou entre em um grupo',
          textAlign: TextAlign.center,
          style: TextStyle(
              color: AppColors.slate400, fontSize: 13),
        ),
      ],
    ),
  );
}

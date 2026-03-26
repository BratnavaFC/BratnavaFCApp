/// GroupIconRenderer
///
/// Widget compartilhado que renderiza ícones configuráveis por patota,
/// espelhando o IconRenderer.tsx do site.
///
/// Formatos suportados:
///   "⚽"            → emoji / caractere
///   "lucide:Trophy" → ícone Material mapeado
///   "letter:G"      → texto em negrito estilizado
library;

import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../features/group_settings/domain/entities/group_settings.dart';

// ── Mapeamento lucide → Material ──────────────────────────────────────────────

const kGroupLucideIcons = <String, IconData>{
  'Trophy':        Icons.emoji_events_outlined,
  'User':          Icons.person_outline,
  'Target':        Icons.gps_fixed,
  'Medal':         Icons.military_tech_outlined,
  'ShieldAlert':   Icons.shield_outlined,
  'Radar':         Icons.radar,
  'Link':          Icons.link_outlined,
  'Handshake':     Icons.handshake_outlined,
  'AlertTriangle': Icons.warning_amber_outlined,
  'Ban':           Icons.block_outlined,
  'Award':         Icons.workspace_premium_outlined,
  'Crown':         Icons.workspace_premium_outlined,
  'UserRound':     Icons.account_circle_outlined,
  'Shirt':         Icons.dry_cleaning_outlined,
};

// ── Função de renderização ────────────────────────────────────────────────────

/// Renderiza um valor de ícone de grupo (emoji, lucide:Nome, ou letter:Texto).
/// Equivalente ao IconRenderer.tsx do site.
Widget renderGroupIcon(String value, {double size = 14, Color? color}) {
  if (value.startsWith('lucide:')) {
    final name = value.substring(7);
    final data = kGroupLucideIcons[name];
    final c    = color ?? AppColors.slate600;
    if (data != null) return Icon(data, size: size, color: c);
    return Text('?', style: TextStyle(fontSize: size * 0.8, color: c));
  }
  if (value.startsWith('letter:')) {
    final text  = value.substring(7);
    final scale = text.length <= 2 ? 0.85 : text.length == 3 ? 0.72 : 0.60;
    return Text(
      text,
      style: TextStyle(
        fontSize:      size * scale,
        fontWeight:    FontWeight.w800,
        letterSpacing: -0.8,
        height:        1,
        color:         color ?? AppColors.slate600,
      ),
    );
  }
  // Emoji ou caractere comum
  return Text(value, style: TextStyle(fontSize: size));
}

// ── Classe de ícones resolvidos ───────────────────────────────────────────────

/// Ícones resolvidos de uma patota, com defaults idênticos ao site.
class GroupIcons {
  final String goal;
  final String goalkeeper;
  final String assist;
  final String ownGoal;
  final String mvp;
  final String player;

  const GroupIcons({
    required this.goal,
    required this.goalkeeper,
    required this.assist,
    required this.ownGoal,
    required this.mvp,
    required this.player,
  });

  /// Defaults (sem configuração salva)
  static const defaults = GroupIcons(
    goal:       '⚽',
    goalkeeper: '🧤',
    assist:     '🤝',
    ownGoal:    '🚩',
    mvp:        'lucide:Trophy',
    player:     'lucide:User',
  );

  /// Resolve a partir de um [GroupSettings] carregado da API.
  factory GroupIcons.from(GroupSettings? s) => GroupIcons(
    goal:       s?.goalIcon       ?? '⚽',
    goalkeeper: s?.goalkeeperIcon ?? '🧤',
    assist:     s?.assistIcon     ?? '🤝',
    ownGoal:    s?.ownGoalIcon    ?? '🚩',
    mvp:        s?.mvpIcon        ?? 'lucide:Trophy',
    player:     s?.playerIcon     ?? 'lucide:User',
  );
}

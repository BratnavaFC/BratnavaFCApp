import 'package:flutter/material.dart';

/// Tailwind CSS slate palette — espelha o design system do site.
class AppColors {
  AppColors._();

  static const slate50  = Color(0xFFF8FAFC);
  static const slate100 = Color(0xFFF1F5F9);
  static const slate200 = Color(0xFFE2E8F0);
  static const slate300 = Color(0xFFCBD5E1);
  static const slate400 = Color(0xFF94A3B8);
  static const slate500 = Color(0xFF64748B);
  static const slate600 = Color(0xFF475569);
  static const slate700 = Color(0xFF334155);
  static const slate800 = Color(0xFF1E293B);
  static const slate900 = Color(0xFF0F172A);
  static const slate950 = Color(0xFF020617);

  // Emerald – sucesso
  static const emerald50  = Color(0xFFECFDF5);
  static const emerald200 = Color(0xFFA7F3D0);
  static const emerald500 = Color(0xFF10B981);
  static const emerald700 = Color(0xFF047857);

  // Green – pagamento / sucesso
  static const green50  = Color(0xFFF0FDF4);
  static const green100 = Color(0xFFDCFCE7);
  static const green200 = Color(0xFFBBF7D0);
  static const green400 = Color(0xFF4ADE80);
  static const green500 = Color(0xFF22C55E);
  static const green600 = Color(0xFF16A34A);
  static const green700 = Color(0xFF15803D);

  // Rose – perigo
  static const rose50  = Color(0xFFFFF1F2);
  static const rose200 = Color(0xFFFFCDD2);
  static const rose400 = Color(0xFFFB7185);
  static const rose500 = Color(0xFFF43F5E);
  static const rose600 = Color(0xFFE11D48);

  // Amber – aviso
  static const amber50  = Color(0xFFFFFBEB);
  static const amber200 = Color(0xFFFDE68A);
  static const amber400 = Color(0xFFFBBF24);
  static const amber500 = Color(0xFFF59E0B);

  // Blue – informação
  static const blue50  = Color(0xFFEFF6FF);
  static const blue200 = Color(0xFFBFDBFE);
  static const blue500 = Color(0xFF3B82F6);
  static const blue600 = Color(0xFF2563EB);

  // Violet – times/match
  static const violet50  = Color(0xFFF5F3FF);
  static const violet200 = Color(0xFFDDD6FE);
  static const violet600 = Color(0xFF7C3AED);
  static const violet700 = Color(0xFF6D28D9);

  // Orange – pós-jogo
  static const orange50  = Color(0xFFFFF7ED);
  static const orange200 = Color(0xFFFED7AA);
  static const orange700 = Color(0xFFC2410C);

  // Gradientes de avatar (determinísticos por nome)
  static const List<List<Color>> avatarGradients = [
    [Color(0xFF8B5CF6), Color(0xFF6366F1)], // violet → indigo
    [Color(0xFF0EA5E9), Color(0xFF22D3EE)], // sky → cyan
    [Color(0xFF10B981), Color(0xFF14B8A6)], // emerald → teal
    [Color(0xFFFB923C), Color(0xFFF43F5E)], // orange → rose
    [Color(0xFFEC4899), Color(0xFFD946EF)], // pink → fuchsia
    [Color(0xFFFBBF24), Color(0xFFF97316)], // amber → orange
  ];

  static List<Color> gradientForName(String name) {
    if (name.isEmpty) return avatarGradients[0];
    final idx = name.codeUnits.fold(0, (s, c) => s + c) % avatarGradients.length;
    return avatarGradients[idx];
  }
}

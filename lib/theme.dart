// ============================================================
// [v1] 앱 테마 — 다크 RPG (UI 시안 기반)
// pipeline: 모바일 클라이언트 / 디자인 시스템
// 구현(요약): 색 팔레트(네이비 배경 + 청록/보라/골드 악센트) + ThemeData.
//            시안: ui-example 1~10. 폰트는 기본(커스텀 폰트는 TODO 이지선).
// 구현일: 2026-06-18 | 작성: kys (app-theme/kys/v1)
// ============================================================
import 'package:flutter/material.dart';

/// 시안에서 뽑은 색 팔레트.
class AppColors {
  static const bg = Color(0xFF080B16); // 최하단 배경(딥 네이비)
  static const surface = Color(0xFF131A2B); // 카드
  static const surfaceHi = Color(0xFF1B2438); // 카드(강조)
  static const border = Color(0xFF26314C);

  static const teal = Color(0xFF5EEAD4); // 지도·완료·기본 CTA
  static const purple = Color(0xFFA78BFA); // 기억석·영웅
  static const gold = Color(0xFFE8B84B); // 퀘스트·전설
  static const blue = Color(0xFF5B9BD5); // 희귀

  static const textPrimary = Color(0xFFF2F5FA);
  static const textSecondary = Color(0xFF8B93A7);
}

/// 등급별 색 (전설=골드 / 영웅=보라 / 희귀=파랑 / 일반=회색)
Color tierColor(String tier) {
  switch (tier) {
    case '전설':
      return AppColors.gold;
    case '영웅':
      return AppColors.purple;
    case '희귀':
      return AppColors.blue;
    default:
      return AppColors.textSecondary;
  }
}

ThemeData buildDokkaebiTheme() {
  const scheme = ColorScheme.dark(
    primary: AppColors.teal,
    secondary: AppColors.purple,
    surface: AppColors.surface,
    onPrimary: Color(0xFF06231F),
    onSurface: AppColors.textPrimary,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.bg,
    fontFamily: null,
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      foregroundColor: AppColors.textPrimary,
    ),
    cardTheme: CardTheme(
      color: AppColors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surface,
      hintStyle: const TextStyle(color: AppColors.textSecondary),
      labelStyle: const TextStyle(color: AppColors.textSecondary),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.teal),
      ),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.teal,
        foregroundColor: const Color(0xFF06231F),
        minimumSize: const Size.fromHeight(52),
        textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
  );
}

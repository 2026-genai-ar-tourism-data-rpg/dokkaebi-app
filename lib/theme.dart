// ============================================================
// [v2] 앱 테마 — 전통 도깨비 미감 (종로의 기억석 UI 시안 기반)
// pipeline: 모바일 클라이언트 / 디자인 시스템
// 구현(요약): 먹빛 배경 + 금(#f4c860)/단청주홍(#c8452c)/도깨비불 민트(#6fd4c1)/한지 크림.
//            폰트 Gowun Batang(제목)·Noto Sans KR(본문) = google_fonts. AppColors 이름 유지(하위호환).
// 구현일: 2026-07-08 | 작성: kys (app-theme/kys/v2) · 시안: 종로의 기억석 UI standalone
// ------------------------------------------------------------
// [v1] 다크 RPG(네이비+청록/보라/골드) — 2026-06-18 kys (app-theme/kys/v1)
// ============================================================
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// 시안(종로의 기억석 UI)에서 뽑은 전통 팔레트.
class AppColors {
  // ── 배경 (먹빛) ──
  static const bg = Color(0xFF0D0B09); // 최하단 배경(먹빛 딥)
  static const surface = Color(0xFF17130F); // 카드
  static const surfaceHi = Color(0xFF2A2118); // 카드(강조, 따뜻한 갈)
  static const border = Color(0xFF4A3D2C); // 청동 라인

  // ── 악센트 (도깨비·단청·기억석) ──
  static const teal = Color(0xFF6FD4C1); // 도깨비불 민트 — 완료·기본 CTA
  static const tealDeep = Color(0xFF2A8577);
  static const gold = Color(0xFFF4C860); // 금 — 기억석·전설·피날레
  static const goldDim = Color(0xFFD9A441); // 은은한 금 — 미방문·진행
  static const vermilion = Color(0xFFC8452C); // 단청 주홍 — 봉인·강조·위험
  static const blue = Color(0xFF5B8FD5); // 희귀

  /// 하위호환 별칭 — 기존 화면의 purple(기억석·영웅·미방문)은 은은한 금으로 매핑.
  static const purple = goldDim;

  // ── 텍스트 (한지) ──
  static const textPrimary = Color(0xFFF2EAD8); // 한지 크림
  static const textSecondary = Color(0xFFC9C1B2); // 따뜻한 회
  static const textMuted = Color(0xFF8A8378);
}

/// 제목용 전통 세리프(Gowun Batang). 코스명·NPC 이름·기억석 라벨 등에.
TextStyle dokkaebiTitle({
  double size = 20,
  FontWeight weight = FontWeight.w700,
  Color color = AppColors.textPrimary,
  double? height,
  double? letterSpacing,
}) =>
    GoogleFonts.gowunBatang(
      fontSize: size,
      fontWeight: weight,
      color: color,
      height: height,
      letterSpacing: letterSpacing,
    );

/// 등급별 색 (전설=금 / 영웅=은은한 금 / 희귀=파랑 / 일반=회색)
Color tierColor(String tier) {
  switch (tier) {
    case '전설':
      return AppColors.gold;
    case '영웅':
      return AppColors.goldDim;
    case '희귀':
      return AppColors.blue;
    default:
      return AppColors.textSecondary;
  }
}

ThemeData buildDokkaebiTheme() {
  const scheme = ColorScheme.dark(
    primary: AppColors.teal, // 도깨비불 민트
    secondary: AppColors.gold, // 금
    tertiary: AppColors.vermilion, // 단청 주홍
    surface: AppColors.surface,
    onPrimary: Color(0xFF06231F),
    onSecondary: Color(0xFF2A2118),
    onSurface: AppColors.textPrimary,
  );
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    brightness: Brightness.dark,
  );
  return base.copyWith(
    scaffoldBackgroundColor: AppColors.bg,
    // 본문 = Noto Sans KR, 색은 한지 크림
    textTheme: GoogleFonts.notoSansKrTextTheme(base.textTheme).apply(
      bodyColor: AppColors.textPrimary,
      displayColor: AppColors.textPrimary,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      foregroundColor: AppColors.textPrimary,
      titleTextStyle: dokkaebiTitle(size: 20),
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
      hintStyle: const TextStyle(color: AppColors.textMuted),
      labelStyle: const TextStyle(color: AppColors.textSecondary),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.gold),
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

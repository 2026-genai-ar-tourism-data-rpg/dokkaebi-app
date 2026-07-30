// ============================================================
// [v1] 혼불 디자인 공유 토큰 — 팔레트·폰트 (지도/코스 상세 등 재사용)
// pipeline: 모바일 클라이언트 / 디자인 시스템 (혼불 레이더 시안 공용)
// 구현(요약): 얼음빛 시안/청록/단청주홍 팔레트 + Gowun Batang·Space Mono 헬퍼.
//            honbul_home_screen(메인)과 scenario_screen(코스 허브 지도·상세) 공용.
// 구현일: 2026-07-08 | 작성: kys (honbul/kys/v1) · 시안: 도깨비 기억석 standalone
// ============================================================
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ── 혼불 팔레트 ──
const hbBg = Color(0xFF141418);
const hbBg2 = Color(0xFF0D0D10);
const hbIce = Color(0xFF59C4F2); // 얼음빛 시안 — 나·기본 악센트
const hbIce2 = Color(0xFF8FE0FF);
const hbTealD = Color(0xFF2E7E76); // 청록 — 되찾은 기억(완료)
const hbTeal2 = Color(0xFF3AA89B);
const hbTeal3 = Color(0xFF9FE0D6);
const hbRed = Color(0xFFC6493C); // 단청 주홍 — 잠든 혼불(진행/미방문)
const hbRed2 = Color(0xFFD9705F);
const hbRed3 = Color(0xFFF0A498);
const hbCream = Color(0xFFE8E1D4);
const hbCream2 = Color(0xFFC9C3B6);
const hbMuted = Color(0xFF8A8A86);
const hbMuted2 = Color(0xFF7D7D78);

TextStyle hbSerif(double size, Color color, {double spacing = 0, double? height, FontWeight w = FontWeight.w400}) =>
    GoogleFonts.gowunBatang(fontSize: size, color: color, letterSpacing: spacing, height: height, fontWeight: w);

TextStyle hbMono(double size, Color color, {double spacing = 0, FontWeight w = FontWeight.w400}) =>
    GoogleFonts.spaceMono(fontSize: size, color: color, letterSpacing: spacing, fontWeight: w);

// ============================================================
// [v1] AR 프레임 공통 위젯 — 종로의 기억석 UI 시안(1a~1f) 재현용 빌딩블록
// pipeline: 모바일 클라이언트 / 디자인 시스템 (인-퀘스트 AR 화면)
// 구현(요약): ArStage(밤하늘→한옥→먹빛 그라디언트 + 한옥 지붕 실루엣 + 비네트),
//            ArTopHud(← · 장소 · 조각 카운터), DokkaebiNpc(먹 도깨비), ParchmentCard(한지 지령카드).
// 구현일: 2026-07-08 | 작성: kys (ar-frame/kys/v1) · 시안: 종로의 기억석 UI standalone
// ============================================================
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme.dart';

/// AR 무대 — 배경 그라디언트 + 한옥 지붕 실루엣 + 비네트. child는 Stack 위에 얹힘.
class ArStage extends StatelessWidget {
  final List<Widget> children;
  const ArStage({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    return Stack(fit: StackFit.expand, children: [
      // 밤하늘 → 한옥 갈색 → 먹빛
      Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1B2138), Color(0xFF2A2440), Color(0xFF453230), Color(0xFF17120E)],
            stops: [0.0, 0.38, 0.62, 1.0],
          ),
        ),
      ),
      // 한옥 지붕 실루엣
      Align(
        alignment: const Alignment(0, 0.55),
        child: ClipPath(
          clipper: _HanokRoofClipper(),
          child: Container(height: 130, color: const Color(0xFF0C0A08)),
        ),
      ),
      // 하단 먹빛 바닥
      Align(
        alignment: Alignment.bottomCenter,
        child: FractionallySizedBox(
          heightFactor: 0.28,
          widthFactor: 1,
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter, end: Alignment.bottomCenter,
                colors: [Color(0xFF14100C), Color(0xFF0A0806)],
              ),
            ),
          ),
        ),
      ),
      // 비네트(가장자리 어둡게)
      IgnorePointer(
        child: Container(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              radius: 0.95,
              colors: [Colors.transparent, Colors.black.withOpacity(0.55)],
              stops: const [0.6, 1.0],
            ),
          ),
        ),
      ),
      ...children,
    ]);
  }
}

class _HanokRoofClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size s) {
    // clip-path:polygon(0 70%,12% 40%,30% 62%,50% 18%,70% 60%,88% 34%,100% 66%,100% 100%,0 100%)
    final w = s.width, h = s.height;
    return Path()
      ..moveTo(0, h * .70)
      ..lineTo(w * .12, h * .40)
      ..lineTo(w * .30, h * .62)
      ..lineTo(w * .50, h * .18)
      ..lineTo(w * .70, h * .60)
      ..lineTo(w * .88, h * .34)
      ..lineTo(w, h * .66)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
  }

  @override
  bool shouldReclip(_) => false;
}

/// 상단 HUD 알약 (배경 반투명 먹빛 + 테두리).
Widget arPill(String text, {Color border = AppColors.goldDim, Color? textColor}) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
    decoration: BoxDecoration(
      color: const Color(0xFF0D0B09).withOpacity(0.72),
      borderRadius: BorderRadius.circular(999),
      border: Border.all(color: border.withOpacity(0.5)),
    ),
    child: Text(text,
        style: TextStyle(
            color: textColor ?? AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w700)),
  );
}

/// 상단 HUD — 뒤로 / 장소 알약 / 조각 카운터.
class ArTopHud extends StatelessWidget {
  final String place;
  final String counter;
  final VoidCallback onBack;
  const ArTopHud({super.key, required this.place, required this.counter, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 14, left: 14, right: 14,
      child: Row(children: [
        GestureDetector(
          onTap: onBack,
          child: Container(
            width: 38, height: 38, alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFF0D0B09).withOpacity(0.72),
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.goldDim.withOpacity(0.4)),
            ),
            child: const Text('←', style: TextStyle(color: Color(0xFFE8DCC4), fontSize: 17)),
          ),
        ),
        Expanded(child: Center(child: arPill(place))),
        arPill(counter, border: AppColors.tealDeep, textColor: AppColors.teal),
      ]),
    );
  }
}

/// 먹 도깨비 NPC — 검은 blob + 금빛 눈 + 뿔 + Lv 뱃지. 둥실 떠있음.
class DokkaebiNpc extends StatefulWidget {
  final String name;
  final int level;
  final double size;
  final bool showBadge;
  const DokkaebiNpc({super.key, this.name = '먹 도깨비', this.level = 7, this.size = 132, this.showBadge = true});
  @override
  State<DokkaebiNpc> createState() => _DokkaebiNpcState();
}

class _DokkaebiNpcState extends State<DokkaebiNpc> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 3200))..repeat(reverse: true);
  @override
  void dispose() { _c.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, child) => Transform.translate(
          offset: Offset(0, math.sin(_c.value * math.pi) * -8), child: child),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        if (widget.showBadge)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFF0D0B09).withOpacity(0.8),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: AppColors.goldDim.withOpacity(0.5)),
            ),
            child: Text('${widget.name} · Lv.${widget.level}',
                style: const TextStyle(color: AppColors.goldDim, fontSize: 12, fontWeight: FontWeight.w700)),
          ),
        if (widget.showBadge) const SizedBox(height: 10),
        SizedBox(
          width: widget.size, height: widget.size,
          child: Stack(clipBehavior: Clip.none, children: [
            // 뿔
            Positioned(top: -12, left: widget.size * .30, child: _horn(-14)),
            Positioned(top: -8, right: widget.size * .32, child: _horn(12)),
            // 머리 (먹빛 blob)
            Container(
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.all(Radius.elliptical(66, 62)),
                gradient: const RadialGradient(
                  center: Alignment(-0.24, -0.36), radius: 0.9,
                  colors: [Color(0xFF33291F), Color(0xFF17130F), Color(0xFF0A0806)],
                  stops: [0.0, 0.55, 1.0],
                ),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.6), blurRadius: 40, offset: const Offset(0, 18))],
              ),
            ),
            // 금빛 눈
            Positioned(top: widget.size * .35, left: widget.size * .27, child: _eye()),
            Positioned(top: widget.size * .35, right: widget.size * .27, child: _eye()),
          ]),
        ),
      ]),
    );
  }

  Widget _eye() => Container(
        width: 14, height: 16,
        decoration: BoxDecoration(
          color: AppColors.gold, borderRadius: BorderRadius.circular(8),
          boxShadow: [BoxShadow(color: AppColors.gold.withOpacity(0.9), blurRadius: 14)],
        ),
      );

  Widget _horn(double deg) => Transform.rotate(
        angle: deg * math.pi / 180,
        child: CustomPaint(size: const Size(18, 26), painter: _HornPainter()),
      );
}

class _HornPainter extends CustomPainter {
  @override
  void paint(Canvas c, Size s) {
    final p = Paint()..color = const Color(0xFF17130F);
    c.drawPath(
      Path()
        ..moveTo(s.width / 2, 0)
        ..lineTo(0, s.height)
        ..lineTo(s.width, s.height)
        ..close(),
      p,
    );
  }

  @override
  bool shouldRepaint(_) => false;
}

/// 한지 지령/대화 카드 — 크림 그라디언트 + 빨간 뱃지 슬롯. 하단 고정용.
class ParchmentCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  const ParchmentCard({super.key, required this.child, this.padding = const EdgeInsets.all(18)});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter, end: Alignment.bottomCenter,
          colors: [Color(0xFFF4EDDA), Color(0xFFEADFC4)],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFD8C9A4)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.55), blurRadius: 44, offset: const Offset(0, 16))],
      ),
      child: child,
    );
  }
}

/// 한지 카드용 색(어두운 먹/청동/단청).
class Hanji {
  static const ink = Color(0xFF2A2118); // 본문 먹빛
  static const inkSoft = Color(0xFF4A3D2C);
  static const bronze = Color(0xFF8A7448);
  static const badge = Color(0xFFC8452C); // 단청 주홍(지령 뱃지·버튼)
  static const cream = Color(0xFFFDF6E6);
  static const line = Color(0xFFB7A374);
}

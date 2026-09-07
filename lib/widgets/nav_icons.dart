// ============================================================
// [v1] 하단 네비게이션 커스텀 아이콘 — 도깨비 테마 벡터 (기와집·두루마리·책·뿔)
// pipeline: 모바일 클라이언트 / 디자인 시스템 (게임감 개선 — 공통 컴포넌트)
// 구현(요약): CustomPainter로 홈/퀘스트/도감/프로필 4종을 그린다. filled=false는 외곽선만,
//            filled=true는 색으로 채우고 세부선은 배경색(AppColors.surface, 네비바 배경과 동일)으로
//            "펀치아웃"해 입체적인 배지처럼 보이게 한다.
// 구현일: 2026-09-01 | 작성: Claude (game-ui-polish/ljs/v1)
// ============================================================
import 'package:flutter/material.dart';

import '../theme.dart';

enum DokkaebiNavIconType { home, quest, dex, profile }

class DokkaebiNavIcon extends StatelessWidget {
  final DokkaebiNavIconType type;
  final Color color;
  final bool filled;
  final double size;
  const DokkaebiNavIcon(
    this.type, {
    super.key,
    required this.color,
    this.filled = false,
    this.size = 24,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _NavIconPainter(type: type, color: color, filled: filled),
      ),
    );
  }
}

/// 선택 시 아이콘이 살짝 튀어 오르는 팝 애니메이션 (전환마다 1회 재생).
class DokkaebiNavIconPop extends StatelessWidget {
  final Widget child;
  const DokkaebiNavIconPop({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.6, end: 1.0),
      duration: const Duration(milliseconds: 260),
      curve: Curves.elasticOut,
      builder: (context, v, c) => Transform.scale(scale: v, child: c),
      child: child,
    );
  }
}

class _NavIconPainter extends CustomPainter {
  final DokkaebiNavIconType type;
  final Color color;
  final bool filled;
  _NavIconPainter({required this.type, required this.color, required this.filled});

  @override
  void paint(Canvas canvas, Size size) {
    final u = size.width / 24;
    final strokeP = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.7
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final fillP = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    // 채워진 도형 위에 "펀치아웃"할 때 쓰는 배경색 (네비바 배경과 동일해야 파여 보인다).
    final cutP = Paint()
      ..color = AppColors.surface
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;

    switch (type) {
      case DokkaebiNavIconType.home:
        _paintHome(canvas, u, strokeP, fillP, cutP);
      case DokkaebiNavIconType.quest:
        _paintQuest(canvas, u, strokeP, fillP, cutP);
      case DokkaebiNavIconType.dex:
        _paintDex(canvas, u, strokeP, fillP, cutP);
      case DokkaebiNavIconType.profile:
        _paintProfile(canvas, u, strokeP, fillP);
    }
  }

  void _paintHome(Canvas c, double u, Paint strokeP, Paint fillP, Paint cutP) {
    final body = RRect.fromRectAndRadius(
        Rect.fromLTRB(6 * u, 12 * u, 18 * u, 21 * u), Radius.circular(1.5 * u));
    final door = Rect.fromLTRB(10 * u, 15 * u, 14 * u, 21 * u);
    if (filled) {
      final roof = Path()
        ..moveTo(3 * u, 12 * u)
        ..lineTo(12 * u, 4 * u)
        ..lineTo(21 * u, 12 * u)
        ..close();
      c.drawPath(roof, fillP);
      c.drawRRect(body, fillP);
      c.drawRRect(RRect.fromRectAndRadius(door, Radius.circular(1 * u)), cutP);
    } else {
      final roof = Path()
        ..moveTo(3 * u, 12 * u)
        ..lineTo(12 * u, 4 * u)
        ..lineTo(21 * u, 12 * u);
      c.drawPath(roof, strokeP);
      c.drawRRect(body, strokeP);
      c.drawRect(door, strokeP);
    }
  }

  void _paintQuest(Canvas c, double u, Paint strokeP, Paint fillP, Paint cutP) {
    final topRoller = RRect.fromRectAndRadius(
        Rect.fromLTRB(4 * u, 3.5 * u, 20 * u, 6.5 * u), Radius.circular(1.5 * u));
    final bottomRoller = RRect.fromRectAndRadius(
        Rect.fromLTRB(4 * u, 17.5 * u, 20 * u, 20.5 * u), Radius.circular(1.5 * u));
    final paper = Rect.fromLTRB(5 * u, 6.5 * u, 19 * u, 17.5 * u);
    if (filled) {
      c.drawRRect(topRoller, fillP);
      c.drawRRect(bottomRoller, fillP);
      c.drawRect(paper, fillP);
      c.drawLine(Offset(7.5 * u, 10.5 * u), Offset(16.5 * u, 10.5 * u), cutP);
      c.drawLine(Offset(7.5 * u, 13.5 * u), Offset(14 * u, 13.5 * u), cutP);
    } else {
      c.drawRRect(topRoller, strokeP);
      c.drawRRect(bottomRoller, strokeP);
      c.drawRect(paper, strokeP);
      final lineP = Paint()
        ..color = color.withOpacity(0.6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..strokeCap = StrokeCap.round;
      c.drawLine(Offset(7.5 * u, 10.5 * u), Offset(16.5 * u, 10.5 * u), lineP);
      c.drawLine(Offset(7.5 * u, 13.5 * u), Offset(14 * u, 13.5 * u), lineP);
    }
  }

  void _paintDex(Canvas c, double u, Paint strokeP, Paint fillP, Paint cutP) {
    final cover = RRect.fromRectAndRadius(
        Rect.fromLTRB(4 * u, 5 * u, 20 * u, 19 * u), Radius.circular(2 * u));
    final bookmark = Path()
      ..moveTo(14.5 * u, 5 * u)
      ..lineTo(17 * u, 5 * u)
      ..lineTo(17 * u, 9.5 * u)
      ..lineTo(15.75 * u, 8 * u)
      ..lineTo(14.5 * u, 9.5 * u)
      ..close();
    if (filled) {
      c.drawRRect(cover, fillP);
      c.drawLine(Offset(12 * u, 5 * u), Offset(12 * u, 19 * u), cutP);
      c.drawPath(bookmark, cutP);
    } else {
      c.drawRRect(cover, strokeP);
      c.drawLine(Offset(12 * u, 5 * u), Offset(12 * u, 19 * u), strokeP);
      c.drawPath(bookmark, strokeP);
    }
  }

  void _paintProfile(Canvas c, double u, Paint strokeP, Paint fillP) {
    final headCenter = Offset(12 * u, 8.2 * u);
    final headR = 3.3 * u;
    final body = Path()
      ..moveTo(5 * u, 21 * u)
      ..cubicTo(5 * u, 15.3 * u, 8.1 * u, 13 * u, 12 * u, 13 * u)
      ..cubicTo(15.9 * u, 13 * u, 19 * u, 15.3 * u, 19 * u, 21 * u);
    // 뿔(도깨비 포인트) — 항상 얇은 선으로, 양쪽 상태 공통.
    final hornP = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    final leftHorn = Path()
      ..moveTo(9.6 * u, 5.6 * u)
      ..quadraticBezierTo(8.2 * u, 4.4 * u, 8.6 * u, 2.6 * u);
    final rightHorn = Path()
      ..moveTo(14.4 * u, 5.6 * u)
      ..quadraticBezierTo(15.8 * u, 4.4 * u, 15.4 * u, 2.6 * u);
    if (filled) {
      final closedBody = Path.from(body)
        ..lineTo(19 * u, 21 * u)
        ..lineTo(5 * u, 21 * u)
        ..close();
      c.drawPath(closedBody, fillP);
      c.drawCircle(headCenter, headR, fillP);
    } else {
      c.drawPath(body, strokeP);
      c.drawCircle(headCenter, headR, strokeP);
    }
    c.drawPath(leftHorn, hornP);
    c.drawPath(rightHorn, hornP);
  }

  @override
  bool shouldRepaint(covariant _NavIconPainter old) =>
      old.type != type || old.color != color || old.filled != filled;
}

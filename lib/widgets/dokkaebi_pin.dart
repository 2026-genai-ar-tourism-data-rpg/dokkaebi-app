// ============================================================
// [v1] 도깨비 번호 핀 — 코스 지도(scenario_screen)의 "다음/완료" 노드 핀.
// 구현일: 2026-09-18 | 작성: Claude · 시안 승인: jch(뿔 제거 버전, v6)
// ------------------------------------------------------------
// [v2] 단순화 — 실사용(코스 8조각 전체가 한 화면에 뜨는 실지도)에서 금장 장식
// 링·구름 문양이 과했다는 피드백으로 "숫자만" 보이는 홑색 핀으로 정리.
// assets/images/quest_pins/pin_N.png(네이티브 지도 마커, quest_journey_screen)와
// 같은 모양·팔레트를 쓴다 — 이쪽은 순수 Flutter CustomPainter라 네이티브 SDK의
// PNG 픽셀 포맷 제약(quest_journey_screen.dart _placeChapterMarkers 주석 참고)이
// 없어 매끈한 베지어 윤곽을 직접 그릴 수 있다.
// 구현일: 2026-09-18 | 작성: Claude
// ============================================================
import 'package:flutter/material.dart';

import '../theme.dart';

enum DokkaebiPinTone { next, done }

class DokkaebiPin extends StatelessWidget {
  final DokkaebiPinTone tone;

  /// 배지에 보일 번호. done 톤은 무시하고 체크 표시를 그린다.
  final int? number;
  final double size;

  const DokkaebiPin({super.key, required this.tone, this.number, this.size = 34});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size * 80 / 64), // assets/images/quest_pins와 같은 64:80 비율
      painter: _PinPainter(tone: tone, number: number),
    );
  }
}

class _PinPainter extends CustomPainter {
  final DokkaebiPinTone tone;
  final int? number;
  _PinPainter({required this.tone, required this.number});

  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / 64, sy = size.height / 80;
    final isDone = tone == DokkaebiPinTone.done;
    final fill = isDone ? AppColors.tealDeep : AppColors.vermilion;
    final stroke = isDone ? const Color(0xFF0D3F34) : const Color(0xFF7A0D0D);
    final ink = isDone ? const Color(0xFFEAFFF9) : const Color(0xFFFDF3DF);

    Offset p(double x, double y) => Offset(x * sx, y * sy);

    final body = Path()
      ..moveTo(p(32, 66).dx, p(32, 66).dy)
      ..cubicTo(p(20, 54).dx, p(20, 54).dy, p(8, 46).dx, p(8, 46).dy, p(8, 36).dx, p(8, 36).dy)
      ..cubicTo(p(8, 18).dx, p(8, 18).dy, p(18, 6).dx, p(18, 6).dy, p(32, 6).dx, p(32, 6).dy)
      ..cubicTo(p(46, 6).dx, p(46, 6).dy, p(56, 18).dx, p(56, 18).dy, p(56, 36).dx, p(56, 36).dy)
      ..cubicTo(p(56, 46).dx, p(56, 46).dy, p(44, 54).dx, p(44, 54).dy, p(32, 66).dx, p(32, 66).dy)
      ..close();

    canvas.drawOval(Rect.fromCenter(center: p(32, 70), width: 20 * sx, height: 5.6 * sy),
        Paint()..color = Colors.black.withValues(alpha: 0.28));
    canvas.drawPath(body, Paint()..color = fill);
    canvas.drawPath(
        body,
        Paint()
          ..color = stroke
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.2 * sx);

    if (isDone) {
      final check = Path()
        ..moveTo(p(23, 35).dx, p(23, 35).dy)
        ..lineTo(p(29, 41).dx, p(29, 41).dy)
        ..lineTo(p(41, 27).dx, p(41, 27).dy);
      canvas.drawPath(
          check,
          Paint()
            ..color = ink
            ..style = PaintingStyle.stroke
            ..strokeWidth = 4.4 * sx
            ..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.round);
      return;
    }

    final n = number;
    if (n == null) return;
    final tp = TextPainter(
      text: TextSpan(
          text: '$n', style: TextStyle(color: ink, fontSize: 19 * sx, fontWeight: FontWeight.w800)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, p(32, 34) - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant _PinPainter old) => old.tone != tone || old.number != number;
}

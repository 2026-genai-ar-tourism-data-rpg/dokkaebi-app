// ============================================================
// [v1] 리워드 등장 연출 — 스케일 팝인 + 반짝임(스파클) 버스트
// pipeline: 모바일 클라이언트 / 디자인 시스템 (게임감 개선 — Phase 2)
// 구현(요약): 기억석/글씨조각 획득 카드·배너가 화면에 처음 나타날 때 한 번(650ms) 재생.
//            반복 애니메이션이 아니라 mount 시 1회 forward 후 끝나는 원샷이라 리스트에
//            여러 개 있어도 계속 도는 티커가 남지 않는다.
// 구현일: 2026-09-01 | 작성: Claude (game-ui-polish/ljs/v1)
// ============================================================
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme.dart';

/// child를 감싸서, 트리에 새로 삽입될 때(예: 보상 카드가 조건부로 처음 나타날 때)
/// 탄력있게 커지며 등장 + 주변에 반짝이는 점이 퍼졌다 사라지는 연출을 더한다.
class RewardPopIn extends StatefulWidget {
  final Widget child;
  const RewardPopIn({super.key, required this.child});

  @override
  State<RewardPopIn> createState() => _RewardPopInState();
}

class _RewardPopInState extends State<RewardPopIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 650))
      ..forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) {
        final t = _c.value;
        final scale = Curves.elasticOut.transform(t.clamp(0.0, 1.0));
        return Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(painter: _SparklePainter(progress: t)),
              ),
            ),
            Transform.scale(scale: scale, child: child),
          ],
        );
      },
      child: widget.child,
    );
  }
}

class _SparklePainter extends CustomPainter {
  final double progress; // 0..1
  _SparklePainter({required this.progress});

  static const _colors = [
    AppColors.gold,
    AppColors.teal,
    AppColors.textPrimary
  ];
  static const _count = 8;
  static const _fadeStart = 0.35;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0.02 || progress >= 1) return;
    final center = size.center(Offset.zero);
    final opacity = progress < _fadeStart
        ? 1.0
        : (1 - (progress - _fadeStart) / (1 - _fadeStart)).clamp(0.0, 1.0);
    final travel = Curves.easeOut.transform(progress.clamp(0.0, 1.0));
    for (var i = 0; i < _count; i++) {
      final angle = (2 * math.pi / _count) * i;
      final dist = size.shortestSide * 0.55 * travel;
      final p = center + Offset(math.cos(angle), math.sin(angle)) * dist;
      final paint = Paint()
        ..color = _colors[i % _colors.length].withOpacity(opacity * 0.9);
      canvas.drawCircle(p, 2.5 * (1 - travel * 0.4), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SparklePainter old) => old.progress != progress;
}

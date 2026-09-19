// ============================================================
// [v1] 기억석 복원 연출 — 모은 조각이 모여 완성된 기억석이 되는 전체 화면.
// pipeline: 모바일 클라이언트 / 디자인 시스템 (피날레 보상)
// 구현(요약): 피날레 선택 뒤·엔딩 화면 앞. 조각 N개가 둥글게 떠올랐다가 가운데로 모이고,
//            복원 빛이 번쩍인 뒤 완성된 기억석과 이름이 나타난다. 영상 대신 정지 그림 3장
//            (조각·완성체·복원 빛) + 앱 애니메이션 — 아이폰은 투명 영상을 못 틀고, 이쪽이 선명·가볍다.
//            재생 중 탭하면 끝 장면으로 건너뛰고, '계속'을 누르면 onContinue.
// 구현일: 2026-09-18
// ============================================================
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme.dart';

/// 기억석 조각·완성체·복원 빛 그림(보상 화면에서도 쓴다).
const String kMemoryFragmentAsset = 'assets/game/memory_stone/memory_stone_fragment.webp';
const String kMemoryStoneAsset = 'assets/game/memory_stone/memory_stone_original.webp';
const String kMemoryRestoreFxAsset = 'assets/game/vfx/memory_stone_restore_vfx.webp';

/// 연출 전체 길이.
const Duration kRestoreDuration = Duration(milliseconds: 3200);

const double _ringRadius = 120; // 조각이 떠 있는 원의 반지름
const double _fragmentSize = 72;
const double _stoneSize = 230;
const double _fxSize = 300;

/// 구간(0~1) — 조각 등장 → 모이기 → 번쩍 → 완성체 → 이름·버튼.
const _appear = Interval(0.0, 0.15, curve: Curves.easeOut);
const _gather = Interval(0.15, 0.55, curve: Curves.easeInCubic);
const _flash = Interval(0.52, 0.74);
const _stone = Interval(0.62, 0.90, curve: Curves.easeOutBack);
const _caption = Interval(0.85, 1.0, curve: Curves.easeOut);

class MemoryStoneRestore extends StatefulWidget {
  /// 모은 조각 수(코스의 조각 수).
  final int fragmentCount;

  /// 완성된 기억석 이름(예: '경주시 기억석').
  final String stoneName;
  final VoidCallback onContinue;

  const MemoryStoneRestore(
      {super.key, required this.fragmentCount, required this.stoneName, required this.onContinue});

  @override
  State<MemoryStoneRestore> createState() => _MemoryStoneRestoreState();
}

class _MemoryStoneRestoreState extends State<MemoryStoneRestore> with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: kRestoreDuration)..forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  /// 재생 중 탭 → 끝 장면으로.
  void _skip() {
    if (_c.isAnimating) _c.value = 1;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _skip,
      child: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.2),
            radius: 1.0,
            colors: [Color(0xFF3A2E1A), Color(0xFF17120C), Color(0xFF0A0806)],
            stops: [0, .55, 1],
          ),
        ),
        // 부모가 느슨한 제약을 줘도 전체 화면을 채운다 — 안 그러면 Stack이 가운데 그림 크기로
        // 줄어 아래쪽 이름·계속 버튼이 화면 밖으로 밀려난다.
        child: SizedBox.expand(
          child: AnimatedBuilder(
            animation: _c,
            builder: (_, __) => _frame(_c.value),
          ),
        ),
      ),
    );
  }

  Widget _frame(double v) {
    final appear = _appear.transform(v);
    final gather = _gather.transform(v);
    final flash = _flash.transform(v);
    final stone = _stone.transform(v);
    final caption = _caption.transform(v);
    final n = math.max(1, widget.fragmentCount);

    return Stack(alignment: Alignment.center, children: [
      // 조각 — 원 위에서 가운데로 모이며 작아지고 돈다. 번쩍일 때 사라진다.
      for (var i = 0; i < n; i++)
        Transform.translate(
          offset: Offset.fromDirection(2 * math.pi * i / n - math.pi / 2, _ringRadius * (1 - gather)),
          child: Opacity(
            opacity: (appear * (1 - flash)).clamp(0.0, 1.0),
            child: Transform.rotate(
              angle: gather * math.pi,
              child: Image.asset(kMemoryFragmentAsset, width: _fragmentSize * (1 - 0.5 * gather)),
            ),
          ),
        ),
      // 복원 빛 — 번쩍 커졌다 사라진다.
      if (flash > 0 && flash < 1)
        Opacity(
          opacity: math.sin(math.pi * flash),
          child: Image.asset(kMemoryRestoreFxAsset, width: _fxSize * (0.5 + flash)),
        ),
      // 완성된 기억석.
      if (stone > 0)
        Opacity(
          opacity: stone.clamp(0.0, 1.0),
          child: Image.asset(kMemoryStoneAsset, width: _stoneSize * stone),
        ),
      // 이름·계속 — 끝나야 누를 수 있다.
      Positioned(
        left: 24,
        right: 24,
        bottom: 56,
        child: Opacity(
          opacity: caption,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('복 원',
                style: TextStyle(fontSize: 12, letterSpacing: 4, color: Color(0xFFA87F2C), fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            Text('「${widget.stoneName}」',
                textAlign: TextAlign.center, style: dokkaebiTitle(size: 24, color: const Color(0xFFFDF6E6))),
            const SizedBox(height: 8),
            Text('흩어진 조각이 하나로 모였느니라.',
                textAlign: TextAlign.center, style: dokkaebiTitle(size: 13, color: const Color(0xFFB3A892))),
            const SizedBox(height: 20),
            IgnorePointer(
              ignoring: v < 1,
              child: FilledButton(
                onPressed: widget.onContinue,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFE8C268),
                  foregroundColor: const Color(0xFF3A2A08),
                  minimumSize: const Size(160, 48),
                ),
                child: const Text('계속', style: TextStyle(fontWeight: FontWeight.w900)),
              ),
            ),
          ]),
        ),
      ),
    ]);
  }
}

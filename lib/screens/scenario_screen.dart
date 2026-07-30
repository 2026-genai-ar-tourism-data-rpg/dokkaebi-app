// ============================================================
// [v2] 화면: 코스 허브 — 종로의 기억석 UI 시안 기반 (5존 구조)
// pipeline: 모바일 클라이언트 / 화면 (코스 = 기억석 체인)
// 구현(요약): ①복원 히어로(조각 슬롯) ②다음 목표 CTA ③동선 지도(식음 구분)
//            ④노드 리스트(사람 언어) — 전통 팔레트(금·단청·도깨비불 민트·한지).
// 구현일: 2026-07-08 | 작성: kys (course-hub/kys/v2) · 시안: 종로의 기억석 UI
// ------------------------------------------------------------
// [v1] 노드 카드 리스트 + 연계 인벤토리 — 2026-06-18 kys (rpg-dialogue/kys/v1)
// ============================================================
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/scenario.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets/honbul_style.dart';
import '../widgets/ui.dart';
import 'quest_play_screen.dart';

/// 시나리오 루트 지도 — 혼불 밤 지도(안개길 + 동선). 노드 좌표를 박스에 정규화.
/// 완료=청록 혼불, 다음=주홍 혼불(맥동 링 + 이름), 미방문=이슬빛 빈 원, 식음=흐린 점.
class _RouteMap extends StatefulWidget {
  final List<QuestNode> nodes;
  final Set<String> done;
  final String? nextId;
  const _RouteMap({required this.nodes, required this.done, this.nextId});
  @override
  State<_RouteMap> createState() => _RouteMapState();
}

class _RouteMapState extends State<_RouteMap> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 2200))..repeat();
  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pts = widget.nodes.where((n) => n.mapX != null && n.mapY != null).toList();
    if (pts.length < 2) return const SizedBox.shrink();
    final xs = pts.map((n) => n.mapX!), ys = pts.map((n) => n.mapY!);
    final minX = xs.reduce(math.min), maxX = xs.reduce(math.max);
    final minY = ys.reduce(math.min), maxY = ys.reduce(math.max);
    double nx(double x) => (maxX - minX).abs() < 1e-9 ? 0.5 : (x - minX) / (maxX - minX);
    double ny(double y) => (maxY - minY).abs() < 1e-9 ? 0.5 : (y - minY) / (maxY - minY);

    var stoneNo = 0;
    final stoneNoOf = <String, int>{};
    for (final n in pts) {
      if (n.isStone) stoneNoOf[n.nodeId] = ++stoneNo;
    }

    return AspectRatio(
      aspectRatio: 1.3,
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          gradient: const RadialGradient(center: Alignment(0, -0.35), radius: 1.1, colors: [Color(0xFF1E1E24), hbBg], stops: [0, 0.72]),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: hbTealD.withOpacity(0.28)),
        ),
        child: LayoutBuilder(builder: (context, box) {
          const pad = 30.0;
          Offset posOf(QuestNode n) => Offset(
                pad + nx(n.mapX!) * (box.maxWidth - pad * 2),
                pad + (1 - ny(n.mapY!)) * (box.maxHeight - pad * 2),
              );
          final line = pts.map(posOf).toList();
          final doneFlags = pts.map((n) => widget.done.contains(n.nodeId)).toList();
          return Stack(children: [
            // 안개 등고선 + 혼불 동선
            Positioned.fill(child: CustomPaint(painter: _HonbulRoutePainter(line, doneFlags))),
            // 핀
            for (var i = 0; i < pts.length; i++)
              Positioned(
                left: line[i].dx - 40,
                top: line[i].dy - 40,
                child: SizedBox(width: 80, height: 80, child: Center(
                  child: _pin(pts[i], doneFlags[i], stoneNoOf[pts[i].nodeId], pts[i].nodeId == widget.nextId),
                )),
              ),
          ]);
        }),
      ),
    );
  }

  Widget _pin(QuestNode n, bool isDone, int? no, bool isNext) {
    // 상태별 색/코어
    final Color glow;
    final Gradient? coreGrad;
    Widget? overlay;
    double core;
    if (n.isFood) {
      glow = hbMuted;
      coreGrad = null;
      core = 7;
      overlay = Text(n.kind == 'cafe' ? '☕' : '🍜', style: const TextStyle(fontSize: 11));
    } else if (isDone) {
      glow = hbTealD;
      coreGrad = const RadialGradient(center: Alignment(-0.3, -0.4), colors: [hbTeal3, hbTealD]);
      core = 13;
      overlay = const Icon(Icons.check, color: Color(0xFF0D0D10), size: 11);
    } else if (isNext) {
      glow = hbRed;
      coreGrad = const RadialGradient(center: Alignment(-0.3, -0.4), colors: [hbRed3, hbRed]);
      core = 14;
    } else {
      glow = hbIce; // 미방문 = 이슬빛 빈 원
      coreGrad = null;
      core = 12;
    }
    final label = n.name ?? '';
    final labelColor = n.isFood ? hbMuted : (isDone ? hbTeal3 : (isNext ? hbRed3 : hbCream.withOpacity(0.55)));

    Widget dot;
    if (n.isFood) {
      dot = _glowCircle(core, glow, coreGrad, overlay);
    } else if (!isDone && !isNext) {
      // 빈 원(미방문)
      dot = Container(width: core, height: core, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: hbCream.withOpacity(0.3))));
    } else {
      dot = _glowCircle(core, glow, coreGrad, overlay);
    }

    return Column(mainAxisSize: MainAxisSize.min, children: [
      SizedBox(width: 46, height: 46, child: Stack(alignment: Alignment.center, clipBehavior: Clip.none, children: [
        // 헤일로
        if (n.isFood || isDone || isNext)
          Container(width: core * 3.6, height: core * 3.6, decoration: BoxDecoration(shape: BoxShape.circle, gradient: RadialGradient(colors: [glow.withOpacity(isDone ? 0.35 : 0.5), glow.withOpacity(0)], stops: const [0, 0.68]))),
        // 다음 노드 맥동 링
        if (isNext)
          AnimatedBuilder(animation: _pulse, builder: (_, __) {
            final p = _pulse.value;
            return Container(width: core * 2.3 * (1 + p * 0.4), height: core * 2.3 * (1 + p * 0.4), decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: hbRed.withOpacity(0.6 * (1 - p)), width: 1.5)));
          }),
        dot,
      ])),
      const SizedBox(height: 2),
      SizedBox(width: 66, child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center,
          style: TextStyle(color: labelColor, fontSize: 9, shadows: const [Shadow(color: Colors.black, blurRadius: 5)]))),
    ]);
  }

  Widget _glowCircle(double size, Color glow, Gradient? grad, Widget? overlay) => Container(
        width: size, height: size, alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: grad,
          color: grad == null ? glow.withOpacity(0.35) : null,
          boxShadow: [BoxShadow(color: glow.withOpacity(0.8), blurRadius: 12)],
        ),
        child: overlay,
      );
}

/// 안개 등고선 + 완료(청록)/예정(이슬빛) 동선.
class _HonbulRoutePainter extends CustomPainter {
  final List<Offset> pts;
  final List<bool> done;
  _HonbulRoutePainter(this.pts, this.done);

  @override
  void paint(Canvas c, Size s) {
    // 안개 등고선 두 줄
    final mist = Paint()..color = hbTealD.withOpacity(0.12)..style = PaintingStyle.stroke..strokeWidth = 1;
    for (final f in [0.32, 0.62]) {
      final path = Path()..moveTo(-10, s.height * f);
      path.cubicTo(s.width * 0.25, s.height * (f - 0.05), s.width * 0.5, s.height * (f + 0.06), s.width * 0.72, s.height * (f - 0.02));
      path.cubicTo(s.width * 0.86, s.height * (f - 0.05), s.width, s.height * (f + 0.02), s.width + 10, s.height * f);
      c.drawPath(path, mist);
    }
    if (pts.length < 2) return;
    // 동선: 완료 구간=청록 굵게, 예정=이슬빛 점선느낌 얇게
    for (var i = 0; i < pts.length - 1; i++) {
      final segDone = done[i] && done[i + 1];
      final under = Paint()
        ..color = (segDone ? hbTealD : hbTealD.withOpacity(0.5)).withOpacity(segDone ? 0.5 : 0.18)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..strokeCap = StrokeCap.round;
      c.drawLine(pts[i], pts[i + 1], under);
      final over = Paint()
        ..color = (segDone ? hbTeal3 : hbIce).withOpacity(segDone ? 0.6 : 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = segDone ? 2 : 1.4
        ..strokeCap = StrokeCap.round;
      c.drawLine(pts[i], pts[i + 1], over);
    }
  }

  @override
  bool shouldRepaint(covariant _HonbulRoutePainter old) => old.pts != pts || old.done != done;
}

class ScenarioScreen extends StatefulWidget {
  final Scenario scenario;
  const ScenarioScreen({super.key, required this.scenario});
  @override
  State<ScenarioScreen> createState() => _ScenarioScreenState();
}

class _ScenarioScreenState extends State<ScenarioScreen> {
  Future<void> _play(QuestNode n, List<String> inventory) async {
    final granted = await Navigator.push<List<String>>(
      context,
      MaterialPageRoute(
        builder: (_) => QuestPlayScreen(node: n, inventory: inventory),
      ),
    );
    if (granted != null) {
      await ScenarioStore.I.completeNode(widget.scenario.scenarioId, n.nodeId, granted);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scn = widget.scenario;
    return Scaffold(
      appBar: AppBar(title: Text(scn.title)),
      body: ListenableBuilder(
        listenable: ScenarioStore.I,
        builder: (context, _) {
          final done = ScenarioStore.I.doneOf(scn.scenarioId).toSet();
          final inventory = ScenarioStore.I.inventoryOf(scn.scenarioId);
          final stones = scn.stoneNodes;
          final stoneDone = stones.where((n) => done.contains(n.nodeId)).length;
          final stoneTotal = scn.stoneTotal;
          final allDone = stoneTotal > 0 && stoneDone >= stoneTotal;
          // 다음 목표 = 시퀀스상 첫 미완료 노드
          QuestNode? next;
          for (final n in scn.nodeSequence) {
            if (!done.contains(n.nodeId)) {
              next = n;
              break;
            }
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            children: [
              // ── B. 복원 히어로 ──────────────────────────
              _RestoreHero(region: scn.region, stones: stones, done: done,
                  total: stoneTotal, doneCount: stoneDone),
              const SizedBox(height: 14),

              // ── C. 다음 목표 CTA ────────────────────────
              if (!allDone && next != null)
                _NextTarget(node: next, onGo: () => _play(next!, inventory))
              else if (allDone)
                _RestoredBanner(),
              const SizedBox(height: 14),

              // ── 연계 인벤토리(모은 단서) ─────────────────
              if (inventory.isNotEmpty) ...[
                _InventoryStrip(items: inventory),
                const SizedBox(height: 14),
              ],

              // ── D. 동선 지도 ───────────────────────────
              _RouteMap(nodes: scn.nodeSequence, done: done, nextId: next?.nodeId),
              const SizedBox(height: 16),

              // ── E. 노드 리스트 (혼불 코스 상세) ─────────
              Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                  Text('COURSE ROUTE', style: hbMono(10, hbTeal2, spacing: 3)),
                  const SizedBox(height: 2),
                  Text('코스 상세', style: hbSerif(20, hbCream, spacing: 0.5)),
                ]),
                const Spacer(),
                Text('$stoneDone / $stoneTotal', style: hbMono(13, hbIce)),
              ]),
              const SizedBox(height: 10),
              ...scn.nodeSequence.map((n) => _NodeRow(
                    node: n,
                    isDone: done.contains(n.nodeId),
                    isNext: n.nodeId == next?.nodeId,
                    onTap: () => _play(n, inventory),
                  )),
            ],
          );
        },
      ),
    );
  }
}

/// B. 복원 히어로 — 기억석 조각 슬롯(채워짐/빈칸) + 진행도.
class _RestoreHero extends StatelessWidget {
  final String region;
  final List<QuestNode> stones;
  final Set<String> done;
  final int total;
  final int doneCount;
  const _RestoreHero({
    required this.region, required this.stones, required this.done,
    required this.total, required this.doneCount,
  });

  @override
  Widget build(BuildContext context) {
    return GlowCard(
      glow: AppColors.gold,
      padding: const EdgeInsets.all(18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Text('💎', style: TextStyle(fontSize: 18)),
          const SizedBox(width: 8),
          Text('$region의 기억석 복원',
              style: dokkaebiTitle(size: 17, color: AppColors.textPrimary)),
          const Spacer(),
          Text('$doneCount/$total',
              style: dokkaebiTitle(size: 17, color: AppColors.gold)),
        ]),
        const SizedBox(height: 14),
        // 조각 슬롯
        Wrap(spacing: 10, runSpacing: 10, children: [
          for (var i = 0; i < total; i++)
            _StoneSlot(filled: i < stones.length && done.contains(stones[i].nodeId)),
        ]),
        const SizedBox(height: 14),
        ProgressBar(total == 0 ? 0 : doneCount / total, color: AppColors.gold),
      ]),
    );
  }
}

class _StoneSlot extends StatelessWidget {
  final bool filled;
  const _StoneSlot({required this.filled});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34, height: 34,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: filled ? AppColors.gold.withOpacity(0.20) : Colors.transparent,
        shape: BoxShape.circle,
        border: Border.all(
            color: filled ? AppColors.gold : AppColors.border, width: 1.5),
        boxShadow: filled
            ? [BoxShadow(color: AppColors.gold.withOpacity(0.45), blurRadius: 10)]
            : null,
      ),
      child: Text('✦',
          style: TextStyle(
              fontSize: 15,
              color: filled ? AppColors.gold : AppColors.textMuted.withOpacity(0.5))),
    );
  }
}

/// C. 다음 목표 CTA — 시퀀스상 다음 노드로 안내 + 탐험 시작.
class _NextTarget extends StatelessWidget {
  final QuestNode node;
  final VoidCallback onGo;
  const _NextTarget({required this.node, required this.onGo});

  @override
  Widget build(BuildContext context) {
    final isFood = node.isFood;
    final label = isFood
        ? (node.kind == 'cafe' ? '☕ 쉬어가기' : '🍜 쉬어가기')
        : (node.isFinale ? '🏁 마지막 조각' : '💎 다음 조각');
    final dist = node.distM != null ? '${node.distM!.toStringAsFixed(0)}m' : '';
    return GlowCard(
      glow: AppColors.teal,
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(label,
              style: const TextStyle(color: AppColors.teal, fontSize: 12, fontWeight: FontWeight.w700)),
          const Spacer(),
          if (dist.isNotEmpty)
            Text(dist, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
        ]),
        const SizedBox(height: 6),
        Text(node.name ?? node.nodeId,
            style: dokkaebiTitle(size: 20, color: AppColors.textPrimary)),
        const SizedBox(height: 14),
        FilledButton.icon(
          onPressed: onGo,
          icon: Icon(isFood ? Icons.local_cafe : Icons.explore, size: 18),
          label: Text(isFood ? '들르기' : (node.isFinale ? '기억 복원하기' : '탐험 시작')),
        ),
      ]),
    );
  }
}

/// 전 조각 복원 완료 배너.
class _RestoredBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GlowCard(
      glow: AppColors.gold,
      child: Row(children: [
        const Icon(Icons.auto_awesome, color: AppColors.gold),
        const SizedBox(width: 10),
        Expanded(
          child: Text('기억석 복원 완료 — 종로의 기억이 되살아났다.',
              style: dokkaebiTitle(size: 15, color: AppColors.gold)),
        ),
      ]),
    );
  }
}

/// 연계 인벤토리 — 지금까지 모은 단서·조각.
class _InventoryStrip extends StatelessWidget {
  final List<String> items;
  const _InventoryStrip({required this.items});
  @override
  Widget build(BuildContext context) {
    return GlowCard(
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('🎒 모은 것',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
        const SizedBox(height: 8),
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (final i in items)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.surfaceHi,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.border),
              ),
              child: Text(i,
                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
            ),
        ]),
      ]),
    );
  }
}

/// E. 노드 카드 — 혼불 톤. 완료=청록 / 다음=주홍 발광 / 미방문=이슬빛 / 식음=흐린 점.
class _NodeRow extends StatelessWidget {
  final QuestNode node;
  final bool isDone;
  final bool isNext;
  final VoidCallback onTap;
  const _NodeRow({
    required this.node, required this.isDone, required this.isNext, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isFood = node.isFood;
    // 상태색
    final Color accent = isFood
        ? hbMuted
        : isDone
            ? hbTealD
            : isNext
                ? hbRed
                : hbIce;
    final subtitle = isFood
        ? '${_dist(node)} · 쉬어가기${node.priceBandLabel != null ? ' · ${node.priceBandLabel}' : ''}'
        : '${_dist(node)} · ${node.isFinale ? '피날레 조각' : '${node.stoneNo ?? ''}번째 조각'}${isDone ? ' · 완료' : ''}';

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
            color: isNext ? hbRed.withOpacity(0.06) : Colors.white.withOpacity(0.04),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isNext ? hbRed.withOpacity(0.4) : Colors.white.withOpacity(0.06)),
            boxShadow: isNext ? [BoxShadow(color: hbRed.withOpacity(0.18), blurRadius: 18, spreadRadius: -4)] : null,
          ),
          child: Row(children: [
            _leading(isFood, accent),
            const SizedBox(width: 13),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Flexible(child: Text(node.name ?? node.nodeId,
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: hbSerif(15.5, hbCream, spacing: 0.3))),
                  if (node.isFinale && !isFood) ...[
                    const SizedBox(width: 6),
                    Text('· 피날레', style: hbMono(9, hbIce, spacing: 1)),
                  ],
                ]),
                const SizedBox(height: 3),
                Text(subtitle, style: TextStyle(color: hbMuted, fontSize: 12)),
              ]),
            ),
            Icon(Icons.chevron_right, color: isNext ? hbRed3 : hbMuted.withOpacity(0.7), size: 20),
          ]),
        ),
      ),
    );
  }

  // 혼불 발광 점 리딩(완료=✓, 다음=주홍, 미방문=이슬빛 빈 원, 식음=아이콘).
  Widget _leading(bool isFood, Color accent) {
    Widget inner;
    if (isFood) {
      inner = Text(node.kind == 'cafe' ? '☕' : '🍜', style: const TextStyle(fontSize: 14));
    } else if (isDone) {
      inner = const Icon(Icons.check, color: Color(0xFF0D0D10), size: 15);
    } else if (isNext) {
      inner = Text('${node.stoneNo ?? node.order + 1}', style: hbMono(13, const Color(0xFF0D0D10), w: FontWeight.w700));
    } else {
      inner = Text('${node.stoneNo ?? node.order + 1}', style: hbMono(13, hbIce, w: FontWeight.w700));
    }
    final filled = isDone || isNext;
    return SizedBox(width: 40, height: 40, child: Stack(alignment: Alignment.center, children: [
      if (filled || isFood)
        Container(width: 40, height: 40, decoration: BoxDecoration(shape: BoxShape.circle, gradient: RadialGradient(colors: [accent.withOpacity(0.4), accent.withOpacity(0)], stops: const [0, 0.68]))),
      Container(
        width: 30, height: 30, alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: filled ? RadialGradient(center: const Alignment(-0.3, -0.4), colors: [_lighten(accent), accent]) : null,
          color: filled ? null : Colors.transparent,
          border: filled ? null : Border.all(color: accent.withOpacity(0.6), width: 1.5),
          boxShadow: filled ? [BoxShadow(color: accent.withOpacity(0.7), blurRadius: 12)] : null,
        ),
        child: inner,
      ),
    ]));
  }

  Color _lighten(Color c) {
    if (c == hbTealD) return hbTeal3;
    if (c == hbRed) return hbRed3;
    return hbIce2;
  }

  String _dist(QuestNode n) => n.distM != null ? '${n.distM!.toStringAsFixed(0)}m' : '-';
}

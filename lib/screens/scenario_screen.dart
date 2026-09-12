// ============================================================
// [v2] 화면: 코스 허브 — 종로의 기억석 UI 시안 기반 (5존 구조)
// pipeline: 모바일 클라이언트 / 화면 (코스 = 기억석 체인)
// 구현(요약): ①복원 히어로(조각 슬롯) ②다음 목표 CTA ③동선 지도(식음 구분)
//            ④노드 리스트(사람 언어) — 전통 팔레트(금·단청·도깨비불 민트·한지).
// 구현일: 2026-07-08 | 작성: kys (course-hub/kys/v2) · 시안: 종로의 기억석 UI
// ------------------------------------------------------------
// [v1] 노드 카드 리스트 + 연계 인벤토리 — 2026-06-18 kys (rpg-dialogue/kys/v1)
// ------------------------------------------------------------
// [v3] 동선 지도 배경을 실지도(KakaoMap)로 — 핀·동선 연출은 그대로 얹는다.
// 구현(요약): 노드 좌표를 상자에 정규화해 그린 가짜 지도라, 실제로 어디를 도는 코스인지
//            알 수 없었다. 배경에 KakaoMap을 깔고 카메라를 전체 노드가 담기게 맞춘 뒤
//            각 노드의 화면 좌표(toScreenPoint)를 받아 기존 핀·동선을 그 위에 그린다.
//            카카오맵에는 선을 그리는 API가 없어(마커·카메라뿐) 동선은 계속 Flutter가 그린다.
//            이 패키지에는 카메라 이동 콜백이 없어 사용자가 지도를 움직이면 오버레이가
//            어긋나므로 제스처를 막고(IgnorePointer) 카메라는 코드로만 움직인다.
//            좌표 변환이 두 번 다 실패하면 실지도를 접고 기존 정규화 배치로 돌아간다.
// 구현일: 2026-09-12 | 작성: ljs (explore-radius-first/ljs/v1)
// ------------------------------------------------------------
// [v4] 실기기 확인 결과 v3가 항상 실패해 지도에 핀이 하나도 안 찍혔다. 원인은
//      kakao_maps_flutter 0.2.2의 iOS 네이티브 구현 자체 — toScreenPoint는 항상
//      {dx:null, dy:null}만 반환하는 스텁이고, CameraUpdate.fromBounds는 네이티브
//      디코더가 position+zoomLevel만 읽어 항상 E004로 실패한다(재시도로 못 고치는
//      구조적 버그). → 둘 다 버리고 카메라 중심·줌을 표준 Web Mercator로 직접
//      계산해([../utils/web_mercator.dart]) moveCamera(position+zoomLevel)로 맞추고,
//      화면 좌표도 그 중심·줌으로 매 build마다 직접 계산한다.
// 구현일: 2026-09-12 | 작성: ljs (explore-radius-first/ljs/v1)
// ============================================================
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:kakao_maps_flutter/kakao_maps_flutter.dart';

import '../game/player_state.dart';
import '../models/scenario.dart';
import '../game/run_session.dart';
import '../store.dart';
import '../theme.dart';
import '../utils/web_mercator.dart';
import '../widgets/honbul_style.dart';
import '../widgets/ui.dart';
import 'quest_journey_screen.dart';
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
  // ⚠️ initState에서 생성 — `late final = AnimationController(...)`는 지연 생성이라
  //    build가 이 컨트롤러를 안 쓰는 분기로 지나가면 dispose()가 최초 접근이 되어
  //    비활성 element에서 TickerMode를 조회하다 터진다.
  late final AnimationController _pulse;

  /// 실지도 배경 — 카메라를 코드로 맞춘다.
  KakaoMapController? _controller;

  /// 마지막으로 맞춘 카메라 중심·줌 — 화면 좌표는 매 build마다 이 값으로 직접 계산한다
  /// (toScreenPoint는 iOS 플러그인 미구현이라 항상 null이라 쓸 수 없다).
  LatLng? _mapCenter;
  int? _mapZoom;

  /// build()에서 매번 갱신 — didUpdateWidget에서 재계산할 때 필요하다.
  Size? _viewportSize;

  /// moveCamera 자체가 실패 — 실지도를 접고 기존 정규화 배치로 돌아간다.
  bool _projectionFailed = false;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 2200))..repeat();
  }

  @override
  void didUpdateWidget(covariant _RouteMap old) {
    super.didUpdateWidget(old);
    // 갈림길을 고르면 밟는 노드가 바뀐다 — 카메라를 다시 맞춰야 동선이 맞는다.
    final controller = _controller;
    final size = _viewportSize;
    if (old.nodes.length != widget.nodes.length && controller != null && size != null) {
      final pts = _placeable;
      if (pts.length >= 2) _fitCamera(controller, pts, size);
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  /// 좌표가 있는 노드만 — 동선·핀의 대상.
  List<QuestNode> get _placeable =>
      widget.nodes.where((n) => n.mapX != null && n.mapY != null).toList();

  /// 전체 노드가 담기게 중심·줌을 직접 계산해 카메라를 맞춘다.
  /// CameraUpdate.fromBounds는 iOS 플러그인에서 항상 E004로 실패해 쓸 수 없다
  /// (네이티브 디코더가 position+zoomLevel만 읽는데 fromBounds는 그 필드를 안 채운다).
  /// onMapCreated 콜백에서 await 없이 호출되므로, 여기서 잡지 않은 예외는 조용히
  /// 사라진다 — 그래서 try/catch로 감싼다.
  Future<void> _fitCamera(KakaoMapController controller, List<QuestNode> pts, Size viewportSize) async {
    _controller = controller;
    final fit = fitBounds(
      points: pts.map((n) => LatLng(latitude: n.mapY!, longitude: n.mapX!)).toList(),
      viewportSize: viewportSize,
      paddingPx: 60,
    );
    try {
      await controller.moveCamera(
        cameraUpdate: CameraUpdate(position: fit.center, zoomLevel: fit.zoom),
      );
    } catch (e, st) {
      debugPrint('[map-debug] scenario moveCamera 예외: $e\n$st');
      if (mounted) setState(() => _projectionFailed = true);
      return;
    }
    if (mounted) {
      setState(() {
        _mapCenter = fit.center;
        _mapZoom = fit.zoom;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final pts = _placeable;
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
          final viewportSize = Size(box.maxWidth, box.maxHeight);
          _viewportSize = viewportSize;
          const pad = 30.0;
          Offset posOf(QuestNode n) => Offset(
                pad + nx(n.mapX!) * (box.maxWidth - pad * 2),
                pad + (1 - ny(n.mapY!)) * (box.maxHeight - pad * 2),
              );
          final center = _mapCenter;
          final zoom = _mapZoom;
          // 카메라를 맞췄으면 그 중심·줌으로 직접 계산한 화면 좌표로, 아니면 기존
          // 정규화 좌표로 그린다.
          final useMap = !_projectionFailed && center != null && zoom != null;
          final line = useMap
              ? pts
                  .map((n) => projectToScreen(
                        point: LatLng(latitude: n.mapY!, longitude: n.mapX!),
                        center: center,
                        zoom: zoom,
                        viewportSize: viewportSize,
                      ))
                  .toList()
              : pts.map(posOf).toList();
          final doneFlags = pts.map((n) => widget.done.contains(n.nodeId)).toList();
          return Stack(children: [
            if (!_projectionFailed)
              // 제스처 차단 — 카메라를 코드로만 움직여야 핀·동선이 지도와 어긋나지 않는다
              // (이 패키지에는 카메라 이동 콜백이 없어 사용자 팬·줌을 따라갈 수 없다).
              Positioned.fill(
                child: IgnorePointer(
                  child: KakaoMap(
                    onMapCreated: (c) => _fitCamera(c, pts, viewportSize),
                    initialPosition:
                        LatLng(latitude: pts.first.mapY!, longitude: pts.first.mapX!),
                    initialLevel: 14,
                  ),
                ),
              ),
            // 좌표를 받기 전에는 그리지 않는다 — 먼저 그리면 지도와 어긋난 자리에 찍힌다.
            if (useMap || _projectionFailed) ...[
              // 혼불 동선(실지도 위에서는 안개 등고선을 빼고 길만 남긴다)
              Positioned.fill(
                  child: CustomPaint(
                      painter: _HonbulRoutePainter(line, doneFlags, mist: !useMap))),
              // 핀
              for (var i = 0; i < pts.length; i++)
                Positioned(
                  left: line[i].dx - 40,
                  top: line[i].dy - 40,
                  child: SizedBox(width: 80, height: 80, child: Center(
                    child: _pin(pts[i], doneFlags[i], stoneNoOf[pts[i].nodeId], pts[i].nodeId == widget.nextId),
                  )),
                ),
            ],
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

  /// 안개 등고선을 그릴지 — 실지도 위에서는 실제 지형을 가리기만 해서 끈다.
  final bool mist;
  _HonbulRoutePainter(this.pts, this.done, {this.mist = true});

  @override
  void paint(Canvas c, Size s) {
    // 안개 등고선 두 줄
    if (mist) {
      final fog = Paint()..color = hbTealD.withOpacity(0.12)..style = PaintingStyle.stroke..strokeWidth = 1;
      for (final f in [0.32, 0.62]) {
        final path = Path()..moveTo(-10, s.height * f);
        path.cubicTo(s.width * 0.25, s.height * (f - 0.05), s.width * 0.5, s.height * (f + 0.06), s.width * 0.72, s.height * (f - 0.02));
        path.cubicTo(s.width * 0.86, s.height * (f - 0.05), s.width, s.height * (f + 0.02), s.width + 10, s.height * f);
        c.drawPath(path, fog);
      }
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
  bool shouldRepaint(covariant _HonbulRoutePainter old) =>
      old.pts != pts || old.done != done || old.mist != mist;
}

class ScenarioScreen extends StatefulWidget {
  final Scenario scenario;
  const ScenarioScreen({super.key, required this.scenario});
  @override
  State<ScenarioScreen> createState() => _ScenarioScreenState();
}

class _ScenarioScreenState extends State<ScenarioScreen> {
  @override
  void initState() {
    super.initState();
    _openRun();
  }

  /// 이 코스의 서버 플레이(run)를 연다 — 진행도·GPS 판정의 주인이 서버가 되는 시점.
  ///
  /// 실패해도 화면을 막지 않는다: 서버 없이도 코스를 훑어볼 수는 있어야 한다.
  /// 대신 그 상태에서는 조각이 서버에 기록되지 않으므로 상단 배너로 알린다.
  Future<void> _openRun() async {
    await RunSession.I.start(widget.scenario.scenarioId);
    if (mounted) setState(() {});
  }

  /// 서버 세션 없이 도는 중임을 알리는 배너 — 조용히 로컬만 쌓이면 나중에 어긋난다.
  Widget? _offlineBanner() {
    if (RunSession.I.isActive) return null;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.orange.withOpacity(0.5)),
      ),
      child: Row(children: [
        const Icon(Icons.cloud_off, size: 16, color: Colors.orangeAccent),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            RunSession.I.error ?? '서버에 연결되지 않아 진행이 저장되지 않습니다.',
            style: const TextStyle(color: Colors.orangeAccent, fontSize: 12, height: 1.4),
          ),
        ),
        TextButton(onPressed: _openRun, child: const Text('재시도')),
      ]),
    );
  }

  /// 노드 진입 — 게이팅(3절)을 먼저 통과시킨다. **미충족은 차단이 아니라 안내.**
  Future<void> _play(QuestNode n, List<String> inventory) async {
    final scn = widget.scenario;
    final state = ScenarioStore.I.stateOf(scn.scenarioId);

    // 갈림길은 대화 안에서 고른다(도깨비가 두 길을 권하고, 고른 갈래가 곧 경로).
    // 여기서 미리 물으면 대화가 그 사실을 모른 채 무관한 선택지를 지어낸다 — ai#24 개편.
    // 대화가 실패해 선택을 못 받은 경우에만 아래에서 시트로 폴백한다.

    if (n.requires.isNotEmpty) {
      final check = scn.checkEntry(n, state);
      if (check.needsGuidance) {
        await _showGuidance(check); // D1/D2 — 안내 모드
        return;
      }
      if (check.softMissing) {
        // D4 — 진행은 되지만 연계 대사를 못 받는다
        _snack('${check.missing.map((m) => m.label).join('·')} 없이 가면 도깨비가 알아보지 못하느니.');
      }
    }

    final granted = await Navigator.push<List<String>>(
      context,
      MaterialPageRoute(
        builder: (_) => QuestPlayScreen(
          node: n,
          inventory: inventory,
          scenarioId: scn.scenarioId,
          regionId: scn.region,
          playerState: {
            'progress': ScenarioStore.I.stoneProgressOf(scn),
            'required': scn.stoneNodes.length,
          },
        ),
      ),
    );
    if (granted == null) return;
    // 플레이 화면이 준 것 + 노드 스키마 grants를 함께 적용(규칙 5조: 단서는 조각과 동봉)
    await ScenarioStore.I.completeNode(
      scn.scenarioId,
      n.nodeId,
      [...granted, ...n.effectiveGrants.map((r) => r.toStorageString())],
    );

    // 폴백: 갈림길인데 대화에서 길을 못 골랐다면(서버 오류 등) 시트로 받는다.
    // 선택이 없으면 다음 노드가 정해지지 않아 코스가 본선으로만 흐른다.
    if (n.branch != null &&
        !ScenarioStore.I.choicesOf(scn.scenarioId).containsKey(n.nodeId) &&
        mounted) {
      await _askBranch(n);
    }
  }

  /// 갈림길 선택 — 고른 갈래를 저장하면 이후 동선(playedPath)이 그 길로 바뀐다.
  Future<void> _askBranch(QuestNode bp) async {
    final b = bp.branch!;
    final picked = await showModalBottomSheet<BranchOption>(
      context: context,
      backgroundColor: hbBg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('갈림길', style: hbSerif(20, hbCream, spacing: 0.5)),
            const SizedBox(height: 8),
            Text(b.prompt, style: hbSerif(14.5, hbCream2, height: 1.6)),
            const SizedBox(height: 16),
            for (final o in b.options)
              InkWell(
                onTap: () => Navigator.pop(ctx, o),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 9),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                  decoration: BoxDecoration(
                    color: o.choiceId == 'main' ? hbTealD.withOpacity(0.14) : hbRed.withOpacity(0.14),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: o.choiceId == 'main' ? hbTealD : hbRed),
                  ),
                  child: Text(o.label, style: hbSerif(14, hbCream, height: 1.5)),
                ),
              ),
          ]),
        ),
      ),
    );
    if (picked == null || !mounted) return;
    await ScenarioStore.I.chooseBranch(widget.scenario.scenarioId, bp.nodeId, picked.choiceId);
  }

  /// 안내 모드(D1/D2) — 획득처를 짚어주고 진행판으로 돌려보낸다. 거부가 아니다.
  Future<void> _showGuidance(RequireCheck c) => showModalBottomSheet<void>(
        context: context,
        backgroundColor: hbBg,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
        builder: (ctx) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(c.isPartial ? '아직 이르니라' : '길을 짚어 주마', style: hbSerif(20, hbCream, spacing: 0.5)),
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                decoration: BoxDecoration(
                  color: hbRed.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: hbRed.withOpacity(0.5)),
                ),
                child: Text(c.guidance(), style: hbSerif(14.5, hbCream, height: 1.6)),
              ),
              const SizedBox(height: 14),
              if (c.held.isNotEmpty) ...[
                Text('이미 지닌 것', style: hbMono(10, hbTeal2, spacing: 2)),
                const SizedBox(height: 6),
                Wrap(spacing: 6, runSpacing: 6, children: [
                  for (final h in c.held) _gateChip(h.label, got: true),
                ]),
                const SizedBox(height: 12),
              ],
              Text('남은 것 — 미완료 거점', style: hbMono(10, hbRed2, spacing: 2)),
              const SizedBox(height: 6),
              Wrap(spacing: 6, runSpacing: 6, children: [
                for (final m in c.missing) _gateChip(m.label, got: false),
              ]),
              if (c.highlightPlaces.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text('들러야 할 곳 · ${c.highlightPlaces.join(' · ')}',
                    style: hbMono(11, hbMuted, spacing: 0.5)),
              ],
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text('진행판으로', style: hbSerif(14.5, hbBg2, w: FontWeight.w700)),
                ),
              ),
            ]),
          ),
        ),
      );

  static Widget _gateChip(String label, {required bool got}) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: got ? hbTealD.withOpacity(0.16) : Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: got ? hbTealD : hbMuted.withOpacity(0.6)),
        ),
        child: Text('${got ? '✓' : '✕'} $label',
            style: hbSerif(12.5, got ? hbTeal3 : hbMuted)),
      );

  /// 피날레까지 남은 조각 수. 피날레 requires가 있으면 **그 미충족 개수**를 쓴다 —
  /// stoneTotal은 피날레 노드 자신도 세므로 "남은 조각"으로 쓰면 1개 많아진다.
  static int _finaleMissing(
      Scenario scn, PlayerState state, List<QuestNode> stones, Set<String> done) {
    final f = scn.finaleNode;
    if (f != null && f.requires.isNotEmpty) {
      return scn.checkEntry(f, state).missing.length;
    }
    // requires 미제공 → 피날레 제외한 조각 노드 중 미완료 수
    return stones.where((n) => !n.isFinale && !done.contains(n.nodeId)).length;
  }

  void _snack(String msg) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(msg, style: hbSerif(13.5, hbCream)),
        backgroundColor: hbBg2,
        behavior: SnackBarBehavior.floating,
      ));

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
          final state = ScenarioStore.I.stateOf(scn.scenarioId);
          // **실제 밟는 경로** — 갈림길을 골랐으면 그 갈래만 보인다(선형이면 그대로).
          final path = ScenarioStore.I.pathOf(scn);
          final stones = path.where((n) => n.isStone).toList();
          final stoneDone = stones.where((n) => done.contains(n.nodeId)).length;
          final stoneTotal = scn.stoneTotal;
          final allDone = stoneTotal > 0 && stoneDone >= stoneTotal;
          final finaleOpen = scn.finaleUnlocked(state);
          // 다음 목표 = 경로상 첫 미완료 노드
          QuestNode? next;
          for (final n in path) {
            if (!done.contains(n.nodeId)) {
              next = n;
              break;
            }
          }
          // 대사 연계에 넘길 것 — 조각·단서 이름만(플래그·쿠폰은 제외)
          final carried = state.carriedNames;
          final offline = _offlineBanner();
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            children: [
              // 서버 세션이 없으면 먼저 알린다 — 조각이 저장되지 않는 상태다.
              if (offline != null) ...[offline, const SizedBox(height: 10)],

              // ── B. 복원 히어로 ──────────────────────────
              _RestoreHero(region: scn.region, stones: stones, done: done,
                  total: stoneTotal, doneCount: stoneDone),
              const SizedBox(height: 14),

              // ── C. 다음 목표 CTA ────────────────────────
              if (!allDone && next != null)
                _NextTarget(
                  node: next,
                  // '탐험 시작'(첫 조각 진입, 식음 아님)은 "새 퀘스트 시작하기"와
                  // 같은 화면(QuestJourneyScreen)으로 보낸다 — 두 진입점을 하나로 동기화.
                  // 피날레도 QuestJourneyScreen이 strategy 기준으로 처리한다(장소 단위 화면
                  // QuestPlayScreen은 strategy를 몰라 항상 "AR로 기억석 찾기"로 뭉뚱그려졌었다).
                  onGo: !next.isFood
                      ? () => Navigator.push(context,
                          MaterialPageRoute(builder: (_) => QuestJourneyScreen(scenario: scn)))
                      : () => _play(next!, carried),
                )
              else if (allDone)
                _RestoredBanner(),
              const SizedBox(height: 14),

              // ── 상태 그래프 — 단서함·성향·쿠폰 ───────────
              if (inventory.isNotEmpty) ...[
                _StateStrip(state: state),
                const SizedBox(height: 14),
              ],

              // ── 피날레 게이팅 안내(하드 requires) ────────
              if (!finaleOpen && stoneDone > 0) ...[
                _FinaleLock(missing: _finaleMissing(scn, state, stones, done)),
                const SizedBox(height: 14),
              ],

              // ── D. 동선 지도 ───────────────────────────
              _RouteMap(nodes: path, done: done, nextId: next?.nodeId),
              const SizedBox(height: 16),

              // ── E. 노드 리스트 (혼불 코스 상세) ─────────
              Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                  Text('COURSE ROUTE', style: hbMono(10, hbTeal2, spacing: 3)),
                  const SizedBox(height: 2),
                  Text('코스 상세', style: hbSerif(20, hbCream, spacing: 0.5)),
                ]),
                const Spacer(),
                if (scn.isBranching)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Text('갈림길', style: hbMono(10, hbRed2, spacing: 1.5)),
                  ),
                Text('$stoneDone / $stoneTotal', style: hbMono(13, hbIce)),
              ]),
              const SizedBox(height: 10),
              ...path.map((n) => _NodeRow(
                    node: n,
                    isDone: done.contains(n.nodeId),
                    isNext: n.nodeId == next?.nodeId,
                    locked: n.requires.isNotEmpty && !scn.checkEntry(n, state).ok && n.isHardGated,
                    // "다음 목표" 카드와 같은 규칙 — 지금 밟을 차례인 지점(next)만 코스 진행 화면으로
                    // 보낸다. 이미 끝났거나 아직 먼 지점은 그대로 장소 단위 화면(QuestPlayScreen)에서 훑어보게 둔다
                    // (QuestJourneyScreen은 특정 지점을 지정해 열 수 없고 항상 현재 진행
                    // 지점부터 시작한다 — 다른 지점을 열면 엉뚱한 지점이 뜬다).
                    onTap: (!n.isFood && n.nodeId == next?.nodeId)
                        ? () => Navigator.push(context,
                            MaterialPageRoute(builder: (_) => QuestJourneyScreen(scenario: scn)))
                        : () => _play(n, carried),
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

/// 상태 그래프 스트립 — 단서함 / 성향(플래그) / 쿠폰·유물을 구분해 보여준다.
/// 구 _InventoryStrip(문자열 나열)을 대체 — 어휘별로 갈라 대사 연계·엔딩 분기 근거를 드러낸다.
class _StateStrip extends StatelessWidget {
  final PlayerState state;
  const _StateStrip({required this.state});

  @override
  Widget build(BuildContext context) {
    final coupon = state.couponTotal;
    return GlowCard(
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text('모은 것', style: hbSerif(14, hbCream, spacing: 0.3)),
          const Spacer(),
          if (state.affinity != 0)
            Text('친밀도 +${state.affinity}', style: hbMono(10, hbTeal2, spacing: 1)),
          if (coupon > 0) ...[
            const SizedBox(width: 8),
            Text('쿠폰 $coupon원', style: hbMono(10, hbIce, spacing: 1)),
          ],
        ]),
        if (state.clues.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text('단서함', style: hbMono(9, hbRed2, spacing: 1.5)),
          const SizedBox(height: 6),
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final c in state.clues) _chip(c, hbRed, hbRed3),
          ]),
        ],
        if (state.fragments.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text('기억석 조각', style: hbMono(9, hbTeal2, spacing: 1.5)),
          const SizedBox(height: 6),
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final f in state.fragments) _chip(f, hbTealD, hbTeal3),
          ]),
        ],
        if (state.flags.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text('성향 — 엔딩에 반영된다', style: hbMono(9, hbIce, spacing: 1.5)),
          const SizedBox(height: 6),
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final f in state.flags) _chip(f, hbIce, hbIce2),
          ]),
        ],
        if (state.relics.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text('유물 — 다음 지역까지 지속', style: hbMono(9, hbMuted, spacing: 1.5)),
          const SizedBox(height: 6),
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final r in state.relics) _chip(r, hbMuted, hbCream2),
          ]),
        ],
      ]),
    );
  }

  Widget _chip(String label, Color border, Color fg) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: border.withOpacity(0.12),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: border.withOpacity(0.6)),
        ),
        child: Text(label, style: hbSerif(12.5, fg)),
      );
}

/// 피날레 잠금 안내 — 조각이 덜 모였을 때. 차단 문구가 아니라 남은 개수 안내.
class _FinaleLock extends StatelessWidget {
  /// 피날레 requires 중 아직 못 채운 개수.
  final int missing;
  const _FinaleLock({required this.missing});

  @override
  Widget build(BuildContext context) {
    final left = missing;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: hbRed.withOpacity(0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: hbRed.withOpacity(0.35)),
      ),
      child: Row(children: [
        Icon(Icons.lock_outline, size: 16, color: hbRed2),
        const SizedBox(width: 10),
        Expanded(
          child: Text('피날레는 조각이 다 모여야 열리느니 — $left조각 남았다.',
              style: hbSerif(13.5, hbCream2, height: 1.5)),
        ),
      ]),
    );
  }
}

/// E. 노드 카드 — 혼불 톤. 완료=청록 / 다음=주홍 발광 / 미방문=이슬빛 / 식음=흐린 점.
class _NodeRow extends StatelessWidget {
  final QuestNode node;
  final bool isDone;
  final bool isNext;

  /// 하드 requires 미충족 — 잠긴 표시만 한다. **탭은 여전히 막지 않는다**(안내 모드로 이어짐).
  final bool locked;
  final VoidCallback onTap;
  const _NodeRow({
    required this.node, required this.isDone, required this.isNext, required this.onTap,
    this.locked = false,
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
        : locked
            ? '${_dist(node)} · 아직 조각이 모이지 않았느니'
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
                  if (node.branch != null) ...[
                    const SizedBox(width: 6),
                    Text('· 갈림길', style: hbMono(9, hbRed2, spacing: 1)),
                  ],
                  if (node.outOfRadius) ...[
                    const SizedBox(width: 6),
                    Text('· 반경 밖', style: hbMono(9, hbRed2, spacing: 1)),
                  ],
                  if (locked) ...[
                    const SizedBox(width: 6),
                    Icon(Icons.lock_outline, size: 12, color: hbMuted),
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

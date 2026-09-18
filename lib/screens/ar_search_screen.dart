// ============================================================
// [v1] 화면: AR 탐색 (시안 4) — QUEST_ACTIVE, 기억석 조각 수집
// pipeline: 모바일 클라이언트 / 화면 (대화 힌트 → AR로 찾기)
// 구현(요약): 카메라 위 AR 마커(기억석·도깨비) + 힌트/스캔/NPC 토글 + 조각 진행.
//            스캔 → 마커 등장 → 기억석 탭 → 수집(pop true).
// ------------------------------------------------------------
// [v2] 실제 AR 연결 — ar_flutter_plugin은 안 씀(pub.dev 확인: 3년 방치,
//      정적분석·최신의존성 검사 실패, 원 기반 arkit_flutter_plugin은 pub.dev에서 삭제됨).
//      대신 ARKit을 네이티브(Swift, ios/Runner/DokkaebiArView.swift)로 얇게 직접 감싸
//      PlatformView로 붙였다. 실외 탐험 게임이라 평면(바닥) 인식은 요구하지 않고
//      포켓몬고식으로 세션 시작 시점 카메라 기준 고정 오프셋에 마커를 띄운다.
//      ⚠️ ARKit은 시뮬레이터 미지원 — dokkaebi/ar_support 채널로 실기기 여부를 먼저
//      확인하고, 아니면(시뮬레이터·구형기기·Android) 기존 고정 2D 마커로 폴백한다.
//      네이티브 코드라 이 폴백 분기 밖은 실기기에서 직접 확인 필요(시뮬레이터로 못 봄).
// 구현일: 2026-08-31 | 작성: 정찬희
// ------------------------------------------------------------
// [v3] 실시간 미션 연출 — 거리·조준으로 굴러가는 네 미션(계획서 2026-08-19 "A층").
// 구현(요약): v2는 마커가 고정 오프셋에 떠 있고 탭하면 끝이라, "다가가면 자국이 늘고
//            겨누면 드러난다"가 없었다. 네이티브가 10Hz로 보내는 거리·조준각을
//            ArMissionController에 흘려 넣고, 그 판정으로 마커 표시를 바꾼다.
//            missionType이 없으면 v2의 기존 2마커 동작 그대로다(하위호환).
// 구현일: 2026-09-16 | 작성: kys (ar-realtime/kys/v1)
// ------------------------------------------------------------
// [v4] 촬영 미션 — 셔터 → 라이브 스냅샷 → 서버 비전 검증 → 도깨비 반응.
// 구현(요약): PHOTO_FIND·PATH_TRACE는 "찾았다"(거리·조준 또는 참조 이미지 인식)로 끝나지
//            않고 셔터가 열린다. 스냅샷은 NativeArView(라이브 프레임)에서만 받아 갤러리
//            사진을 못 쓰게 하고, 검증 결과의 npc_line을 그대로 띄운다 — 검증이 곧 연출.
//            verified=false면 화면에 남아 다시 찍게 하고, null(판정 불가)은 신뢰로 통과시킨다
//            (현장에서 모델 장애로 셔터가 막히면 안 된다). 참조 사진 URL은 ARKit 인식용으로
//            네이티브에도 넘긴다(arReferenceImages).
// 구현일: 2026-09-16 | 작성: kys (photo-verify/kys/v1)
// ------------------------------------------------------------
// [v5] HUNT 엽전 줍기 — 주울 때마다 엽전 획득 효과를 화면 가운데 잠깐 띄우고,
//      마지막 엽전은 효과가 보이도록 잠시 뒤에 닫는다.
// 구현일: 2026-09-18 | 작성: ljs (npc-character-set/ljs/v1)
// ============================================================
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../models/scenario.dart';

import '../game/ar_mission_controller.dart';
import '../session.dart';
import '../theme.dart';
import '../widgets/native_ar_view.dart';

class ArSearchScreen extends StatefulWidget {
  final String placeName;
  final String order; // 도깨비 지령
  final List<String> hints; // 단계 힌트(방탈출)
  final int collected; // 진행: 이미 모은 조각 수
  final int total;

  /// 원격 체험 모드 — 그 장소에서 멀리 떨어져 있을 때.
  ///
  /// 카메라 대신 가상 배경을 쓴다. 집에서 켜면 어차피 그 장소의 사물이 없어
  /// 카메라를 띄워도 의미가 없고, 방바닥 위에 조각이 떠 있는 그림만 남는다.
  /// 조각은 여기서도 찾을 수 있지만 실제 방문 인증이 아니므로 서버 기록은 하지 않는다
  /// (호출부가 판단 — 이 화면은 연출만 바꾼다).
  final bool remote;

  /// 서버 미션 타입(HUNT·RESTORE_AR·PHOTO_FIND·FIND…). 주면 그 연출로 돈다.
  /// null이면 기존 2마커(조각·도깨비) 동작 — 호출부를 한꺼번에 못 고쳐도 되게.
  final String? missionType;

  /// 미션 목표 개수(AI 미션 JSON의 parts·target_count). 없으면 타입별 기본값.
  final int? targetCount;

  /// 촬영 미션용 — 서버 검증 요청에 실린다. 없으면 검증 없이(행위 완료) 진행.
  final String? nodeId;
  final List<String> photoTargets;
  final List<PhotoRef> photoRefs;

  /// ARKit Augmented Images 참조 사진(TourAPI). 인식되면 "AR이 타깃을 봤다".
  final List<String> arReferenceImages;

  const ArSearchScreen(
      {super.key, this.placeName = '', this.order = '', this.hints = const [], this.collected = 0, this.total = 5,
      this.remote = false, this.missionType, this.targetCount,
      this.nodeId, this.photoTargets = const [], this.photoRefs = const [], this.arReferenceImages = const []});
  @override
  State<ArSearchScreen> createState() => _ArSearchScreenState();
}

class _ArSearchScreenState extends State<ArSearchScreen> with SingleTickerProviderStateMixin {
  String _mode = 'scan'; // hint | scan | npc
  bool _scanned = false;
  int _hintShown = 1; // 방탈출: 처음 1개만, "다음 힌트"로 단계 노출
  bool? _arSupported; // null=확인 중, true=실제 ARKit, false=2D 폴백(시뮬레이터 등)
  bool _arError = false;

  static const _fragmentMarker = ArMarkerDef(
    id: 'fragment', label: '기억석 조각', color: AppColors.teal,
    forward: 1.8, right: -0.4, down: 0.15,
  );
  static const _dokkaebiMarker = ArMarkerDef(
    id: 'dokkaebi', label: '도깨비', color: AppColors.purple,
    forward: 2.1, right: 0.5, down: 0.05,
  );
  // ⚠️ initState에서 생성한다. `late final _ac = AnimationController(...)` 형태로 두면
  //    지연 생성이라, build가 이 컨트롤러를 안 쓰는 분기(_mode='scan' 등)로만 지나가면
  //    dispose()의 _ac.dispose()가 '최초 접근'이 되어 dispose 도중에 컨트롤러를 만든다.
  //    그 시점엔 element가 비활성이라 TickerMode 조회가 터진다
  //    ("Looking up a deactivated widget's ancestor is unsafe").
  late final AnimationController _ac;

  /// 미션 연출 상태기계. missionType이 없으면 null(기존 동작).
  ArMissionController? _mission;
  ArViewController? _arController;

  /// 촬영 미션: 찾기 단계가 끝나 셔터가 열린 상태.
  bool _photoReady = false;
  bool _verifying = false;
  /// 검증 결과 도깨비 대사 — HUD 문구를 잠시 덮는다.
  String? _verdictLine;

  /// HUNT: 주운 엽전 수 — 바뀔 때마다 획득 효과를 새로 띄운다(효과 위젯의 키).
  int _coinPicks = 0;

  bool get _isPhotoMission => _mission?.type == ArMissionType.photo;

  // ── 촬영 미션 전용 디지털 줌 ──
  // 펜스 등으로 실제 사물에 다가갈 수 없는 경우를 위한 확대. HUNT·RESTORE_AR·FIND는
  // 카메라 프레임을 보지 않고 거리·조준만으로 판정하므로(ar_mission_controller.dart 참고)
  // 확대해도 판정에 영향이 없다 — 그래서 사진 미션에만 켠다.
  static const double _zoomMin = 1.0;
  static const double _zoomMax = 3.0;
  double _zoom = _zoomMin;
  double _zoomBase = _zoomMin;

  /// 이 미션이 쓰는 마커 — 기존 동작이면 조각·도깨비 2개.
  late final List<ArMarkerDef> _markers;

  // ── admin 전용 AR 시뮬레이션 ──
  // 실외·실기기 없이도 "카메라는 켜진 채로 거리만 좁혀지는" 상태를 테스트하기 위함.
  // 네이티브(ARKit) 텔레메트리 대신 이 값들로 onTelemetry를 직접 채운다(gps_simulator.dart와
  // 같은 발상 — Session.isAdmin일 때만). 마커별 시작 거리에서 _adminWalked만큼 뺀 값을 쏜다,
  // 실제로 앞으로 걸으면 정면의 마커들과의 거리가 고르게 줄어드는 것과 같다.
  Timer? _adminArTimer;
  double _adminWalked = 0;
  Map<String, double> _adminOrigDist = const {};

  void _startAdminArSim() {
    _adminOrigDist = {
      for (final m in _markers)
        m.id: math.sqrt(m.forward * m.forward + m.right * m.right + m.down * m.down),
    };
    _adminArTimer = Timer.periodic(const Duration(milliseconds: 200), (_) => _pushAdminTelemetry());
  }

  void _pushAdminTelemetry() {
    final readings = <String, ArMarkerReading>{
      for (final m in _markers)
        m.id: ArMarkerReading(
            distance: math.max(0, (_adminOrigDist[m.id] ?? 0) - _adminWalked), aimError: 0),
    };
    _mission?.onTelemetry(readings);
  }

  void _adminWalk(double deltaM) {
    setState(() => _adminWalked = math.max(0, _adminWalked + deltaM));
    _pushAdminTelemetry();
  }

  Widget _adminArPanel() {
    Widget btn(String label, VoidCallback onTap) => GestureDetector(
          onTap: onTap,
          child: Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.75),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.teal.withValues(alpha: 0.55)),
            ),
            child: Text(label,
                style: const TextStyle(fontSize: 15, color: AppColors.teal, fontWeight: FontWeight.w900)),
          ),
        );
    return Container(
      padding: const EdgeInsets.all(8),
      decoration:
          BoxDecoration(color: Colors.black.withValues(alpha: 0.4), borderRadius: BorderRadius.circular(12)),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Text('admin 이동', style: TextStyle(fontSize: 9, color: AppColors.teal, fontWeight: FontWeight.w900)),
        const SizedBox(height: 4),
        Text('${_adminWalked.toStringAsFixed(1)}m',
            style: const TextStyle(fontSize: 10, color: Colors.white70)),
        const SizedBox(height: 4),
        btn('▲', () => _adminWalk(1.0)),
        const SizedBox(height: 4),
        btn('⟲', () {
          setState(() => _adminWalked = 0);
          _pushAdminTelemetry();
        }),
        const SizedBox(height: 4),
        btn('▼', () => _adminWalk(-1.0)),
      ]),
    );
  }

  @override
  void initState() {
    super.initState();
    _ac = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))
      ..repeat(reverse: true);

    final raw = widget.missionType;
    if (raw == null || raw.isEmpty) {
      _markers = const [_fragmentMarker, _dokkaebiMarker];
    } else {
      final type = arMissionTypeOf(raw);
      var built = buildArMarkers(
        type: type,
        primary: AppColors.teal,
        accent: AppColors.purple,
        count: widget.targetCount,
      );
      // 촬영 미션은 마커 이름표를 실제 타깃(예: '흥화문')으로 — '문양'은 장소를 모른다.
      if (type == ArMissionType.photo && widget.photoTargets.isNotEmpty) {
        built = [
          for (final m in built)
            ArMarkerDef(id: m.id, label: widget.photoTargets.first, color: m.color, forward: m.forward,
                right: m.right, down: m.down, kind: m.kind, state: m.state),
        ];
      }
      _markers = built;
      _mission = ArMissionController(
        type: type,
        markers: _markers,
        onCollected: type == ArMissionType.hunt
            ? (_) {
                if (mounted) setState(() => _coinPicks++);
              }
            : null,
        onComplete: () async {
          if (!mounted) return;
          if (type == ArMissionType.photo) {
            // 찾았다 → 셔터를 연다. 조각은 촬영·검증이 끝나야 준다.
            setState(() => _photoReady = true);
          } else {
            // 마지막 엽전의 획득 효과가 보이도록 잠깐 기다린다.
            if (type == ArMissionType.hunt) await Future<void>.delayed(_coinFxDuration);
            if (!mounted) return;
            // 목표를 다 찾으면 조각 획득으로 화면을 닫는다 — 호출부가 서버 collect를 한다.
            Navigator.pop(context, true);
          }
        },
      )..addListener(() {
          if (mounted) setState(() {});
        });
      // remote(원격 체험)는 애초에 카메라를 켜지 않으니 admin 시뮬레이션도 의미가 없다 —
      // 켜 두면 화면이 안 보이는 채로 몇 초 뒤 onComplete가 조용히 화면을 닫아 버린다.
      if (Session.isAdmin && !widget.remote) _startAdminArSim();
    }
    if (widget.remote) {
      // 원격 체험은 카메라를 아예 켜지 않는다 — 권한 팝업도 띄우지 않는다.
      _arSupported = false;
    } else {
      isArSupported().then((ok) {
        if (mounted) setState(() => _arSupported = ok);
      });
    }
  }

  void _onNativeMarkerTapped(String id) {
    final m = _mission;
    if (m != null) {
      m.onTapped(id);
      return;
    }
    if (id == 'fragment') {
      Navigator.pop(context, true);
    } else if (id == 'dokkaebi') {
      setState(() => _mode = 'npc');
    }
  }

  /// 셔터: 라이브 스냅샷 → 서버 검증 → 도깨비 대사 → 통과면 조각 획득으로 닫기.
  Future<void> _shoot() async {
    if (_verifying) return;
    final ctl = _arController;
    setState(() { _verifying = true; _verdictLine = '도깨비가 사진을 살피는 중…'; });

    final b64 = await ctl?.snapshot();
    if (b64 == null || b64.isEmpty) {
      // 스냅샷을 못 얻으면 검증할 대상이 없다 — 막지 않고 행위 완료로 넘긴다.
      if (mounted) Navigator.pop(context, true);
      return;
    }
    final target = widget.photoTargets.isNotEmpty ? widget.photoTargets.first : widget.placeName;
    PhotoVerdict verdict;
    try {
      verdict = await ApiClient().verifyPhoto(
        nodeId: widget.nodeId ?? '',
        nodeName: widget.placeName,
        target: target,
        imageB64: b64,
        refImages: [for (final r in widget.photoRefs) if (r.refImage != null) r.refImage!],
        aliases: [widget.placeName],
      );
    } catch (_) {
      // 서버·네트워크 실패 = 판정 불가. 현장에서 셔터가 막히면 안 된다 → 신뢰로 통과.
      verdict = const PhotoVerdict(
        verified: null, mode: 'unverified', confidence: 0, textSeen: '',
        npcLine: '허허, 내 눈이 잠시 흐려졌구나. 네가 담아 온 것을 믿어 보겠느니라.',
      );
    }
    if (!mounted) return;
    setState(() { _verifying = false; _verdictLine = verdict.npcLine; });
    if (verdict.passes) {
      await Future<void>.delayed(const Duration(milliseconds: 1800));
      if (mounted) Navigator.pop(context, true);
    }
    // verified=false: 화면에 남는다. 대사가 "아닌 듯하구나"를 말하고 셔터는 다시 열려 있다.
  }

  /// 사진 미션에서만 두 손가락 확대·축소를 받는다 — 펜스 등으로 다가갈 수 없는
  /// 사물을 화면 안에서 키워 본다. 다른 미션은 손대지 않고 그대로 반환한다.
  Widget _zoomable(Widget child) {
    if (!_isPhotoMission) return child;
    return GestureDetector(
      onScaleStart: (_) => _zoomBase = _zoom,
      onScaleUpdate: (d) => setState(() => _zoom = (_zoomBase * d.scale).clamp(_zoomMin, _zoomMax)),
      child: Transform.scale(scale: _zoom, child: child),
    );
  }

  @override
  void dispose() {
    _adminArTimer?.cancel();
    _mission?.dispose();
    _ac.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(children: [
        // 배경: 실기기(ARKit 지원)면 실제 카메라+3D 마커, 아니면(시뮬레이터·구형·Android·
        // 확인 중) 검은 placeholder + 아래 2D 고정 마커로 폴백.
        if (_arSupported == true && _mode == 'scan' && !_arError)
          _zoomable(NativeArView(
            markers: _markers,
            referenceImages: widget.arReferenceImages,
            onMarkerTapped: _onNativeMarkerTapped,
            onError: () => setState(() => _arError = true),
            onReady: (c) {
              _arController = c;
              _mission?.attach(c);
            },
            // admin은 실기기 텔레메트리 대신 방향키로 넣은 값만 쓴다 — 안 끊으면 실측(제자리라
            // 거리 그대로)이 10Hz로 덮어써서 방향키 조작이 즉시 지워진다.
            onTelemetry: Session.isAdmin ? null : _mission?.onTelemetry,
            onImageDetected: _mission?.onImageDetected,
            enablePinchZoom: _isPhotoMission,
          ))
        else if (widget.remote)
          // 원격 체험 배경 — 그 자리에 없으니 카메라 대신 도깨비 기운이 도는 밤 풍경.
          _RemoteBackdrop(anim: _ac)
        else
          Container(
            color: const Color(0xFF0A0E16),
            child: const Center(child: Icon(Icons.camera_alt_outlined, color: Colors.white10, size: 90)),
          ),

        // 상단: 장소 + 진행 + 닫기
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(children: [
              _chip(Icons.place, widget.placeName.isEmpty ? 'AR 탐색' : widget.placeName),
              const Spacer(),
              _chip(Icons.diamond, '${widget.collected}/${widget.total}', color: AppColors.teal),
              const SizedBox(width: 8),
              IconButton(
                onPressed: () => Navigator.pop(context, false),
                icon: const Icon(Icons.close, color: Colors.white70),
              ),
            ]),
          ),
        ),

        // 미션 HUD — 남은 거리 + 지금 뭘 해야 하는지. 실기기에서 이게 없으면
        // "가까이 가야 하는 줄" 자체를 모른 채 헤맨다.
        if (_mission != null && _arSupported == true && _mode == 'scan' && !_arError)
          _MissionHud(progress: _mission!.progress, statusOverride: _verdictLine),

        // 엽전 획득 효과 — 주울 때마다 키가 바뀌어 처음부터 다시 재생된다.
        if (_coinPicks > 0)
          IgnorePointer(child: Center(child: _CoinPickFx(key: ValueKey(_coinPicks)))),

        // admin 전용 — 방향키로 "다가가기/물러서기"(실외 이동 없이 엽전·AR 미션 테스트).
        if (_mission != null && Session.isAdmin && _arSupported == true && _mode == 'scan' && !_arError)
          Positioned(right: 12, top: 130, child: _adminArPanel()),

        // 촬영 미션 셔터 — 찾기 단계가 끝난 뒤에만. 검증 중엔 눌리지 않는다.
        if (_isPhotoMission && _photoReady && _arSupported == true && _mode == 'scan' && !_arError)
          Positioned(
            bottom: 108, left: 0, right: 0,
            child: Center(child: _ShutterButton(busy: _verifying, onTap: _shoot)),
          ),

        // 힌트 모드 (방탈출: 지령 + 단계 힌트)
        if (_mode == 'hint')
          Center(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 28),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.75),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.gold.withOpacity(0.5)),
              ),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.assignment_outlined, color: AppColors.gold, size: 28),
                const SizedBox(height: 10),
                if (widget.order.isNotEmpty)
                  Text('🧙 "${widget.order}"',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white, height: 1.5, fontWeight: FontWeight.w600)),
                const SizedBox(height: 12),
                ...List.generate(
                  widget.hints.take(_hintShown).length,
                  (i) => Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text('힌트 ${i + 1}. ${widget.hints[i]}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: AppColors.gold, fontSize: 13, height: 1.4)),
                  ),
                ),
                if (_hintShown < widget.hints.length) ...[
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: () => setState(() => _hintShown++),
                    child: const Text('다음 힌트 보기', style: TextStyle(color: AppColors.gold)),
                  ),
                ],
              ]),
            ),
          ),

        // NPC 모드
        if (_mode == 'npc')
          Center(child: _panel(Icons.local_fire_department, AppColors.purple,
              '이 곳의 도깨비가 지켜보고 있다. 대화로 받은 단서를 떠올려 보자.')),

        // 스캔 모드 2D 폴백 마커 — 실제 AR(NativeArView) 사용 중이면 안 그림(중복 방지).
        if (!(_arSupported == true && !_arError)) ...[
          if (_mode == 'scan' && _scanned) ...[
            _marker(0.30, 0.40, AppColors.teal, Icons.diamond, '기억석 조각', onTap: () => Navigator.pop(context, true)),
            _marker(0.68, 0.55, AppColors.purple, Icons.local_fire_department, '도깨비', onTap: () => setState(() => _mode = 'npc')),
          ],
          if (_mode == 'scan' && !_scanned)
            const Center(child: Text('아래 "스캔"으로 주변을 살펴보세요',
                style: TextStyle(color: Colors.white54))),
        ],
        // 실제 AR 로딩 중 안내(마커가 뜨기 전 잠깐 표시).
        if (_arSupported == true && _mode == 'scan' && !_arError)
          const Positioned(
            bottom: 120, left: 0, right: 0,
            child: Center(child: Text('천천히 주변을 비춰 보세요 — 도깨비가 나타납니다',
                style: TextStyle(color: Colors.white54, fontSize: 12))),
          ),

        // 하단 토글 (힌트 / 스캔 / NPC)
        Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 28, left: 16, right: 16),
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(children: [
                _tab('hint', Icons.lightbulb_outline, '힌트'),
                _tab('scan', Icons.radar, '스캔'),
                _tab('npc', Icons.face_retouching_natural, 'NPC'),
              ]),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _tab(String mode, IconData icon, String label) {
    final on = _mode == mode;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() {
          _mode = mode;
          if (mode == 'scan') _scanned = true; // 스캔 누르면 마커 등장
        }),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: on ? AppColors.teal.withOpacity(0.18) : Colors.transparent,
            borderRadius: BorderRadius.circular(22),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, color: on ? AppColors.teal : Colors.white60, size: 20),
            Text(label, style: TextStyle(color: on ? AppColors.teal : Colors.white60, fontSize: 11)),
          ]),
        ),
      ),
    );
  }

  Widget _marker(double x, double y, Color c, IconData icon, String label, {VoidCallback? onTap}) {
    return LayoutBuilder(builder: (context, _) {
      final size = MediaQuery.of(context).size;
      return Positioned(
        left: size.width * x - 36,
        top: size.height * y - 36,
        child: GestureDetector(
          onTap: onTap,
          child: ScaleTransition(
            scale: Tween(begin: 0.9, end: 1.1).animate(_ac),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                width: 64, height: 64,
                decoration: BoxDecoration(
                  color: c.withOpacity(0.2),
                  shape: BoxShape.circle,
                  border: Border.all(color: c, width: 2),
                  boxShadow: [BoxShadow(color: c.withOpacity(0.5), blurRadius: 24, spreadRadius: 2)],
                ),
                child: Icon(icon, color: c, size: 28),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(10)),
                child: Text(label, style: TextStyle(color: c, fontSize: 11)),
              ),
            ]),
          ),
        ),
      );
    });
  }

  Widget _chip(IconData icon, String text, {Color color = Colors.white}) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.black54,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Text(text, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w600)),
        ]),
      );

  Widget _panel(IconData icon, Color color, String text) => Container(
        margin: const EdgeInsets.symmetric(horizontal: 32),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.7),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.5)),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 12),
          Text(text, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, height: 1.5)),
        ]),
      );
}

/// 원격 체험 배경 — 카메라를 못 쓰는(또는 쓸 이유가 없는) 자리에서의 대체 화면.
///
/// 사진을 깔지 않고 그라데이션·별·안개로만 그린다. 실제 그 장소의 사진을 쓰면
/// "지금 눈앞"이라고 오해할 수 있는데, 원격 체험은 그 반대를 분명히 해야 한다.
class _RemoteBackdrop extends StatelessWidget {
  final Animation<double> anim;
  const _RemoteBackdrop({required this.anim});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: anim,
      builder: (context, _) => Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0B1020), Color(0xFF161226), Color(0xFF241B24)],
          ),
        ),
        child: Stack(children: [
          // 도깨비불 — 숨쉬듯 밝기가 오르내린다.
          Positioned(
            left: 60, top: 180,
            child: _Glow(color: AppColors.teal, size: 120, opacity: 0.10 + 0.06 * anim.value),
          ),
          Positioned(
            right: 40, top: 300,
            child: _Glow(color: AppColors.purple, size: 160, opacity: 0.08 + 0.05 * (1 - anim.value)),
          ),
          Positioned(
            left: 120, bottom: 220,
            child: _Glow(color: AppColors.gold, size: 100, opacity: 0.06 + 0.04 * anim.value),
          ),
          // 먼 능선 — 바깥 어딘가라는 감만 준다.
          Align(
            alignment: Alignment.bottomCenter,
            child: ClipPath(
              clipper: _RidgeClipper(),
              child: Container(height: 170, color: const Color(0xFF0A0A12)),
            ),
          ),
        ]),
      ),
    );
  }
}

class _Glow extends StatelessWidget {
  final Color color;
  final double size;
  final double opacity;
  const _Glow({required this.color, required this.size, required this.opacity});

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [color.withOpacity(opacity), color.withOpacity(0)],
          ),
        ),
      );
}

/// 배경 아래쪽 능선 실루엣.
class _RidgeClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final p = Path()..moveTo(0, size.height);
    p.lineTo(0, size.height * 0.55);
    p.lineTo(size.width * 0.18, size.height * 0.18);
    p.lineTo(size.width * 0.34, size.height * 0.50);
    p.lineTo(size.width * 0.52, size.height * 0.10);
    p.lineTo(size.width * 0.70, size.height * 0.46);
    p.lineTo(size.width * 0.86, size.height * 0.22);
    p.lineTo(size.width, size.height * 0.52);
    p.lineTo(size.width, size.height);
    return p..close();
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

/// 미션 진행 HUD — 거리·진행률·안내 한 줄.
class _MissionHud extends StatelessWidget {
  final ArMissionProgress progress;
  /// 검증 결과 대사처럼 상태기계 문구를 잠시 덮어야 할 때.
  final String? statusOverride;
  const _MissionHud({required this.progress, this.statusOverride});

  @override
  Widget build(BuildContext context) {
    final p = progress;
    final d = p.nearestM;
    return SafeArea(
      child: Column(children: [
        const SizedBox(height: 56),
        // 남은 거리 — 숫자가 줄어드는 것만으로 "다가가라"가 전달된다.
        if (d != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: AppColors.teal.withValues(alpha: 0.5)),
            ),
            child: Text(
              d < 10 ? '${d.toStringAsFixed(1)} m' : '${d.round()} m',
              style: const TextStyle(color: AppColors.teal, fontSize: 18, fontWeight: FontWeight.w600),
            ),
          ),
        const Spacer(),
        // 스캔·응시처럼 차오르는 미션만 진행 막대를 보여준다.
        if (p.ratio > 0 && p.ratio < 1)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 48),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: p.ratio,
                minHeight: 5,
                backgroundColor: Colors.white24,
                valueColor: const AlwaysStoppedAnimation(AppColors.teal),
              ),
            ),
          ),
        const SizedBox(height: 10),
        Container(
          margin: const EdgeInsets.only(bottom: 92),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(statusOverride ?? p.status,
              style: const TextStyle(color: Colors.white, fontSize: 13.5)),
        ),
      ]),
    );
  }
}

const _coinFxDuration = Duration(milliseconds: 700);
const double _coinFxSize = 220;
const _coinFxAsset = 'assets/game/vfx/coin_pickup_vfx.webp';

/// 엽전 획득 효과 — 금빛 고리가 커지며 사라진다.
class _CoinPickFx extends StatelessWidget {
  const _CoinPickFx({super.key});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: _coinFxDuration,
      builder: (_, t, child) => Opacity(
        opacity: 1 - t,
        child: Transform.scale(scale: 0.6 + 0.6 * t, child: child),
      ),
      child: Image.asset(_coinFxAsset, width: _coinFxSize),
    );
  }
}

/// 촬영 미션 셔터. 검증 중엔 회전 인디케이터로 바뀌고 눌리지 않는다.
class _ShutterButton extends StatelessWidget {
  final bool busy;
  final VoidCallback onTap;
  const _ShutterButton({required this.busy, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '사진 찍기',
      child: GestureDetector(
        onTap: busy ? null : onTap,
        child: Container(
          width: 74, height: 74,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.black.withValues(alpha: 0.45),
            border: Border.all(color: Colors.white, width: 4),
          ),
          child: Center(
            child: busy
                ? const SizedBox(width: 30, height: 30,
                    child: CircularProgressIndicator(strokeWidth: 3, color: AppColors.teal))
                : Container(
                    width: 54, height: 54,
                    decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
                  ),
          ),
        ),
      ),
    );
  }
}


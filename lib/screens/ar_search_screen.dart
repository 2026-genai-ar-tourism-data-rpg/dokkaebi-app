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
//      마지막 엽전은 효과가 보이도록 잠시 뒤에 닫는다. 마커 배치 직후 상태를 다시 보내고
//      (admin에서 엽전이 안 보이던 원인), admin 방향키 한 칸은 1m→0.5m.
// 구현일: 2026-09-18 | 작성: ljs (npc-character-set/ljs/v1)
// ------------------------------------------------------------
// [v6] 촬영 미션 → 도깨비불 길들이기 (AR 미션 교체 명세 v1.0, 2026-09-19).
// 구현(요약): PHOTO_FIND·PATH_TRACE는 더 이상 셔터·촬영·OCR 검증을 타지 않는다. 제자리에서
//            폰을 돌려 불꽃 3마리를 각 2초 조준해 모으면 초롱이 켜지고 pop(true) — 조각·collect는
//            기존대로 상위 화면(quest_play_screen) 담당. 판정은 fire_capture_controller.dart.
//            AR 미지원·카메라 거부·원격 체험은 "터치 모드"(드래그로 시야 회전, 같은 규칙).
//            모은 불꽃은 로컬(userId+runId+nodeId+버전)에 저장해 이탈·재진입 시 복원한다.
//            구 시나리오의 "현판을 찍어라" 지령은 여기서 불빛 모으기 문구로 치환한다.
//            촬영·검증 코드(_shoot 등)는 남겨 두되 이 경로에서는 호출하지 않는다.
//            그림은 에셋 안내서(ar-fire) 4종: 불꽃(3마리 재사용)·흡수 소용돌이·초롱 꺼짐/켜짐.
//            초롱은 같은 자리·크기로 두고 3마리째에 300ms 교차 페이드로 켠다.
// 구현일: 2026-09-19 | 작성: kys (fire-capture/kys/v1)
// ============================================================
import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api/api_client.dart';
import '../models/scenario.dart';

import '../game/ar_mission_controller.dart';
import '../game/fire_capture_controller.dart';
import '../game/run_session.dart';
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

class _ArSearchScreenState extends State<ArSearchScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  bool? _arSupported; // null=확인 중, true=실제 ARKit, false=2D 폴백(시뮬레이터 등)
  bool _arError = false;

  // ── 도깨비불 길들이기 (사진 미션 대체) ──
  FireCaptureController? _fire;
  Timer? _fireTick;                 // 흡수 연출(800ms) 종료 판정용
  bool _fireTracking = true;        // ARKit tracking 정상 여부(네이티브 이벤트)
  bool _fireIntroShown = true;      // 인트로(초롱 소개 + 시작) 표시 중
  String? _fireKey;                 // 로컬 저장 키

  bool _lanternLit = false;         // 3마리째 → 초롱 점등(꺼짐→켜짐 교차 페이드)

  static const _fireSpiritAsset = 'assets/game/ar/fire/fire_spirit_idle.png';
  static const _fireWispAsset = 'assets/game/ar/fire/capture_wisp.png';

  bool get _isFireMission => _fire != null;
  /// AR을 못 쓰는 경우(미지원·에러·원격) — 터치 모드로 같은 규칙을 돌린다.
  bool get _fireTouchMode => _isFireMission && !(_arSupported == true && !_arError);

  /// 구 시나리오의 촬영 지령을 불빛 모으기 문구로 — 데이터는 그대로 두고 표시만 바꾼다.
  String get _displayOrder {
    if (!_isFireMission) return widget.order;
    final o = widget.order;
    if (o.isEmpty || RegExp(r'(찍|촬영|사진|담아|문양|현판)').hasMatch(o)) {
      return '골목에 흩어진 불빛 세 마리를 모아 초롱을 깨워라';
    }
    return o;
  }

  static const _fragmentMarker = ArMarkerDef(
    id: 'fragment', label: '기억석 조각', color: AppColors.teal,
    forward: 1.8, right: -0.4, down: 0.15,
  );
  static const _dokkaebiMarker = ArMarkerDef(
    id: 'dokkaebi', label: '도깨비', color: AppColors.purple,
    forward: 2.1, right: 0.5, down: 0.05,
  );
  // ⚠️ initState에서 생성한다. `late final _ac = AnimationController(...)` 형태로 두면
  //    지연 생성이라, build가 이 컨트롤러를 안 쓰는 분기(2D 폴백 미사용 등)로만 지나가면
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

  /// admin 방향키 한 칸(m). 1m면 엽전 줍기 반경(1.2m)과 간격(1.3m)보다 커서 반짝이는 걸
  /// 보기도 전에 한 칸에 하나씩 주워졌다.
  static const double _adminStepM = 0.5;

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
        btn('▲', () => _adminWalk(_adminStepM)),
        const SizedBox(height: 4),
        btn('⟲', () {
          setState(() => _adminWalked = 0);
          _pushAdminTelemetry();
        }),
        const SizedBox(height: 4),
        btn('▼', () => _adminWalk(-_adminStepM)),
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
    } else if (arMissionTypeOf(raw) == ArMissionType.photo) {
      // 사진 미션 → 도깨비불 길들이기. ArMissionController·셔터·검증은 만들지 않는다.
      _markers = _fireMarkers(FireTarget.defaults());
      _setupFire();
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

  // ── 도깨비불: 마커·컨트롤러·저장 ────────────────────────
  /// 불꽃 3개를 시작 카메라 기준 yaw 방향(+32°, -26°, +12°) 2.4m 눈높이에 둔다.
  /// 활성 불꽃만 solid, 나머지는 hidden — 동시에 1마리만 보인다.
  static List<ArMarkerDef> _fireMarkers(List<FireTarget> targets, {Set<String> collected = const {}}) {
    String? active;
    for (final t in targets) {
      if (!collected.contains(t.id)) { active = t.id; break; }
    }
    return [
      for (final t in targets)
        if (!collected.contains(t.id))
          ArMarkerDef(
            id: t.id, label: '도깨비불', color: AppColors.teal, kind: ArMarkerKind.fire,
            image: _fireSpiritAsset,
            forward: kFireDistanceM * math.cos(t.yawRad),
            right: kFireDistanceM * math.sin(t.yawRad),
            down: 0.0,
            state: t.id == active ? ArMarkerState.solid : ArMarkerState.hidden,
          ),
    ];
  }

  void _setupFire() {
    _fireKey = fireProgressKey(
      userId: Session.userId ?? 'guest',
      runId: RunSession.I.runId ?? '-',
      nodeId: widget.nodeId ?? widget.placeName,
    );
    _fire = FireCaptureController(
      onCaptured: _onFireCaptured,
      onAllCaptured: _onAllFiresCaptured,
    )..addListener(() { if (mounted) setState(() {}); });
    WidgetsBinding.instance.addObserver(this);
    _restoreFire();
  }

  /// 이탈·재시작 뒤 모은 수량 복원(게이지는 버림). 이미 완료면 곧장 마무리로.
  Future<void> _restoreFire() async {
    final key = _fireKey;
    if (key == null) return;
    try {
      final p = await SharedPreferences.getInstance();
      final raw = p.getString(key);
      if (raw == null || !mounted) return;
      final d = jsonDecode(raw) as Map<String, dynamic>;
      final ids = ((d['collected'] as List?) ?? const []).map((e) => e.toString()).toSet();
      if (ids.isEmpty) return;
      _fire?.dispose();
      _fire = FireCaptureController(
        restoredCollected: ids,
        onCaptured: _onFireCaptured,
        onAllCaptured: _onAllFiresCaptured,
      )..addListener(() { if (mounted) setState(() {}); });
      setState(() => _markers = _fireMarkers(FireTarget.defaults(), collected: ids));
    } catch (_) {
      // 저장소를 못 읽으면 처음부터 — 복원 실패가 플레이를 막으면 안 된다.
    }
  }

  Future<void> _persistFire({bool done = false}) async {
    final key = _fireKey; final f = _fire;
    if (key == null || f == null) return;
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(key, jsonEncode({'collected': f.collectedIds.toList(), 'done': done}));
    } catch (_) {}
  }

  void _startFire() {
    setState(() => _fireIntroShown = false);
    _fire?.start();
    _fireTick ??= Timer.periodic(const Duration(milliseconds: 100), (_) {
      _fire?.tick();
      if (_fireTouchMode) _pushTouchObservation();
    });
  }

  void _onFireCaptured(String id) {
    _arController?.absorbMarker(id, image: _fireWispAsset);
    if (_fireTouchMode) {
      final t = FireTarget.defaults().where((e) => e.id == id).firstOrNull;
      setState(() { _touchWispYaw = t?.yawRad; _touchWispSeq++; });
      Future<void>.delayed(const Duration(milliseconds: kFireCaptureMs), () {
        if (mounted) setState(() => _touchWispYaw = null);
      });
    }
    _persistFire();
    // 800ms 뒤 다음 불꽃을 켠다(컨트롤러가 capture→seek로 넘어가는 시점과 같다).
    Future<void>.delayed(const Duration(milliseconds: kFireCaptureMs), () {
      final next = _fire?.activeTarget?.id;
      if (next != null && mounted) _arController?.setMarkerState(next, ArMarkerState.solid);
    });
  }

  Future<void> _onAllFiresCaptured() async {
    if (mounted) setState(() => _lanternLit = true);   // 꺼짐→켜짐 300ms 교차 페이드
    await _persistFire(done: true);
    // 초롱 점등 연출을 잠깐 보여주고 닫는다. 조각·collect·재시도는 상위 화면 담당.
    await Future<void>.delayed(const Duration(milliseconds: 1400));
    if (!mounted) return;
    _fire?.markSynced();
    Navigator.pop(context, true);
  }

  /// 네이티브 텔레메트리 → 활성 불꽃 관측 1건.
  void _onFireTelemetry(Map<String, ArMarkerReading> r) {
    final f = _fire; final id = f?.activeTarget?.id;
    if (f == null || id == null) return;
    final read = r[id];
    if (read == null) return;
    f.observe(FireObservation(aimErrorRad: read.aimError, yawDeltaRad: read.yawDelta, tracking: _fireTracking));
  }

  // ── 터치 모드: 드래그·버튼으로 가상 시야(yaw)를 돌린다 ──
  double _touchYaw = 0;                       // 가상 카메라 yaw(라디안)
  double? _touchWispYaw;                      // 흡수 소용돌이를 그릴 방향(800ms)
  int _touchWispSeq = 0;                      // 연출 재시작 키
  static const double _touchFovRad = 70 * math.pi / 180;

  void _pushTouchObservation() {
    final f = _fire; final t = f?.activeTarget;
    if (f == null || t == null) return;
    var d = t.yawRad - _touchYaw;
    while (d > math.pi) { d -= 2 * math.pi; }
    while (d < -math.pi) { d += 2 * math.pi; }
    f.observe(FireObservation(aimErrorRad: d.abs(), yawDeltaRad: d, tracking: true));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_isFireMission) return;
    if (state == AppLifecycleState.resumed) {
      _fire?.resume();
    } else {
      _fire?.pause();
    }
  }

  void _onNativeMarkerTapped(String id) {
    final m = _mission;
    if (m != null) {
      m.onTapped(id);
      return;
    }
    if (_isFireMission) return;       // 불꽃은 탭으로 안 줍힌다 — 조준 유지만
    if (id == 'fragment') {
      Navigator.pop(context, true);
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
    _fireTick?.cancel();
    if (_isFireMission) WidgetsBinding.instance.removeObserver(this);
    _fire?.dispose();
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
        if (_arSupported == true && !_arError)
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
            onTelemetry: _isFireMission ? _onFireTelemetry : (Session.isAdmin ? null : _mission?.onTelemetry),
            onImageDetected: _mission?.onImageDetected,
            onTrackingChanged: _isFireMission ? (ok) => _fireTracking = ok : null,
            enablePinchZoom: _isPhotoMission,
            // 배치 전에 보낸 상태는 사라졌다 — 다시 보내게 하고, admin은 거리 값을 바로 다시 넣는다
            // (실기기 텔레메트리는 배치 뒤에 오지만 admin 이동은 뷰가 뜨기 전부터 돈다).
            onMarkersPlaced: () {
              _mission?.resync();
              if (Session.isAdmin && !widget.remote) _pushAdminTelemetry();
            },
          ))
        else if (_fireTouchMode)
          // 터치 모드 — 카메라 없이 같은 3마리·2초 규칙. 드래그로 시야를 돌린다.
          _FireTouchView(
            backdrop: widget.remote ? _RemoteBackdrop(anim: _ac) : null,
            yaw: _touchYaw,
            fov: _touchFovRad,
            active: _fire?.activeTarget,
            collected: _fire?.collectedIds ?? const {},
            holdRatio: _fire?.progress.holdRatio ?? 0,
            wispYaw: _touchWispYaw,
            wispSeq: _touchWispSeq,
            onYaw: (y) => setState(() => _touchYaw = y),
          )
        else if (widget.remote)
          // 원격 체험 배경 — 그 자리에 없으니 카메라 대신 도깨비 기운이 도는 밤 풍경.
          _RemoteBackdrop(anim: _ac)
        else
          Container(
            color: const Color(0xFF0A0E16),
            child: const Center(child: Icon(Icons.camera_alt_outlined, color: Colors.white10, size: 90)),
          ),

        // 상단: 장소 + 진행 + 닫기, 그 아래 지령 한 줄.
        // 힌트 탭(단계별 힌트 목록)·NPC 탭(고정 문구)은 걷어냈다 — AR 판정이 거리 기반이라
        // 근처를 비추기만 하면 되고, 실제 탐색 난이도에 기여하지 않아 기능적 가치가 없었다
        // (팀 판단). 장소별로 실제 다른 지령(order) 한 줄만 상시 노출로 남긴다.
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(children: [
                _chip(Icons.place, widget.placeName.isEmpty ? 'AR 탐색' : widget.placeName),
                const Spacer(),
                _chip(Icons.diamond, '${widget.collected}/${widget.total}', color: AppColors.teal),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () => Navigator.pop(context, false),
                  icon: const Icon(Icons.close, color: Colors.white70),
                ),
              ]),
              if (_displayOrder.isNotEmpty) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.gold.withValues(alpha: 0.4)),
                  ),
                  child: Text('🧙 "$_displayOrder"',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontSize: 12.5, height: 1.4, fontWeight: FontWeight.w600)),
                ),
              ],
            ]),
          ),
        ),

        // 미션 HUD — 남은 거리 + 지금 뭘 해야 하는지. 실기기에서 이게 없으면
        // "가까이 가야 하는 줄" 자체를 모른 채 헤맨다.
        if (_mission != null && _arSupported == true && !_arError)
          _MissionHud(progress: _mission!.progress, statusOverride: _verdictLine),

        // 도깨비불 HUD — 수집 수, 중앙 조준 원(게이지), 좌우 힌트, 안내 한 줄.
        if (_isFireMission && !_fireIntroShown && _arSupported != null)
          _FireHud(progress: _fire!.progress, lanternLit: _lanternLit),

        // 도깨비불 인트로 — 초롱 소개 + 시작. GPS 인증은 이미 상위 화면에서 끝났다.
        if (_isFireMission && _fireIntroShown && _arSupported != null)
          _FireIntro(placeName: widget.placeName, onStart: _startFire),

        // 엽전 획득 효과 — 주울 때마다 키가 바뀌어 처음부터 다시 재생된다.
        if (_coinPicks > 0)
          IgnorePointer(child: Center(child: _CoinPickFx(key: ValueKey(_coinPicks)))),

        // admin 전용 — 방향키로 "다가가기/물러서기"(실외 이동 없이 엽전·AR 미션 테스트).
        if (_mission != null && Session.isAdmin && _arSupported == true && !_arError)
          Positioned(right: 12, top: 130, child: _adminArPanel()),

        // 촬영 미션 셔터 — 찾기 단계가 끝난 뒤에만. 검증 중엔 눌리지 않는다.
        if (_isPhotoMission && _photoReady && _arSupported == true && !_arError)
          Positioned(
            bottom: 108, left: 0, right: 0,
            child: Center(child: _ShutterButton(busy: _verifying, onTap: _shoot)),
          ),

        // 실제 AR을 못 쓰는 기기(시뮬레이터·구형)의 2D 폴백 마커 — 하위호환(missionType 없는
        // 호출부, quest_tab_screen.dart)에서만 의미가 있다.
        if (!(_arSupported == true && !_arError) && !_isFireMission) ...[
          _marker(0.30, 0.40, AppColors.teal, Icons.diamond, '기억석 조각', onTap: () => Navigator.pop(context, true)),
          _marker(0.68, 0.55, AppColors.purple, Icons.local_fire_department, '도깨비'),
        ],
        // 실제 AR 로딩 중 안내(마커가 뜨기 전 잠깐 표시).
        if (_arSupported == true && !_arError && !_isFireMission)
          const Positioned(
            bottom: 120, left: 0, right: 0,
            child: Center(child: Text('천천히 주변을 비춰 보세요 — 도깨비가 나타납니다',
                style: TextStyle(color: Colors.white54, fontSize: 12))),
          ),
      ]),
    );
  }

  // Positioned는 Stack의 직계 자식이어야 하는데, LayoutBuilder를 거치면(그 안에서도 쓰지
  // 않는 constraints 대신 MediaQuery.size를 썼다) "호환 안 되는 ParentData" 예외가 난다
  // (State 자체의 context로 충분해 애초에 LayoutBuilder가 필요 없었다).
  Widget _marker(double x, double y, Color c, IconData icon, String label, {VoidCallback? onTap}) {
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

// ═══════════════════════════════════════════════════════════
// 도깨비불 길들이기 — 위젯
// ═══════════════════════════════════════════════════════════

/// 인트로 — 초롱 소개와 시작. 명세 2쪽 "도착·소개" 단계.
class _FireIntro extends StatelessWidget {
  final String placeName;
  final VoidCallback onStart;
  const _FireIntro({required this.placeName, required this.onStart});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withValues(alpha: 0.55),
      child: Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 28),
          padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
          decoration: BoxDecoration(
            color: const Color(0xFF14110C).withValues(alpha: 0.96),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.gold.withValues(alpha: 0.5)),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const _LanternImage(lit: false, size: 120),
            const SizedBox(height: 4),
            const Text('잠든 초롱을 깨워줘',
                style: TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(
              '${placeName.isEmpty ? '이곳' : placeName}의 골목에 불빛 세 마리가 흩어졌어요.\n'
              '제자리에서 폰을 천천히 돌려 불빛을 가운데에 두고 2초만 기다리세요.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 13.5, height: 1.5),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(backgroundColor: AppColors.gold, foregroundColor: Colors.black),
                onPressed: onStart,
                child: const Text('시작', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

/// HUD — 수집 수 · 중앙 조준 원(유지 게이지) · 좌우 힌트 · 안내.
class _FireHud extends StatelessWidget {
  final FireProgress progress;
  final bool lanternLit;
  const _FireHud({required this.progress, required this.lanternLit});

  @override
  Widget build(BuildContext context) {
    final p = progress;
    final aimed = p.aimed;
    final ringColor = aimed ? AppColors.gold : Colors.white.withValues(alpha: 0.7);
    final showArrow = !aimed && (p.state == FireState.seek || p.state == FireState.hold) &&
        (p.hint == FireHint.left || p.hint == FireHint.right);
    final arrowSize = p.stalled ? 64.0 : 40.0;
    return IgnorePointer(
      child: Stack(children: [
        // 초롱(같은 자리·크기, 켜짐은 교차 페이드) + 수집 수
        SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: const EdgeInsets.only(top: 84),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                _LanternImage(lit: lanternLit, size: lanternLit ? 150 : 84),
                const SizedBox(height: 2),
                Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: AppColors.gold.withValues(alpha: 0.5)),
                ),
                  child: Text('${p.collected} / ${p.total}',
                      style: const TextStyle(color: AppColors.gold, fontSize: 18, fontWeight: FontWeight.w700)),
                ),
              ]),
            ),
          ),
        ),
        // 중앙 조준 원 + 게이지 (6° 허용 범위를 원 크기로 표현)
        Center(
          child: SizedBox(
            width: 96, height: 96,
            child: Stack(fit: StackFit.expand, children: [
              CircularProgressIndicator(
                value: p.holdRatio,
                strokeWidth: 5,
                backgroundColor: Colors.white.withValues(alpha: 0.18),
                valueColor: AlwaysStoppedAnimation(ringColor),
              ),
              Center(
                child: Container(
                  width: 12, height: 12,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: ringColor),
                ),
              ),
            ]),
          ),
        ),
        // 좌우 힌트 화살표 — 진전이 없으면(8초) 더 크게
        if (showArrow)
          Align(
            alignment: p.hint == FireHint.left ? const Alignment(-0.85, 0) : const Alignment(0.85, 0),
            child: Icon(
              p.hint == FireHint.left ? Icons.chevron_left : Icons.chevron_right,
              color: AppColors.gold, size: arrowSize,
            ),
          ),
        // 안내 한 줄
        Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            margin: const EdgeInsets.only(bottom: 92),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(p.status, style: const TextStyle(color: Colors.white, fontSize: 13.5)),
          ),
        ),
      ]),
    );
  }
}

/// 터치 모드 — 카메라 대신 가상 시야. 드래그(또는 좌우 버튼)로 yaw를 돌리고,
/// 활성 불꽃을 (목표 yaw − 시야 yaw)에 따라 가로 위치로 그린다. 판정 규칙은 AR과 동일.
class _FireTouchView extends StatelessWidget {
  final Widget? backdrop;
  final double yaw;
  final double fov;
  final FireTarget? active;
  final Set<String> collected;
  final double holdRatio;
  final double? wispYaw;
  final int wispSeq;
  final ValueChanged<double> onYaw;
  const _FireTouchView({
    required this.backdrop, required this.yaw, required this.fov, required this.active,
    required this.collected, required this.holdRatio, required this.wispYaw, required this.wispSeq,
    required this.onYaw,
  });

  /// 목표 yaw를 화면 x로 — 시야각(fov) 밖이면 null.
  double? _xFor(double targetYaw, double width) {
    var d = targetYaw - yaw;
    while (d > math.pi) { d -= 2 * math.pi; }
    while (d < -math.pi) { d += 2 * math.pi; }
    if (d.abs() > fov) return null;
    return width / 2 + (d / (fov / 2)) * (width / 2);
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final fireX = active == null ? null : _xFor(active!.yawRad, size.width);
    final wispX = wispYaw == null ? null : _xFor(wispYaw!, size.width);
    final fireSize = 120 + 24 * holdRatio;   // 유지할수록 살짝 커진다
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      // 화면 폭을 다 끌면 시야각(70°)만큼 돈다 — 실제 폰을 돌리는 감각에 가깝게.
      onHorizontalDragUpdate: (d) => onYaw(yaw - d.delta.dx / size.width * fov),
      child: Stack(fit: StackFit.expand, children: [
        backdrop ??
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter, end: Alignment.bottomCenter,
                  colors: [Color(0xFF0B0E16), Color(0xFF17131B), Color(0xFF221A18)],
                ),
              ),
            ),
        if (fireX != null)
          Positioned(
            left: fireX - fireSize / 2, top: size.height * 0.45 - fireSize / 2,
            child: Image.asset(_ArSearchScreenState._fireSpiritAsset,
                width: fireSize, height: fireSize, filterQuality: FilterQuality.medium),
          ),
        // 흡수 소용돌이 — 회전·축소·페이드 800ms (에셋 안내서 권장 연출)
        if (wispX != null)
          Positioned(
            left: wispX - 90, top: size.height * 0.45 - 90,
            child: TweenAnimationBuilder<double>(
              key: ValueKey(wispSeq),
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: kFireCaptureMs),
              builder: (_, t, child) => Opacity(
                opacity: t < 0.15 ? t / 0.15 : (1 - t).clamp(0, 1),
                child: Transform.rotate(
                  angle: -t * math.pi * 1.5,
                  child: Transform.scale(scale: 1.0 - 0.9 * t, child: child),
                ),
              ),
              child: Image.asset(_ArSearchScreenState._fireWispAsset, width: 180, height: 180),
            ),
          ),
        // 좌우 버튼 — 드래그가 어려운 경우(접근성)
        Positioned(
          left: 12, bottom: 150,
          child: _TouchTurnButton(icon: Icons.chevron_left, onTap: () => onYaw(yaw - 6 * math.pi / 180)),
        ),
        Positioned(
          right: 12, bottom: 150,
          child: _TouchTurnButton(icon: Icons.chevron_right, onTap: () => onYaw(yaw + 6 * math.pi / 180)),
        ),
        const Positioned(
          left: 0, right: 0, bottom: 128,
          child: Center(child: Text('터치 모드 — 화면을 좌우로 끌어 시야를 돌리세요',
              style: TextStyle(color: Colors.white38, fontSize: 11))),
        ),
      ]),
    );
  }
}

class _TouchTurnButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _TouchTurnButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.55),
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.gold.withValues(alpha: 0.5)),
          ),
          child: Icon(icon, color: AppColors.gold),
        ),
      );
}

/// 초롱 — 꺼짐/켜짐 두 그림을 같은 자리·같은 크기에 겹쳐 두고 300ms 교차 페이드한다
/// (에셋 안내서: 자동 자르기 없이 원본 캔버스 여백을 유지해야 전환 시 정렬이 안 흔들린다).
class _LanternImage extends StatelessWidget {
  final bool lit;
  final double size;
  const _LanternImage({required this.lit, required this.size});

  static const _unlit = 'assets/game/ar/fire/lantern_unlit.png';
  static const _lit = 'assets/game/ar/fire/lantern_lit.png';

  @override
  Widget build(BuildContext context) => AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: size, height: size,
        child: Stack(fit: StackFit.expand, children: [
          Image.asset(_unlit, fit: BoxFit.contain),
          AnimatedOpacity(
            opacity: lit ? 1 : 0,
            duration: const Duration(milliseconds: 300),
            child: Image.asset(_lit, fit: BoxFit.contain),
          ),
        ]),
      );
}


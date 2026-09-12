// ============================================================
// [v8] 조각 획득 팝업을 실제 챕터·서버 보상으로(계획 B1·B2).
// 구현(요약): 어느 코스·어느 챕터에서 조각을 얻어도 종로 시안 문구가 그대로 떴다
//            (「훈(訓)」 · 종로의 기억석 1/4 · 경험치 +50 · 단서 「申時」 · 익선동 카페 쿠폰 +500원).
//            서버가 complete 응답으로 준 실제 보상(경험치·도감·칭호)은 읽지도 않고 버렸다.
//            → 확정된 챕터(_claimed: 챕터·그때 받은 것·서버 보상)를 팝업이 그대로 읽는다.
//              장소명·지역·조각 번호·단서는 그 챕터 노드에서, 경험치·도감·칭호는 서버 보상에서,
//              쿠폰은 그 챕터에서 실제로 지급한 것만. 없는 항목은 줄 자체를 빼고,
//              서버에 기록하지 못한 조각("기록 없이 계속"·좌표 없는 장소)은 경험치 줄 대신 그 사실을 알린다.
// 구현일: 2026-09-12 | 작성: ljs (mission-strategy-routing/ljs/v1)
// ------------------------------------------------------------
// [v7] 조각은 서버 기록이 성공해야 확정 — 실패하면 공통 팝업으로 멈추고 다시 시도(계획 C1).
// 구현(요약): 미션을 끝내면 조각 수·획득 팝업·로컬 저장을 먼저 하고 서버 기록(collect·complete)은
//            결과를 보지 않아, 폰에선 완주·서버에선 미완주가 생겼다.
//            → 미션 버튼 6곳(퀴즈·사냥·수집·사진·발자국·카페)과 피날레가 _claimChapter 한 경로로
//              서버에 먼저 기록하고, 성공해야 화면(조각 수·획득 팝업·엔딩)과 로컬 진행에 반영한다.
//              실패하면 공통 팝업(_recordSheet): 통신·5xx는 다시 시도만, 4xx 조건 미충족처럼 다시 해도
//              안 되는 실패는 "기록 없이 계속"도 준다(RunSession.errorRetryable). 서버 run이 없으면
//              다시 시도 때 다시 연다. 좌표 없는 장소라 도착 인증을 건너뛴 곳은 기록을 시도하지 않는다.
// 구현일: 2026-09-12 | 작성: ljs (mission-strategy-routing/ljs/v1)
// ------------------------------------------------------------
// [v6] 위치 권한이 꺼져 있으면 이미 도착 인증한 장소도 멈춘다 + 권한 경고에 설정 열기.
// 구현(요약): 실기기에서 도착 인증 → iOS 설정에서 위치 권한 끔(앱 강제 종료) → 다시 열어 같은 장소
//            도착 인증을 누르니 그대로 진행됐다. 서버에 인증 기록이 있으면 위치를 전혀 보지 않고
//            통과시켰기 때문이다. 이제 이미 인증한 장소는 서버 재판정 없이 위치 권한·위치 서비스만
//            확인한다(LocationService.checkAccess — 좌표는 안 읽어 실내 신호 약함엔 막히지 않음).
//            거리 갱신 중 권한·서비스 문제가 보이면 도착 인증 전에도 설정 열기를 주고, 지도 카드는
//            "거리 확인 중"에 머물지 않고 "위치 설정 필요/위치 확인 불가"로 보여준다.
//            같은 경고가 거리 줄과 안내에 두 번 뜨던 것도 한 번으로 줄였다.
// 구현일: 2026-09-12 | 작성: ljs (mission-strategy-routing/ljs/v1)
// ------------------------------------------------------------
// [v5] 이동 단계를 실제 GPS 도착 인증으로 — 걷기 시뮬레이션·조각 기록 시점 위치 확인 제거.
// 구현(요약): 이동 화면이 걷기 애니메이션으로 거리를 줄이고 "GPS 도착 인증"은 위치 확인 없이
//            통과했다. 실제 위치는 미션을 끝내고 조각을 기록할 때만 확인해, 그 자리에 없으면
//            안내만 뜨고 연출은 계속됐다(서버 기록만 빠짐).
//            → 지도·이동 화면에 있는 동안 현재 위치를 주기적으로 읽어 목표까지 실제 거리를
//              보여주고(코스 출발점 기준 거리 대체), 도착 인증은 서버 판정(verify-location)을
//              통과해야 소환으로 넘어간다. 실패하면 사유 안내 + 다시 확인(권한 영구 거부·위치
//              서비스 꺼짐이면 설정 열기). 서버가 좌표 없는 장소라고 하면 "위치 확인 없이
//              진행" 탈출구를 준다(그 장소 조각은 서버에 기록되지 않는다고 안내).
//            조각 기록(_recordOnServer)은 위치를 다시 보지 않는다 — 도착 때 서버에 방문이 남는다.
//            개발자 옵션(GPS 인증 건너뛰기)도 도착 인증 시점으로 옮겼다. 이미 인증한 장소는
//            서버 run 기록으로 판단해 다시 묻지 않는다. 코스 데이터 없는 데모 모드는 시뮬레이션 유지.
//            테스트가 가짜 서버를 붙이도록 RunSession을 주입받는다(기본 RunSession.I).
// 구현일: 2026-09-12 | 작성: ljs (mission-strategy-routing/ljs/v1)
// ------------------------------------------------------------
// [v4] "기억석 컬렉션" 모달(_collSheet/_collCard)도 v2와 같은 하드코딩 버그가
//      남아있었다 — collDefs가 종로 훈민정음 4장 고정 텍스트였고 루프도
//      `i < 4` 고정이라, 다른 지역·5조각 이상 코스에서도 늘 같은 4장이 뜨고
//      개수도 어긋났다. targets(이미 실제 노드 기반으로 채워지는 챕터 목록,
//      v2가 화면 나머지에 쓰던 것과 동일)를 그대로 재사용해 해결 — collDefs
//      제거, `for (i < 4)` → `for (i < targets.length)`, def 튜플 → _Target.
// 구현일: 2026-09-01 | 작성: ljs (dex-stones/ljs/v1)
// ------------------------------------------------------------
// [v1] 화면: 퀘스트 여정 — "종로, 잊혀진 글씨의 비밀 플레이 v2" 시안 1:1 재현
// pipeline: 모바일 클라이언트 / 화면 (새 퀘스트 시작하기 → 전 구간 플레이)
// 구현(요약): setup→지도→GPS→AR소환→대화→퀴즈→지령→사냥→사진→발자국→카페→
//            인사동→세종→엔딩 + 보상/힌트/컬렉션 모달을 한 화면 상태머신으로 재현.
//            콘텐츠(코스명·장소·조각)는 Scenario 데이터 연동, 없으면 종로 기본값 폴백.
// 구현일: 2026-07-08 | 작성: kys (quest-journey/kys/v1) · 시안: 종로의 기억석 플레이 v2 standalone
// ------------------------------------------------------------
// [v2] 조각 수 하드코딩(4) 제거 — 코스 길이를 따라간다.
// 구현(요약): 시안이 종로 4조각이라 '/ 4'·`i < 4`·`math.min(3, …)`가 화면 전체에 박혀 있었다.
//            앱 마법사의 「시간」 입력이 코스 길이(4·6·8조각)를 바꾸게 되면서 그대로 두면
//            표시가 전부 어긋나고, 조각이 4개 미만인 코스는 POI 그리기에서 RangeError가 난다
//            (targets[i], i<4 고정 루프). 실제 챕터 수(targets.length)를 단일 기준으로 쓴다.
//            좁은 화면 HUD·조각 패널 오버플로도 같이 정리(320px 스모크 게이트).
// 구현일: 2026-08-18 | 작성: kys (explore-input-wiring/kys/v1)
// ------------------------------------------------------------
// [v3] 종로 시안 재생 → **코스 데이터 재생**. 이 화면이 메인 진입점(코스 CTA·퀘스트 탭)인데
//      어느 지역 코스를 만들어도 종로 정답지 연출이 그대로 돌고 있었다.
// 구현(요약): ① 퀴즈 하드코딩('운현궁은 누구의 집?' 정답=흥선대원군) → 노드의 quiz 사용.
//              퀴즈가 없는 노드는 시험 단계를 건너뛴다(있지도 않은 문제를 내지 않는다).
//            ② 스테이지 종류를 종로 순서 순환(summon→cafe→insa→sejong)이 아니라
//              **노드 미션 타입**에서 정한다 — QUIZ_FIND→시험, PHOTO_FIND→사진,
//              PATH_TRACE→발자국, HUNT→사냥, 그 외→지령. 마지막은 복원.
//            ③ 도깨비 이름을 노드 npc에서 가져온다(전 지역 '먹 도깨비'였다).
//            ④ 챕터 완료가 로컬에만 남던 것을 서버(run)에도 기록한다 — 이 경로로 플레이하면
//              조각·경험치·도감이 서버에 하나도 안 쌓이고 있었다.
//              ⚠️ 서버 인증은 **실제 기기 위치**로만 보낸다. 처음엔 노드 좌표를 GPS인 척
//              보냈는데, 이 화면은 걸음이 연출(gpsDist 애니메이션)이라 챕터를 4초 만에
//              넘기면 600m를 순간이동한 꼴이 되어 서버 스푸핑 방어(IMPOSSIBLE_SPEED)에
//              전부 막혔다(실측: 정상 속도 플레이가 1/4에서 정지). 실제로 그 자리에
//              가 있지 않으면 서버 기록은 건너뛰고 연출만 진행한다 — 조각의 주인은 서버다.
// 구현일: 2026-08-22 | 작성: kys (play-path-unify/kys/v1)
// ============================================================
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../debug_flags.dart';
import '../game/hint_ladder_controller.dart';
import '../game/player_state.dart';
import '../game/location_service.dart';
import '../game/run_session.dart';
import '../models/run.dart';
import '../models/scenario.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets/native_ar_view.dart';
import '../widgets/reward_pop.dart';
import 'create_scenario_screen.dart' show haversineMeters;

// ── 실제 GPS 도착 인증 ────────────────────────────────
/// 지도·이동 화면에 있는 동안 현재 위치를 다시 읽는 주기.
const _gpsPollInterval = Duration(seconds: 5);

/// "걸어서 약 N분" 표시에 쓰는 걷는 속도(m/분).
const _walkMetersPerMinute = 70;

/// 데모 모드(코스 데이터 없음) 시뮬레이션의 도착 반경(m).
const _demoArriveRadiusM = 30;

/// 도착 인증 실패 — 안내 문구와 다음 행동(설정 열기·위치 확인 없이 진행)을 고르는 근거.
typedef _ArrivalFailure = ({String message, bool needsSettings, bool noCoords});

/// 조각 서버 기록 실패 — 안내 문구와, 다시 해도 안 되는 실패라 "기록 없이 계속"을 줄지.
typedef _RecordFailure = ({String message, bool canSkip});

/// 서버 기록을 기다리는 챕터 확정 — 다시 시도·기록 없이 계속이 같은 챕터를 이어받는다.
/// [onClaimed]는 확정된 뒤의 화면 반영(조각 수·획득 팝업·엔딩 등).
typedef _PendingClaim = ({int chapterIdx, List<StateRef> extra, Future<void> Function() onClaimed});

/// 조각 서버 기록 결과 — 실패 사유(성공이면 null)와 서버가 준 보상(기록하지 않았으면 null).
typedef _RecordResult = ({_RecordFailure? failure, NodeReward? reward});

/// 방금 확정된 조각 — 획득 팝업이 읽는다. 팝업이 뜰 때는 조각 수가 이미 올라
/// "지금 챕터"가 다음 장소를 가리키므로, 확정 순간의 챕터·받은 것을 따로 들고 있어야 한다.
typedef _ClaimedReward = ({int chapterIdx, List<StateRef> extra, NodeReward? reward});

// ── 시안 팔레트(로컬 상수) ──────────────────────────────
const _ink = Color(0xFF17130F); // 먹빛
const _inkDeep = Color(0xFF0D0B09);
const _cream = Color(0xFFF2EAD8); // 한지 크림 텍스트
const _muted = Color(0xFF8A8378);
const _soft = Color(0xFFC9C1B2);
const _gold = Color(0xFFF4C860);
const _goldDim = Color(0xFFD9A441);
const _verm = Color(0xFFC8452C); // 단청 주홍
const _teal = Color(0xFF6FD4C1);
const _tealDeep = Color(0xFF2A8577);
const _blue = Color(0xFF6FB8D4);
const _parchTop = Color(0xFFF7F1E2);
const _parchBot = Color(0xFFEEE4CD);
const _parchInk = Color(0xFF2A2118);
const _parchInkSoft = Color(0xFF4A3D2C);
const _bronze = Color(0xFF8A7448);

String _won(int n) {
  final s = n.toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
    b.write(s[i]);
  }
  return '$b원';
}

/// 여정 챕터(목표 장소) — 시안 targets 구조 + **그 챕터를 담당하는 실제 노드**.
///
/// node가 있으면 게이팅(requires)·힌트 사다리·grants는 전부 노드 기준으로 돈다.
/// node가 null이면 시안 기본값만으로 구르는 데모 모드(스키마 미대응 구간).
class _Target {
  final String name, hanja, title, obj, after; // after: summon-meok|cafe|insa|summon-sejong
  final int dist0;
  final QuestNode? node;
  const _Target(this.name, this.hanja, this.dist0, this.title, this.obj, this.after, {this.node});

  /// 이 챕터에서 얻는 단서 이름(단서설계규칙) — 없으면 시안 기본 체인.
  String? get clue => node?.clueName;
}

const _defaultTargets = <_Target>[
  _Target('운현궁', '宮', 550, '운현궁의 먹그림자', '운현궁 대문 앞에서 먹 도깨비를 소환하라', 'summon-meok'),
  _Target('익선동 한옥 카페', '茶', 650, '가마솥에 떨어진 글씨', '申時의 단서를 들고 차 한 잔을 시켜라', 'cafe'),
  _Target('인사동 붓방', '筆', 800, '붓방 간판의 모음', '전통 간판을 담아 모음 ㅏ를 깨워라', 'insa'),
  _Target('광화문 광장', '門', 1200, '마지막 조각, 마음', '세종대왕 앞에서 기억석을 복원하라', 'summon-sejong'),
];

/// 시안 기본 단서 체인(申時→ㄱ→ㅏ) — 노드가 clue를 안 주는 데모 모드 폴백.
const _defaultClues = ['申時', 'ㄱ', 'ㅏ', ''];

/// 코스 데이터 없는 데모 모드의 지역명(시안이 종로 4챕터다).
const _defaultRegion = '종로';

class QuestJourneyScreen extends StatefulWidget {
  /// 도착 인증에 쓸 위치 서비스. 테스트·데모에서 갈아끼운다.
  final LocationService locationService;

  final Scenario? scenario;

  /// 대화(A/B 선택지 답변)에 쓸 API 클라이언트. 테스트가 MockClient로 갈아끼운다.
  final ApiClient? apiClient;

  /// 서버 플레이 세션(run·도착 판정·조각 기록). 테스트가 가짜 서버를 붙인 세션으로 갈아끼운다.
  final RunSession? runSession;

  const QuestJourneyScreen({
    super.key,
    this.scenario,
    this.locationService = const LocationService(),
    this.apiClient,
    this.runSession,
  });
  @override
  State<QuestJourneyScreen> createState() => _QuestJourneyScreenState();
}

class _QuestJourneyScreenState extends State<QuestJourneyScreen> with TickerProviderStateMixin {
  // ── 시안 initState 그대로 ──
  // '새 여정 꾸리기(setup)' 화면 제거 — "도깨비에게 길 묻기" 진입점인 'map'에서 바로 시작.
  String screen = 'map';
  int budget = 20000, hours = 2;
  String? flag;
  int dlgStep = 0;
  late final ApiClient _api = widget.apiClient ?? ApiClient();
  RunSession get _session => widget.runSession ?? RunSession.I;

  // ── 실제 GPS 도착 인증(코스 데이터가 있을 때) ──
  /// 마지막으로 읽은 현재 위치 → _liveDistNodeId 장소까지 거리(m).
  int? _liveDistM;
  String? _liveDistNodeId;
  double? _liveAccuracyM;

  /// 현재 위치를 못 읽은 사유(권한·신호). 읽으면 null.
  String? _locError;

  /// 위치를 못 읽은 이유가 앱 설정으로 가야 풀리는 것인지(권한 영구 거부·위치 서비스 꺼짐).
  bool _locNeedsSettings = false;
  bool _locating = false; // 위치 읽기가 겹치지 않게
  Timer? _gpsPollTimer;

  /// 도착 판정 요청 중 — 버튼 연타 방지.
  bool _arriving = false;

  /// 도착 인증 실패 안내. null이면 안내 없음.
  _ArrivalFailure? _arrivalFailure;

  // ── 조각 서버 기록(확정은 기록 성공 뒤) ──
  /// 서버에 조각을 기록하는 중 — 공통 팝업을 띄우고 연타를 막는다.
  bool _recording = false;

  /// 조각 기록 실패. null이면 실패 없음.
  _RecordFailure? _recordFailure;

  /// 기록을 기다리는(또는 실패한) 챕터 확정 — 다시 시도·기록 없이 계속이 이어받는다.
  _PendingClaim? _pendingClaim;

  /// 방금 확정된 조각 — 획득 팝업이 읽는다(확정되면 조각 수가 올라 "지금 챕터"는 다음 장소가 된다).
  _ClaimedReward? _claimed;

  /// 도착 인증을 건너뛴 장소(서버가 좌표 없는 장소라고 함) — 서버가 기록을 거절하니 시도하지 않는다.
  final Set<String> _unrecordedNodeIds = {};
  // A/B("사연이오?"/"보상은?")는 dialogueTurn으로 실제 장소 정보를 물어 받는다.
  // C(바로 진행)는 안 물어보므로 대상 없음. 실패하면 _npcLines 고정 문구로 폴백.
  bool _dialogueLoading = false;
  String? _liveAnswer;
  String quizState = 'idle';
  int fragments = 0, coupon = 0, spent = 0, exp = 0, brush = 3;
  late List<Map<String, dynamic>> enemies = [
    {'id': 1, 'left': .38, 'top': .30, 'size': 96.0, 'dur': 3.0, 'dead': false},
    {'id': 2, 'left': .12, 'top': .48, 'size': 64.0, 'dur': 3.6, 'dead': false},
    {'id': 3, 'left': .68, 'top': .44, 'size': 72.0, 'dur': 2.8, 'dead': false},
    {'id': 4, 'left': .26, 'top': .22, 'size': 58.0, 'dur': 3.3, 'dead': false},
    {'id': 5, 'left': .62, 'top': .20, 'size': 54.0, 'dur': 2.6, 'dead': false},
  ];
  // 위 초기값은 데모(노드 데이터 없음) 폴백 — 실제 노드에서는 _prepareHuntEnemies()가
  // defeat/tap 원자의 이름·개수로 다시 채운다.
  String huntLabel = '먹그림자 처치';
  // S1(대화→수집)·S6(수집 누적) 전용 — 전투 없는 탭 수집 화면(_gatherScreen).
  List<Map<String, dynamic>> gatherItems = [];
  String gatherLabel = '글씨조각 수집';
  String photoState = 'idle';
  int scan = 0;
  int trail = 0;
  bool fragTaken = false, showReward = false;
  bool hintOpen = false;
  bool cafeOrdered = false;
  String insaPhase = 'photo';
  int insaScan = 0;
  String insaPick = '';
  String insaState = 'idle';
  bool sideOpen = false, sideDone = false;
  String? ending;
  int gpsIdx = 0, gpsDist = 550;
  bool gpsWalking = false;
  String? summonFor; // meok | sejong
  String summonPhase = 'scan';
  bool collOpen = false;

  // ── 실제 AR(ARKit) ──
  // null=확인 중, true=NativeArView(카메라+3D 마커), false=기존 2D 연출 폴백
  // (시뮬레이터·미지원 기기·Android). 세션 에러가 나면 그 자리에서 2D로 강등.
  bool? _arSupported;
  bool _arError = false;

  late List<_Target> targets;

  // ── 상태 그래프 (시나리오구조화 3절) ──
  /// 이 플레이의 누적 상태(조각·단서·플래그·친밀도·쿠폰·유물). 진행률·게이팅·엔딩의 기준.
  final PlayerState pstate = PlayerState();

  /// 갈림길 선택 `{분기노드id: choiceId}` — playedPath 순회에 그대로 넘긴다.
  final Map<String, String> branchChoices = {};

  /// 안내 모드(D1/D2) 표시용 판정 결과. null이면 안내 없음.
  RequireCheck? guidance;

  /// 갈림길 선택 대기 중인 노드(있으면 갈림길 화면).
  QuestNode? branchAt;

  /// 힌트 사다리 — 문구는 노드/콘텐츠, 타이밍은 이 컨트롤러(H1 fail1|idle60 → H2 idle90 → H3 요청).
  HintLadderController? _hint;

  HintLadderController get hint => _hint ??= _newHint();

  // ── 애니메이션 컨트롤러 ──
  // initState에서 생성한다. `late final ... = AnimationController(...)`(지연 초기화)로 두면
  // setup 화면만 보고 뒤로 나갈 때 dispose()의 `_float.dispose()`가 **그 자리에서 컨트롤러를
  // 처음 생성**하고, unmount 중 TickerMode 조상 조회가 일어나 크래시한다.
  late final AnimationController _float;
  late final AnimationController _pulse;
  late final AnimationController _glow;

  Timer? _walkTimer, _scanTimer, _summonTimer;

  @override
  void initState() {
    super.initState();
    _float = AnimationController(vsync: this, duration: const Duration(milliseconds: 3200))
      ..repeat(reverse: true);
    _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))..repeat();
    _glow = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))
      ..repeat(reverse: true);
    _restoreProgress();
    targets = _resolveTargets(widget.scenario);
    fragments = math.min(_stoneTotal, fragments);   // 코스보다 많은 조각은 표시상 의미 없음
    isArSupported().then((ok) {
      if (mounted) setState(() => _arSupported = ok);
    });
    _ensureRun();
    _startGpsPolling();
  }

  /// 서버 run을 연다(이미 열려 있으면 그대로 쓴다).
  ///
  /// 퀘스트 탭의 '탐험 시작'은 코스 화면을 거치지 않고 바로 이 화면으로 들어와서,
  /// run이 없는 채로 플레이가 끝나면 조각·경험치가 서버에 하나도 안 남는다.
  /// 실패해도 연출은 그대로 진행한다(서버 없이도 데모가 돌아야 한다).
  Future<void> _ensureRun() async {
    final s = widget.scenario;
    if (s == null) return;
    await _session.start(s.scenarioId);
  }

  /// 저장된 진행 복원 — 갈림길 선택·인벤토리를 먼저 읽어야 경로가 확정된다.
  void _restoreProgress() {
    final s = widget.scenario;
    if (s == null) return;
    branchChoices.addAll(ScenarioStore.I.choicesOf(s.scenarioId));
    pstate.applyAll(
        ScenarioStore.I.inventoryOf(s.scenarioId).map(StateRef.parse));
    fragments = pstate.fragments.length;      // 캡은 targets 확정 후(initState)에서
    coupon = pstate.couponTotal;
  }

  /// Scenario → 챕터 매핑. **실제 밟는 경로(playedPath)의 조각 노드**를 쓴다 —
  /// 갈림길을 b1로 골랐으면 샛길 노드가 챕터로 들어온다. 없으면 종로 기본값.
  List<_Target> _resolveTargets(Scenario? s) {
    if (s == null) return _defaultTargets;
    final stones = s.playedPath(branchChoices).where((n) => n.isStone).toList();
    if (stones.isEmpty) return _defaultTargets;
    return [
      for (var i = 0; i < stones.length; i++) _targetOf(stones[i], i, stones.length),
    ];
  }

  /// 조각 노드 1개 → 챕터. 시안 상수(한자·스테이지)는 순환해 쓰고, 문구는 데이터 우선.
  ///
  /// 예전에는 정확히 4개만 만들었다(`for i < 4`) — 코스가 짧으면 종로 기본 노드로 채우고
  /// 길면 잘라냈다. 탐험 시간 입력이 코스 길이(4·6·8조각)를 바꾸면서 그대로 두면
  /// 6조각 코스가 화면에서 4챕터로 보이고, 있지도 않은 운현궁이 챕터로 끼어든다.
  /// 도착 직후 스테이지 — 항상 도깨비 소환(AR 등장)부터. 실제 미션 갈래(사냥·사진·
  /// 퀴즈…)는 대화가 끝난 뒤 strategy로 정한다(_missionStageFor 참고) — 백엔드가
  /// 모든 노드에 goto+listen(대화)을 먼저 컴파일해 넣는 것과 맞춘다. 예전엔 PHOTO_FIND/
  /// PATH_TRACE/HUNT 노드가 대화 자체를 건너뛰고 바로 미션으로 들어갔었다.
  static String _stageFor(bool isFinale) => isFinale ? 'summon-sejong' : 'summon-meok';

  _Target _targetOf(QuestNode n, int i, int total) {
    final isFinale = i == total - 1;
    // 마지막은 항상 '기억석 복원' 스테이지 — 피날레의 의미가 거기 붙어 있다.
    final base = isFinale
        ? _defaultTargets.last
        : _defaultTargets[i % (_defaultTargets.length - 1)];
    final name = n.name ?? base.name;
    // 시안 제목은 종로 정답지 노드에서만 맞는다 — 다른 장소엔 장소명으로 지은 제목을 쓴다.
    final title = name == base.name
        ? base.title
        : (isFinale ? '마지막 조각, $name' : '$name에 잠든 글씨');
    return _Target(
      name,
      base.hanja,
      n.distM?.round() ?? base.dist0,
      title,
      n.objective?.order.isNotEmpty == true
          ? n.objective!.order
          : (n.mission?.order.isNotEmpty == true
              ? n.mission!.order
              // 지령이 없는 노드에 시안 문구를 그대로 쓰면 딴 장소 지령이 뜬다
              // ('운현궁 대문 앞에서…'가 강남 노드에). 장소명으로 만든 기본 지령을 쓴다.
              : (name == base.name ? base.obj : '$name 주변을 살펴 기억석 조각을 찾아라.')),
      _stageFor(isFinale),
      node: n,
    );
  }

  /// 대화 이후 실제로 밟을 미션 화면 — node.strategy(S1~S7) 기준.
  /// strategy가 없는 노드(시나리오 없는 데모 등)는 예전 mission.type 기준으로 폴백해
  /// 기존 동작을 그대로 유지한다.
  String _missionStageFor(QuestNode? node) {
    final code = node?.strategy.isNotEmpty == true ? strategyCode(node!.strategy.first) : null;
    switch (code) {
      case 'S3':
        return 'quiz';
      case 'S4':
      case 'S5':
        return 'photo';
      case 'S7':
        return 'cafe';
      case 'S2':
        return 'hunt';
      case 'S1':
      case 'S6':
        return 'gather'; // 전투 없이 tap만(대화→수집/수집 누적) — 전용 화면
    }
    // 폴백(strategy 미대응 노드) — 예전 mission.type 분기 그대로.
    switch (node?.mission?.type) {
      case 'PHOTO_FIND':
      case 'PATH_TRACE':
        return 'photo';
      case 'HUNT':
        return 'hunt';
      default:
        return node?.quiz == null ? 'hunt' : 'quiz';
    }
  }

  /// 현재 챕터 노드의 컴파일된 액션 원자 중 타입이 `type`인 첫 번째 것.
  ActionAtom? _actionAtom(String type) {
    for (final a in _curNode?.actions ?? const <ActionAtom>[]) {
      if (a.a == type) return a;
    }
    return null;
  }

  static const _huntPositions = [
    (.38, .30), (.12, .48), (.68, .44), (.26, .22), (.62, .20), (.50, .58),
  ];

  /// 사냥 화면(_huntScreen)을 이 챕터의 실제 데이터로 다시 채운다 — defeat
  /// 원자가 있으면 몬스터 이름·마릿수(S2), 없으면 tap 원자의 대상·개수(S1/S6,
  /// 전투 없이 수집만). 둘 다 없으면(데모) 원래 종로 기본값(먹그림자 5마리)로.
  void _prepareHuntEnemies() {
    final defeat = _actionAtom('defeat');
    final tap = _actionAtom('tap');
    final atom = defeat ?? tap;
    final count = (atom?.countTarget ?? 5).clamp(1, _huntPositions.length);
    huntLabel = defeat != null
        ? '${defeat.object ?? '먹그림자'} 처치'
        : '${tap?.target ?? '흔적'} 수집';
    enemies = [
      for (var i = 0; i < count; i++)
        {
          'id': i,
          'left': _huntPositions[i].$1,
          'top': _huntPositions[i].$2,
          'size': 92.0 - i * 6,
          'dur': 2.6 + (i % 4) * 0.3,
          'dead': false,
        },
    ];
  }

  /// 수집 화면(_gatherScreen)을 이 챕터의 실제 데이터로 다시 채운다 — S1/S6은
  /// 전투 없이 tap 원자 대상·개수만 있다(_prepareHuntEnemies와 갈래만 다름).
  void _prepareGatherItems() {
    final tap = _actionAtom('tap');
    final count = (tap?.countTarget ?? 1).clamp(1, _huntPositions.length);
    gatherLabel = '${tap?.target ?? '글씨조각'} 수집';
    gatherItems = [
      for (var i = 0; i < count; i++)
        {
          'id': i,
          'left': _huntPositions[i].$1,
          'top': _huntPositions[i].$2,
          'size': 64.0,
          'collected': false,
        },
    ];
  }

  /// 현재 챕터의 힌트 사다리 컨트롤러(문구=노드 hint_ladder, 없으면 시안 문구).
  HintLadderController _newHint() {
    final ladder = _target.node?.hints ??
        const HintLadder(h1: '"그늘은 해가 드는 반대편이니라."', h2: '"이로당 처마를 보거라."');
    return HintLadderController(
      ladder: ladder.isEmpty
          ? const HintLadder(h1: '"그늘은 해가 드는 반대편이니라."', h2: '"이로당 처마를 보거라."')
          : ladder,
    )
      ..addListener(_onHintChanged)
      ..start();
  }

  void _onHintChanged() {
    if (mounted) setState(() {});
  }

  /// 챕터가 바뀌면 사다리 초기화(다음 노드의 문구·타이밍으로 갈아끼움).
  void _resetHintForChapter() {
    _hint?.removeListener(_onHintChanged);
    _hint?.dispose();
    _hint = null;
  }

  @override
  void dispose() {
    _float.dispose();
    _pulse.dispose();
    _glow.dispose();
    _walkTimer?.cancel();
    _scanTimer?.cancel();
    _summonTimer?.cancel();
    _gpsPollTimer?.cancel();
    _hint?.removeListener(_onHintChanged);
    _hint?.dispose();
    super.dispose();
  }

  void go(String s) => setState(() => screen = s);

  /// 이 코스의 조각 총수 — 실제 밟는 챕터 수. 데모(시나리오 없음)는 기본 4.
  int get _stoneTotal => targets.isEmpty ? _defaultTargets.length : targets.length;

  int get _tIdx => math.min(_stoneTotal - 1, fragments);
  _Target get _target => targets[_tIdx];

  /// 지금 챕터의 노드(데모 모드면 null). 퀴즈·NPC 이름·대사의 출처.
  QuestNode? get _curNode => targets.isEmpty ? null : targets[_tIdx].node;

  /// 이 챕터에 낼 시험이 있나 — 없으면 시험 단계를 통째로 건너뛴다.
  Quiz? get _curQuiz => _curNode?.quiz;

  /// 이 장소를 지키는 도깨비 이름(없으면 시안 기본값).
  String get _npcName {
    final n = _curNode?.npcName ?? '';
    return n.isEmpty ? '먹 도깨비' : n;
  }

  // ── 스캔 진행(사진·인사동) ──
  void _startScan(String key) {
    _scanTimer?.cancel();
    _scanTimer = Timer.periodic(const Duration(milliseconds: 70), (t) {
      setState(() {
        if (key == 'photo') {
          scan = math.min(100, scan + 7);
          if (scan >= 100) {
            t.cancel();
            Timer(const Duration(milliseconds: 250), () => setState(() => photoState = 'done'));
          }
        } else {
          insaScan = math.min(100, insaScan + 7);
          if (insaScan >= 100) {
            t.cancel();
            Timer(const Duration(milliseconds: 250), () => setState(() => insaPhase = 'combine'));
          }
        }
      });
    });
  }

  void _walk() {
    if (gpsWalking) return;
    setState(() => gpsWalking = true);
    _walkTimer?.cancel();
    _walkTimer = Timer.periodic(const Duration(milliseconds: 130), (t) {
      setState(() {
        final d = math.max(12, gpsDist - 48);
        gpsDist = d;
        if (d <= 30) {
          t.cancel();
          gpsWalking = false;
        }
      });
    });
  }

  /// 이 챕터를 실제 GPS로 인증하는가 — 코스 노드가 있으면 실제, 없으면(데모) 시뮬레이션.
  bool _usesRealGps(_Target t) => widget.scenario != null && t.node != null;

  /// 마지막으로 읽은 위치 기준 이 챕터 장소까지 거리. 아직 못 읽었으면 null.
  int? _liveDistTo(_Target t) =>
      t.node != null && _liveDistNodeId == t.node!.nodeId ? _liveDistM : null;

  static String _distLabel(int m) =>
      m >= 1000 ? '${(m / 1000).toStringAsFixed(1)}km' : '${m}m';

  /// 지도·이동 화면에 있는 동안 현재 위치를 주기적으로 읽는다(데모 모드는 시뮬레이션이라 안 읽음).
  void _startGpsPolling() {
    if (widget.scenario == null) return;
    _refreshLiveDistance();
    _gpsPollTimer = Timer.periodic(_gpsPollInterval, (_) => _refreshLiveDistance());
  }

  /// 현재 위치 → 지금 목표 장소까지 실제 거리 갱신. 미션 등 다른 화면에서는 읽지 않는다.
  Future<void> _refreshLiveDistance() async {
    if (_locating || (screen != 'map' && screen != 'gps')) return;
    final n = (screen == 'gps' ? targets[gpsIdx] : _target).node;
    if (n == null || n.mapY == null || n.mapX == null) return;
    _locating = true;
    final loc = await widget.locationService.current();
    _locating = false;
    if (!mounted) return;
    setState(() {
      if (loc.isOk) {
        _liveDistM = haversineMeters(loc.lat!, loc.lng!, n.mapY!, n.mapX!).round();
        _liveDistNodeId = n.nodeId;
        _liveAccuracyM = loc.accuracyM;
        _locError = null;
        _locNeedsSettings = false;
      } else {
        _locError = loc.message;
        _locNeedsSettings = loc.needsSettings;
      }
    });
  }

  /// 도착 인증(실제 GPS) — 서버 판정을 통과해야 소환(_verifyGps)으로 넘어간다.
  /// 실패하면 사유와 다음 행동(다시 확인·설정 열기·위치 확인 없이 진행)을 보여준다.
  Future<void> _arrive() async {
    if (_arriving) return;
    final t = targets[gpsIdx];
    // 피날레 안내 모드는 위치와 무관하다 — 판정 요청 전에 먼저 보여준다.
    final check = _checkTarget(t);
    if (check != null && check.needsGuidance) {
      setState(() => guidance = check);
      return;
    }
    setState(() {
      _arriving = true;
      _arrivalFailure = null;
    });
    // 이미 도착 인증한 장소(재진입·앱 재시작)는 서버에 다시 묻지 않는다 — 서버 run 기록 기준.
    // 다만 위치 권한·위치 서비스는 확인한다(좌표는 안 읽어 실내 신호 약함엔 막히지 않는다).
    final failure = _session.isVerified(t.node!.nodeId)
        ? await _checkLocationAccess()
        : await _requestArrival(t.node!);
    if (!mounted) return;
    setState(() {
      _arriving = false;
      _arrivalFailure = failure;
    });
    if (failure == null) _verifyGps();
  }

  /// 이미 도착 인증한 장소 — 위치 권한·위치 서비스만 확인한다. 쓸 수 있으면 null.
  /// 디버그 빌드에서 개발자 옵션을 켜면 확인을 건너뛴다(이동 없이 테스트).
  Future<_ArrivalFailure?> _checkLocationAccess() async {
    if (kDebugMode && DebugFlags.skipGpsVerify) return null;
    final denied = await widget.locationService.checkAccess();
    if (denied == null) return null;
    final result = LocationResult.fail(denied);
    return (message: result.message, needsSettings: result.needsSettings, noCoords: false);
  }

  /// 서버에 도착 판정을 요청한다. 통과면 null, 아니면 실패 사유.
  /// 디버그 빌드에서 개발자 옵션을 켜면 실제 위치 대신 장소 좌표를 보낸다(이동 없이 테스트).
  Future<_ArrivalFailure?> _requestArrival(QuestNode n) async {
    _ArrivalFailure fail(String message, {bool needsSettings = false, bool noCoords = false}) =>
        (message: message, needsSettings: needsSettings, noCoords: noCoords);

    // run이 없으면(앞서 서버 연결 실패) 여기서 다시 연다 — 다시 확인이 곧 재시도다.
    if (!_session.isActive && !await _session.start(widget.scenario!.scenarioId)) {
      return fail(_session.error ?? '서버에 연결되지 않았느니라.');
    }
    final double lat, lng;
    double? accuracyM;
    if (kDebugMode && DebugFlags.skipGpsVerify && n.mapY != null && n.mapX != null) {
      lat = n.mapY!;
      lng = n.mapX!;
    } else {
      final loc = await widget.locationService.current();
      if (!loc.isOk) return fail(loc.message, needsSettings: loc.needsSettings);
      lat = loc.lat!;
      lng = loc.lng!;
      accuracyM = loc.accuracyM;
    }
    final verdict =
        await _session.verify(nodeId: n.nodeId, lat: lat, lng: lng, accuracyM: accuracyM);
    if (verdict == null) return fail(_session.error ?? '서버와 통신하지 못했느니라.');
    if (!verdict.verified) {
      return fail(verdict.message, noCoords: verdict.reason == VerifyReason.nodeHasNoCoords);
    }
    return null;
  }

  /// 서버가 좌표 없는 장소라 위치를 확인할 수 없을 때의 탈출구 — 진행은 하되 조각은 서버에 남지 않는다.
  void _skipArrival() {
    setState(() => _arrivalFailure = null);
    _unrecordedNodeIds.add(targets[gpsIdx].node!.nodeId);
    _verifyGps();
  }

  void _verifyGps() {
    final t = targets[gpsIdx];

    // ── 도착 판정 전 게이팅(3절 규칙 1조) — 미충족은 차단이 아니라 안내 ──
    final check = _checkTarget(t);
    if (check != null && check.needsGuidance) {
      // D1/D2: 피날레 하드 requires 미충족 → 안내 모드(미완료 거점 짚어주기)
      setState(() => guidance = check);
      return;
    }
    if (check != null && check.softMissing) {
      // D4: 소프트 미충족 → 진행은 하되 연계 대사를 못 받는다는 것만 알린다
      _snack('${check.missing.map((m) => m.label).join('·')} 없이 왔구나. 도깨비가 알아보지 못할 것이야.');
    }

    // ── 갈림길: 이 노드가 분기점이면 선택을 먼저 받는다 ──
    final bp = _branchPointAt(t);
    if (bp != null) {
      setState(() => branchAt = bp);
      return;
    }

    // 실제 노드(시나리오 있음)는 after가 항상 summon-meok/summon-sejong —
    // 모든 챕터가 소환(AR 등장) → 대화부터 시작한다(실제 미션 갈래는 대화 뒤
    // strategy로 정해진다). cafe/insa는 시나리오 없는 데모 전용 고정 스테이지라
    // 예전처럼 소환 없이 바로 들어간다.
    if (t.after == 'cafe' || t.after == 'insa') {
      go(t.after);
      return;
    }
    setState(() {
      screen = 'summon';
      summonFor = t.after == 'summon-sejong' ? 'sejong' : 'meok';
      summonPhase = 'scan';
    });
    _summonTimer?.cancel();
    _summonTimer = Timer(const Duration(milliseconds: 1500), () => setState(() => summonPhase = 'appear'));
  }

  /// 이 챕터 노드의 requires 판정. 시나리오/노드가 없으면 null(게이팅 없음).
  RequireCheck? _checkTarget(_Target t) {
    final s = widget.scenario;
    final n = t.node;
    if (s == null || n == null || n.requires.isEmpty) return null;
    return s.checkEntry(n, pstate);
  }

  /// 이 챕터 노드가 아직 선택 안 된 갈림길인가.
  QuestNode? _branchPointAt(_Target t) {
    final n = t.node;
    if (n?.branch == null) return null;
    if (branchChoices.containsKey(n!.nodeId)) return null;
    return n;
  }

  /// 갈림길 선택 확정 — 저장하고 경로(targets)를 다시 계산한다.
  Future<void> _pickBranch(QuestNode bp, BranchOption opt) async {
    branchChoices[bp.nodeId] = opt.choiceId;
    final s = widget.scenario;
    if (s != null) await ScenarioStore.I.chooseBranch(s.scenarioId, bp.nodeId, opt.choiceId);
    if (!mounted) return;
    setState(() {
      targets = _resolveTargets(widget.scenario);
      branchAt = null;
    });
    _verifyGps(); // 선택 후 그 갈래로 계속 진행
  }

  /// 챕터 보상 확정 — grants를 상태 그래프에 적용하고 영속한다(규칙 5조: 단서는 조각과 동봉).
  ///
  /// 노드가 없으면 시안 기본 조각·단서로 대체해 데모 모드에서도 인벤토리가 쌓인다.
  Future<void> _grantChapter(int chapterIdx, {List<StateRef> extra = const []}) async {
    final t = targets[chapterIdx.clamp(0, targets.length - 1)];
    final n = t.node;
    final refs = <StateRef>[
      if (n != null)
        ...n.effectiveGrants
      else ...[
        StateRef(kind: StateKind.fragment, value: '글씨조각${chapterIdx + 1}'),
        if (_defaultClues[chapterIdx.clamp(0, 3)].isNotEmpty)
          StateRef(kind: StateKind.clue, value: _defaultClues[chapterIdx.clamp(0, 3)]),
      ],
      ...extra,
    ];
    pstate.applyAll(refs);
    _resetHintForChapter(); // 다음 챕터 사다리로 교체

    final s = widget.scenario;
    if (s == null) return;
    if (n != null) {
      await ScenarioStore.I.completeNodeWithGrants(s.scenarioId, n, extra: extra);
    } else {
      await ScenarioStore.I
          .completeNode(s.scenarioId, 'chapter_$chapterIdx', refs.map((r) => r.toStorageString()).toList());
    }
  }

  /// 지금 챕터 조각 확정(일반 챕터) — 서버에 기록되면 조각 수를 올리고 획득 팝업을 띄운다.
  /// [also]는 그 챕터 고유의 화면 반영(발자국 파편 거두기·카페 주문 완료 등) — 확정될 때 함께 적용한다.
  void _claimCurrentChapter({List<StateRef> extra = const [], VoidCallback? also}) {
    final idx = _tIdx; // 확정되면 fragments가 바뀌어 _tIdx도 바뀐다 — 지금 챕터를 먼저 읽어 둔다
    _claimChapter(idx, extra: extra, onClaimed: () async {
      setState(() {
        also?.call();
        fragments = idx + 1;
        showReward = true;
      });
    });
  }

  /// 챕터 조각 확정 — 서버 기록(collect·complete)이 성공해야 화면(onClaimed)과 로컬 진행(_grantChapter)에
  /// 반영한다. 실패하면 공통 팝업(_recordSheet)으로 이유와 다시 시도를 보여준다 — 조각의 주인은 서버다.
  Future<void> _claimChapter(int idx,
      {List<StateRef> extra = const [], required Future<void> Function() onClaimed}) async {
    if (_recording) return;
    final claim = (chapterIdx: idx, extra: extra, onClaimed: onClaimed);
    setState(() {
      _recording = true;
      _recordFailure = null;
      _pendingClaim = claim;
    });
    final result = await _recordOnServer(targets[idx.clamp(0, targets.length - 1)].node);
    if (!mounted) return;
    setState(() {
      _recording = false;
      _recordFailure = result.failure;
    });
    if (result.failure == null) await _confirmClaim(claim, result.reward);
  }

  /// 확정 반영 — 서버 기록이 성공했거나, 다시 해도 안 되는 실패에서 "기록 없이 계속"을 골랐을 때.
  /// [reward]는 서버가 준 보상 — 기록하지 못한 조각이면 null이고, 획득 팝업이 그대로 보여준다.
  Future<void> _confirmClaim(_PendingClaim claim, NodeReward? reward) async {
    setState(() {
      _pendingClaim = null;
      _recordFailure = null;
      _claimed = (chapterIdx: claim.chapterIdx, extra: claim.extra, reward: reward);
    });
    await claim.onClaimed();
    await _grantChapter(claim.chapterIdx, extra: claim.extra);
  }

  /// 챕터 조각을 서버 run에 기록한다(collect → complete) — 조각·경험치·도감·칭호가 여기서 나온다.
  /// 성공하면 서버가 준 보상을, 서버에 기록할 수 없는 챕터면 둘 다 null을,
  /// 실패하면 사유(다시 해도 안 되는 실패인지 포함)를 돌려준다.
  ///
  /// 위치는 다시 확인하지 않는다 — 도착 인증(_arrive)에서 서버에 방문이 이미 남았다.
  /// 서버 run이 없으면(앱 재시작 후 복원 실패 등) 여기서 다시 연다 — 다시 시도가 곧 재연결이다.
  Future<_RecordResult> _recordOnServer(QuestNode? n) async {
    final s = widget.scenario;
    // 데모 모드(코스 없음)·노드 없는 챕터·도착 인증을 건너뛴 장소는 서버가 기록할 수 없다 — 로컬만.
    if (s == null || n == null || _unrecordedNodeIds.contains(n.nodeId)) {
      return (failure: null, reward: null);
    }
    _RecordResult fail() => (
          failure: (
            message: _session.error ?? '조각을 기록하지 못했느니라.',
            canSkip: !_session.errorRetryable,
          ),
          reward: null,
        );
    if (!_session.isActive && !await _session.start(s.scenarioId)) return fail();
    if (n.fragmentId.isNotEmpty && await _session.collect(n.nodeId) == null) return fail();
    final reward = await _session.complete(
      n.nodeId,
      choiceId: branchChoices[n.nodeId],   // 갈림길을 골랐으면 그 갈래를 함께 보낸다
    );
    return reward == null ? fail() : (failure: null, reward: reward);
  }

  /// 선택지 효과(플래그·친밀도·쿠폰) 즉시 적용 + 영속. 규칙 2조: grants 종류는 안 바뀐다.
  Future<void> _applyChoice(List<StateRef> refs) async {
    pstate.applyAll(refs);
    final s = widget.scenario;
    if (s != null) await ScenarioStore.I.grant(s.scenarioId, refs);
  }

  /// A/B/C 선택 — 플래그·보상은 원래대로 고정이고(엔딩 분기가 여기 걸려 있다),
  /// A/B(정보를 묻는 선택)만 실제 도깨비 대화(dialogueTurn)로 답을 받는다.
  /// C는 안 물어보는 선택이라 API를 안 탄다. 실패하면 _npcLines 고정 문구로 폴백.
  Future<void> _pickChoice(String letter, String question, List<StateRef> refs,
      {VoidCallback? extra}) async {
    extra?.call();
    if (question.isEmpty) {
      setState(() { flag = letter; dlgStep = 1; });
      await _applyChoice(refs);
      return;
    }
    setState(() { flag = letter; _dialogueLoading = true; });
    final node = _curNode;
    String? answer;
    if (node != null) {
      try {
        final t = await _api.dialogueTurn(
          nodeId: node.nodeId,
          nodeName: node.name,
          fragmentId: node.fragmentId,
          regionId: widget.scenario?.region,
          history: [{'role': 'me', 'text': question}],
          kind: node.kind,
          playerState: {'progress': fragments, 'required': _stoneTotal},
        );
        answer = t.response.isNotEmpty ? t.response : null;
      } catch (_) {
        answer = null; // 실패 → 아래에서 고정 문구로 폴백
      }
    }
    if (!mounted) return;
    setState(() { _liveAnswer = answer; _dialogueLoading = false; dlgStep = 1; });
    await _applyChoice(refs);
  }

  /// 피날레 마감 — 조각 복원 + **엔딩 분기**(3절 규칙 3조: 플래그는 여기서만 지불).
  ///
  /// 세종 앞 마지막 선택(pick)에 누적 플래그를 얹어 결정한다:
  /// - `true`(백성을 위한 글) + 호기심 누적 → `good`
  /// - `true`지만 실리만 쌓였으면 → `normal` (말만 곱게 한 셈)
  /// - `false`(보상부터) → `normal`
  Future<void> _finish(String pick) async {
    final curious = pstate.flags.contains('호기심');
    final resolved = (pick == 'good' && curious) ? 'good' : 'normal';
    // 챕터 번호 하드코딩(옛 4챕터 종로 대본) 제거 — 피날레는 늘 마지막 챕터다.
    // 피날레 조각도 서버 기록이 성공해야 엔딩으로 넘어간다(_claimChapter).
    await _claimChapter(_stoneTotal - 1, onClaimed: () async {
      setState(() {
        ending = resolved;
        screen = 'ending';
        fragments = _stoneTotal;
        exp += 200;
      });
      final s = widget.scenario;
      if (s != null) await ScenarioStore.I.setEnding(s.scenarioId, resolved);
    });
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: _gowun(13.5, _cream)),
      backgroundColor: _inkDeep,
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 3),
    ));
  }

  void _restart() {
    _walkTimer?.cancel();
    _scanTimer?.cancel();
    _summonTimer?.cancel();
    setState(() {
      screen = 'map';
      budget = 20000;
      hours = 2;
      flag = null;
      dlgStep = 0;
      quizState = 'idle';
      fragments = 0;
      coupon = 0;
      spent = 0;
      exp = 0;
      brush = 3;
      for (final e in enemies) {
        e['dead'] = false;
      }
      photoState = 'idle';
      scan = 0;
      trail = 0;
      fragTaken = false;
      showReward = false;
      hintOpen = false;
      cafeOrdered = false;
      insaPhase = 'photo';
      insaScan = 0;
      insaPick = '';
      insaState = 'idle';
      sideOpen = false;
      sideDone = false;
      ending = null;
      gpsIdx = 0;
      gpsDist = 550;
      gpsWalking = false;
      summonFor = null;
      summonPhase = 'scan';
      collOpen = false;
      guidance = null;
      branchAt = null;
      _arrivalFailure = null;
      _recordFailure = null;
      _pendingClaim = null;
      _claimed = null;
      pstate.clear();
      branchChoices.clear();
      targets = _resolveTargets(widget.scenario);
    });
    _resetHintForChapter();
    final s = widget.scenario;
    if (s != null) ScenarioStore.I.resetProgress(s.scenarioId);
  }

  int get _remain => budget - spent;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _ink,
      body: Stack(children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 350),
          switchInCurve: Curves.easeOut,
          transitionBuilder: (child, anim) => FadeTransition(
            opacity: anim,
            child: SlideTransition(
              position: Tween(begin: const Offset(0, 0.04), end: Offset.zero).animate(anim),
              child: child,
            ),
          ),
          child: KeyedSubtree(key: ValueKey(screen), child: _currentScreen()),
        ),
        // 각 화면 HUD와 같은 top(54~58) 라인에 맞춘다 — 그보다 위(상태바 영역)에 두면
        // 시계·배터리와 겹친다. 대신 이 자리를 쓰는 HUD(map/dialogue/order/insa/cafe)는
        // 버튼 폭만큼 안쪽으로 밀어 자리를 냈다(각 화면 주석 참고).
        Positioned(
          top: 58,
          left: 14,
          child: GestureDetector(
            onTap: () => Navigator.of(context).maybePop(),
            child: Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.arrow_back, color: _soft, size: 18),
            ),
          ),
        ),
        if (showReward && _claimed != null) _rewardModal(_claimed!),
        if (_recording || _recordFailure != null) _recordSheet(),
        if (hintOpen) _hintSheet(),
        if (collOpen) _collSheet(),
        if (branchAt != null) _branchSheet(branchAt!),
        if (guidance != null) _guidanceSheet(guidance!),
      ]),
    );
  }

  // ════════════════════════════════════════════════════
  // 갈림길 (route_tree 분기) — 선택지 렌더
  // ════════════════════════════════════════════════════
  Widget _branchSheet(QuestNode bp) {
    final b = bp.branch!;
    return Positioned.fill(child: Stack(children: [
      Container(color: Colors.black.withOpacity(0.62)),
      Align(alignment: Alignment.bottomCenter, child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 36),
        decoration: const BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [_parchTop, _parchBot]),
          borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(child: Container(width: 44, height: 5, decoration: BoxDecoration(color: const Color(0xFFC9B88F), borderRadius: BorderRadius.circular(999)))),
          const SizedBox(height: 14),
          Row(children: [
            Container(
              width: 34, height: 34, alignment: Alignment.center,
              decoration: BoxDecoration(shape: BoxShape.circle, color: _verm.withOpacity(0.12), border: Border.all(color: _verm)),
              child: Text('岐', style: dokkaebiTitle(size: 16, color: _verm)),
            ),
            const SizedBox(width: 10),
            Expanded(child: Text('갈림길', style: dokkaebiTitle(size: 20, color: _parchInk))),
          ]),
          const SizedBox(height: 10),
          Text(b.prompt, style: dokkaebiTitle(size: 15.5, color: _parchInk, height: 1.6)),
          const SizedBox(height: 16),
          for (final o in b.options) ...[
            GestureDetector(
              onTap: () => _pickBranch(bp, o),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: o.choiceId == 'main' ? const Color(0xFFFBF6E9) : _verm.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: o.choiceId == 'main' ? const Color(0xFFD8C9A4) : _verm.withOpacity(0.55), width: 1.5),
                ),
                child: Row(children: [
                  Expanded(child: Text(o.label, style: dokkaebiTitle(size: 14.5, color: _parchInk, height: 1.5))),
                  const SizedBox(width: 8),
                  Text(o.choiceId == 'main' ? '直' : '岐', style: dokkaebiTitle(size: 16, color: o.choiceId == 'main' ? _bronze : _verm)),
                ]),
              ),
            ),
          ],
          const SizedBox(height: 2),
          Center(child: Text('고른 길은 저장되어 이후 동선에 반영되느니라.',
              style: const TextStyle(fontSize: 11.5, color: _bronze))),
        ]),
      )),
    ]));
  }

  // ════════════════════════════════════════════════════
  // 안내 모드 (D1 피날레 직행 / D2 부분 스킵) — 차단이 아니라 길 안내
  // ════════════════════════════════════════════════════
  Widget _guidanceSheet(RequireCheck c) {
    return Positioned.fill(child: Stack(children: [
      GestureDetector(onTap: () => setState(() => guidance = null), child: Container(color: Colors.black.withOpacity(0.62))),
      Align(alignment: Alignment.bottomCenter, child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 36),
        decoration: const BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [_parchTop, _parchBot]),
          borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(child: Container(width: 44, height: 5, decoration: BoxDecoration(color: const Color(0xFFC9B88F), borderRadius: BorderRadius.circular(999)))),
          const SizedBox(height: 14),
          Row(children: [
            Container(
              width: 34, height: 34, alignment: Alignment.center,
              decoration: BoxDecoration(shape: BoxShape.circle, color: _gold.withOpacity(0.16), border: Border.all(color: _goldDim)),
              child: Text('守', style: dokkaebiTitle(size: 16, color: const Color(0xFF7A5A12))),
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(c.isPartial ? '아직 이르니라' : '길을 짚어 주마', style: dokkaebiTitle(size: 20, color: _parchInk))),
          ]),
          const SizedBox(height: 12),
          // 수호급 NPC의 안내 문구 — 획득처를 역추적해 생성
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: const Color(0xFF2A2118).withOpacity(0.06),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFD8C9A4)),
            ),
            child: Text(c.guidance(), style: dokkaebiTitle(size: 15, color: _parchInk, height: 1.6)),
          ),
          const SizedBox(height: 14),
          // 가진 것 / 남은 것 (D2 부분 인지)
          if (c.held.isNotEmpty) ...[
            Text('이미 지닌 것', style: dokkaebiTitle(size: 13, color: _bronze)),
            const SizedBox(height: 6),
            Wrap(spacing: 6, runSpacing: 6, children: [
              for (final h in c.held) _stateChip(h.label, got: true),
            ]),
            const SizedBox(height: 12),
          ],
          Text('남은 것 — 미완료 거점', style: dokkaebiTitle(size: 13, color: _verm)),
          const SizedBox(height: 6),
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final m in c.missing) _stateChip(m.label, got: false),
          ]),
          if (c.highlightPlaces.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text('들러야 할 곳 · ${c.highlightPlaces.join(' · ')}',
                style: const TextStyle(fontSize: 12, color: _bronze, height: 1.5)),
          ],
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: GestureDetector(
              onTap: () => setState(() { guidance = null; screen = 'map'; }),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                alignment: Alignment.center,
                decoration: BoxDecoration(color: _parchInk, borderRadius: BorderRadius.circular(12)),
                child: Text('진행판 보기', style: dokkaebiTitle(size: 14.5, color: _cream, weight: FontWeight.w700)),
              ),
            )),
          ]),
          const SizedBox(height: 8),
          Center(child: GestureDetector(
            onTap: () => setState(() => guidance = null),
            child: const Text('닫기', style: TextStyle(fontSize: 12.5, color: _bronze, fontWeight: FontWeight.w700)),
          )),
        ]),
      )),
    ]));
  }

  Widget _stateChip(String label, {required bool got}) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
        decoration: BoxDecoration(
          color: got ? const Color(0xFFFBF6E9) : const Color(0x0A2A2118),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: got ? _tealDeep.withOpacity(0.6) : const Color(0xFFC9B88F)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(got ? '✓' : '✕', style: TextStyle(fontSize: 11, color: got ? _tealDeep : _bronze, fontWeight: FontWeight.w900)),
          const SizedBox(width: 5),
          Text(label, style: dokkaebiTitle(size: 13, color: got ? _parchInk : _bronze)),
        ]),
      );

  Widget _currentScreen() {
    switch (screen) {
      case 'map':
        return _mapScreen();
      case 'gps':
        return _gpsScreen();
      case 'summon':
        return _summonScreen();
      case 'dialogue':
        return _dialogueScreen();
      case 'quiz':
        return _quizScreen();
      case 'order':
        return _orderScreen();
      case 'hunt':
        return _huntScreen();
      case 'gather':
        return _gatherScreen();
      case 'photo':
        return _photoScreen();
      case 'trail':
        return _trailScreen();
      case 'cafe':
        return _cafeScreen();
      case 'insa':
        return _insaScreen();
      case 'sejong':
        return _sejongScreen();
      case 'ending':
        return _endingScreen();
    }
    return _mapScreen();
  }

  // ════════════════════════════════════════════════════
  // 공통 조각
  // ════════════════════════════════════════════════════
  Widget _pill(String text, {Color border = _goldDim, Color? textColor, Color bg = _inkDeep, double opacity = 0.72}) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
        decoration: BoxDecoration(
          color: bg.withOpacity(opacity),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: border.withOpacity(0.5)),
        ),
        child: Text(text, style: TextStyle(color: textColor ?? _cream, fontSize: 13, fontWeight: FontWeight.w700)),
      );

  Widget _cta(String text, VoidCallback onTap,
          {Color bg = _verm, Color fg = const Color(0xFFFDF6E6), Gradient? gradient, double fontSize = 15}) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          height: 50,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: gradient == null ? bg : null,
            gradient: gradient,
            borderRadius: BorderRadius.circular(13),
            boxShadow: [BoxShadow(color: bg.withOpacity(0.4), blurRadius: 16, offset: const Offset(0, 6))],
          ),
          child: Text(text, style: TextStyle(color: fg, fontWeight: FontWeight.w900, fontSize: fontSize)),
        ),
      );

  static const _goldGrad = LinearGradient(
    begin: Alignment.topRight, end: Alignment.bottomLeft,
    colors: [Color(0xFFE8C268), Color(0xFFC89A3A)],
  );

  Widget _parchment({required Widget child, EdgeInsets padding = const EdgeInsets.fromLTRB(18, 16, 18, 16)}) => Container(
        padding: padding,
        decoration: BoxDecoration(
          gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [_parchTop, _parchBot]),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFD8C9A4)),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.55), blurRadius: 44, offset: const Offset(0, -12))],
        ),
        child: child,
      );

  Widget _progress(double v, {Gradient grad = const LinearGradient(colors: [_blue, Color(0xFF3A8DB4)]), Color track = const Color(0x1F2A2118)}) =>
      ClipRRect(
        borderRadius: BorderRadius.circular(999),
        child: Container(
          height: 10,
          color: track,
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: v.clamp(0.0, 1.0),
            child: Container(decoration: BoxDecoration(gradient: grad)),
          ),
        ),
      );

  // ════════════════════════════════════════════════════
  // 2. MAP — 챕터 지도
  // ════════════════════════════════════════════════════
  Widget _mapScreen() {
    final t = _target;
    final chapterNum = _tIdx + 1;
    return Container(
      color: const Color(0xFF14111A),
      child: LayoutBuilder(builder: (ctx, box) {
        return Stack(children: [
          const Positioned.fill(child: CustomPaint(painter: _GridPainter())),
          // 길
          Positioned(left: -box.maxWidth * .1, top: box.maxHeight * .47, child: Transform.rotate(angle: 6 * math.pi / 180, child: Container(width: box.maxWidth * 1.2, height: 16, decoration: BoxDecoration(color: _cream.withOpacity(0.07), borderRadius: BorderRadius.circular(999))))),
          // 상단 HUD
          // left: 58 — 좌상단 뒤로가기 버튼(top:58,left:14,36폭) 자리를 비켜준다.
          Positioned(top: 54, left: 58, right: 14, child: _mapHud(chapterNum)),
          // 조각 패널
          Positioned(top: 118, left: 14, right: 14, child: _fragPanel()),
          // POI
          ..._buildPois(box),
          // 플레이어
          _buildPlayer(box),
          // 챕터 카드
          Positioned(left: 12, right: 12, bottom: 18, child: _chapterCard(t, chapterNum)),
        ]);
      }),
    );
  }

  Widget _mapHud(int chapterNum) => Row(children: [
        // 아바타
        SizedBox(
          width: 52, height: 52,
          child: Stack(clipBehavior: Clip.none, children: [
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFF4EDDA), Color(0xFFEADFC4)]),
                border: Border.all(color: _tealDeep, width: 2),
              ),
              alignment: Alignment.center,
              child: Text('글', style: dokkaebiTitle(size: 21, color: _parchInk)),
            ),
            Positioned(
              right: -3, bottom: -3,
              child: Container(
                width: 20, height: 20, alignment: Alignment.center,
                decoration: BoxDecoration(shape: BoxShape.circle, color: _verm, border: Border.all(color: const Color(0xFF14111A), width: 2)),
                child: Text('$chapterNum', style: const TextStyle(color: Color(0xFFFDF6E6), fontSize: 11, fontWeight: FontWeight.w900)),
              ),
            ),
          ]),
        ),
        const SizedBox(width: 10),
        // Expanded — 좁은 화면(320px)에서 칭호·챕터 텍스트가 우측 스탯을 밀어내 오버플로났다.
        // 남는 폭을 텍스트가 갖고, 모자라면 말줄임으로 접는다(스탯은 항상 보여야 함).
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text('글지기 견습',
                maxLines: 1, overflow: TextOverflow.ellipsis,
                style: dokkaebiTitle(size: 17, color: _cream)),
            Text('제 $chapterNum 장 진행 중',
                maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11, color: _muted)),
          ]),
        ),
        const SizedBox(width: 8),
        _hudStat(_remain.toString(), _gold, ring: true),
        const SizedBox(width: 7),
        _hudStat('붓털 $brush', _soft),
      ]);

  Widget _hudStat(String text, Color color, {bool ring = false}) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
        decoration: BoxDecoration(
          color: _inkDeep.withOpacity(0.75),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: ring ? _goldDim.withOpacity(0.45) : Colors.white.withOpacity(0.14)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (ring)
            Container(width: 14, height: 14, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: _gold, width: 2.5)))
          else
            Container(width: 5, height: 14, decoration: BoxDecoration(color: _soft, borderRadius: BorderRadius.circular(3))),
          const SizedBox(width: 6),
          Text(text, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w900, color: color)),
        ]),
      );

  Widget _fragPanel() => GestureDetector(
        onTap: () => setState(() => collOpen = true),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
          decoration: BoxDecoration(
            color: _inkDeep.withOpacity(0.72),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _cream.withOpacity(0.14)),
          ),
          child: Row(children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              const Text('글씨조각', style: TextStyle(fontSize: 10, color: _muted, fontWeight: FontWeight.w700, letterSpacing: 0.8)),
              RichText(text: TextSpan(children: [
                TextSpan(text: '$fragments ', style: dokkaebiTitle(size: 19, color: _blue)),
                TextSpan(text: '/ $_stoneTotal', style: const TextStyle(fontSize: 13, color: _muted)),
              ])),
            ]),
            const SizedBox(width: 8),
            // 조각 표시는 남는 폭 안에서 축소한다 — 조각이 8개인 코스나 320px 화면에서
            // 자연 폭 그대로 두면 우측으로 넘친다(스모크 게이트가 잡는 오버플로).
            Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  for (var i = 0; i < _stoneTotal; i++)
                    Padding(
                      padding: const EdgeInsets.only(left: 13),
                      child: Transform.rotate(
                        angle: math.pi / 4,
                        child: Container(
                          width: 17, height: 17,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(4),
                            gradient: i < fragments ? const LinearGradient(colors: [Color(0xFFF4D98A), _goldDim]) : null,
                            color: i < fragments ? null : _cream.withOpacity(0.06),
                            border: Border.all(color: i < fragments ? _verm : _muted.withOpacity(0.4), width: 1.5),
                            boxShadow: i < fragments ? [BoxShadow(color: _gold.withOpacity(0.55), blurRadius: 12)] : null,
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(width: 12),
                  const Text('컬렉션 ›', style: TextStyle(fontSize: 11, color: _muted)),
                ]),
              ),
            ),
          ]),
        ),
      );

  List<Widget> _buildPois(BoxConstraints box) {
    final poiPos = [const Offset(.30, .29), const Offset(.59, .35), const Offset(.39, .46), const Offset(.12, .56)];
    final out = <Widget>[];
    // 시안 좌표가 4개뿐이라 그 이상은 지도에 안 찍는다. 그 이하 코스에서 targets[i]가
    // 범위를 벗어나 터지던 것도 여기서 막는다(조각 3개짜리 코스 = RangeError).
    final shown = math.min(targets.length, poiPos.length);
    for (var i = 0; i < shown; i++) {
      final done = i < fragments;
      final active = i == _tIdx && !done;
      final size = active ? 58.0 : 48.0;
      out.add(Positioned(
        left: box.maxWidth * poiPos[i].dx - size / 2,
        top: box.maxHeight * poiPos[i].dy - size / 2,
        child: Opacity(
          opacity: done || active ? 1 : .6,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            SizedBox(
              width: size, height: size,
              child: Stack(alignment: Alignment.center, clipBehavior: Clip.none, children: [
                if (active)
                  AnimatedBuilder(
                    animation: _pulse,
                    builder: (_, __) => Container(
                      width: size + 14 + _pulse.value * 30,
                      height: size + 14 + _pulse.value * 30,
                      decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: _verm.withOpacity(1 - _pulse.value), width: 2.5)),
                    ),
                  ),
                Container(
                  width: size, height: size, alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: active ? const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFF4EDDA), Color(0xFFEADFC4)]) : null,
                    color: done ? _tealDeep.withOpacity(0.9) : (active ? null : _inkDeep.withOpacity(0.75)),
                    border: Border.all(
                      color: done ? _tealDeep : (active ? Colors.transparent : _muted.withOpacity(0.55)),
                      width: done ? 2 : 1.5,
                    ),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.45), blurRadius: 18, offset: const Offset(0, 6))],
                  ),
                  child: Text(
                    done ? '✓' : (active || i == shown - 1 ? targets[i].hanja : '?'),
                    style: dokkaebiTitle(size: active ? 23 : 18, color: done ? _teal : (active ? _parchInk : _muted)),
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 6),
            Text(targets[i].name, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: done ? _teal : (active ? _cream : _muted), shadows: const [Shadow(color: Colors.black, blurRadius: 6)])),
          ]),
        ),
      ));
    }
    return out;
  }

  Widget _buildPlayer(BoxConstraints box) {
    // _buildPois와 같은 이유 — 시안 좌표가 4개뿐이라 5번째 조각부터는 마지막 자리에 그대로 둔다.
    const playerPos = [Offset(.22, .24), Offset(.34, .33), Offset(.61, .41), Offset(.41, .51)];
    final pos = playerPos[_tIdx.clamp(0, playerPos.length - 1)];
    return Positioned(
      left: box.maxWidth * pos.dx - 8,
      top: box.maxHeight * pos.dy - 8,
      child: SizedBox(
        width: 16, height: 16,
        child: Stack(alignment: Alignment.center, clipBehavior: Clip.none, children: [
          AnimatedBuilder(
            animation: _pulse,
            builder: (_, __) => Container(
              width: 16 + 16 * _pulse.value, height: 16 + 16 * _pulse.value,
              decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: _blue.withOpacity(0.7 * (1 - _pulse.value)), width: 2)),
            ),
          ),
          Container(
            width: 16, height: 16,
            decoration: BoxDecoration(shape: BoxShape.circle, color: _blue, border: Border.all(color: const Color(0xFFEAF6FC), width: 2.5), boxShadow: [BoxShadow(color: _blue.withOpacity(0.9), blurRadius: 14)]),
          ),
        ]),
      ),
    );
  }

  Widget _chapterCard(_Target t, int chapterNum) {
    final collectPct = _stoneTotal == 0 ? 0.0 : fragments / _stoneTotal;
    // 실제 GPS 모드는 지금 위치 기준 거리(아직 못 읽었으면 확인 중), 데모는 시안 거리.
    final int? distM = _usesRealGps(t) ? _liveDistTo(t) : t.dist0;
    // 위치를 못 읽으면 "거리 확인 중"에 머물지 않고 이유를 짧게 — 설정으로 풀어야 하는지 구분한다.
    final distText = distM != null
        ? '📍 ${t.name}까지 ${_distLabel(distM)}'
        : '📍 ${t.name} · ${_locError == null ? '거리 확인 중' : (_locNeedsSettings ? '위치 설정 필요' : '위치 확인 불가')}';
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [_parchTop, _parchBot]),
        borderRadius: BorderRadius.circular(20),
        border: const Border(top: BorderSide(color: Color(0x59C8452C), width: 3)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.55), blurRadius: 44, offset: const Offset(0, -12))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 3),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), border: Border.all(color: _verm, width: 1.5)),
            child: Text('제 $chapterNum 장', style: dokkaebiTitle(size: 13, color: _verm)),
          ),
          const SizedBox(width: 9),
          Row(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 7, height: 7, decoration: const BoxDecoration(shape: BoxShape.circle, color: _tealDeep)),
            const SizedBox(width: 5),
            const Text('추적 중', style: TextStyle(fontSize: 12, color: _tealDeep, fontWeight: FontWeight.w900)),
          ]),
          const Spacer(),
          const Text('자세히 ▾', style: TextStyle(fontSize: 12, color: _bronze, fontWeight: FontWeight.w700)),
        ]),
        const SizedBox(height: 9),
        Text(t.title, style: dokkaebiTitle(size: 21, color: _parchInk)),
        const SizedBox(height: 7),
        Row(children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(shape: BoxShape.circle, color: _blue, boxShadow: [BoxShadow(color: _blue.withOpacity(0.8), blurRadius: 6)])),
          const SizedBox(width: 8),
          Expanded(child: Text(t.obj, style: const TextStyle(fontSize: 13, color: _parchInkSoft))),
        ]),
        const SizedBox(height: 12),
        Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
          RichText(text: TextSpan(children: [
            const TextSpan(text: '조각 ', style: TextStyle(fontSize: 12.5, color: _parchInkSoft, fontWeight: FontWeight.w700)),
            TextSpan(text: '$fragments', style: const TextStyle(fontSize: 12.5, color: _verm, fontWeight: FontWeight.w700)),
            TextSpan(text: ' / $_stoneTotal', style: const TextStyle(fontSize: 12.5, color: _parchInkSoft, fontWeight: FontWeight.w700)),
          ])),
          const SizedBox(width: 8),
          // Expanded + 말줄임 — "… · 거리 확인 중" 문구나 긴 장소명이 좁은 화면에서 넘치지 않게.
          Expanded(
            child: Text(distText,
                textAlign: TextAlign.right,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12.5, color: _verm, fontWeight: FontWeight.w900)),
          ),
        ]),
        const SizedBox(height: 7),
        _progress(collectPct),
        const SizedBox(height: 13),
        _cta('이동 시작 — GPS 추적', () {
          setState(() {
            gpsIdx = _tIdx;
            gpsDist = _target.dist0;
            gpsWalking = false;
            _arrivalFailure = null;
            screen = 'gps';
          });
          _refreshLiveDistance(); // 이동 화면에 들어오자마자 거리 갱신(주기를 기다리지 않음)
        }),
      ]),
    );
  }

  // ════════════════════════════════════════════════════
  // 3. GPS — 이동·도착 인증
  // ════════════════════════════════════════════════════
  Widget _gpsScreen() {
    final gpsT = targets[gpsIdx];
    final real = _usesRealGps(gpsT);
    // 실제 GPS 모드: 지금 위치 → 목표 거리, 반경은 서버 판정과 같은 노드 값.
    // 데모 모드: 시뮬레이션 거리(gpsDist)와 시안 반경.
    final radiusM = real ? gpsT.node!.triggerRadiusM : _demoArriveRadiusM;
    final int? dist = real ? _liveDistTo(gpsT) : gpsDist;
    final gpsNear = dist != null && dist <= radiusM;
    final double prog = dist == null
        ? 0
        : (real ? math.min(1.0, radiusM / math.max(1, dist)) : 1 - dist / gpsT.dist0);
    final distLabel = dist == null ? '—' : _distLabel(dist);
    // 위치를 못 읽은 사유 전문은 아래 안내에서 한 번만 보여준다 — 여기엔 짧게.
    final distNote = dist == null
        ? (_locError == null ? '위치를 확인하는 중' : '위치 확인 불가')
        : '남음 · 걸어서 약 ${math.max(1, (dist / _walkMetersPerMinute).ceil())}분';
    final accuracyLabel = !real
        ? '정확도 ±8m'
        : (_liveAccuracyM == null ? '' : '정확도 ±${_liveAccuracyM!.round()}m');
    return Container(
      color: const Color(0xFF14111A),
      child: LayoutBuilder(builder: (ctx, box) {
        return Stack(children: [
          const Positioned.fill(child: CustomPaint(painter: _GridPainter())),
          // 상단 칩
          Positioned(top: 54, left: 0, right: 0, child: Center(child: _pill('● GPS 추적 중 — ${gpsT.name}', border: _blue, textColor: const Color(0xFF9FD4EC)))),
          // 목적지 마커 + 반경
          Positioned(
            left: 0, right: 0, top: box.maxHeight * .22,
            child: Center(
              child: SizedBox(
                width: 170, height: 190,
                child: Stack(alignment: Alignment.center, clipBehavior: Clip.none, children: [
                  Container(
                    width: 170, height: 170,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: (gpsNear ? _tealDeep : _verm).withOpacity(gpsNear ? 0.1 : 0.05),
                      border: Border.all(color: (gpsNear ? _tealDeep : _verm).withOpacity(gpsNear ? 1 : 0.6), width: 2, style: BorderStyle.solid),
                    ),
                  ),
                  Container(
                    width: 62, height: 62, alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFF4EDDA), Color(0xFFEADFC4)]),
                      border: Border.all(color: _verm, width: 2.5),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 22, offset: const Offset(0, 8))],
                    ),
                    child: Text(gpsT.hanja, style: dokkaebiTitle(size: 26, color: _parchInk)),
                  ),
                  Positioned(
                    bottom: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 3),
                      decoration: BoxDecoration(color: _inkDeep.withOpacity(0.85), borderRadius: BorderRadius.circular(999)),
                      child: Text('인증 반경 ${_distLabel(radiusM)}', style: const TextStyle(fontSize: 10, color: _muted)),
                    ),
                  ),
                ]),
              ),
            ),
          ),
          // 플레이어(접근하며 위로)
          AnimatedPositioned(
            duration: const Duration(milliseconds: 250),
            left: box.maxWidth / 2 - 10,
            top: box.maxHeight * (0.62 - prog * 0.26),
            child: SizedBox(
              width: 20, height: 20,
              child: Stack(alignment: Alignment.center, clipBehavior: Clip.none, children: [
                AnimatedBuilder(animation: _pulse, builder: (_, __) => Container(width: 20 + 18 * _pulse.value, height: 20 + 18 * _pulse.value, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: _blue.withOpacity(0.7 * (1 - _pulse.value)), width: 2)))),
                Container(width: 20, height: 20, decoration: BoxDecoration(shape: BoxShape.circle, color: _blue, border: Border.all(color: const Color(0xFFEAF6FC), width: 3), boxShadow: [BoxShadow(color: _blue.withOpacity(0.9), blurRadius: 16)])),
              ]),
            ),
          ),
          // 하단 카드
          Positioned(left: 12, right: 12, bottom: 18, child: _parchment(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
              Text(distLabel, style: dokkaebiTitle(size: 34, color: _parchInk)),
              const SizedBox(width: 10),
              // Expanded + 말줄임 — 위치를 못 읽은 사유 문구가 길어도 정확도 표시를 밀어내지 않게.
              Expanded(
                child: Text(distNote,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12.5, color: _bronze, fontWeight: FontWeight.w700)),
              ),
              Text(accuracyLabel, style: const TextStyle(fontSize: 11, color: _bronze)),
            ]),
            const SizedBox(height: 9),
            _progress(math.max(0.03, prog)),
            const SizedBox(height: 13),
            if (real)
              ..._arrivalActions(gpsNear)
            else if (!gpsNear) ...[
              _cta(gpsWalking ? '걷는 중…' : '걷기 시작 (GPS 시뮬레이션)', _walk, bg: _parchInk, fg: _cream),
              const SizedBox(height: 8),
              const Center(child: Text('실제 앱에서는 걷는 동안 자동으로 줄어든다 (GPS)', style: TextStyle(fontSize: 11, color: _bronze))),
            ] else ...[
              _nearBanner(),
              const SizedBox(height: 10),
              _cta('GPS 도착 인증', _verifyGps, bg: _tealDeep, fg: const Color(0xFFEAFFF9)),
            ],
          ]))),
        ]);
      }),
    );
  }

  /// 인증 반경 안에 들어왔다는 안내 띠.
  Widget _nearBanner() => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(color: _tealDeep.withOpacity(0.12), borderRadius: BorderRadius.circular(12), border: Border.all(color: _tealDeep.withOpacity(0.5))),
        child: Row(children: [
          Container(width: 22, height: 22, alignment: Alignment.center, decoration: const BoxDecoration(shape: BoxShape.circle, color: _tealDeep), child: const Text('✓', style: TextStyle(color: Color(0xFFEAFFF9), fontSize: 12, fontWeight: FontWeight.w900))),
          const SizedBox(width: 9),
          const Expanded(child: Text('인증 반경 진입 — 기운이 느껴진다', style: TextStyle(fontSize: 13, color: Color(0xFF1D4A41), fontWeight: FontWeight.w900))),
        ]),
      );

  /// 실제 GPS 모드 하단 — 도착 인증 버튼. 실패하면 사유와 다음 행동
  /// (다시 확인 · 권한 문제면 설정 열기 · 좌표 없는 장소면 위치 확인 없이 진행)을 보여준다.
  List<Widget> _arrivalActions(bool near) {
    final failure = _arrivalFailure;
    return [
      if (failure != null) ...[
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(color: _verm.withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: _verm.withOpacity(0.45))),
          child: Text(
            failure.noCoords
                ? '${failure.message} 확인 없이 가면 이 장소 조각은 서버에 기록되지 않느니라.'
                : failure.message,
            style: _gowun(13, const Color(0xFF8A3320), height: 1.5),
          ),
        ),
        const SizedBox(height: 10),
      ] else if (near) ...[
        _nearBanner(),
        const SizedBox(height: 10),
      ] else if (_locError != null) ...[
        Center(child: Text(_locError!, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11.5, color: _bronze, height: 1.4))),
        const SizedBox(height: 8),
      ],
      _cta(
        _arriving ? '확인하는 중…' : (failure == null ? 'GPS 도착 인증' : '다시 확인'),
        _arrive,
        bg: near ? _tealDeep : _parchInk,
        fg: near ? const Color(0xFFEAFFF9) : _cream,
      ),
      // 설정 열기 — 도착 인증 실패뿐 아니라, 거리 갱신 중 권한·위치 서비스 문제가 보일 때도 준다.
      if ((failure?.needsSettings ?? false) || (_locError != null && _locNeedsSettings)) ...[
        const SizedBox(height: 8),
        _cta('설정 열기', () => widget.locationService.openSettings(), bg: _bronze, fg: _cream),
      ],
      if (failure != null && failure.noCoords) ...[
        const SizedBox(height: 8),
        _cta('위치 확인 없이 진행', _skipArrival, bg: _bronze, fg: _cream),
      ],
    ];
  }

  // ════════════════════════════════════════════════════
  // 4. SUMMON — AR 소환
  // ════════════════════════════════════════════════════
  Widget _summonScreen() {
    final sejong = summonFor == 'sejong';
    final scanning = summonPhase == 'scan';
    // 실제 AR 경로: 카메라 배경 + 3D 도깨비 마커. 2D 연출 요소(그라데이션 배경·지붕·
    // 먹웅덩이·그림 도깨비)는 카메라를 가리므로 AR일 땐 그리지 않는다.
    // 마커 탭 = '말 걸기'와 동일(스캔 중이면 대기를 건너뛰고 바로 등장).
    final bool realAr = _arSupported == true && !_arError;
    return Container(
      decoration: realAr ? null : BoxDecoration(gradient: sejong ? _sejongBg : _dialBg),
      child: LayoutBuilder(builder: (ctx, box) {
        return Stack(children: [
          if (realAr)
            Positioned.fill(
              child: NativeArView(
                markers: [
                  ArMarkerDef(
                    id: 'summon',
                    label: sejong ? '세종대왕' : (_npcName.isEmpty ? '도깨비' : _npcName),
                    color: sejong ? _gold : AppColors.teal,
                    forward: 1.8,
                    down: 0.1,
                  ),
                ],
                onMarkerTapped: (_) => setState(() {
                  if (summonPhase == 'scan') {
                    _summonTimer?.cancel();
                    summonPhase = 'appear';
                  } else {
                    go(sejong ? 'sejong' : 'dialogue');
                  }
                }),
                onError: () => setState(() => _arError = true),
              ),
            )
          else
            Align(alignment: const Alignment(0, 0.55), child: ClipPath(clipper: _RoofClipper(), child: Container(height: 130, color: sejong ? const Color(0xFF2A1F16) : const Color(0xFF0C0A08)))),
          Positioned(top: 58, left: 0, right: 0, child: Center(child: _pill(
            sejong ? 'AR — 수호 정령 반응 · 신호 매우 강함' : 'AR — 정령 반응 감지 · 신호 강함',
            border: _goldDim, textColor: _gold,
          ))),
          // 먹 웅덩이 (2D 폴백 전용)
          if (!realAr)
            Positioned(
              left: 0, right: 0, top: box.maxHeight * .60,
              child: Center(child: Container(width: 180, height: 44, decoration: BoxDecoration(color: Colors.black.withOpacity(0.8), borderRadius: BorderRadius.circular(90)))),
            ),
          if (scanning) ...[
            Positioned(
              left: 0, right: 0, top: box.maxHeight * .48,
              child: Center(child: AnimatedBuilder(animation: _pulse, builder: (_, __) => Container(
                width: 60 + 100 * _pulse.value, height: 60 + 100 * _pulse.value,
                decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: _gold.withOpacity(0.55 * (1 - _pulse.value)), width: 2)),
              ))),
            ),
            Positioned(left: 0, right: 0, top: box.maxHeight * .74, child: Center(child: Text(
              realAr ? '천천히 주변을 비춰 보거라…' : (sejong ? '거룩한 기운이 모여든다…' : '먹 기운이 모여든다…'),
              style: dokkaebiTitle(size: 15, color: const Color(0xFFE8DCC4))))),
          ] else ...[
            // 실제 AR에서는 도깨비가 카메라 공간의 3D 마커로 떠 있으므로 그림을 겹치지 않는다.
            if (!realAr)
              Positioned(
                left: 0, right: 0, top: box.maxHeight * .30,
                child: Center(child: _Floaty(anim: _float, child: Column(mainAxisSize: MainAxisSize.min, children: [
                  _pill(sejong ? '세종대왕 · 수호' : '먹 도깨비 · Lv.7', border: _goldDim, textColor: _goldDim),
                  const SizedBox(height: 10),
                  sejong ? const _Sejong(size: 140) : const _Dokkaebi(size: 140),
                ]))),
              ),
            Positioned(left: 14, right: 14, bottom: 40, child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(color: _inkDeep.withOpacity(0.85), borderRadius: BorderRadius.circular(14), border: Border.all(color: _goldDim.withOpacity(0.35))),
                child: Text(sejong ? '"기다리고 있었네, 글지기여."' : '"허허… 누가 날 깨우는 게냐."', textAlign: TextAlign.center, style: dokkaebiTitle(size: 14, color: const Color(0xFFE8DCC4))),
              ),
              const SizedBox(height: 9),
              _cta('말 걸기', () => go(sejong ? 'sejong' : 'dialogue')),
            ])),
          ],
        ]);
      }),
    );
  }

  // ════════════════════════════════════════════════════
  // 5. DIALOGUE — 분기 대화
  // ════════════════════════════════════════════════════
  // 데모(코스 데이터 없음, _curNode==null) 전용 폴백 대사 — 종로 시안 그대로.
  static const _npcLines = {
    0: '"허허, 운현궁에 발을 들였구나. 흥선대원군의 사저에… 세종 임금의 글씨 한 조각이 먹물 속으로 숨어버렸느니라. 자네, 글을 아끼는 자인가?"',
    'A': '"허허, 사연이 궁금한 게로구나. 마음이 곧은 자로군." (친밀도 +1)',
    'B': '"허허, 셈부터 빠르구나. 이 조각엔 옛 기억의 힘이 깃들었지." (이후 쿠폰 +100원)',
    'C': '"성격 급한 게로구나. 그럼 따라오너라."',
  };

  Widget _dialogueScreen() {
    // 실제 코스면 AI가 이 노드용으로 지은 대사를 쓰고, 데모(코스 데이터 없음)면 시안 대사로.
    // dlgStep==1의 답변도 마찬가지 — dialogueTurn이 준 실제 답이 있으면 그걸, 없으면(데모·실패) 고정 문구.
    final npcLine = dlgStep == 0
        ? (_curNode?.npcDialogue.isNotEmpty == true ? _curNode!.npcDialogue : _npcLines[0]!)
        : (_liveAnswer ?? _npcLines[flag]!);
    return Container(
      decoration: BoxDecoration(gradient: _dialBg),
      child: LayoutBuilder(builder: (ctx, box) {
        return Stack(children: [
          Align(alignment: const Alignment(0, 0.35), child: ClipPath(clipper: _RoofClipper(), child: Container(height: 110, color: const Color(0xFF0C0A08)))),
          // left: 58 — 좌상단 뒤로가기 버튼 자리를 비켜준다.
          Positioned(top: 58, left: 58, right: 14, child: Row(children: [
            _pill('${_target.name} · 제 ${_tIdx + 1} 장'),
            const Spacer(),
            _pill('조각 $fragments/$_stoneTotal', border: _tealDeep, textColor: _teal),
          ])),
          Positioned(left: 0, right: 0, top: box.maxHeight * .16, child: Center(child: _Floaty(anim: _float, child: const _Dokkaebi(size: 150)))),
          Positioned(left: 14, right: 14, bottom: 34, child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            // NPC 말풍선
            Stack(clipBehavior: Clip.none, children: [
              Container(
                padding: const EdgeInsets.fromLTRB(18, 22, 18, 16),
                decoration: BoxDecoration(
                  color: _inkDeep.withOpacity(0.92),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: _goldDim.withOpacity(0.55), width: 1.5),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.6), blurRadius: 40, offset: const Offset(0, 14))],
                ),
                child: _dialogueLoading
                    ? const Padding(
                        padding: EdgeInsets.symmetric(vertical: 4),
                        child: SizedBox(
                            width: 22, height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2.4, color: _gold)))
                    : Text(npcLine, style: dokkaebiTitle(size: 16, color: _cream, height: 1.65)),
              ),
              Positioned(top: -14, left: 16, child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                decoration: BoxDecoration(color: _verm, borderRadius: BorderRadius.circular(8)),
                child: Text(_npcName, style: const TextStyle(color: Color(0xFFFDF6E6), fontSize: 13, fontWeight: FontWeight.w900)),
              )),
            ]),
            if (dlgStep == 0 && !_dialogueLoading) ...[
              const SizedBox(height: 10),
              _choiceRow('A', _tealDeep, const Color(0xFFEAFFF9), '"그게 무슨 사연이오?"', '친밀도+', _teal,
                  () => _pickChoice('A', '그게 무슨 사연이오? 이곳에 얽힌 이야기가 궁금하오.',
                      [const StateRef(kind: StateKind.flag, value: '호기심'), const StateRef(kind: StateKind.affinity, value: '', amount: 1)])),
              const SizedBox(height: 8),
              _choiceRow('B', _goldDim, _parchInk, '"보상은 무엇이오?"', '쿠폰+100', _gold,
                  () => _pickChoice('B', '이 조각을 찾으면 무슨 보상이 있소?',
                      [const StateRef(kind: StateKind.flag, value: '실리'), const StateRef(kind: StateKind.coupon, value: '', amount: 100)],
                      extra: () => coupon += 100)),
              const SizedBox(height: 8),
              _choiceRow('C', const Color(0xFF3A352E), _soft, '"그냥 빨리 찾겠소."', '바로 진행', _muted,
                  () => _pickChoice('C', '', [const StateRef(kind: StateKind.flag, value: '실속')])),
            ] else if (dlgStep == 0 && _dialogueLoading) ...[
              const SizedBox(height: 4),
            ] else ...[
              const SizedBox(height: 10),
              // strategy가 S3(퀴즈→개봉)인 노드만 시험으로, 나머지는 지령으로.
              _missionStageFor(_curNode) == 'quiz'
                  ? _cta('계속 — 도깨비의 시험', () => go('quiz'))
                  : _cta('계속 — 지령 받기', () => go('order')),
            ],
          ])),
        ]);
      }),
    );
  }

  Widget _choiceRow(String letter, Color badgeBg, Color badgeFg, String text, String tag, Color tagColor, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
            color: const Color(0xFF181410).withOpacity(0.94),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: badgeBg.withOpacity(0.55)),
          ),
          child: Row(children: [
            Container(width: 28, height: 28, alignment: Alignment.center, decoration: BoxDecoration(color: badgeBg, borderRadius: BorderRadius.circular(8)), child: Text(letter, style: TextStyle(color: badgeFg, fontWeight: FontWeight.w900, fontSize: 14))),
            const SizedBox(width: 12),
            Expanded(child: Text(text, style: const TextStyle(color: Color(0xFFE8DCC4), fontSize: 14, fontWeight: FontWeight.w500))),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: tagColor.withOpacity(0.16), borderRadius: BorderRadius.circular(6)),
              child: Text(tag, style: TextStyle(fontSize: 11, color: tagColor, fontWeight: FontWeight.w700)),
            ),
          ]),
        ),
      );

  // ════════════════════════════════════════════════════
  // 6. QUIZ — 도깨비의 시험
  // ════════════════════════════════════════════════════
  Widget _quizScreen() {
    // [v3] 시안 문제('운현궁은 누구의 집?')를 노드 퀴즈로 교체.
    //      AI가 QUIZ_FIND 미션에서 만들어 준 문제를 그대로 쓴다.
    final quiz = _curQuiz;
    final answers = quiz == null
        ? const [('1', '세종대왕', false), ('2', '흥선대원군', true), ('3', '정조', false)]
        : [
            for (var i = 0; i < quiz.options.length; i++)
              ('${i + 1}', quiz.options[i], i == quiz.answer)
          ];
    return Container(
      decoration: BoxDecoration(gradient: _dialBg),
      child: Stack(children: [
        Positioned.fill(child: Container(color: Colors.black.withOpacity(0.72))),
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: SingleChildScrollView(
              child: Stack(clipBehavior: Clip.none, children: [
                _parchment(
                  padding: const EdgeInsets.fromLTRB(20, 26, 20, 18),
                  child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(
                        quiz?.q.isNotEmpty == true
                            ? '"${quiz!.q}"'
                            : '"글씨를 찾으려면 이 집의 주인을 알아야 하느니. 운현궁은 누구의 집이었더냐?"',
                        style: dokkaebiTitle(size: 17, color: _parchInk, height: 1.55)),
                    const SizedBox(height: 16),
                    for (final a in answers) Padding(padding: const EdgeInsets.only(bottom: 9), child: _quizOption(a.$1, a.$2, a.$3)),
                    if (quizState == 'wrong') ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                        decoration: BoxDecoration(color: _verm.withOpacity(0.1), borderRadius: BorderRadius.circular(11), border: Border.all(color: _verm.withOpacity(0.4))),
                        child: RichText(text: TextSpan(style: _gowun(13.5, const Color(0xFF8A3320)), children: [
                          const TextSpan(text: '"허허, '),
                          TextSpan(
                              text: quiz?.wrongHint.isNotEmpty == true ? quiz!.wrongHint : '다시 보거라. 고종의 아버지니라.',
                              style: const TextStyle(fontWeight: FontWeight.w900)),
                          const TextSpan(text: '" — 다시 골라도 페널티는 없다'),
                        ])),
                      ),
                    ],
                    if (quizState == 'correct') ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                        decoration: BoxDecoration(color: _tealDeep.withOpacity(0.1), borderRadius: BorderRadius.circular(11), border: Border.all(color: _tealDeep.withOpacity(0.45))),
                        child: Row(children: [
                          Flexible(child: Text('"옳거니! 안목이 있구나."', style: dokkaebiTitle(size: 13.5, color: const Color(0xFF1D4A41)))),
                          const Spacer(),
                          _miniTag('경험치 +30', _tealDeep),
                          const SizedBox(width: 6),
                          _miniTag('쿠폰 +200원', const Color(0xFFA87F2C)),
                        ]),
                      ),
                      const SizedBox(height: 12),
                      // S3(퀴즈→개봉)은 정답 자체가 곧 개봉이다 — 지령 화면을
                      // 거치지 않고 바로 조각을 지급한다(원래 order→hunt로
                      // 흘러가던 건 챕터 0 전용 하드코딩 사슬이었다).
                      _cta('계속하기', () => _claimCurrentChapter()),
                    ],
                  ]),
                ),
                Positioned(top: -15, left: 0, right: 0, child: Center(child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 6),
                  decoration: BoxDecoration(color: _verm, borderRadius: BorderRadius.circular(999)),
                  child: const Text('도깨비의 시험', style: TextStyle(color: Color(0xFFFDF6E6), fontWeight: FontWeight.w900, fontSize: 14, letterSpacing: 1.2)),
                ))),
              ]),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _miniTag(String s, Color c) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: c.withOpacity(0.16), borderRadius: BorderRadius.circular(6)),
        child: Text(s, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: c)),
      );

  Widget _quizOption(String num, String label, bool correct) {
    final picked = quizState == 'correct' && correct;
    return GestureDetector(
      onTap: () {
        if (quizState == 'correct') return;
        if (correct) {
          setState(() { quizState = 'correct'; exp += 30; coupon += 200; });
          hint.noteProgress();
        } else {
          setState(() => quizState = 'wrong');
          hint.noteFailure(); // 실패 1회 → H1 개방(5절 fail1)
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
        decoration: BoxDecoration(
          color: picked ? _tealDeep.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: picked ? _tealDeep : const Color(0xFFC9B88F), width: picked ? 2 : 1.5),
        ),
        child: Row(children: [
          Container(
            width: 26, height: 26, alignment: Alignment.center,
            decoration: BoxDecoration(shape: BoxShape.circle, color: picked ? _tealDeep : Colors.transparent, border: picked ? null : Border.all(color: const Color(0xFFB7A374), width: 2)),
            child: Text(picked ? '✓' : num, style: TextStyle(color: picked ? const Color(0xFFEAFFF9) : _bronze, fontWeight: FontWeight.w900, fontSize: 13)),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: const TextStyle(color: _parchInk, fontWeight: FontWeight.w700, fontSize: 15))),
          if (picked) const Text('정답!', style: TextStyle(fontSize: 11, color: _tealDeep, fontWeight: FontWeight.w900)),
        ]),
      ),
    );
  }

  // ════════════════════════════════════════════════════
  // 7. ORDER — 지령
  // ════════════════════════════════════════════════════
  Widget _orderScreen() {
    // 지령을 받은 뒤 실제로 갈 미션 화면 — strategy 기반(_missionStageFor).
    final stage = _missionStageFor(_curNode);
    final ctaLabel = switch (stage) {
      'photo' => '지령 받기 — 사진 인증 시작',
      'cafe' => '지령 받기 — 주문하러 가기',
      'gather' => '지령 받기 — 수집 시작',
      _ => '지령 받기 — 사냥 시작',
    };
    final code = _curNode?.strategy.isNotEmpty == true ? strategyCode(_curNode!.strategy.first) : null;
    return Container(
      decoration: BoxDecoration(gradient: _dialBg),
      child: LayoutBuilder(builder: (ctx, box) {
        return Stack(children: [
          Align(alignment: const Alignment(0, 0.48), child: ClipPath(clipper: _RoofClipper(), child: Container(height: 120, color: const Color(0xFF0C0A08)))),
          // left: 58 — 좌상단 뒤로가기 버튼 자리를 비켜준다.
          Positioned(top: 58, left: 58, right: 14, child: Row(children: [_pill('${_target.name} · 제 ${_tIdx + 1} 장'), const Spacer(), _pill('조각 $fragments/$_stoneTotal', border: _tealDeep, textColor: _teal)])),
          Positioned(left: 0, right: 0, top: box.maxHeight * .20, child: Center(child: _Floaty(anim: _float, child: const _Dokkaebi(size: 120)))),
          Positioned(left: 14, right: 14, bottom: 34, child: _parchment(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(
                  width: 46, height: 46, alignment: Alignment.center,
                  decoration: BoxDecoration(color: _verm, borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFF8F1E0).withOpacity(0.35), width: 2)),
                  child: Text('지령', style: dokkaebiTitle(size: 18, color: const Color(0xFFF8F1E0))),
                ),
                const SizedBox(width: 12),
                // 실제 노드 지령 문구(챕터 카드와 같은 값) — 종로 하드코딩 제거.
                Expanded(child: Text('"${_target.obj}"', style: dokkaebiTitle(size: 16, color: _parchInk, height: 1.55))),
              ]),
              if (code != null && strategyLabels[code] != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFC9B88F))),
                  child: Text(strategyLabels[code]!, style: const TextStyle(fontSize: 11.5, color: _bronze, fontWeight: FontWeight.w700)),
                ),
              ],
              const SizedBox(height: 16),
              _cta(ctaLabel, () {
                if (stage == 'hunt') _prepareHuntEnemies();
                if (stage == 'gather') _prepareGatherItems();
                go(stage);
              }, fontSize: 15.5),
            ]),
          )),
        ]);
      }),
    );
  }

  // ════════════════════════════════════════════════════
  // 8. HUNT — 먹그림자 사냥
  // ════════════════════════════════════════════════════
  Widget _huntScreen() {
    final huntTotal = enemies.length;
    final huntCount = enemies.where((e) => e['dead'] == true).length;
    final done = huntCount >= huntTotal;
    return Container(
      decoration: BoxDecoration(gradient: _dialBg),
      child: LayoutBuilder(builder: (ctx, box) {
        return Stack(children: [
          Align(alignment: const Alignment(0, 0.52), child: ClipPath(clipper: _RoofClipper(), child: Container(height: 130, color: const Color(0xFF0C0A08)))),
          // 상단 카운터
          Positioned(top: 58, left: 0, right: 0, child: Column(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
              decoration: BoxDecoration(color: _inkDeep.withOpacity(0.8), borderRadius: BorderRadius.circular(16), border: Border.all(color: _verm.withOpacity(0.6))),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text(huntLabel, style: const TextStyle(fontSize: 13, color: Color(0xFFE8A08D), fontWeight: FontWeight.w700)),
                const SizedBox(width: 12),
                RichText(text: TextSpan(children: [
                  TextSpan(text: '$huntCount', style: dokkaebiTitle(size: 26, color: _cream)),
                  TextSpan(text: ' / $huntTotal', style: const TextStyle(fontSize: 16, color: _muted)),
                ])),
              ]),
            ),
            const SizedBox(height: 8),
            SizedBox(width: 220, child: _progress(huntCount / huntTotal, grad: const LinearGradient(colors: [_verm, Color(0xFFE8743A)]), track: const Color(0xBF0D0B09))),
            const SizedBox(height: 6),
            const Text('그림자를 탭하면 붓질로 쫓는다', style: TextStyle(fontSize: 11.5, color: Color(0xFFB3A892))),
          ])),
          // 적
          for (final e in enemies)
            if (e['dead'] != true)
              Positioned(
                left: box.maxWidth * (e['left'] as double) - (e['size'] as double) / 2,
                top: box.maxHeight * (e['top'] as double) - (e['size'] as double) / 2,
                child: _Floaty(anim: _float, amplitude: 6, child: GestureDetector(
                  onTap: () => setState(() => e['dead'] = true),
                  child: _MeokShadow(size: e['size'] as double, pulse: _pulse),
                )),
              ),
          if (done) ...[
            Positioned(left: 14, right: 14, bottom: 100, child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
              decoration: BoxDecoration(color: const Color(0xFF142A26).withOpacity(0.92), borderRadius: BorderRadius.circular(14), border: Border.all(color: _tealDeep.withOpacity(0.7))),
              child: Row(children: [
                Container(width: 24, height: 24, alignment: Alignment.center, decoration: const BoxDecoration(shape: BoxShape.circle, color: _tealDeep), child: const Text('✓', style: TextStyle(color: Color(0xFFEAFFF9), fontSize: 13, fontWeight: FontWeight.w900))),
                const SizedBox(width: 10),
                const Expanded(child: Text('모두 해치웠다 — 이제 조각을 살필 차례', style: TextStyle(fontSize: 13.5, color: Color(0xFFBDEEE1), fontWeight: FontWeight.w700))),
              ]),
            )),
            // 예전엔 여기서 photo→trail로 이어졌다 — 챕터 0(운현궁) 전용 3화면
            // 사슬이었다. 사냥(S1/S2/S6 임시 재사용)은 독립 미션이라 여기서
            // 바로 조각을 지급한다(서버 기록이 성공해야 확정).
            Positioned(left: 14, right: 14, bottom: 34, child: _cta('돌아와 조각을 살피다', () => _claimCurrentChapter())),
          ] else
            Positioned(right: 18, bottom: 34, child: GestureDetector(
              onTap: () => setState(() => hintOpen = true),
              child: Container(width: 52, height: 52, alignment: Alignment.center, decoration: BoxDecoration(shape: BoxShape.circle, color: _inkDeep.withOpacity(0.75), border: Border.all(color: _verm.withOpacity(0.5))), child: const Text('힌트', style: TextStyle(fontSize: 12, color: Color(0xFFE8A08D), fontWeight: FontWeight.w700))),
            )),
        ]);
      }),
    );
  }

  // ════════════════════════════════════════════════════
  // 8-2. GATHER — 전투 없는 탭 수집 (S1 대화→수집 · S6 수집 누적)
  // ════════════════════════════════════════════════════
  Widget _gatherScreen() {
    final gatherTotal = gatherItems.length;
    final gatherCount = gatherItems.where((e) => e['collected'] == true).length;
    final done = gatherCount >= gatherTotal;
    return Container(
      decoration: BoxDecoration(gradient: _dialBg),
      child: LayoutBuilder(builder: (ctx, box) {
        return Stack(children: [
          Align(alignment: const Alignment(0, 0.52), child: ClipPath(clipper: _RoofClipper(), child: Container(height: 130, color: const Color(0xFF0C0A08)))),
          // 상단 카운터 — 사냥 화면과 같은 틀이지만 전투 색(주홍) 대신 수집 색(청록).
          Positioned(top: 58, left: 0, right: 0, child: Column(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
              decoration: BoxDecoration(color: _inkDeep.withOpacity(0.8), borderRadius: BorderRadius.circular(16), border: Border.all(color: _tealDeep.withOpacity(0.6))),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text(gatherLabel, style: const TextStyle(fontSize: 13, color: _teal, fontWeight: FontWeight.w700)),
                const SizedBox(width: 12),
                RichText(text: TextSpan(children: [
                  TextSpan(text: '$gatherCount', style: dokkaebiTitle(size: 26, color: _cream)),
                  TextSpan(text: ' / $gatherTotal', style: const TextStyle(fontSize: 16, color: _muted)),
                ])),
              ]),
            ),
            const SizedBox(height: 8),
            SizedBox(width: 220, child: _progress(gatherTotal == 0 ? 0 : gatherCount / gatherTotal, grad: const LinearGradient(colors: [_tealDeep, _teal]), track: const Color(0xBF0D0B09))),
            const SizedBox(height: 6),
            const Text('은은한 빛을 따라 손끝으로 거두어라', style: TextStyle(fontSize: 11.5, color: Color(0xFFB3A892))),
          ])),
          // 수집물 — 전투 없이 탭 한 번으로 거둔다.
          for (final it in gatherItems)
            if (it['collected'] != true)
              Positioned(
                left: box.maxWidth * (it['left'] as double) - (it['size'] as double) / 2,
                top: box.maxHeight * (it['top'] as double) - (it['size'] as double) / 2,
                child: _Floaty(anim: _float, amplitude: 6, child: GestureDetector(
                  onTap: () => setState(() => it['collected'] = true),
                  child: _FragShard(glyph: _target.hanja, size: it['size'] as double),
                )),
              ),
          if (done) ...[
            Positioned(left: 14, right: 14, bottom: 100, child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
              decoration: BoxDecoration(color: const Color(0xFF142A26).withOpacity(0.92), borderRadius: BorderRadius.circular(14), border: Border.all(color: _tealDeep.withOpacity(0.7))),
              child: Row(children: [
                Container(width: 24, height: 24, alignment: Alignment.center, decoration: const BoxDecoration(shape: BoxShape.circle, color: _tealDeep), child: const Text('✓', style: TextStyle(color: Color(0xFFEAFFF9), fontSize: 13, fontWeight: FontWeight.w900))),
                const SizedBox(width: 10),
                const Expanded(child: Text('모두 거두었다 — 이제 조각을 살필 차례', style: TextStyle(fontSize: 13.5, color: Color(0xFFBDEEE1), fontWeight: FontWeight.w700))),
              ]),
            )),
            Positioned(left: 14, right: 14, bottom: 34, child: _cta('돌아와 조각을 살피다', () => _claimCurrentChapter())),
          ] else
            Positioned(right: 18, bottom: 34, child: GestureDetector(
              onTap: () => setState(() => hintOpen = true),
              child: Container(width: 52, height: 52, alignment: Alignment.center, decoration: BoxDecoration(shape: BoxShape.circle, color: _inkDeep.withOpacity(0.75), border: Border.all(color: _tealDeep.withOpacity(0.5))), child: const Text('힌트', style: TextStyle(fontSize: 12, color: _teal, fontWeight: FontWeight.w700))),
            )),
        ]);
      }),
    );
  }

  // ════════════════════════════════════════════════════
  // 9. PHOTO — 사진 인증
  // ════════════════════════════════════════════════════
  Widget _photoScreen() {
    final bracket = photoState == 'done' ? _teal : _cream.withOpacity(0.75);
    // S4(사진→추적→파편)만 발자국으로 이어진다 — S5(사진 인증)나 strategy 없는
    // 폴백(PATH_TRACE가 아닌 PHOTO_FIND)은 촬영만으로 끝난다.
    final code = _curNode?.strategy.isNotEmpty == true ? strategyCode(_curNode!.strategy.first) : null;
    final hasTrail = code == 'S4' || (code == null && _curNode?.mission?.type == 'PATH_TRACE');
    // capture 원자가 준 실제 촬영 대상(예: "현판·건물 외관") — 없으면 챕터 지령으로.
    final captureTargets = _actionAtom('capture')?.targets ?? const <String>[];
    final captureLabel = captureTargets.isNotEmpty ? captureTargets.join('·') : _target.obj;
    return Container(
      decoration: BoxDecoration(gradient: _dialBg),
      child: LayoutBuilder(builder: (ctx, box) {
        return Stack(children: [
          Align(alignment: const Alignment(0, 0.55), child: ClipPath(clipper: _RoofClipper(), child: Container(height: 140, color: const Color(0xFF0C0A08)))),
          Positioned(top: 58, left: 0, right: 0, child: Center(child: _pill('사진 미션 — $captureLabel'))),
          // 뷰파인더
          Positioned(
            left: 0, right: 0, top: box.maxHeight * .26,
            child: Center(child: SizedBox(
              width: 230, height: 170,
              child: Stack(clipBehavior: Clip.none, children: [
                _corner(bracket, top: true, left: true), _corner(bracket, top: true, left: false),
                _corner(bracket, top: false, left: true), _corner(bracket, top: false, left: false),
                Positioned(left: 23, right: 23, bottom: 30, child: ClipPath(clipper: _GateClipper(), child: Container(height: 56, color: const Color(0xFF0C0A08)))),
                if (photoState == 'scanning')
                  Positioned(bottom: -44, left: 0, right: 0, child: Center(child: _pill('인식 중 · $scan%', border: _teal, textColor: _teal))),
                if (photoState == 'done')
                  Positioned(bottom: -44, left: 0, right: 0, child: Center(child: _pill('✓ 인증 완료 — 마음에 담겼다', border: _tealDeep, textColor: const Color(0xFFBDEEE1)))),
              ]),
            )),
          ),
          if (photoState == 'idle')
            Positioned(left: 0, right: 0, bottom: 40, child: Column(children: [
              const Text('셔터를 누르면 도깨비가 살펴본다', style: TextStyle(fontSize: 12, color: Color(0xFFB3A892))),
              const SizedBox(height: 12),
              _shutter(() { setState(() { photoState = 'scanning'; scan = 0; }); _startScan('photo'); }),
            ])),
          if (photoState == 'scanning')
            Positioned(left: 60, right: 60, bottom: 60, child: _progress(scan / 100, grad: const LinearGradient(colors: [_tealDeep, _teal]), track: const Color(0xBF0D0B09))),
          if (photoState == 'done')
            Positioned(left: 14, right: 14, bottom: 34, child: hasTrail
                ? _cta('길이 열렸다 — 발자국을 따라가라', () => go('trail'))
                : _cta('돌아와 조각을 살피다', () => _claimCurrentChapter())),
        ]);
      }),
    );
  }

  Widget _corner(Color c, {required bool top, required bool left}) => Positioned(
        top: top ? 0 : null, bottom: top ? null : 0, left: left ? 0 : null, right: left ? null : 0,
        child: Container(
          width: 28, height: 28,
          decoration: BoxDecoration(border: Border(
            top: top ? BorderSide(color: c, width: 3.5) : BorderSide.none,
            bottom: top ? BorderSide.none : BorderSide(color: c, width: 3.5),
            left: left ? BorderSide(color: c, width: 3.5) : BorderSide.none,
            right: left ? BorderSide.none : BorderSide(color: c, width: 3.5),
          )),
        ),
      );

  Widget _shutter(VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 78, height: 78, alignment: Alignment.center,
          decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: _cream, width: 5)),
          child: Container(width: 58, height: 58, decoration: BoxDecoration(shape: BoxShape.circle, color: _cream, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 18, offset: const Offset(0, 6))])),
        ),
      );

  // ════════════════════════════════════════════════════
  // 10. TRAIL — 발자국 추적
  // ════════════════════════════════════════════════════
  static const _trailLines = [
    '"길이 열렸느니라. 발자국은 해 지는 쪽으로 번졌느니 — 하나씩 밟아 보거라."',
    '"옳지, 하나. 먹내음이 짙어지는구나."',
    '"둘. 거의 다 왔느니."',
    '"저기다! 처마 아래 빛나는 것을 거두거라."',
  ];

  Widget _trailScreen() {
    final fpDefs = [
      (0.20, 0.22, 56.0, -18.0), (0.38, 0.32, 48.0, -24.0), (0.55, 0.42, 40.0, -30.0),
    ];
    // follow 원자의 걸음 수 — 화면엔 발자국 3개까지만 배치해뒀으니 그 안으로 클램프.
    final trailTotal = (_actionAtom('follow')?.steps ?? 3).clamp(1, fpDefs.length);
    final fragVisible = trail >= trailTotal && !fragTaken;
    return Container(
      decoration: BoxDecoration(gradient: _dialBg),
      child: LayoutBuilder(builder: (ctx, box) {
        return Stack(children: [
          Align(alignment: const Alignment(0, 0.55), child: ClipPath(clipper: _RoofClipper(), child: Container(height: 110, color: const Color(0xFF0C0A08)))),
          Positioned(top: 58, left: 0, right: 0, child: Center(child: Row(mainAxisSize: MainAxisSize.min, children: [
            _pill('발자국 $trail/$trailTotal', border: _goldDim, textColor: _gold),
            const SizedBox(width: 10),
            _pill('파편까지 ${(trailTotal - trail) * 4}m', border: Colors.white, textColor: _soft),
          ]))),
          for (var i = 0; i < trailTotal; i++)
            if (trail >= i && trail < trailTotal)
              Positioned(
                left: box.maxWidth * fpDefs[i].$1,
                bottom: box.maxHeight * fpDefs[i].$2,
                child: GestureDetector(
                  onTap: () { if (trail == i) setState(() => trail = i + 1); },
                  child: Transform.rotate(
                    angle: fpDefs[i].$4 * math.pi / 180,
                    child: Opacity(
                      opacity: trail == i ? 0.9 : 0.4,
                      child: Container(
                        width: fpDefs[i].$3, height: 26,
                        decoration: BoxDecoration(
                          color: Colors.black,
                          borderRadius: const BorderRadius.only(topLeft: Radius.circular(28), topRight: Radius.circular(28), bottomLeft: Radius.circular(16), bottomRight: Radius.circular(16)),
                          boxShadow: trail == i ? [BoxShadow(color: _gold.withOpacity(0.55), blurRadius: 20)] : null,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          if (fragVisible)
            Positioned(
              right: box.maxWidth * .14, bottom: box.maxHeight * .5,
              child: GestureDetector(
                // 서버 기록이 성공해야 파편을 거둔다 — 지금 챕터 번호는 _claimCurrentChapter가 먼저 읽어 둔다.
                onTap: () => _claimCurrentChapter(
                  extra: [const StateRef(kind: StateKind.coupon, value: '', to: '익선동카페', amount: 500)],
                  also: () {
                    fragTaken = true;
                    exp += 50;
                    coupon += 500;
                  },
                ),
                child: _Floaty(anim: _float, child: SizedBox(
                  width: 110, height: 110,
                  child: Stack(alignment: Alignment.center, clipBehavior: Clip.none, children: [
                    Container(width: 110, height: 110, decoration: BoxDecoration(shape: BoxShape.circle, gradient: RadialGradient(colors: [_gold.withOpacity(0.45), _gold.withOpacity(0)]))),
                    _FragShard(glyph: _target.hanja, size: 52),
                    Positioned(bottom: -24, child: _pill('탭하여 수집', border: _goldDim, textColor: _gold)),
                  ]),
                )),
              ),
            ),
          // 도깨비 귀띔
          Positioned(left: 14, right: 14, bottom: 34, child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 14),
            decoration: BoxDecoration(color: _inkDeep.withOpacity(0.85), borderRadius: BorderRadius.circular(16), border: Border.all(color: _goldDim.withOpacity(0.35))),
            child: Row(children: [
              Container(
                width: 38, height: 38,
                decoration: BoxDecoration(shape: BoxShape.circle, gradient: const RadialGradient(center: Alignment(-0.24, -0.36), colors: [Color(0xFF33291F), Color(0xFF0A0806)]), border: Border.all(color: _goldDim.withOpacity(0.4))),
                child: Stack(children: [
                  Positioned(top: 13, left: 9, child: Container(width: 6, height: 7, decoration: BoxDecoration(color: _gold, borderRadius: BorderRadius.circular(3)))),
                  Positioned(top: 13, right: 9, child: Container(width: 6, height: 7, decoration: BoxDecoration(color: _gold, borderRadius: BorderRadius.circular(3)))),
                ]),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(_trailLines[trail], style: dokkaebiTitle(size: 14, color: const Color(0xFFE8DCC4), height: 1.5))),
            ]),
          )),
          if (trail < 3)
            Positioned(right: 18, top: 120, child: GestureDetector(
              onTap: () => setState(() => hintOpen = true),
              child: Container(width: 48, height: 48, alignment: Alignment.center, decoration: BoxDecoration(shape: BoxShape.circle, color: _inkDeep.withOpacity(0.75), border: Border.all(color: _verm.withOpacity(0.5))), child: const Text('힌트', style: TextStyle(fontSize: 11.5, color: Color(0xFFE8A08D), fontWeight: FontWeight.w700))),
            )),
        ]);
      }),
    );
  }

  // ════════════════════════════════════════════════════
  // 11. CAFE — 익선동 카페
  // ════════════════════════════════════════════════════
  Widget _cafeScreen() {
    // S7(주문 인증) 실제 데이터 — purchase 원자의 메뉴명, 없으면 장소명으로 대체.
    final menu = _actionAtom('purchase')?.menu ?? '${_target.name} 한 상';
    final npcLine = _curNode?.npcDialogue.isNotEmpty == true ? _curNode!.npcDialogue : '"${_target.obj}"';
    final cafeCoupon = math.min(coupon, 5000);
    final cafePayN = 5000 - cafeCoupon;
    return Container(
      decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [_ink, Color(0xFF211A14)])),
      child: SafeArea(
        child: SingleChildScrollView(
          // top: 44 — 좌상단 뒤로가기 버튼(그 위 전역 Stack) 아래로 내용을 밀어 겹치지 않게 한다.
          padding: const EdgeInsets.fromLTRB(18, 44, 18, 40),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Text(_target.name, style: dokkaebiTitle(size: 19, color: _cream)),
                Text('제 ${_tIdx + 1} 장 · GPS 인증 완료 ✓', style: const TextStyle(fontSize: 11.5, color: _muted)),
              ]),
              const Spacer(),
              _pill('조각 $fragments/$_stoneTotal', border: _tealDeep, textColor: _teal),
            ]),
            const SizedBox(height: 14),
            // 도깨비 안내
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFFF4EDDA), Color(0xFFEADFC4)]), borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFD8C9A4))),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(width: 44, height: 44, decoration: BoxDecoration(shape: BoxShape.circle, gradient: const RadialGradient(center: Alignment(-0.24, -0.36), colors: [Color(0xFF2B2A20), Color(0xFF0A0A06)]), border: Border.all(color: _tealDeep.withOpacity(0.4))), child: Stack(children: [
                  Positioned(top: 15, left: 11, child: Container(width: 6, height: 7, decoration: BoxDecoration(color: _teal, borderRadius: BorderRadius.circular(3)))),
                  Positioned(top: 15, right: 11, child: Container(width: 6, height: 7, decoration: BoxDecoration(color: _teal, borderRadius: BorderRadius.circular(3)))),
                ])),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(_npcName, style: const TextStyle(fontSize: 11, color: _tealDeep, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 4),
                  Text(npcLine, style: _gowun(14, _parchInk, height: 1.55)),
                ])),
              ]),
            ),
            const SizedBox(height: 12),
            // 주문 미션
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: _cream.withOpacity(0.05), borderRadius: BorderRadius.circular(16), border: Border.all(color: _goldDim.withOpacity(0.3))),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('주문 인증 미션', style: TextStyle(fontSize: 12, color: _goldDim, fontWeight: FontWeight.w900, letterSpacing: 0.7)),
                const SizedBox(height: 10),
                Row(children: [
                  Container(width: 52, height: 52, alignment: Alignment.center, decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF3B332A), Color(0xFF221C15)]), borderRadius: BorderRadius.circular(12)), child: Text(_target.hanja, style: dokkaebiTitle(size: 20, color: _gold))),
                  const SizedBox(width: 12),
                  Expanded(child: Text(menu, style: const TextStyle(fontSize: 15, color: _cream, fontWeight: FontWeight.w700))),
                  Column(crossAxisAlignment: CrossAxisAlignment.end, mainAxisSize: MainAxisSize.min, children: [
                    const Text('5,000원', style: TextStyle(fontSize: 12, color: _muted, decoration: TextDecoration.lineThrough)),
                    Text(_won(cafePayN), style: const TextStyle(fontSize: 17, color: _gold, fontWeight: FontWeight.w900)),
                  ]),
                ]),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
                  decoration: BoxDecoration(color: _goldDim.withOpacity(0.1), borderRadius: BorderRadius.circular(10), border: Border.all(color: _goldDim.withOpacity(0.45))),
                  child: Row(children: [
                    const Text('🎟 보유 쿠폰 적용', style: TextStyle(fontSize: 12.5, color: Color(0xFFE8DCC4), fontWeight: FontWeight.w500)),
                    const Spacer(),
                    Text('−${_won(cafeCoupon)}', style: const TextStyle(fontSize: 13, color: _gold, fontWeight: FontWeight.w900)),
                  ]),
                ),
                const SizedBox(height: 12),
                if (!cafeOrdered)
                  _cta('영수증 촬영으로 인증하기', () => _claimCurrentChapter(also: () {
                    cafeOrdered = true;
                    spent += cafePayN;
                    coupon = 0;
                  }), fontSize: 15)
                else
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(color: const Color(0xFF142A26).withOpacity(0.7), borderRadius: BorderRadius.circular(12), border: Border.all(color: _tealDeep.withOpacity(0.6))),
                    child: Row(children: [
                      Container(width: 22, height: 22, alignment: Alignment.center, decoration: const BoxDecoration(shape: BoxShape.circle, color: _tealDeep), child: const Text('✓', style: TextStyle(color: Color(0xFFEAFFF9), fontSize: 12, fontWeight: FontWeight.w900))),
                      const SizedBox(width: 10),
                      Expanded(child: Text('주문 인증 완료 — 여비에서 ${_won(cafePayN)} 차감', style: const TextStyle(fontSize: 13, color: Color(0xFFBDEEE1), fontWeight: FontWeight.w700))),
                    ]),
                  ),
              ]),
            ),
            const SizedBox(height: 20),
            // 남은 여비
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
              decoration: BoxDecoration(color: _cream.withOpacity(0.05), borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.white.withOpacity(0.1))),
              child: Column(children: [
                Row(children: [
                  const Text('남은 여비', style: TextStyle(fontSize: 11.5, color: _soft, fontWeight: FontWeight.w700)),
                  const Spacer(),
                  Text(_won(_remain), style: const TextStyle(fontSize: 11.5, color: _cream, fontWeight: FontWeight.w900)),
                ]),
                const SizedBox(height: 8),
                _progress(math.max(0.04, _remain / budget), grad: const LinearGradient(colors: [_tealDeep, Color(0xFF3AA88F)]), track: const Color(0xCC0D0B09)),
              ]),
            ),
          ]),
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════
  // 12. INSA — 인사동 붓방
  // ════════════════════════════════════════════════════
  Widget _insaScreen() {
    final bracket = insaPhase == 'combine' ? _teal : _cream.withOpacity(0.75);
    return Container(
      decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFA3BDD1), Color(0xFFCFC6A9), Color(0xFF9A8668), Color(0xFF5F5140), Color(0xFF3A322A)], stops: [0, .34, .55, .76, 1])),
      child: LayoutBuilder(builder: (ctx, box) {
        return Stack(children: [
          // left: 58 — 좌상단 뒤로가기 버튼 자리를 비켜준다.
          Positioned(top: 58, left: 58, right: 14, child: Row(children: [_pill('인사동 · 세 번째 기억'), const Spacer(), _pill('조각 $fragments/$_stoneTotal', border: _tealDeep, textColor: _teal)])),
          // 간판
          Positioned(
            left: 0, right: 0, top: box.maxHeight * .27,
            child: Center(child: SizedBox(
              width: 190, height: 90,
              child: Stack(clipBehavior: Clip.none, alignment: Alignment.center, children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  decoration: BoxDecoration(gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF2E2620), Color(0xFF1D1712)]), border: Border.all(color: const Color(0xFF6E5638), width: 3), borderRadius: BorderRadius.circular(6)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text('筆', style: dokkaebiTitle(size: 30, color: const Color(0xFFE8D5A8))),
                    const SizedBox(width: 18),
                    Text('房', style: dokkaebiTitle(size: 30, color: const Color(0xFFE8D5A8))),
                  ]),
                ),
                _corner(bracket, top: true, left: true), _corner(bracket, top: true, left: false),
                _corner(bracket, top: false, left: true), _corner(bracket, top: false, left: false),
                Positioned(bottom: -44, child:
                  insaPhase == 'photo' ? _pill('전통 간판을 담아 보거라', border: _goldDim, textColor: const Color(0xFFE8DCC4))
                  : insaPhase == 'scanning' ? _pill('간판 인식 중 · $insaScan%', border: _teal, textColor: _teal)
                  : _pill('✓ 모음 「ㅏ」 를 얻었다', border: _tealDeep, textColor: const Color(0xFFBDEEE1)),
                ),
              ]),
            )),
          ),
          if (insaPhase == 'photo')
            Positioned(left: 0, right: 0, bottom: 40, child: Center(child: _shutter(() { setState(() { insaPhase = 'scanning'; insaScan = 0; }); _startScan('insa'); }))),
          if (insaPhase == 'combine')
            Positioned(left: 16, right: 16, bottom: 36, child: _insaCombinePanel()),
        ]);
      }),
    );
  }

  Widget _insaCombinePanel() {
    final tiles = ['고', '가', '구', '기'];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: _inkDeep.withOpacity(0.92), borderRadius: BorderRadius.circular(18), border: Border.all(color: _goldDim.withOpacity(0.4))),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          _letterBox('ㄱ'), const SizedBox(width: 12), const Text('+', style: TextStyle(fontSize: 19, color: _muted, fontWeight: FontWeight.w700)), const SizedBox(width: 12),
          _letterBox('ㅏ'), const SizedBox(width: 12), const Text('=', style: TextStyle(fontSize: 19, color: _muted, fontWeight: FontWeight.w700)), const SizedBox(width: 12),
          Container(
            width: 60, height: 60, alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: insaState == 'opened' ? _goldGrad : null,
              color: insaState == 'opened' ? null : _cream.withOpacity(0.1),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _gold.withOpacity(0.6), width: 2),
            ),
            child: Text(insaState == 'opened' ? '가' : '?', style: dokkaebiTitle(size: 30, color: const Color(0xFF3A2A08))),
          ),
        ]),
        const SizedBox(height: 12),
        const Text('글자를 골라 함을 열어라', style: TextStyle(fontSize: 11.5, color: _muted)),
        const SizedBox(height: 10),
        GridView.count(
          crossAxisCount: 4, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 8, crossAxisSpacing: 8, childAspectRatio: 1.3,
          children: [for (final t in tiles) _tile(t)],
        ),
        if (insaState == 'wrong') ...[
          const SizedBox(height: 10),
          Text('"자음 아래 모음을 붙여 보거라."', style: dokkaebiTitle(size: 12.5, color: const Color(0xFFE8A08D))),
        ],
        if (insaState == 'opened') ...[
          const SizedBox(height: 12),
          RewardPopIn(
            child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(color: _goldDim.withOpacity(0.12), borderRadius: BorderRadius.circular(12), border: Border.all(color: _gold.withOpacity(0.5))),
            child: Row(children: [
              _FragShard(glyph: '正', size: 30, fontSize: 12),
              const SizedBox(width: 10),
              const Expanded(child: Text('함이 열렸다 — 글씨조각 「정(正)」 획득', style: TextStyle(fontSize: 13, color: _gold, fontWeight: FontWeight.w900))),
            ]),
            ),
          ),
          const SizedBox(height: 12),
          _cta('지도로 — 마지막 기억', () => go('map'), bg: const Color(0xFFC89A3A), fg: const Color(0xFF3A2A08), gradient: _goldGrad),
        ],
      ]),
    );
  }

  Widget _letterBox(String s) => Container(
        width: 52, height: 52, alignment: Alignment.center,
        decoration: BoxDecoration(gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFF4EDDA), Color(0xFFEADFC4)]), borderRadius: BorderRadius.circular(12)),
        child: Text(s, style: dokkaebiTitle(size: 25, color: _parchInk)),
      );

  Widget _tile(String t) {
    final picked = insaPick == t;
    final isAnswer = t == '가';
    final solved = insaState == 'opened' && isAnswer;
    return GestureDetector(
      onTap: () {
        if (insaState == 'opened') return;
        if (isAnswer) {
          // 챕터 번호 하드코딩(옛 4챕터 종로 대본: 인사동=항상 2번) 제거.
          final idx = _tIdx;
          setState(() { insaPick = t; insaState = 'opened'; fragments = idx + 1; exp += 40; });
          hint.noteProgress();
          _grantChapter(idx);
        } else {
          setState(() { insaPick = t; insaState = 'wrong'; });
          hint.noteFailure();
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: solved ? _goldGrad : null,
          color: solved ? null : (picked ? _verm.withOpacity(0.25) : _cream.withOpacity(0.07)),
          borderRadius: BorderRadius.circular(11),
          border: Border.all(color: solved ? _gold : Colors.white.withOpacity(0.12), width: solved ? 2 : 1),
        ),
        child: Text(t, style: dokkaebiTitle(size: 21, color: solved ? const Color(0xFF3A2A08) : _soft)),
      ),
    );
  }

  // ════════════════════════════════════════════════════
  // 13. SEJONG — 세종대왕
  // ════════════════════════════════════════════════════
  Widget _sejongScreen() {
    return Container(
      decoration: BoxDecoration(gradient: _sejongBg),
      child: LayoutBuilder(builder: (ctx, box) {
        return Stack(children: [
          Positioned(top: 58, left: 0, right: 0, child: Column(children: [
            _pill('글씨조각 3/4 — 마지막 조각은 어디에?', border: _gold, textColor: _gold),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () => setState(() => sideOpen = true),
              child: _pill('⚔ 사이드 — 이순신 장군 ${sideDone ? '완료 ✓' : '도전 가능'}', bg: const Color(0xFF2A3A52), opacity: 0.85, border: const Color(0xFFDCE8F8), textColor: const Color(0xFFDCE8F8)),
            ),
          ])),
          Positioned(left: 0, right: 0, top: box.maxHeight * .22, child: Center(child: _Floaty(anim: _float, amplitude: 10, child: const _Sejong(size: 170, halo: true)))),
          Positioned(left: 14, right: 14, bottom: 34, child: Column(mainAxisSize: MainAxisSize.min, children: [
            Stack(clipBehavior: Clip.none, children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(18, 22, 18, 16),
                decoration: BoxDecoration(color: _inkDeep.withOpacity(0.92), borderRadius: BorderRadius.circular(18), border: Border.all(color: _gold.withOpacity(0.7), width: 2)),
                child: Text('"그대가 흩어진 글씨를 모아 왔는가. 백성이 쉬이 익히라 만든 글이거늘, 잊혀선 아니 되네. 마지막 조각은… 그대 마음에 있네."', style: dokkaebiTitle(size: 16, color: _cream, height: 1.65)),
              ),
              Positioned(top: -14, left: 16, child: Row(children: [
                Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5), decoration: BoxDecoration(gradient: _goldGrad, borderRadius: BorderRadius.circular(8)), child: const Text('세종대왕', style: TextStyle(color: Color(0xFF3A2A08), fontWeight: FontWeight.w900, fontSize: 13))),
                const SizedBox(width: 6),
                Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5), decoration: BoxDecoration(color: _inkDeep.withOpacity(0.9), borderRadius: BorderRadius.circular(8), border: Border.all(color: _gold.withOpacity(0.5))), child: const Text('수호', style: TextStyle(color: _gold, fontWeight: FontWeight.w900, fontSize: 11))),
              ])),
            ]),
            const SizedBox(height: 10),
            _sejongChoice('"백성을 위한 글이었군요."', '굿 엔딩', _gold, () => _finish('good')),
            const SizedBox(height: 8),
            _sejongChoice('"보상부터 주시죠."', '노멀 엔딩', _muted, () => _finish('normal')),
          ])),
          if (sideOpen) _sideModal(),
        ]);
      }),
    );
  }

  Widget _sejongChoice(String text, String tag, Color tagColor, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(color: const Color(0xFF181410).withOpacity(0.94), borderRadius: BorderRadius.circular(14), border: Border.all(color: tagColor == _gold ? _gold.withOpacity(0.6) : Colors.white.withOpacity(0.14), width: tagColor == _gold ? 1.5 : 1)),
          child: Row(children: [
            Expanded(child: Text(text, style: TextStyle(fontSize: 14, color: tagColor == _gold ? _cream : const Color(0xFFE8DCC4), fontWeight: tagColor == _gold ? FontWeight.w700 : FontWeight.w500))),
            Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: tagColor.withOpacity(0.14), borderRadius: BorderRadius.circular(6)), child: Text(tag, style: TextStyle(fontSize: 11, color: tagColor, fontWeight: FontWeight.w900))),
          ]),
        ),
      );

  Widget _sideModal() {
    final sideAnswers = [('1', '학이 날개를 편 모양', true), ('2', '거북이 등딱지 모양', false), ('3', '일자로 늘어선 모양', false)];
    return Positioned.fill(child: Container(
      color: Colors.black.withOpacity(0.78),
      alignment: Alignment.center,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Stack(clipBehavior: Clip.none, children: [
          Container(
            padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
            decoration: BoxDecoration(color: _inkDeep.withOpacity(0.96), borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFFDCE8F8).withOpacity(0.3), width: 1.5)),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              const SizedBox(height: 6),
              RichText(text: TextSpan(style: _gowun(15, _cream, height: 1.6), children: const [
                TextSpan(text: '"묻겠다. 한산 앞바다에서 펼친 '),
                TextSpan(text: '학익진', style: TextStyle(color: _gold)),
                TextSpan(text: '은 무슨 모양이었는가."'),
              ])),
              const SizedBox(height: 13),
              for (final a in sideAnswers) Padding(padding: const EdgeInsets.only(bottom: 7), child: _sideOption(a.$1, a.$2, a.$3)),
              if (sideDone) ...[
                const SizedBox(height: 5),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                  decoration: BoxDecoration(color: _tealDeep.withOpacity(0.12), borderRadius: BorderRadius.circular(11), border: Border.all(color: _tealDeep.withOpacity(0.5))),
                  child: Row(children: [
                    const Flexible(child: Text('"과연." — 유물 「충무공의 나침반」 획득', style: TextStyle(fontSize: 13, color: _teal, fontWeight: FontWeight.w900))),
                    const Spacer(),
                    const Text('AR 탐지 범위 ↑', style: TextStyle(fontSize: 10.5, color: Color(0xFF8FA8C8), fontWeight: FontWeight.w700)),
                  ]),
                ),
                const SizedBox(height: 11),
                _cta('돌아가기', () => setState(() => sideOpen = false), bg: const Color(0xFF3A352E), fg: _cream),
              ],
            ]),
          ),
          Positioned(top: -13, left: 16, child: Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5), decoration: BoxDecoration(color: const Color(0xFF2A3A52), borderRadius: BorderRadius.circular(8)), child: const Text('이순신 장군', style: TextStyle(color: Color(0xFFDCE8F8), fontWeight: FontWeight.w900, fontSize: 13)))),
          Positioned(top: 12, right: 14, child: GestureDetector(onTap: () => setState(() => sideOpen = false), child: Container(width: 28, height: 28, alignment: Alignment.center, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(0.08)), child: const Text('✕', style: TextStyle(color: _soft, fontSize: 13))))),
        ]),
      ),
    ));
  }

  Widget _sideOption(String num, String label, bool correct) {
    final picked = sideDone && correct;
    return GestureDetector(
      onTap: () { if (correct) setState(() { sideDone = true; exp += 30; }); },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
        decoration: BoxDecoration(color: picked ? _tealDeep.withOpacity(0.14) : _cream.withOpacity(0.04), borderRadius: BorderRadius.circular(12), border: Border.all(color: picked ? _tealDeep : Colors.white.withOpacity(0.1), width: picked ? 1.5 : 1)),
        child: Row(children: [
          Container(width: 24, height: 24, alignment: Alignment.center, decoration: BoxDecoration(color: const Color(0xFF3A352E), borderRadius: BorderRadius.circular(7)), child: Text(num, style: const TextStyle(color: _soft, fontWeight: FontWeight.w900, fontSize: 12))),
          const SizedBox(width: 11),
          Expanded(child: Text(picked ? '✓ $label' : label, style: const TextStyle(fontSize: 13.5, color: Color(0xFFE8DCC4), fontWeight: FontWeight.w500))),
        ]),
      ),
    );
  }

  // ════════════════════════════════════════════════════
  // 14. ENDING — 엔딩
  // ════════════════════════════════════════════════════
  Widget _endingScreen() {
    final good = ending == 'good';
    return Container(
      decoration: const BoxDecoration(gradient: RadialGradient(center: Alignment(0, -0.32), radius: 1.0, colors: [Color(0xFF3A2E1A), Color(0xFF17120C), Color(0xFF0A0806)], stops: [0, .55, 1])),
      child: LayoutBuilder(builder: (ctx, box) {
        return Stack(children: [
          Positioned(left: 0, right: 0, top: box.maxHeight * .12, child: Center(child: _Floaty(anim: _float, child: Container(
            width: 200, height: 200, alignment: Alignment.center,
            child: Stack(alignment: Alignment.center, children: [
              AnimatedBuilder(animation: _glow, builder: (_, __) => Container(width: 200, height: 200, decoration: BoxDecoration(shape: BoxShape.circle, gradient: RadialGradient(colors: [_gold.withOpacity(0.35 * (0.55 + _glow.value * 0.45)), Colors.transparent], stops: const [0, 0.66])))),
              Container(width: 164, height: 164, padding: const EdgeInsets.all(22), decoration: BoxDecoration(shape: BoxShape.circle, gradient: const RadialGradient(center: Alignment(-0.2, -0.36), colors: [Color(0xFF4A4034), Color(0xFF2A2318), Color(0xFF17120C)], stops: [0, .55, 1]), border: Border.all(color: _gold.withOpacity(0.55), width: 2), boxShadow: [BoxShadow(color: _gold.withOpacity(0.4), blurRadius: 44)]),
                child: GridView.count(crossAxisCount: 2, physics: const NeverScrollableScrollPhysics(), children: [for (final c in ['訓', '民', '正', '音']) Center(child: Text(c, style: dokkaebiTitle(size: 32, color: const Color(0xFFFFE9B0))))])),
            ]),
          )))),
          Positioned(left: 0, right: 0, top: box.maxHeight * .41, child: Column(children: [
            Text(good ? '복 원 · 굿 엔딩' : '복 원 · 노멀 엔딩', style: const TextStyle(fontSize: 12, letterSpacing: 4, color: Color(0xFFA87F2C), fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            Text('종로 글씨 기억석 복원', style: dokkaebiTitle(size: 25, color: _cream)),
            const SizedBox(height: 8),
            Text('"백성의 글이 다시 깨어났다.\n그대의 걸음이 사백 년의 먹을 되살렸느니."', textAlign: TextAlign.center, style: dokkaebiTitle(size: 13, color: const Color(0xFFB3A892), height: 1.7)),
          ])),
          Positioned(left: 20, right: 20, bottom: 34, child: Column(mainAxisSize: MainAxisSize.min, children: [
            Row(children: [
              _endStat('칭호', '종로의 글지기', _gold, _gold),
              if (good) ...[const SizedBox(width: 8), _endStat('희귀 유물', '집현전 붓', _gold, _gold)],
              const SizedBox(width: 8),
              _endStat('경험치', '+$exp', _tealDeep, _teal),
            ]),
            if (sideDone) ...[
              const SizedBox(height: 8),
              Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11), decoration: BoxDecoration(color: const Color(0xFF2A3A52).withOpacity(0.4), borderRadius: BorderRadius.circular(13), border: Border.all(color: const Color(0xFFDCE8F8).withOpacity(0.25))), child: Row(children: [
                const Text('⚔ 사이드 완료 — 유물 「충무공의 나침반」', style: TextStyle(fontSize: 12, color: Color(0xFFDCE8F8))),
                const Spacer(),
                const Text('NEW', style: TextStyle(fontSize: 11, color: _teal, fontWeight: FontWeight.w900)),
              ])),
            ],
            const SizedBox(height: 8),
            Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11), decoration: BoxDecoration(color: _cream.withOpacity(0.05), borderRadius: BorderRadius.circular(13), border: Border.all(color: Colors.white.withOpacity(0.1))), child: Row(children: [
              Expanded(child: Text('총 지출 ${_won(spent)} · 예산 ${_won(budget)} 안에서 ✓', style: const TextStyle(fontSize: 12, color: _soft))),
              Text('여비 ${_won(_remain)} 남음', style: const TextStyle(fontSize: 11, color: _teal, fontWeight: FontWeight.w900)),
            ])),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: GestureDetector(onTap: _restart, child: Container(height: 48, alignment: Alignment.center, decoration: BoxDecoration(borderRadius: BorderRadius.circular(13), border: Border.all(color: Colors.white.withOpacity(0.18))), child: const Text('처음부터 다시', style: TextStyle(color: _soft, fontWeight: FontWeight.w900, fontSize: 14))))),
              const SizedBox(width: 8),
              Expanded(flex: 14, child: GestureDetector(
                onTap: () => Navigator.of(context).maybePop(),
                child: Container(height: 48, alignment: Alignment.center, decoration: BoxDecoration(gradient: _goldGrad, borderRadius: BorderRadius.circular(13), boxShadow: [BoxShadow(color: const Color(0xFFE8C268).withOpacity(0.3), blurRadius: 22, offset: const Offset(0, 8))]), child: const Text('다음 지역 — 북촌 해금', style: TextStyle(color: Color(0xFF3A2A08), fontWeight: FontWeight.w900, fontSize: 14))),
              )),
            ]),
          ])),
        ]);
      }),
    );
  }

  Widget _endStat(String label, String value, Color border, Color valueColor) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(color: _cream.withOpacity(0.06), borderRadius: BorderRadius.circular(13), border: Border.all(color: border.withOpacity(0.4))),
          child: Column(children: [
            Text(label, style: TextStyle(fontSize: 10.5, color: border == _tealDeep ? _tealDeep : const Color(0xFFA87F2C), fontWeight: FontWeight.w900, letterSpacing: 0.7)),
            const SizedBox(height: 4),
            Text(value, style: dokkaebiTitle(size: 13.5, color: valueColor), maxLines: 1, overflow: TextOverflow.ellipsis),
          ]),
        ),
      );

  // ════════════════════════════════════════════════════
  // 모달: 보상 / 힌트 / 컬렉션
  // ════════════════════════════════════════════════════
  /// 조각 기록 공통 팝업 — 기록 중 안내, 실패하면 이유와 다시 시도.
  /// 다시 해도 안 되는 실패면 "기록 없이 계속"도 준다. 닫으면 미션 화면에 남아 버튼으로 다시 시도할 수 있다.
  Widget _recordSheet() {
    final failure = _recordFailure;
    final claim = _pendingClaim;
    return Positioned.fill(child: Container(
      color: Colors.black.withOpacity(0.72),
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 26),
      child: _parchment(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(failure == null ? '조각을 기록하는 중…' : '조각을 기록하지 못했느니라',
              textAlign: TextAlign.center, style: dokkaebiTitle(size: 18, color: _parchInk)),
          const SizedBox(height: 14),
          if (failure == null)
            const Center(child: SizedBox(width: 26, height: 26, child: CircularProgressIndicator(strokeWidth: 2.6, color: _verm)))
          else ...[
            Text(
              failure.canSkip ? '${failure.message} 기록 없이 가면 이 조각은 서버에 남지 않느니라.' : failure.message,
              textAlign: TextAlign.center,
              style: _gowun(13.5, _parchInkSoft, height: 1.55),
            ),
            const SizedBox(height: 16),
            if (claim != null) ...[
              _cta('다시 시도', () => _claimChapter(claim.chapterIdx, extra: claim.extra, onClaimed: claim.onClaimed)),
              if (failure.canSkip) ...[
                const SizedBox(height: 8),
                _cta('기록 없이 계속', () => _confirmClaim(claim, null), bg: _bronze, fg: _cream),
              ],
            ],
            const SizedBox(height: 6),
            Center(child: TextButton(
              onPressed: () => setState(() {
                _recordFailure = null;
                _pendingClaim = null;
              }),
              child: const Text('닫기', style: TextStyle(color: _bronze, fontWeight: FontWeight.w700)),
            )),
          ],
        ]),
      ),
    ));
  }

  /// 조각 획득 팝업 — 방금 확정된 챕터([c])의 실제 장소·단서·쿠폰과 서버가 준 보상을 보여준다.
  Widget _rewardModal(_ClaimedReward c) {
    final t = targets[c.chapterIdx.clamp(0, targets.length - 1)];
    final reward = c.reward;
    final region = widget.scenario?.region ?? _defaultRegion;
    // 단서는 노드가 준 것 우선 — 코스 없는 데모 모드만 시안 기본 체인(申時→ㄱ→ㅏ).
    final clue = t.clue ?? (widget.scenario == null ? _defaultClues[c.chapterIdx.clamp(0, 3)] : '');
    // 이 챕터에서 실제로 지급한 쿠폰만(발자국 미션 등) — 없으면 줄 자체를 빼고 보여주지 않는다.
    final coupons = c.extra.where((r) => r.kind == StateKind.coupon && (r.amount ?? 0) > 0).toList();
    final couponAmount = coupons.fold<int>(0, (sum, r) => sum + (r.amount ?? 0));
    return Positioned.fill(child: Container(
        color: Colors.black.withOpacity(0.8),
        alignment: Alignment.center,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 26),
          child: Stack(clipBehavior: Clip.none, children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(22, 26, 22, 20),
              decoration: BoxDecoration(gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFF4EDDA), Color(0xFFEADFC4)]), borderRadius: BorderRadius.circular(22), border: Border.all(color: const Color(0xFFD8C9A4)), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.7), blurRadius: 70)]),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const SizedBox(height: 8),
                _FragShard(glyph: t.hanja, size: 104, fontSize: 48),
                const SizedBox(height: 14),
                Text('「${t.name}」의 기억석 조각',
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: dokkaebiTitle(size: 20, color: _parchInk)),
                const SizedBox(height: 4),
                Text('${region.isEmpty ? '' : '$region의 '}기억석 · ${c.chapterIdx + 1}/$_stoneTotal 조각',
                    style: const TextStyle(fontSize: 13, color: _bronze, fontWeight: FontWeight.w700)),
                const SizedBox(height: 14),
                // 경험치·도감·칭호는 서버가 계산해 실제로 지급한 값 — 로컬 추정이 아니다.
                if (reward != null)
                  _rewardRow('경험치', reward.alreadyRewarded ? '이미 받은 보상' : '+${reward.expGained}', _tealDeep)
                else if (widget.scenario != null)
                  Text('이 조각은 서버에 남지 않았느니라.',
                      textAlign: TextAlign.center, style: _gowun(12.5, _bronze)),
                if (clue.isNotEmpty) ...[
                  const SizedBox(height: 7),
                  _rewardRow('단서 「$clue」', '신규', _verm),
                ],
                if (couponAmount > 0) ...[
                  const SizedBox(height: 7),
                  _rewardRow('${coupons.first.to ?? ''} 쿠폰'.trim(), '+${_won(couponAmount)}', _goldDim),
                ],
                if (reward?.dexEntry != null) ...[
                  const SizedBox(height: 7),
                  _rewardRow('도감', '«${reward!.dexEntry}»', _blue),
                ],
                for (final title in reward?.titles ?? const <String>[]) ...[
                  const SizedBox(height: 7),
                  _rewardRow('칭호', title, _goldDim),
                ],
                const SizedBox(height: 16),
                _cta('가방에 넣기 — 지도로', () => setState(() { showReward = false; screen = 'map'; }), bg: _parchInk, fg: _cream),
              ]),
            ),
            Positioned(top: -16, left: 0, right: 0, child: Center(child: Container(padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 7), decoration: BoxDecoration(color: _verm, borderRadius: BorderRadius.circular(999), boxShadow: [BoxShadow(color: _verm.withOpacity(0.5), blurRadius: 18, offset: const Offset(0, 6))]), child: const Text('획 득', style: TextStyle(color: Color(0xFFFDF6E6), fontWeight: FontWeight.w900, fontSize: 15, letterSpacing: 1.4))))),
          ]),
        ),
      ));
  }

  Widget _rewardRow(String label, String value, Color c) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
        decoration: BoxDecoration(color: const Color(0xFF2A2118).withOpacity(0.06), borderRadius: BorderRadius.circular(10)),
        child: Row(children: [
          Text('✦', style: TextStyle(color: c, fontWeight: FontWeight.w900)),
          const SizedBox(width: 10),
          // 장소·도깨비·칭호 이름이 들어오면서 길이가 데이터에 따라 달라진다 — 넘치면 줄임표.
          Expanded(
              child: Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13, color: _parchInkSoft))),
          const SizedBox(width: 10),
          Flexible(
              child: Text(value,
                  textAlign: TextAlign.right,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 13, color: c, fontWeight: FontWeight.w900))),
        ]),
      );

  Widget _hintSheet() => Positioned.fill(child: Stack(children: [
        GestureDetector(onTap: () => setState(() => hintOpen = false), child: Container(color: Colors.black.withOpacity(0.55))),
        Align(alignment: Alignment.bottomCenter, child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 40),
          decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFF4EDDA), Color(0xFFEADFC4)]), borderRadius: BorderRadius.vertical(top: Radius.circular(26))),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Center(child: Container(width: 44, height: 5, decoration: BoxDecoration(color: const Color(0xFFC9B88F), borderRadius: BorderRadius.circular(999)))),
            const SizedBox(height: 14),
            Row(children: [
              Text('도깨비의 귀띔', style: dokkaebiTitle(size: 19, color: _parchInk)),
              const Spacer(),
              // 사다리 단수 표시 — 열린 단만 주홍
              for (var t = 1; t <= 3; t++) ...[
                if (t > 1) const SizedBox(width: 5),
                _hdot(hint.openTier >= t ? _verm : const Color(0xFFC9B88F)),
              ],
            ]),
            const SizedBox(height: 14),
            // 열린 단의 문구만 노출 (H1 fail1|idle60 → H2 idle90 → H3 요청)
            if (hint.openTier == 0)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFC9B88F), width: 1.5)),
                child: Text('아직 귀띔할 때가 아니니라. 잠시 헤매어 보거라.',
                    style: dokkaebiTitle(size: 14, color: _bronze, height: 1.55)),
              )
            else
              for (var t = 1; t <= hint.openTier; t++)
                if (hint.ladder.textOf(t) != null) ...[
                  if (t > 1) const SizedBox(height: 10),
                  _hintCard('힌트 $t', hint.ladder.textOf(t)!),
                ],
            // 다음 단 — 붓털을 치르고 앞당기기(데드락 금지 방향의 요청형 개방)
            if (hint.hasMore) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFC9B88F), width: 1.5)),
                child: Row(children: [
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('힌트 ${hint.openTier + 1} — ${hint.openTier + 1 == 3 ? '정답에 가깝다' : '장소를 짚어준다'}',
                        style: const TextStyle(fontSize: 13, color: _parchInkSoft, fontWeight: FontWeight.w700)),
                    Text('보유 붓털 $brush개 · 아낄수록 탐구 보너스 ↑ (현재 ×${hint.penaltyFactor.toStringAsFixed(1)})',
                        style: const TextStyle(fontSize: 11, color: _bronze)),
                  ])),
                  GestureDetector(
                    onTap: brush <= 0 ? null : () => setState(() {
                      if (hint.forceNext()) brush = math.max(0, brush - 1);
                    }),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                      decoration: BoxDecoration(color: brush <= 0 ? _bronze : _parchInk, borderRadius: BorderRadius.circular(10)),
                      child: Text(brush <= 0 ? '붓털 없음' : '붓털 1개로 열기',
                          style: const TextStyle(color: _cream, fontSize: 12.5, fontWeight: FontWeight.w900)),
                    ),
                  ),
                ]),
              ),
            ],
            const SizedBox(height: 14),
            Center(child: GestureDetector(onTap: () => setState(() => hintOpen = false), child: const Text('닫기', style: TextStyle(fontSize: 12.5, color: _bronze, fontWeight: FontWeight.w700)))),
          ]),
        )),
      ]));

  Widget _hdot(Color c) => Container(width: 9, height: 9, decoration: BoxDecoration(shape: BoxShape.circle, color: c));

  Widget _hintCard(String tag, String text) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: BoxDecoration(color: const Color(0xFF2A2118).withOpacity(0.06), borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFD8C9A4))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2), decoration: BoxDecoration(color: _verm, borderRadius: BorderRadius.circular(6)), child: Text(tag, style: const TextStyle(color: Color(0xFFFDF6E6), fontSize: 11, fontWeight: FontWeight.w900))),
          const SizedBox(height: 8),
          Text(text, style: dokkaebiTitle(size: 15, color: _parchInk, height: 1.55)),
        ]),
      );

  Widget _collSheet() {
    return Positioned.fill(child: Stack(children: [
      GestureDetector(onTap: () => setState(() => collOpen = false), child: Container(color: Colors.black.withOpacity(0.55))),
      Align(alignment: Alignment.bottomCenter, child: FractionallySizedBox(
        heightFactor: 0.86,
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
          decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [_parchTop, Color(0xFFEFE6D0)]), borderRadius: BorderRadius.vertical(top: Radius.circular(26))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Center(child: Container(width: 44, height: 5, decoration: BoxDecoration(color: const Color(0xFFC9B88F), borderRadius: BorderRadius.circular(999)))),
            const SizedBox(height: 14),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Text('기억석 컬렉션', style: dokkaebiTitle(size: 23, color: _parchInk)),
                RichText(text: TextSpan(style: const TextStyle(fontSize: 12.5, color: _bronze), children: [
                  TextSpan(text: '잊혀진 글씨의 $_stoneTotal조각 — '),
                  TextSpan(text: '$fragments', style: const TextStyle(color: _verm, fontWeight: FontWeight.w900)),
                  TextSpan(text: ' / $_stoneTotal 회수'),
                ])),
              ]),
              const Spacer(),
              GestureDetector(onTap: () => setState(() => collOpen = false), child: Container(width: 34, height: 34, alignment: Alignment.center, decoration: BoxDecoration(shape: BoxShape.circle, color: const Color(0xFF2A2118).withOpacity(0.08), border: Border.all(color: const Color(0xFFD8C9A4))), child: const Text('✕', style: TextStyle(color: _bronze, fontSize: 14)))),
            ]),
            const SizedBox(height: 14),
            Container(height: 1, color: const Color(0xFFDDD0B0)),
            const SizedBox(height: 14),
            // 단서함 — 상태 그래프에 실제로 모인 단서(申時→ㄱ→ㅏ 체인)
            if (pstate.clues.isNotEmpty) ...[
              Text('단서함', style: dokkaebiTitle(size: 14, color: _bronze)),
              const SizedBox(height: 7),
              Wrap(spacing: 6, runSpacing: 6, children: [
                for (final c in pstate.clues) _stateChip(c, got: true),
                if (pstate.flags.isNotEmpty)
                  for (final f in pstate.flags)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                      decoration: BoxDecoration(
                        color: _gold.withOpacity(0.14),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: _goldDim.withOpacity(0.7)),
                      ),
                      child: Text('성향 · $f', style: dokkaebiTitle(size: 12.5, color: const Color(0xFF7A5A12))),
                    ),
              ]),
              const SizedBox(height: 14),
            ],
            Expanded(child: GridView.count(
              crossAxisCount: 2, mainAxisSpacing: 11, crossAxisSpacing: 11, childAspectRatio: 0.92,
              children: [for (var i = 0; i < targets.length; i++) _collCard(i, targets[i], i < fragments)],
            )),
          ]),
        ),
      )),
    ]));
  }

  Widget _collCard(int i, _Target t, bool got) => Container(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 13),
        decoration: BoxDecoration(color: got ? const Color(0xFFFBF6E9) : const Color(0x0A2A2118), borderRadius: BorderRadius.circular(16), border: Border.all(color: got ? const Color(0xFFE2D5B2) : const Color(0xFFDDD0B0))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Transform.rotate(
              angle: math.pi / 4,
              child: Container(
                width: 40, height: 40, alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: got ? const LinearGradient(colors: [Color(0xFFF4D98A), _goldDim]) : null,
                  color: got ? null : const Color(0x142A2118),
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(color: got ? _verm : const Color(0xFFC9B88F), width: 2),
                  boxShadow: got ? [BoxShadow(color: _gold.withOpacity(0.5), blurRadius: 14)] : null,
                ),
                child: Transform.rotate(angle: -math.pi / 4, child: Text(got ? t.hanja : '?', style: dokkaebiTitle(size: 17, color: got ? const Color(0xFF7A2A12) : const Color(0xFFB7A374)))),
              ),
            ),
            const Spacer(),
            Text('第 ${i + 1}', style: dokkaebiTitle(size: 12, color: const Color(0xFFB7A374))),
          ]),
          const Spacer(),
          Text(got ? t.title : '봉인된 조각', style: dokkaebiTitle(size: 16.5, color: got ? _parchInk : _bronze)),
          const SizedBox(height: 4),
          Text(got ? t.obj : '아직 되찾지 못한 조각', style: const TextStyle(fontSize: 11.5, color: _bronze, height: 1.5)),
        ]),
      );

  // ── 공유 그라디언트 ──
  static const _dialBg = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF1B2138), Color(0xFF2A2440), Color(0xFF453230), Color(0xFF17120E)], stops: [0, .38, .62, 1]);
  static const _sejongBg = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFD8A86A), Color(0xFFC98A52), Color(0xFF8A5A3E), Color(0xFF4A3226), Color(0xFF241A12)], stops: [0, .26, .52, .76, 1]);
}

// ════════════════════════════════════════════════════════
// 재사용 시각 부품 (도깨비/세종/먹그림자/조각/배경 등)
// ════════════════════════════════════════════════════════

/// google_fonts Gowun Batang 스타일(RichText용).
TextStyle _gowun(double size, Color color, {double? height, FontWeight weight = FontWeight.w400}) =>
    dokkaebiTitle(size: size, color: color, height: height, weight: weight);

/// 위아래로 둥실.
class _Floaty extends StatelessWidget {
  final Animation<double> anim;
  final Widget child;
  final double amplitude;
  const _Floaty({required this.anim, required this.child, this.amplitude = 8});
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: anim,
        builder: (_, c) => Transform.translate(offset: Offset(0, math.sin(anim.value * math.pi) * -amplitude), child: c),
        child: child,
      );
}

/// 먹 도깨비 — 검은 blob + 금빛 눈 + 뿔.
class _Dokkaebi extends StatelessWidget {
  final double size;
  const _Dokkaebi({this.size = 140});
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size, height: size,
      child: Stack(clipBehavior: Clip.none, children: [
        Positioned(top: -14, left: size * .28, child: _horn(-14, 20, 30)),
        Positioned(top: -10, right: size * .30, child: _horn(12, 17, 24)),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.all(Radius.elliptical(size * .49, size * .52)),
            gradient: const RadialGradient(center: Alignment(-0.24, -0.36), radius: 0.9, colors: [Color(0xFF33291F), Color(0xFF17130F), Color(0xFF0A0806)], stops: [0, .55, 1]),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.65), blurRadius: 44, offset: const Offset(0, 18))],
          ),
        ),
        Positioned(top: size * .34, left: size * .27, child: _eye()),
        Positioned(top: size * .34, right: size * .27, child: _eye()),
      ]),
    );
  }

  Widget _eye() => Container(width: 15, height: 17, decoration: BoxDecoration(color: _gold, borderRadius: BorderRadius.circular(9), boxShadow: [BoxShadow(color: _gold.withOpacity(0.9), blurRadius: 16)]));
  Widget _horn(double deg, double w, double h) => Transform.rotate(angle: deg * math.pi / 180, child: CustomPaint(size: Size(w, h), painter: _HornPainter()));
}

class _HornPainter extends CustomPainter {
  @override
  void paint(Canvas c, Size s) {
    c.drawPath(Path()..moveTo(s.width / 2, 0)..lineTo(0, s.height)..lineTo(s.width, s.height)..close(), Paint()..color = _ink);
  }
  @override
  bool shouldRepaint(_) => false;
}

/// 세종대왕 정령 — 금빛 실루엣 + 익선관.
class _Sejong extends StatelessWidget {
  final double size;
  final bool halo;
  const _Sejong({this.size = 170, this.halo = false});
  @override
  Widget build(BuildContext context) {
    final bodyW = size * .88, bodyH = size;
    return SizedBox(
      width: size, height: size * 1.06,
      child: Stack(alignment: Alignment.topCenter, clipBehavior: Clip.none, children: [
        if (halo) Positioned(top: size * .04, child: Container(width: size * .95, height: size * .95, decoration: BoxDecoration(shape: BoxShape.circle, gradient: RadialGradient(colors: [_gold.withOpacity(0.3), Colors.transparent], stops: const [0, 0.68])))),
        // 관모
        Positioned(top: -20, child: Container(width: size * .45, height: 26, decoration: BoxDecoration(gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF2A2118), _ink]), border: Border.all(color: _goldDim, width: 1.5), borderRadius: const BorderRadius.vertical(top: Radius.circular(6), bottom: Radius.circular(2))))),
        Positioned(top: -34, child: Container(width: size * .21, height: 18, decoration: BoxDecoration(color: _ink, border: Border.all(color: _goldDim, width: 1.5), borderRadius: const BorderRadius.vertical(top: Radius.circular(5))))),
        // 얼굴
        Positioned(top: 6, child: Container(
          width: bodyW, height: bodyH,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.all(Radius.elliptical(bodyW, bodyH)),
            gradient: const RadialGradient(center: Alignment(-0.16, -0.44), colors: [Color(0xFF4A3D28), Color(0xFF241D12), Color(0xFF100C07)], stops: [0, .52, 1]),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.6), blurRadius: 50, offset: const Offset(0, 20))],
          ),
        )),
        Positioned(top: size * .40, left: size * .30, child: _eye()),
        Positioned(top: size * .40, right: size * .30, child: _eye()),
      ]),
    );
  }

  Widget _eye() => Container(width: 15, height: 16, decoration: BoxDecoration(color: const Color(0xFFFFE9B0), borderRadius: BorderRadius.circular(8), boxShadow: [BoxShadow(color: const Color(0xFFFFE9B0).withOpacity(0.95), blurRadius: 18)]));
}

/// 먹그림자(적) — 검은 blob + 붉은 눈 + 펄스 링.
class _MeokShadow extends StatelessWidget {
  final double size;
  final Animation<double> pulse;
  const _MeokShadow({required this.size, required this.pulse});
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size, height: size,
      child: Stack(alignment: Alignment.center, clipBehavior: Clip.none, children: [
        AnimatedBuilder(animation: pulse, builder: (_, __) => Container(width: size + 16 + size * .3 * pulse.value, height: size + 16 + size * .3 * pulse.value, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: _verm.withOpacity(0.7 * (1 - pulse.value)), width: 2)))),
        Container(
          width: size, height: size,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.all(Radius.elliptical(size * .5, size * .5)),
            gradient: const RadialGradient(center: Alignment(-0.2, -0.4), colors: [Color(0xFF262029), Color(0xFF0B0A0D), Color(0xFF000000)], stops: [0, .6, 1]),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.7), blurRadius: 30, offset: const Offset(0, 12))],
          ),
        ),
        Positioned(left: size * .26, top: size * .36, child: _eye(size)),
        Positioned(right: size * .26, top: size * .36, child: _eye(size)),
      ]),
    );
  }

  Widget _eye(double s) => Container(width: s * .11, height: s * .13, decoration: BoxDecoration(shape: BoxShape.circle, color: const Color(0xFFFF5D45), boxShadow: [BoxShadow(color: const Color(0xFFFF5D45).withOpacity(0.9), blurRadius: 12)]));
}

/// 글씨 파편 조각 — 각진 돌 + 금빛 글자.
class _FragShard extends StatelessWidget {
  final String glyph;
  final double size;
  final double fontSize;
  const _FragShard({required this.glyph, this.size = 52, this.fontSize = 20});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: size, height: size * 1.13, alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: const LinearGradient(begin: Alignment.topRight, end: Alignment.bottomLeft, colors: [Color(0xFF3B332A), Color(0xFF221C15)]),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [BoxShadow(color: _gold.withOpacity(0.45), blurRadius: 22)],
      ),
      child: Text(glyph, style: dokkaebiTitle(size: fontSize, color: _gold)),
    );
  }
}

/// 지도 격자 배경.
class _GridPainter extends CustomPainter {
  const _GridPainter();
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = const Color(0xFFF4EDDA).withOpacity(0.045)..strokeWidth = 1;
    const step = 46.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), p);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
    }
  }
  @override
  bool shouldRepaint(_) => false;
}

/// 한옥 지붕 실루엣.
class _RoofClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size s) {
    final w = s.width, h = s.height;
    return Path()
      ..moveTo(0, h * .66)..lineTo(w * .14, h * .36)..lineTo(w * .32, h * .60)..lineTo(w * .52, h * .16)
      ..lineTo(w * .70, h * .58)..lineTo(w * .88, h * .32)..lineTo(w, h * .62)..lineTo(w, h)..lineTo(0, h)..close();
  }
  @override
  bool shouldReclip(_) => false;
}

/// 대문(성문) 실루엣.
class _GateClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size s) {
    final w = s.width, h = s.height;
    return Path()
      ..moveTo(0, h)..lineTo(w * .08, h * .30)..lineTo(w * .50, 0)..lineTo(w * .92, h * .30)..lineTo(w, h)..close();
  }
  @override
  bool shouldReclip(_) => false;
}

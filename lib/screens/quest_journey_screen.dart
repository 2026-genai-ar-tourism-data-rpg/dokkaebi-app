// ============================================================
// [v1] 화면: 퀘스트 여정 — "종로, 잊혀진 글씨의 비밀 플레이 v2" 시안 1:1 재현
// pipeline: 모바일 클라이언트 / 화면 (새 퀘스트 시작하기 → 전 구간 플레이)
// 구현(요약): setup→지도→GPS→AR소환→대화→퀴즈→지령→사냥→사진→발자국→카페→
//            인사동→세종→엔딩 + 보상/힌트/컬렉션 모달을 한 화면 상태머신으로 재현.
//            콘텐츠(코스명·장소·조각)는 Scenario 데이터 연동, 없으면 종로 기본값 폴백.
// 구현일: 2026-07-08 | 작성: kys (quest-journey/kys/v1) · 시안: 종로의 기억석 플레이 v2 standalone
// ============================================================
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../game/hint_ladder_controller.dart';
import '../game/player_state.dart';
import '../models/scenario.dart';
import '../store.dart';
import '../theme.dart';

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

class QuestJourneyScreen extends StatefulWidget {
  final Scenario? scenario;
  const QuestJourneyScreen({super.key, this.scenario});
  @override
  State<QuestJourneyScreen> createState() => _QuestJourneyScreenState();
}

class _QuestJourneyScreenState extends State<QuestJourneyScreen> with TickerProviderStateMixin {
  // ── 시안 initState 그대로 ──
  String screen = 'setup';
  int budget = 20000, hours = 2;
  final Map<String, bool> tags = {
    'history': true, 'hanok': true, 'cafe': true,
    'food': false, 'photo': false, 'market': false,
  };
  String? flag;
  int dlgStep = 0;
  String quizState = 'idle';
  int fragments = 0, coupon = 0, spent = 0, exp = 0, brush = 3;
  late List<Map<String, dynamic>> enemies = [
    {'id': 1, 'left': .38, 'top': .30, 'size': 96.0, 'dur': 3.0, 'dead': false},
    {'id': 2, 'left': .12, 'top': .48, 'size': 64.0, 'dur': 3.6, 'dead': false},
    {'id': 3, 'left': .68, 'top': .44, 'size': 72.0, 'dur': 2.8, 'dead': false},
    {'id': 4, 'left': .26, 'top': .22, 'size': 58.0, 'dur': 3.3, 'dead': false},
    {'id': 5, 'left': .62, 'top': .20, 'size': 54.0, 'dur': 2.6, 'dead': false},
  ];
  String photoState = 'idle';
  int scan = 0;
  int trail = 0;
  bool fragTaken = false, showReward = false;
  bool hintOpen = false;
  bool cafeOrdered = false;
  String cafeState = 'idle';
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
  }

  /// 저장된 진행 복원 — 갈림길 선택·인벤토리를 먼저 읽어야 경로가 확정된다.
  void _restoreProgress() {
    final s = widget.scenario;
    if (s == null) return;
    branchChoices.addAll(ScenarioStore.I.choicesOf(s.scenarioId));
    pstate.applyAll(
        ScenarioStore.I.inventoryOf(s.scenarioId).map(StateRef.parse));
    fragments = math.min(4, pstate.fragments.length);
    coupon = pstate.couponTotal;
  }

  /// Scenario → 챕터 매핑. **실제 밟는 경로(playedPath)의 조각 노드**를 쓴다 —
  /// 갈림길을 b1로 골랐으면 샛길 노드가 챕터로 들어온다. 없으면 종로 기본값.
  List<_Target> _resolveTargets(Scenario? s) {
    if (s == null) return _defaultTargets;
    final stones = s.playedPath(branchChoices).where((n) => n.isStone).toList();
    if (stones.isEmpty) return _defaultTargets;
    return [
      for (var i = 0; i < 4; i++)
        if (i < stones.length)
          _Target(
            stones[i].name ?? _defaultTargets[i].name,
            _defaultTargets[i].hanja,
            stones[i].distM?.round() ?? _defaultTargets[i].dist0,
            _defaultTargets[i].title,
            stones[i].objective?.order.isNotEmpty == true
                ? stones[i].objective!.order
                : (stones[i].mission?.order.isNotEmpty == true
                    ? stones[i].mission!.order
                    : _defaultTargets[i].obj),
            _defaultTargets[i].after,
            node: stones[i],
          )
        else
          _defaultTargets[i],
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
    _hint?.removeListener(_onHintChanged);
    _hint?.dispose();
    super.dispose();
  }

  void go(String s) => setState(() => screen = s);

  int get _tIdx => math.min(3, fragments);
  _Target get _target => targets[_tIdx];

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

    final after = t.after;
    if (after == 'summon-meok' || after == 'summon-sejong') {
      setState(() {
        screen = 'summon';
        summonFor = after == 'summon-meok' ? 'meok' : 'sejong';
        summonPhase = 'scan';
      });
      _summonTimer?.cancel();
      _summonTimer = Timer(const Duration(milliseconds: 1500), () => setState(() => summonPhase = 'appear'));
    } else {
      go(after);
    }
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

  /// 선택지 효과(플래그·친밀도·쿠폰) 즉시 적용 + 영속. 규칙 2조: grants 종류는 안 바뀐다.
  Future<void> _applyChoice(List<StateRef> refs) async {
    pstate.applyAll(refs);
    final s = widget.scenario;
    if (s != null) await ScenarioStore.I.grant(s.scenarioId, refs);
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
    setState(() {
      ending = resolved;
      screen = 'ending';
      fragments = 4;
      exp += 200;
    });
    await _grantChapter(3);
    final s = widget.scenario;
    if (s != null) await ScenarioStore.I.setEnding(s.scenarioId, resolved);
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
      screen = 'setup';
      budget = 20000;
      hours = 2;
      tags.updateAll((k, v) => {'history': true, 'hanok': true, 'cafe': true, 'food': false, 'photo': false, 'market': false}[k]!);
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
      cafeState = 'idle';
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
        if (showReward) _rewardModal(),
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
      case 'setup':
        return _setupScreen();
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
    return _setupScreen();
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
  // 1. SETUP — 새 여정 꾸리기
  // ════════════════════════════════════════════════════
  Widget _setupScreen() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [_ink, Color(0xFF211A14)]),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 24, 18, 40),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('새 여정 꾸리기', style: dokkaebiTitle(size: 24, color: _cream)),
            const SizedBox(height: 4),
            const Text('조건을 적으면, 도깨비가 길을 놓는다', style: TextStyle(fontSize: 12.5, color: _muted)),
            const SizedBox(height: 16),
            // 출발/도착 카드
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _cream.withOpacity(0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _goldDim.withOpacity(0.3)),
              ),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Column(children: [
                    Container(width: 11, height: 11, decoration: BoxDecoration(shape: BoxShape.circle, color: _tealDeep, boxShadow: [BoxShadow(color: _tealDeep.withOpacity(0.7), blurRadius: 8)])),
                    Container(width: 2, height: 40, color: Colors.white.withOpacity(0.14), margin: const EdgeInsets.symmetric(vertical: 4)),
                    Container(width: 11, height: 11, decoration: BoxDecoration(borderRadius: BorderRadius.circular(3), color: _goldDim, boxShadow: [BoxShadow(color: _goldDim.withOpacity(0.7), blurRadius: 8)])),
                  ]),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    _routeField('출발', _teal, '안국역 3호선', hint: ' · 현재 위치'),
                    const SizedBox(height: 12),
                    _routeField('도착', _gold, targets.last.name),
                  ]),
                ),
              ]),
            ),
            const SizedBox(height: 12),
            // 시간 / 여비
            Row(children: [
              Expanded(child: _stepper('시간', _soft, '$hours시간', () => setState(() => hours = math.max(1, hours - 1)), () => setState(() => hours = math.min(4, hours + 1)))),
              const SizedBox(width: 10),
              Expanded(child: _stepper('여비 (예산)', _goldDim, _won(budget), () => setState(() => budget = math.max(10000, budget - 5000)), () => setState(() => budget = math.min(50000, budget + 5000)), valueColor: _gold, border: _goldDim.withOpacity(0.35))),
            ]),
            const SizedBox(height: 12),
            // 취향 태그
            Container(
              padding: const EdgeInsets.fromLTRB(14, 13, 14, 14),
              decoration: BoxDecoration(
                color: _cream.withOpacity(0.05),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                RichText(
                  text: const TextSpan(children: [
                    TextSpan(text: '가고 싶은 곳 · 취향 ', style: TextStyle(color: _soft, fontSize: 10.5, fontWeight: FontWeight.w900, letterSpacing: 0.8)),
                    TextSpan(text: '(탭해서 켜고 끄기)', style: TextStyle(color: _muted, fontSize: 10.5, fontWeight: FontWeight.w500)),
                  ]),
                ),
                const SizedBox(height: 10),
                Wrap(spacing: 7, runSpacing: 7, children: [
                  for (final e in const [['history', '역사 이야기'], ['hanok', '한옥·골목'], ['cafe', '카페'], ['food', '미식'], ['photo', '사진 명소'], ['market', '시장 구경']])
                    _tagChip(e[0], e[1]),
                ]),
              ]),
            ),
            const SizedBox(height: 28),
            _cta('도깨비에게 길 묻기', () => go('map'), bg: const Color(0xFFC89A3A), fg: const Color(0xFF3A2A08), gradient: _goldGrad, fontSize: 16),
          ]),
        ),
      ),
    );
  }

  Widget _routeField(String label, Color labelColor, String value, {String? hint}) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: labelColor, fontSize: 10.5, fontWeight: FontWeight.w900, letterSpacing: 0.8)),
          const SizedBox(height: 4),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: _inkDeep.withOpacity(0.6),
              borderRadius: BorderRadius.circular(11),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: RichText(
              text: TextSpan(children: [
                TextSpan(text: value, style: const TextStyle(color: _cream, fontSize: 15, fontWeight: FontWeight.w700)),
                if (hint != null) TextSpan(text: hint, style: const TextStyle(color: _muted, fontSize: 11, fontWeight: FontWeight.w500)),
              ]),
            ),
          ),
        ],
      );

  Widget _stepper(String label, Color labelColor, String value, VoidCallback down, VoidCallback up, {Color valueColor = _cream, Color? border}) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
        decoration: BoxDecoration(
          color: _cream.withOpacity(0.05),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: border ?? Colors.white.withOpacity(0.1)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: TextStyle(color: labelColor, fontSize: 10.5, fontWeight: FontWeight.w900, letterSpacing: 0.8)),
          const SizedBox(height: 6),
          Row(children: [
            _stepBtn('−', down),
            Expanded(child: Center(child: Text(value, style: dokkaebiTitle(size: 19, color: valueColor)))),
            _stepBtn('+', up),
          ]),
        ]),
      );

  Widget _stepBtn(String s, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 32, height: 32, alignment: Alignment.center,
          decoration: BoxDecoration(
            color: _inkDeep.withOpacity(0.6),
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: Colors.white.withOpacity(0.12)),
          ),
          child: Text(s, style: const TextStyle(color: _soft, fontSize: 16)),
        ),
      );

  Widget _tagChip(String key, String label) {
    final on = tags[key] ?? false;
    return GestureDetector(
      onTap: () => setState(() => tags[key] = !on),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
        decoration: BoxDecoration(
          color: on ? _verm : _inkDeep.withOpacity(0.5),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: on ? _verm : Colors.white.withOpacity(0.14)),
        ),
        child: Text(label, style: TextStyle(color: on ? const Color(0xFFFDF6E6) : _muted, fontSize: 12.5, fontWeight: FontWeight.w700)),
      ),
    );
  }

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
          Positioned(top: 54, left: 14, right: 14, child: _mapHud(chapterNum)),
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
        Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Text('글지기 견습', style: dokkaebiTitle(size: 17, color: _cream)),
          Text('제 $chapterNum 장 진행 중', style: const TextStyle(fontSize: 11, color: _muted)),
        ]),
        const Spacer(),
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
                const TextSpan(text: '/ 4', style: TextStyle(fontSize: 13, color: _muted)),
              ])),
            ]),
            const Spacer(),
            for (var i = 0; i < 4; i++)
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
      );

  List<Widget> _buildPois(BoxConstraints box) {
    final poiPos = [const Offset(.30, .29), const Offset(.59, .35), const Offset(.39, .46), const Offset(.12, .56)];
    final out = <Widget>[];
    for (var i = 0; i < 4; i++) {
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
                    done ? '✓' : (active || i == 3 ? targets[i].hanja : '?'),
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
    final pos = [const Offset(.22, .24), const Offset(.34, .33), const Offset(.61, .41), const Offset(.41, .51)][_tIdx];
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
    final collectPct = fragments / 4;
    final distLabel = t.dist0 >= 1000 ? '${t.dist0 / 1000}km' : '${t.dist0}m';
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
            const TextSpan(text: ' / 4', style: TextStyle(fontSize: 12.5, color: _parchInkSoft, fontWeight: FontWeight.w700)),
          ])),
          const Spacer(),
          Text('📍 ${t.name}까지 $distLabel', style: const TextStyle(fontSize: 12.5, color: _verm, fontWeight: FontWeight.w900)),
        ]),
        const SizedBox(height: 7),
        _progress(collectPct),
        const SizedBox(height: 13),
        _cta('이동 시작 — GPS 추적', () {
          setState(() {
            gpsIdx = _tIdx;
            gpsDist = _target.dist0;
            gpsWalking = false;
            screen = 'gps';
          });
        }),
      ]),
    );
  }

  // ════════════════════════════════════════════════════
  // 3. GPS — 이동·도착 인증
  // ════════════════════════════════════════════════════
  Widget _gpsScreen() {
    final gpsT = targets[gpsIdx];
    final gpsNear = gpsDist <= 30;
    final prog = 1 - gpsDist / gpsT.dist0;
    final distLabel = gpsDist >= 1000 ? '${(gpsDist / 1000).toStringAsFixed(1)}km' : '${gpsDist}m';
    final mins = math.max(1, (gpsDist / 70).ceil());
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
                      child: const Text('인증 반경 30m', style: TextStyle(fontSize: 10, color: _muted)),
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
              Text('남음 · 걸어서 약 $mins분', style: const TextStyle(fontSize: 12.5, color: _bronze, fontWeight: FontWeight.w700)),
              const Spacer(),
              const Text('정확도 ±8m', style: TextStyle(fontSize: 11, color: _bronze)),
            ]),
            const SizedBox(height: 9),
            _progress(math.max(0.03, prog)),
            const SizedBox(height: 13),
            if (!gpsNear) ...[
              _cta(gpsWalking ? '걷는 중…' : '걷기 시작 (GPS 시뮬레이션)', _walk, bg: _parchInk, fg: _cream),
              const SizedBox(height: 8),
              const Center(child: Text('실제 앱에서는 걷는 동안 자동으로 줄어든다 (GPS)', style: TextStyle(fontSize: 11, color: _bronze))),
            ] else ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                decoration: BoxDecoration(color: _tealDeep.withOpacity(0.12), borderRadius: BorderRadius.circular(12), border: Border.all(color: _tealDeep.withOpacity(0.5))),
                child: Row(children: [
                  Container(width: 22, height: 22, alignment: Alignment.center, decoration: const BoxDecoration(shape: BoxShape.circle, color: _tealDeep), child: const Text('✓', style: TextStyle(color: Color(0xFFEAFFF9), fontSize: 12, fontWeight: FontWeight.w900))),
                  const SizedBox(width: 9),
                  const Expanded(child: Text('인증 반경 진입 — 기운이 느껴진다', style: TextStyle(fontSize: 13, color: Color(0xFF1D4A41), fontWeight: FontWeight.w900))),
                ]),
              ),
              const SizedBox(height: 10),
              _cta('GPS 도착 인증', _verifyGps, bg: _tealDeep, fg: const Color(0xFFEAFFF9)),
            ],
          ]))),
        ]);
      }),
    );
  }

  // ════════════════════════════════════════════════════
  // 4. SUMMON — AR 소환
  // ════════════════════════════════════════════════════
  Widget _summonScreen() {
    final sejong = summonFor == 'sejong';
    final scanning = summonPhase == 'scan';
    return Container(
      decoration: BoxDecoration(gradient: sejong ? _sejongBg : _dialBg),
      child: LayoutBuilder(builder: (ctx, box) {
        return Stack(children: [
          Align(alignment: const Alignment(0, 0.55), child: ClipPath(clipper: _RoofClipper(), child: Container(height: 130, color: sejong ? const Color(0xFF2A1F16) : const Color(0xFF0C0A08)))),
          Positioned(top: 58, left: 0, right: 0, child: Center(child: _pill(
            sejong ? 'AR — 수호 정령 반응 · 신호 매우 강함' : 'AR — 정령 반응 감지 · 신호 강함',
            border: _goldDim, textColor: _gold,
          ))),
          // 먹 웅덩이
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
            Positioned(left: 0, right: 0, top: box.maxHeight * .74, child: Center(child: Text(sejong ? '거룩한 기운이 모여든다…' : '먹 기운이 모여든다…', style: dokkaebiTitle(size: 15, color: const Color(0xFFE8DCC4))))),
          ] else ...[
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
  static const _npcLines = {
    0: '"허허, 운현궁에 발을 들였구나. 흥선대원군의 사저에… 세종 임금의 글씨 한 조각이 먹물 속으로 숨어버렸느니라. 자네, 글을 아끼는 자인가?"',
    'A': '"훈민정음이 흩어졌느니, 백성의 글이 잠들었지. 마음이 곧은 자로구나." (친밀도 +1)',
    'B': '"허허, 셈부터 빠르구나. 글씨엔 옛 기록의 힘이 깃들었지." (이후 쿠폰 +100원)',
    'C': '"성격 급한 게로구나. 그럼 따라오너라."',
  };

  Widget _dialogueScreen() {
    final npcLine = dlgStep == 0 ? _npcLines[0]! : _npcLines[flag]!;
    return Container(
      decoration: BoxDecoration(gradient: _dialBg),
      child: LayoutBuilder(builder: (ctx, box) {
        return Stack(children: [
          Align(alignment: const Alignment(0, 0.35), child: ClipPath(clipper: _RoofClipper(), child: Container(height: 110, color: const Color(0xFF0C0A08)))),
          Positioned(top: 58, left: 14, right: 14, child: Row(children: [
            _pill('운현궁 · 첫 번째 기억'),
            const Spacer(),
            _pill('조각 $fragments/4', border: _tealDeep, textColor: _teal),
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
                child: Text(npcLine, style: dokkaebiTitle(size: 16, color: _cream, height: 1.65)),
              ),
              Positioned(top: -14, left: 16, child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                decoration: BoxDecoration(color: _verm, borderRadius: BorderRadius.circular(8)),
                child: const Text('먹 도깨비', style: TextStyle(color: Color(0xFFFDF6E6), fontSize: 13, fontWeight: FontWeight.w900)),
              )),
            ]),
            if (dlgStep == 0) ...[
              const SizedBox(height: 10),
              _choiceRow('A', _tealDeep, const Color(0xFFEAFFF9), '"세종대왕의 글씨라니, 무슨 일이오?"', '친밀도+', _teal, () { setState(() { flag = 'A'; dlgStep = 1; }); _applyChoice([const StateRef(kind: StateKind.flag, value: '호기심'), const StateRef(kind: StateKind.affinity, value: '', amount: 1)]); }),
              const SizedBox(height: 8),
              _choiceRow('B', _goldDim, _parchInk, '"보상은 무엇이오?"', '쿠폰+100', _gold, () { setState(() { flag = 'B'; dlgStep = 1; coupon += 100; }); _applyChoice([const StateRef(kind: StateKind.flag, value: '실리'), const StateRef(kind: StateKind.coupon, value: '', amount: 100)]); }),
              const SizedBox(height: 8),
              _choiceRow('C', const Color(0xFF3A352E), _soft, '"그냥 빨리 찾겠소."', '바로 진행', _muted, () { setState(() { flag = 'C'; dlgStep = 1; }); _applyChoice([const StateRef(kind: StateKind.flag, value: '실속')]); }),
            ] else ...[
              const SizedBox(height: 10),
              _cta('계속 — 도깨비의 시험', () => go('quiz')),
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
    final answers = [('1', '세종대왕', false), ('2', '흥선대원군', true), ('3', '정조', false)];
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
                    Text('"글씨를 찾으려면 이 집의 주인을 알아야 하느니. 운현궁은 누구의 집이었더냐?"', style: dokkaebiTitle(size: 17, color: _parchInk, height: 1.55)),
                    const SizedBox(height: 16),
                    for (final a in answers) Padding(padding: const EdgeInsets.only(bottom: 9), child: _quizOption(a.$1, a.$2, a.$3)),
                    if (quizState == 'wrong') ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                        decoration: BoxDecoration(color: _verm.withOpacity(0.1), borderRadius: BorderRadius.circular(11), border: Border.all(color: _verm.withOpacity(0.4))),
                        child: RichText(text: TextSpan(style: _gowun(13.5, const Color(0xFF8A3320)), children: const [
                          TextSpan(text: '"허허, 다시 보거라. '),
                          TextSpan(text: '고종의 아버지', style: TextStyle(fontWeight: FontWeight.w900)),
                          TextSpan(text: '니라." — 다시 골라도 페널티는 없다'),
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
                      _cta('계속하기', () => go('order')),
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
    return Container(
      decoration: BoxDecoration(gradient: _dialBg),
      child: LayoutBuilder(builder: (ctx, box) {
        return Stack(children: [
          Align(alignment: const Alignment(0, 0.48), child: ClipPath(clipper: _RoofClipper(), child: Container(height: 120, color: const Color(0xFF0C0A08)))),
          Positioned(top: 58, left: 14, right: 14, child: Row(children: [_pill('운현궁 · 첫 번째 기억'), const Spacer(), _pill('조각 $fragments/4', border: _tealDeep, textColor: _teal)])),
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
                Expanded(child: Text('"처마 그늘에 번진 먹그림자 다섯을 쫓고, 그 아래 숨은 글씨를 찾거라."', style: dokkaebiTitle(size: 16, color: _parchInk, height: 1.55))),
              ]),
              const SizedBox(height: 14),
              _orderItem('먹그림자 처치', '0/5'),
              const SizedBox(height: 8),
              _orderItem('대문·처마 사진에 담기', '0/1'),
              const SizedBox(height: 8),
              _orderItem('글씨 파편 수집', '0/1'),
              const SizedBox(height: 16),
              _cta('지령 받기 — 사냥 시작', () => go('hunt'), fontSize: 15.5),
            ]),
          )),
        ]);
      }),
    );
  }

  Widget _orderItem(String label, String count) => Row(children: [
        Container(width: 20, height: 20, decoration: BoxDecoration(borderRadius: BorderRadius.circular(6), border: Border.all(color: const Color(0xFFB7A374), width: 2))),
        const SizedBox(width: 10),
        Expanded(child: Text(label, style: const TextStyle(color: _parchInkSoft, fontSize: 13.5, fontWeight: FontWeight.w500))),
        Text(count, style: const TextStyle(color: _bronze, fontSize: 13.5, fontWeight: FontWeight.w700)),
      ]);

  // ════════════════════════════════════════════════════
  // 8. HUNT — 먹그림자 사냥
  // ════════════════════════════════════════════════════
  Widget _huntScreen() {
    final huntCount = enemies.where((e) => e['dead'] == true).length;
    final done = huntCount >= 5;
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
                const Text('먹그림자 처치', style: TextStyle(fontSize: 13, color: Color(0xFFE8A08D), fontWeight: FontWeight.w700)),
                const SizedBox(width: 12),
                RichText(text: TextSpan(children: [
                  TextSpan(text: '$huntCount', style: dokkaebiTitle(size: 26, color: _cream)),
                  const TextSpan(text: ' / 5', style: TextStyle(fontSize: 16, color: _muted)),
                ])),
              ]),
            ),
            const SizedBox(height: 8),
            SizedBox(width: 220, child: _progress(huntCount / 5, grad: const LinearGradient(colors: [_verm, Color(0xFFE8743A)]), track: const Color(0xBF0D0B09))),
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
                const Expanded(child: Text('먹그림자를 모두 쫓았다 — 이제 이 집을 마음에 담을 차례', style: TextStyle(fontSize: 13.5, color: Color(0xFFBDEEE1), fontWeight: FontWeight.w700))),
              ]),
            )),
            Positioned(left: 14, right: 14, bottom: 34, child: _cta('다음 — 사진 인증', () => go('photo'))),
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
  // 9. PHOTO — 사진 인증
  // ════════════════════════════════════════════════════
  Widget _photoScreen() {
    final bracket = photoState == 'done' ? _teal : _cream.withOpacity(0.75);
    return Container(
      decoration: BoxDecoration(gradient: _dialBg),
      child: LayoutBuilder(builder: (ctx, box) {
        return Stack(children: [
          Align(alignment: const Alignment(0, 0.55), child: ClipPath(clipper: _RoofClipper(), child: Container(height: 140, color: const Color(0xFF0C0A08)))),
          Positioned(top: 58, left: 0, right: 0, child: Center(child: _pill('사진 미션 — 대문·처마를 담아라'))),
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
                  Positioned(bottom: -44, left: 0, right: 0, child: Center(child: _pill('처마 인식 중 · $scan%', border: _teal, textColor: _teal))),
                if (photoState == 'done')
                  Positioned(bottom: -44, left: 0, right: 0, child: Center(child: _pill('✓ 인증 완료 — 대문이 마음에 담겼다', border: _tealDeep, textColor: const Color(0xFFBDEEE1)))),
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
            Positioned(left: 14, right: 14, bottom: 34, child: _cta('길이 열렸다 — 발자국을 따라가라', () => go('trail'))),
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
    final fragVisible = trail >= 3 && !fragTaken;
    return Container(
      decoration: BoxDecoration(gradient: _dialBg),
      child: LayoutBuilder(builder: (ctx, box) {
        return Stack(children: [
          Align(alignment: const Alignment(0, 0.55), child: ClipPath(clipper: _RoofClipper(), child: Container(height: 110, color: const Color(0xFF0C0A08)))),
          Positioned(top: 58, left: 0, right: 0, child: Center(child: Row(mainAxisSize: MainAxisSize.min, children: [
            _pill('발자국 $trail/3', border: _goldDim, textColor: _gold),
            const SizedBox(width: 10),
            _pill('파편까지 ${12 - trail * 4}m', border: Colors.white, textColor: _soft),
          ]))),
          for (var i = 0; i < 3; i++)
            if (trail >= i && trail < 3)
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
                onTap: () {
                setState(() { fragTaken = true; showReward = true; fragments = 1; exp += 50; coupon += 500; });
                _grantChapter(0, extra: [const StateRef(kind: StateKind.coupon, value: '', to: '익선동카페', amount: 500)]);
              },
                child: _Floaty(anim: _float, child: SizedBox(
                  width: 110, height: 110,
                  child: Stack(alignment: Alignment.center, clipBehavior: Clip.none, children: [
                    Container(width: 110, height: 110, decoration: BoxDecoration(shape: BoxShape.circle, gradient: RadialGradient(colors: [_gold.withOpacity(0.45), _gold.withOpacity(0)]))),
                    _FragShard(glyph: '訓', size: 52),
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
    final cafeCoupon = math.min(coupon, 5000);
    final cafePayN = 5000 - cafeCoupon;
    final cafeAnswers = [('날개', false), ('더할 익(益)', true), ('물', false)];
    return Container(
      decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [_ink, Color(0xFF211A14)])),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 20, 18, 40),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Text('익선동 한옥 카페', style: dokkaebiTitle(size: 19, color: _cream)),
                const Text('두 번째 기억 · GPS 인증 완료 ✓', style: TextStyle(fontSize: 11.5, color: _muted)),
              ]),
              const Spacer(),
              _pill('조각 $fragments/4', border: _tealDeep, textColor: _teal),
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
                  const Text('한옥 도깨비 — 단서를 알아본다', style: TextStyle(fontSize: 11, color: _tealDeep, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 4),
                  RichText(text: TextSpan(style: _gowun(14, _parchInk, height: 1.55), children: const [
                    TextSpan(text: '"허허, 운현궁에서 '),
                    TextSpan(text: '申時 단서', style: TextStyle(backgroundColor: Color(0x24C8452C), color: _verm, fontWeight: FontWeight.w700)),
                    TextSpan(text: '를 얻어 왔구나! 차 한 잔 시키고 둘러보거라."'),
                  ])),
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
                  Container(width: 52, height: 52, alignment: Alignment.center, decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF3B332A), Color(0xFF221C15)]), borderRadius: BorderRadius.circular(12)), child: Text('茶', style: dokkaebiTitle(size: 20, color: _gold))),
                  const SizedBox(width: 12),
                  Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                    const Text('쌍화차', style: TextStyle(fontSize: 15, color: _cream, fontWeight: FontWeight.w700)),
                    const Text('"쌍화차에 글씨의 온기가 도느니"', style: TextStyle(fontSize: 12, color: _muted)),
                  ]),
                  const Spacer(),
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
                  _cta('영수증 촬영으로 인증하기', () => setState(() { cafeOrdered = true; spent += cafePayN; coupon = 0; }), fontSize: 15)
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
            // 퀴즈(주문 후)
            if (cafeOrdered) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: _cream.withOpacity(0.05), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white.withOpacity(0.1))),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('"이 골목 이름 익선동의 \'익\'은 무엇을 뜻하겠느냐?"', style: dokkaebiTitle(size: 15, color: _cream)),
                  const SizedBox(height: 11),
                  Row(children: [
                    for (var i = 0; i < cafeAnswers.length; i++) ...[
                      if (i > 0) const SizedBox(width: 8),
                      Expanded(child: _cafeOption(cafeAnswers[i].$1, cafeAnswers[i].$2)),
                    ],
                  ]),
                  if (cafeState == 'wrong') ...[
                    const SizedBox(height: 10),
                    Text('"더할수록 복이 온다는 뜻이니라 — 다시 보거라."', style: dokkaebiTitle(size: 12.5, color: const Color(0xFFE8A08D))),
                  ],
                  if (cafeState == 'correct') ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(color: _goldDim.withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: _gold.withOpacity(0.5))),
                      child: Row(children: [
                        _FragShard(glyph: '民', size: 30, fontSize: 12),
                        const SizedBox(width: 10),
                        const Expanded(child: Text('글씨조각 「민(民)」 획득 · 단서 「ㄱ」', style: TextStyle(fontSize: 13, color: _gold, fontWeight: FontWeight.w900))),
                        const Text('쿠폰 +1,300원', style: TextStyle(fontSize: 10.5, color: Color(0xFFA87F2C), fontWeight: FontWeight.w900)),
                      ]),
                    ),
                    const SizedBox(height: 12),
                    _cta('지도로 — 다음 기억을 찾아서', () => go('map'), bg: const Color(0xFFC89A3A), fg: const Color(0xFF3A2A08), gradient: _goldGrad),
                  ],
                ]),
              ),
            ],
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

  Widget _cafeOption(String label, bool correct) {
    final picked = cafeState == 'correct' && correct;
    return GestureDetector(
      onTap: () {
        if (cafeState == 'correct') return;
        if (correct) {
          setState(() { cafeState = 'correct'; fragments = 2; exp += 40; coupon = 1300; });
          hint.noteProgress();
          _grantChapter(1, extra: [const StateRef(kind: StateKind.coupon, value: '', to: '인사동', amount: 1000)]);
        } else {
          setState(() => cafeState = 'wrong');
          hint.noteFailure();
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: picked ? _tealDeep.withOpacity(0.16) : _inkDeep.withOpacity(0.5),
          borderRadius: BorderRadius.circular(11),
          border: Border.all(color: picked ? _tealDeep : Colors.white.withOpacity(0.12), width: picked ? 1.5 : 1),
        ),
        child: Text(picked ? '✓ $label' : label, style: TextStyle(fontSize: 13.5, color: picked ? _teal : const Color(0xFFE8DCC4), fontWeight: FontWeight.w700)),
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
          Positioned(top: 58, left: 14, right: 14, child: Row(children: [_pill('인사동 · 세 번째 기억'), const Spacer(), _pill('조각 $fragments/4', border: _tealDeep, textColor: _teal)])),
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
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(color: _goldDim.withOpacity(0.12), borderRadius: BorderRadius.circular(12), border: Border.all(color: _gold.withOpacity(0.5))),
            child: Row(children: [
              _FragShard(glyph: '正', size: 30, fontSize: 12),
              const SizedBox(width: 10),
              const Expanded(child: Text('함이 열렸다 — 글씨조각 「정(正)」 획득', style: TextStyle(fontSize: 13, color: _gold, fontWeight: FontWeight.w900))),
            ]),
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
          setState(() { insaPick = t; insaState = 'opened'; fragments = 3; exp += 40; });
          hint.noteProgress();
          _grantChapter(2);
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
  Widget _rewardModal() => Positioned.fill(child: Container(
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
                _FragShard(glyph: '訓', size: 104, fontSize: 48),
                const SizedBox(height: 14),
                Text('글씨조각 「훈(訓)」', style: dokkaebiTitle(size: 20, color: _parchInk)),
                const SizedBox(height: 4),
                const Text('종로의 기억석 · 1/4 조각', style: TextStyle(fontSize: 13, color: _bronze, fontWeight: FontWeight.w700)),
                const SizedBox(height: 14),
                _rewardRow('경험치', '+50', _tealDeep),
                const SizedBox(height: 7),
                _rewardRow('단서 「申時」', '신규', _verm),
                const SizedBox(height: 7),
                _rewardRow('익선동 카페 쿠폰', '+500원', _goldDim),
                const SizedBox(height: 16),
                _cta('가방에 넣기 — 지도로', () => setState(() { showReward = false; screen = 'map'; }), bg: _parchInk, fg: _cream),
              ]),
            ),
            Positioned(top: -16, left: 0, right: 0, child: Center(child: Container(padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 7), decoration: BoxDecoration(color: _verm, borderRadius: BorderRadius.circular(999), boxShadow: [BoxShadow(color: _verm.withOpacity(0.5), blurRadius: 18, offset: const Offset(0, 6))]), child: const Text('획 득', style: TextStyle(color: Color(0xFFFDF6E6), fontWeight: FontWeight.w900, fontSize: 15, letterSpacing: 1.4))))),
          ]),
        ),
      ));

  Widget _rewardRow(String label, String value, Color c) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
        decoration: BoxDecoration(color: const Color(0xFF2A2118).withOpacity(0.06), borderRadius: BorderRadius.circular(10)),
        child: Row(children: [
          Text('✦', style: TextStyle(color: c, fontWeight: FontWeight.w900)),
          const SizedBox(width: 10),
          Text(label, style: const TextStyle(fontSize: 13, color: _parchInkSoft)),
          const Spacer(),
          Text(value, style: TextStyle(fontSize: 13, color: c, fontWeight: FontWeight.w900)),
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
    final collDefs = [
      ('訓', '훈 — 운현궁', '먹그림자 아래 잠들었던 첫 조각'),
      ('民', '민 — 익선동', '가마솥 온기에 숨어 있던 조각'),
      ('正', '정 — 인사동', '붓방의 잠긴 함이 지키던 조각'),
      ('音', '음 — 광화문', '그대 마음에 있던 마지막 조각'),
    ];
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
                  const TextSpan(text: '잊혀진 글씨의 네 조각 — '),
                  TextSpan(text: '$fragments', style: const TextStyle(color: _verm, fontWeight: FontWeight.w900)),
                  const TextSpan(text: ' / 4 회수'),
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
              children: [for (var i = 0; i < 4; i++) _collCard(i, collDefs[i], i < fragments)],
            )),
          ]),
        ),
      )),
    ]));
  }

  Widget _collCard(int i, (String, String, String) def, bool got) => Container(
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
                child: Transform.rotate(angle: -math.pi / 4, child: Text(got ? def.$1 : '?', style: dokkaebiTitle(size: 17, color: got ? const Color(0xFF7A2A12) : const Color(0xFFB7A374)))),
              ),
            ),
            const Spacer(),
            Text('第 ${i + 1}', style: dokkaebiTitle(size: 12, color: const Color(0xFFB7A374))),
          ]),
          const Spacer(),
          Text(got ? def.$2 : '봉인된 조각', style: dokkaebiTitle(size: 16.5, color: got ? _parchInk : _bronze)),
          const SizedBox(height: 4),
          Text(got ? def.$3 : '아직 되찾지 못한 조각', style: const TextStyle(fontSize: 11.5, color: _bronze, height: 1.5)),
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

// ============================================================
// [v2] 시나리오 스토어 — 생성 탐험 + 진행상황(유저별 영속) + 상태 그래프
// pipeline: 모바일 클라이언트 / 상태
// 구현(요약): v1의 done/inventory에 **상태 그래프 전체**를 얹음 —
//            플래그·친밀도·쿠폰·유물(PlayerState)과 갈림길 선택·엔딩까지 영속.
//            inventory는 v1 문자열 리스트 형식을 그대로 두고(하위호환) StateRef 표기로 승격,
//            읽을 때 stateOf()가 파싱 → 앱 재시작해도 플래그·쿠폰이 살아남는다.
//            ⚠️ 서버 측 진행 영속(scenario_runs)·동기화는 추후.
// 구현일: 2026-07-30 | 작성: kys (app-v3-back/kys/v1)
// ------------------------------------------------------------
// [v1] 생성 Scenario + 완료 노드·인벤토리 영속 — 2026-06-18/19 kys (app-scaffold/kys/v1)
// ============================================================
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'game/player_state.dart';
import 'models/scenario.dart';
import 'session.dart';

class ScenarioStore extends ChangeNotifier {
  ScenarioStore._();
  static final ScenarioStore I = ScenarioStore._();

  final List<Scenario> scenarios = [];
  final Map<String, List<String>> _doneNodes = {}; // scenarioId -> 완료 node_id
  final Map<String, List<String>> _inventory = {}; // scenarioId -> 획득 상태(StateRef 표기)
  final Map<String, Map<String, String>> _choices = {}; // scenarioId -> {분기노드id: choiceId}
  final Map<String, String> _endings = {}; // scenarioId -> 엔딩 코드

  String get _key => 'store_${Session.userId ?? 'guest'}';

  // ── 조회 ──
  List<String> doneOf(String scenarioId) => _doneNodes[scenarioId] ?? const [];
  List<String> inventoryOf(String scenarioId) => _inventory[scenarioId] ?? const [];
  int progressOf(Scenario s) => doneOf(s.scenarioId).length;

  /// 갈림길 선택 — `Scenario.playedPath()`에 그대로 넘긴다.
  Map<String, String> choicesOf(String scenarioId) => _choices[scenarioId] ?? const {};

  /// 도달한 엔딩(없으면 null).
  String? endingOf(String scenarioId) => _endings[scenarioId];

  /// **상태 그래프 스냅샷** — 조각·단서·플래그·친밀도·쿠폰·유물.
  /// requires 게이팅·연계 대사·엔딩 분기는 전부 이걸 기준으로 한다.
  PlayerState stateOf(String scenarioId) => PlayerState.fromStrings(inventoryOf(scenarioId));

  /// 완료한 '기억석 조각' 수(식음 노드 제외) — 진행률·완료 판정용.
  int stoneProgressOf(Scenario s) {
    final done = doneOf(s.scenarioId).toSet();
    return s.stoneNodes.where((n) => done.contains(n.nodeId)).length;
  }

  /// 실제 밟은 경로 기준 노드 목록(선형이면 node_sequence 그대로).
  List<QuestNode> pathOf(Scenario s) => s.playedPath(choicesOf(s.scenarioId));

  /// 저장된 탐험·진행 복원 (앱 시작·로그인 직후).
  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    scenarios.clear();
    _doneNodes.clear();
    _inventory.clear();
    _choices.clear();
    _endings.clear();
    final raw = p.getString(_key);
    if (raw != null && raw.isNotEmpty) {
      final d = jsonDecode(raw) as Map<String, dynamic>;
      for (final e in (d['scenarios'] ?? []) as List) {
        scenarios.add(Scenario.fromJson(e as Map<String, dynamic>));
      }
      (d['done'] as Map<String, dynamic>? ?? {}).forEach(
          (k, v) => _doneNodes[k] = (v as List).map((e) => e.toString()).toList());
      (d['inventory'] as Map<String, dynamic>? ?? {}).forEach(
          (k, v) => _inventory[k] = (v as List).map((e) => e.toString()).toList());
      (d['choices'] as Map<String, dynamic>? ?? {}).forEach((k, v) =>
          _choices[k] = (v as Map).map((ck, cv) => MapEntry(ck.toString(), cv.toString())));
      (d['endings'] as Map<String, dynamic>? ?? {}).forEach((k, v) => _endings[k] = v.toString());
    }
    notifyListeners();
  }

  /// 새 탐험 추가.
  Future<void> add(Scenario s) async {
    scenarios.removeWhere((e) => e.scenarioId == s.scenarioId);
    scenarios.insert(0, s);
    notifyListeners();
    await _persist();
  }

  /// 노드 완료 기록(연계 인벤토리 누적). 코스 진행 상황 영속.
  ///
  /// grants는 StateRef 표기(`clue:申時`)든 구 조각 문자열이든 그대로 받는다 —
  /// 읽을 때 stateOf()가 파싱하므로 저장 형식이 섞여도 안전.
  /// 소유형은 중복 저장하지 않아 재방문 시 이중 누적이 없다.
  Future<void> completeNode(String scenarioId, String nodeId, List<String> grants) async {
    final done = _doneNodes[scenarioId] ??= [];
    if (!done.contains(nodeId)) done.add(nodeId);
    final inv = _inventory[scenarioId] ??= [];
    for (final g in grants) {
      if (!inv.contains(g)) inv.add(g);
    }
    notifyListeners();
    await _persist();
  }

  /// 노드 완료 + grants 적용을 한 번에 — 스키마 v1.1 노드용.
  /// extra에는 선택지 보너스(쿠폰·친밀도) 같은 노드 밖 획득을 넣는다.
  Future<void> completeNodeWithGrants(
    String scenarioId,
    QuestNode node, {
    Iterable<StateRef> extra = const [],
  }) =>
      completeNode(
        scenarioId,
        node.nodeId,
        [...node.effectiveGrants, ...extra].map((r) => r.toStorageString()).toList(),
      );

  /// 노드 완료와 무관한 상태 획득 — 선택지 플래그·친밀도·쿠폰 보너스.
  /// 누적형(친밀도·쿠폰)은 여러 번 쌓이고, 소유형(조각·단서·플래그·유물)은 1회만.
  Future<void> grant(String scenarioId, Iterable<StateRef> refs) async {
    final inv = _inventory[scenarioId] ??= [];
    for (final r in refs) {
      final s = r.toStorageString();
      final cumulative = r.kind == StateKind.affinity || r.kind == StateKind.coupon;
      if (cumulative || !inv.contains(s)) inv.add(s);
    }
    notifyListeners();
    await _persist();
  }

  /// 갈림길 선택 기록 — 이후 playedPath가 이 갈래로 순회한다.
  Future<void> chooseBranch(String scenarioId, String branchNodeId, String choiceId) async {
    (_choices[scenarioId] ??= {})[branchNodeId] = choiceId;
    notifyListeners();
    await _persist();
  }

  /// 엔딩 기록(피날레 도달).
  Future<void> setEnding(String scenarioId, String ending) async {
    _endings[scenarioId] = ending;
    notifyListeners();
    await _persist();
  }

  /// 이 코스 진행만 초기화(다시 처음부터). 생성된 시나리오 자체는 유지.
  Future<void> resetProgress(String scenarioId) async {
    _doneNodes.remove(scenarioId);
    _inventory.remove(scenarioId);
    _choices.remove(scenarioId);
    _endings.remove(scenarioId);
    notifyListeners();
    await _persist();
  }

  Future<void> _persist() async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_key, jsonEncode({
      'scenarios': scenarios.map((s) => s.toJson()).toList(),
      'done': _doneNodes,
      'inventory': _inventory,
      'choices': _choices,
      'endings': _endings,
    }));
  }
}

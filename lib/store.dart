// ============================================================
// [v1] 시나리오 스토어 — 생성 탐험 + 진행상황(유저별 영속)
// pipeline: 모바일 클라이언트 / 상태
// 구현(요약): 생성한 Scenario + 진행(완료 노드)·인벤토리(연계)를 유저별 SharedPreferences에 저장.
//            퀘스트 탭·코스 화면이 구독 → 진행 상황 표시·유지. 로그인 유저별 분리.
//            ⚠️ 서버 측 진행 영속(scenario_runs)·동기화는 추후(김예슬).
// 구현일: 2026-06-18 (진행상황: 2026-06-19) | 작성: kys (app-scaffold/kys/v1)
// ============================================================
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models/scenario.dart';
import 'session.dart';

class ScenarioStore extends ChangeNotifier {
  ScenarioStore._();
  static final ScenarioStore I = ScenarioStore._();

  final List<Scenario> scenarios = [];
  final Map<String, List<String>> _doneNodes = {}; // scenarioId -> 완료 node_id
  final Map<String, List<String>> _inventory = {}; // scenarioId -> 모은 단서·조각

  String get _key => 'store_${Session.userId ?? 'guest'}';

  // 조회
  List<String> doneOf(String scenarioId) => _doneNodes[scenarioId] ?? const [];
  List<String> inventoryOf(String scenarioId) => _inventory[scenarioId] ?? const [];
  int progressOf(Scenario s) => doneOf(s.scenarioId).length;

  /// 저장된 탐험·진행 복원 (앱 시작·로그인 직후).
  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    scenarios.clear();
    _doneNodes.clear();
    _inventory.clear();
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
  Future<void> completeNode(String scenarioId, String nodeId, List<String> grants) async {
    final done = _doneNodes[scenarioId] ??= [];
    if (!done.contains(nodeId)) done.add(nodeId);
    (_inventory[scenarioId] ??= []).addAll(grants);
    notifyListeners();
    await _persist();
  }

  Future<void> _persist() async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_key, jsonEncode({
      'scenarios': scenarios.map((s) => s.toJson()).toList(),
      'done': _doneNodes,
      'inventory': _inventory,
    }));
  }
}

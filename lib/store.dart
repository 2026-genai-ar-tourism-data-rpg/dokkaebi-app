// ============================================================
// [v1] 시나리오 스토어 — 생성된 탐험 보관(유저별 영속)
// pipeline: 모바일 클라이언트 / 상태
// 구현(요약): 생성된 Scenario를 메모리 + SharedPreferences(유저별 키)에 저장.
//            로그인 유지되면 만든 탐험도 앱 재시작 후 유지. 퀘스트 탭·홈이 구독.
//            ⚠️ 서버 측 '내 시나리오' 목록 API는 추후(김예슬) — 지금은 기기 로컬 저장.
// 구현일: 2026-06-18 | 작성: kys (app-scaffold/kys/v1)
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

  // 유저별 저장 키 (로그인 유저의 탐험만 보이게)
  String get _key => 'scenarios_${Session.userId ?? 'guest'}';

  /// 저장된 내 탐험 복원 (앱 시작·로그인 직후 호출).
  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_key);
    scenarios.clear();
    if (raw != null && raw.isNotEmpty) {
      for (final e in jsonDecode(raw) as List) {
        scenarios.add(Scenario.fromJson(e as Map<String, dynamic>));
      }
    }
    notifyListeners();
  }

  /// 새 탐험 추가(최신이 위로) + 영속 저장.
  Future<void> add(Scenario s) async {
    scenarios.removeWhere((e) => e.scenarioId == s.scenarioId);
    scenarios.insert(0, s);
    notifyListeners();
    await _persist();
  }

  Future<void> _persist() async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_key, jsonEncode(scenarios.map((s) => s.toJson()).toList()));
  }
}

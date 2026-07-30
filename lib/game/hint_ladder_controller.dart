// ============================================================
// [v1] 힌트 사다리 컨트롤러 — H1~H3 공개 타이밍 (코드 담당분)
// pipeline: 모바일 클라이언트 / 게임 로직 (방탈출 힌트 규격, Nicholson 2015)
// 구현(요약): **문구는 LLM/콘텐츠(#31), 단수·공개 타이밍은 코드** — 그 코드 쪽.
//            H1 = 실패 1회 or 60초 무진행 / H2 = H1 후 90초 무진행 / H3 = H2 후 버튼 요청.
//            openRule 문자열(`"fail1|idle60"`)을 파싱해 규칙을 데이터로 받는다.
//            H3까지 열려도 보상 *종류*는 불변 — 퀴즈 보너스만 감소(penaltyFactor).
// 구현일: 2026-07-30 | 작성: kys (app-v3-back/kys/v1) · 명세: 시나리오구조화.md 5절
// ============================================================
import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/scenario.dart';

/// 한 노드의 힌트 사다리 상태. 화면이 구독해 힌트 버튼·배지를 갱신한다.
///
/// 사용법:
/// ```dart
/// final hint = HintLadderController(ladder: node.hints)..start();
/// // 진행이 생기면 hint.noteProgress();  실패하면 hint.noteFailure();
/// // 버튼 눌리면 hint.requestNext();
/// // 표시: hint.openTier / hint.visibleTexts / hint.canRequestMore
/// hint.dispose();
/// ```
class HintLadderController extends ChangeNotifier {
  final HintLadder ladder;

  /// 무진행 판정 주기. 테스트에서 짧게 줄일 수 있게 주입 가능.
  final Duration tick;

  HintLadderController({required this.ladder, this.tick = const Duration(seconds: 1)});

  int _openTier = 0; // 0=닫힘, 1~3=열린 단
  int _failures = 0;
  Duration _idle = Duration.zero;
  Timer? _timer;
  bool _started = false;

  /// 현재 열린 단(0~3).
  int get openTier => _openTier;

  int get failures => _failures;

  /// 무진행 경과 시간.
  Duration get idle => _idle;

  /// 열린 단까지의 문구들(문구 없는 단은 건너뜀).
  List<String> get visibleTexts => [
        for (var t = 1; t <= _openTier; t++)
          if (ladder.textOf(t) != null) ladder.textOf(t)!,
      ];

  /// 지금 막 열린 단의 문구(토스트·말풍선 1회 노출용).
  String? get latestText => ladder.textOf(_openTier);

  /// 사다리에 실제로 남은 단이 있는가.
  bool get hasMore => _openTier < ladder.filledTiers;

  /// 버튼으로 요청 가능한가 — 다음 단의 규칙이 `button`이면 즉시, 아니면 시간/실패 대기.
  /// 규칙 5절: H3은 요청형. 데드락 금지를 위해 마지막 단은 항상 요청으로 열 수 있다.
  bool get canRequestMore => hasMore && (_ruleOf(_openTier + 1).hasButton || _openTier + 1 >= 3);

  /// H3까지 열었을 때 퀴즈 보너스 배율. 보상 *종류*는 불변(규칙: 진행은 항상 가능).
  double get penaltyFactor => switch (_openTier) {
        0 => 1.0,
        1 => 0.8,
        2 => 0.6,
        _ => 0.5,
      };

  void start() {
    if (_started) return;
    _started = true;
    _timer = Timer.periodic(tick, (_) {
      _idle += tick;
      _evaluate();
    });
  }

  /// 진행이 생김(도착·정답·수집 등) → 무진행 타이머 리셋.
  /// 화면에 보이는 상태(열린 단)는 안 바뀌므로 notify하지 않는다.
  void noteProgress() => _idle = Duration.zero;

  /// 실패(오답·헛탐색) → H1의 `fail1` 조건 트리거.
  void noteFailure() {
    _failures++;
    _idle = Duration.zero;
    _evaluate();
  }

  /// 플레이어가 힌트 버튼을 눌렀다 — 규칙이 요청형(button)인 단만 개방.
  bool requestNext() {
    if (!canRequestMore) return false;
    _open(_openTier + 1);
    return true;
  }

  /// **대가를 치르고** 다음 단을 즉시 개방(붓털 소비 등). 규칙 대기(idle)를 건너뛴다.
  ///
  /// 규칙 5절의 "진행은 항상 가능(데드락 ❌)" 쪽으로만 넓히는 예외 —
  /// 시간을 기다려야만 열리는 H2를 플레이어가 자원으로 앞당길 수 있게 한다.
  /// 보상 *종류*는 여전히 불변이고 penaltyFactor만 내려간다.
  bool forceNext() {
    if (!hasMore) return false;
    _open(_openTier + 1);
    return true;
  }

  /// 다음 노드로 넘어갈 때 초기화.
  void reset() {
    _openTier = 0;
    _failures = 0;
    _idle = Duration.zero;
    notifyListeners();
  }

  /// 개방 조건 평가. **단이 열릴 때만 notify** — 매 tick 알리면 화면이 1초마다 리빌드된다.
  void _evaluate() {
    final next = _openTier + 1;
    if (next > 3 || next > ladder.filledTiers) return;
    final rule = _ruleOf(next);
    final failHit = rule.failCount != null && _failures >= rule.failCount!;
    final idleHit = rule.idleSeconds != null && _idle.inSeconds >= rule.idleSeconds!;
    if (failHit || idleHit) _open(next);
  }

  void _open(int tier) {
    _openTier = tier.clamp(0, 3);
    _idle = Duration.zero;
    notifyListeners();
  }

  /// 1-base 단의 공개 규칙. openRule 부족 시 기본 사다리로 폴백.
  _OpenRule _ruleOf(int tier) {
    final rules = ladder.openRule.isNotEmpty ? ladder.openRule : HintLadder.defaultOpenRule;
    final raw = tier - 1 < rules.length
        ? rules[tier - 1]
        : HintLadder.defaultOpenRule[(tier - 1).clamp(0, 2)];
    return _OpenRule.parse(raw);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

/// `"fail1|idle60"` · `"idle90"` · `"button"` 파싱 결과.
@immutable
class _OpenRule {
  final int? failCount;
  final int? idleSeconds;
  final bool hasButton;

  const _OpenRule({this.failCount, this.idleSeconds, this.hasButton = false});

  factory _OpenRule.parse(String raw) {
    int? fail;
    int? idle;
    var button = false;
    for (final tok in raw.toLowerCase().split('|')) {
      final t = tok.trim();
      if (t == 'button' || t == 'request') {
        button = true;
      } else if (t.startsWith('fail')) {
        fail = int.tryParse(t.substring(4)) ?? 1;
      } else if (t.startsWith('idle')) {
        idle = int.tryParse(t.substring(4)) ?? 60;
      }
    }
    return _OpenRule(failCount: fail, idleSeconds: idle, hasButton: button);
  }
}

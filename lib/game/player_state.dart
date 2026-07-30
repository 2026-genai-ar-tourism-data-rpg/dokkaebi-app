// ============================================================
// [v1] 상태 그래프 런타임 — 인벤토리(조각·단서·플래그) + requires 게이팅
// pipeline: 모바일 클라이언트 / 게임 로직 (노드는 서로 모른다 — 상태로만 연결)
// 구현(요약): PlayerState(fragment·clue·flag·affinity·coupon·relic 누적) +
//            check(node)로 requires 판정. **미충족은 차단이 아니라 안내**(규칙 1조):
//            soft→기본 대사 진행(D4), hard(피날레)→안내 모드 + 부분 인지(D1/D2).
//            안내 문구는 "어디서 얻는지"를 시나리오에서 역추적해 만든다.
// 구현일: 2026-07-30 | 작성: kys (app-v3-back/kys/v1) · 명세: 시나리오구조화.md 3·3-1절
// ============================================================
import '../models/scenario.dart';

/// 플레이어 누적 상태. 조각·단서·플래그는 **읽기 전용 누적**(규칙 3조, 중간 소비 없음).
class PlayerState {
  final Set<String> fragments = {};
  final Set<String> clues = {};
  final Set<String> flags = {};
  final Set<String> relics = {};
  int affinity = 0;

  /// 사용처별 쿠폰 잔액. key = 사용처(없으면 '').
  final Map<String, int> coupons = {};

  PlayerState();

  /// 저장된 inventory 문자열 목록에서 복원 (`ScenarioStore.inventoryOf`).
  factory PlayerState.fromStrings(Iterable<String> raw) {
    final s = PlayerState();
    for (final e in raw) {
      s.apply(StateRef.parse(e));
    }
    return s;
  }

  /// grants 한 건 적용.
  void apply(StateRef r) {
    switch (r.kind) {
      case StateKind.fragment:
        fragments.add(r.value);
      case StateKind.clue:
        clues.add(r.value);
      case StateKind.flag:
        flags.add(r.value);
      case StateKind.relic:
        relics.add(r.value);
      case StateKind.affinity:
        affinity += r.amount ?? 0;
      case StateKind.coupon:
        coupons[r.to ?? ''] = (coupons[r.to ?? ''] ?? 0) + (r.amount ?? 0);
      case StateKind.unknown:
        break;
    }
  }

  void applyAll(Iterable<StateRef> refs) => refs.forEach(apply);

  /// 이 상태 참조를 이미 가지고 있는가.
  bool has(StateRef r) => switch (r.kind) {
        StateKind.fragment => fragments.contains(r.value),
        StateKind.clue => clues.contains(r.value),
        StateKind.flag => flags.contains(r.value),
        StateKind.relic => relics.contains(r.value),
        StateKind.affinity => affinity >= (r.amount ?? 0),
        StateKind.coupon => (coupons[r.to ?? ''] ?? 0) >= (r.amount ?? 0),
        StateKind.unknown => false,
      };

  int get couponTotal => coupons.values.fold(0, (a, b) => a + b);

  /// 서버·LLM에 넘길 inventory 배열 (grounding 패킷 `player.inventory`).
  List<String> toStrings() => [
        ...fragments.map((e) => 'fragment:$e'),
        ...clues.map((e) => 'clue:$e'),
        ...flags.map((e) => 'flag:$e'),
        ...relics.map((e) => 'relic:$e'),
        if (affinity != 0) 'affinity:${affinity >= 0 ? '+' : ''}$affinity',
        ...coupons.entries.where((e) => e.value > 0).map((e) => 'coupon:${e.key}:${e.value}'),
      ];

  /// 대사 연계용 — NPC가 인지해야 할 조각·단서 이름만 (구 inventory 호환).
  List<String> get carriedNames => [...fragments, ...clues];
}

/// requires 판정 결과. **blocked=true여도 데드락이 아니다** — 안내 모드로 진입한다.
class RequireCheck {
  final RequiresMode mode;
  final List<StateRef> missing;
  final List<StateRef> held; // 가진 것 — D2 부분 인지에 쓰임
  final Map<String, String> sourceOf; // missing.key → 얻을 수 있는 노드 이름

  const RequireCheck({
    required this.mode,
    required this.missing,
    required this.held,
    required this.sourceOf,
  });

  bool get ok => missing.isEmpty;

  /// 하드 requires 미충족 → 진행 대신 **안내 모드**(D1/D2). 소프트는 항상 진행.
  bool get needsGuidance => !ok && mode == RequiresMode.hard;

  /// 소프트 미충족 — 진행은 하되 연계 대사를 못 쓰는 상태(D4).
  bool get softMissing => !ok && mode == RequiresMode.soft;

  /// 연계 인지 가능 — 요구 상태를 실제로 들고 왔다(특별 대사 조건).
  bool get canRecognize => ok && mode != RequiresMode.none;

  /// 부분 인지 여부 — 일부만 가져옴(LLM 슬롯 `guidance_partial`).
  bool get isPartial => held.isNotEmpty && missing.isNotEmpty;

  /// 안내 문구 — "운현궁에서 申時를 얻어 오거라" 형태. 거부가 아니라 길 안내.
  String guidance() {
    if (ok) return '';
    final parts = missing.map((m) {
      final where = sourceOf[m.key];
      return where != null ? '$where에서 ${m.label}' : m.label;
    }).toList();
    final needs = parts.join(', ');
    if (isPartial) {
      final have = held.map((h) => h.label).join('·');
      return '$have은(는) 잘 챘구나. 남은 것은 $needs — 그것부터 얻어 오거라.';
    }
    return '$needs을(를) 얻어 오거라.';
  }

  /// 안내 모드에서 지도에 하이라이트할 노드 이름들(D1 미완료 거점 강조).
  List<String> get highlightPlaces =>
      missing.map((m) => sourceOf[m.key]).whereType<String>().toSet().toList();
}

extension ScenarioGating on Scenario {
  /// 각 상태를 **어느 노드가 주는지** 역인덱스. 안내 문구·지도 하이라이트에 사용.
  Map<String, String> grantSourceIndex() {
    final idx = <String, String>{};
    for (final n in nodeSequence) {
      for (final g in n.effectiveGrants) {
        idx.putIfAbsent(g.key, () => n.name ?? n.nodeId);
      }
    }
    return idx;
  }

  /// 노드 진입 판정. 데드락 금지 — hard여도 결과는 '안내', 차단 종료가 아니다.
  RequireCheck checkEntry(QuestNode node, PlayerState state) {
    final idx = grantSourceIndex();
    final missing = <StateRef>[];
    final held = <StateRef>[];
    for (final r in node.requires) {
      (state.has(r) ? held : missing).add(r);
    }
    return RequireCheck(
      mode: node.requires.isEmpty ? RequiresMode.none : node.requiresMode,
      missing: missing,
      held: held,
      sourceOf: {for (final m in missing) m.key: idx[m.key] ?? ''}
        ..removeWhere((_, v) => v.isEmpty),
    );
  }

  /// 피날레 requires = 고정 조각 셋 → 조합 가능성 보장(규칙 4조, 구조적 종료).
  /// requires가 비어 있으면 조각 전량을 하드 조건으로 간주해 구조적 종료를 유지한다.
  QuestNode? get finaleNode =>
      nodeSequence.where((n) => n.isFinale).firstOrNull ??
      (stoneNodes.isNotEmpty ? stoneNodes.last : null);

  /// 피날레 개방 여부 — 조각 총량 도달 판정(폴백 포함).
  bool finaleUnlocked(PlayerState state) {
    final f = finaleNode;
    if (f == null) return false;
    if (f.requires.isNotEmpty) return checkEntry(f, state).ok;
    final needed = stoneNodes.where((n) => !n.isFinale).map((n) => n.fragmentId).where((e) => e.isNotEmpty);
    return needed.every(state.fragments.contains);
  }
}

extension _FirstOrNull<E> on Iterable<E> {
  E? get firstOrNull => isEmpty ? null : first;
}

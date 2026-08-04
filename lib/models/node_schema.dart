// ============================================================
// [v1] 노드 스키마 v1.1 — 3층 문법(동기/전략/액션) + 상태 그래프 DTO
// pipeline: 모바일 클라이언트 / 모델 (AI↔서버↔앱 contract seam)
// 구현(요약): 최종_시나리오/시나리오구조화.md 2·3·5절을 앱 모델로 옮김.
//            StateRef(fragment·clue·flag·affinity·coupon·relic 파싱) · ActionAtom(원자 액션 10종)
//            · HintLadder(H1~H3 문구 슬롯 + 공개 규칙) · RequiresMode(none/soft/hard).
//            전 필드 옵셔널 — AI가 아직 안 내려줘도 기존 mission/quiz/objective로 동작(하위호환).
// 구현일: 2026-07-30 | 작성: kys (app-v3-back/kys/v1)
// ============================================================

/// 상태 어휘 6종 (시나리오구조화 3절). 모르는 접두사는 unknown.
enum StateKind { fragment, clue, flag, affinity, coupon, relic, unknown }

StateKind _kindOf(String s) => switch (s) {
      'fragment' => StateKind.fragment,
      'clue' => StateKind.clue,
      'flag' => StateKind.flag,
      'affinity' => StateKind.affinity,
      'coupon' => StateKind.coupon,
      'relic' => StateKind.relic,
      _ => StateKind.unknown,
    };

String _kindName(StateKind k) => switch (k) {
      StateKind.fragment => 'fragment',
      StateKind.clue => 'clue',
      StateKind.flag => 'flag',
      StateKind.affinity => 'affinity',
      StateKind.coupon => 'coupon',
      StateKind.relic => 'relic',
      StateKind.unknown => 'unknown',
    };

/// 상태 참조 한 건 — grants/requires의 원소.
///
/// 문자열 표기(AI/서버 1차 형태)를 그대로 받는다:
/// - `fragment:글씨조각1` · `clue:申時` · `flag:호기심` · `relic:나침반`
/// - `affinity:+1` (amount=1) · `coupon:500` (amount=500) · `coupon:익선동카페:500` (to+amount)
///
/// 맵 표기(`{"kind":"clue","value":"申時"}`)도 받는다 — 스키마가 객체로 승격돼도 앱 수정 불필요.
class StateRef {
  final StateKind kind;
  final String value; // 조각·단서·플래그·유물 이름 (coupon/affinity는 '')
  final int? amount; // coupon 금액 · affinity 증감
  final String? to; // coupon 사용처

  const StateRef({required this.kind, required this.value, this.amount, this.to});

  /// `"clue:申時"` 형태 파싱. 접두사가 없으면 조각으로 간주(구 inventory 문자열 호환).
  factory StateRef.parse(String raw) {
    final s = raw.trim();
    final i = s.indexOf(':');
    if (i < 0) return StateRef(kind: StateKind.fragment, value: s);

    final kind = _kindOf(s.substring(0, i));
    final rest = s.substring(i + 1).trim();
    if (kind == StateKind.unknown) {
      // 접두사가 어휘에 없음 → 전체를 조각 이름으로 (구 형식 "글씨조각1:운현궁" 등)
      return StateRef(kind: StateKind.fragment, value: s);
    }

    if (kind == StateKind.affinity) {
      return StateRef(kind: kind, value: '', amount: int.tryParse(rest.replaceFirst('+', '')) ?? 1);
    }
    if (kind == StateKind.coupon) {
      final parts = rest.split(':');
      if (parts.length >= 2) {
        return StateRef(kind: kind, value: '', to: parts[0].trim(), amount: int.tryParse(parts[1].trim()));
      }
      final n = int.tryParse(rest);
      return n != null ? StateRef(kind: kind, value: '', amount: n) : StateRef(kind: kind, value: '', to: rest);
    }
    return StateRef(kind: kind, value: rest);
  }

  factory StateRef.fromJson(dynamic j) {
    if (j is String) return StateRef.parse(j);
    if (j is Map) {
      final m = j.cast<String, dynamic>();
      return StateRef(
        kind: _kindOf((m['kind'] ?? '').toString()),
        value: (m['value'] ?? m['name'] ?? '').toString(),
        amount: (m['amount'] as num?)?.toInt(),
        to: m['to']?.toString(),
      );
    }
    return StateRef(kind: StateKind.unknown, value: j.toString());
  }

  static List<StateRef> listFrom(dynamic v) =>
      v is List ? v.map(StateRef.fromJson).toList() : const [];

  /// 소유 판정용 키 — 같은 상태를 가리키면 같은 키.
  String get key => kind == StateKind.coupon
      ? 'coupon:${to ?? ''}'
      : '${_kindName(kind)}:$value';

  /// 인벤토리·단서함 카드에 쓸 표시 문구.
  String get label => switch (kind) {
        StateKind.fragment => value,
        StateKind.clue => value,
        StateKind.flag => value,
        StateKind.relic => value,
        StateKind.affinity => '친밀도 ${(amount ?? 0) >= 0 ? '+' : ''}${amount ?? 0}',
        StateKind.coupon => '쿠폰 ${amount ?? 0}원${to != null ? ' ($to)' : ''}',
        StateKind.unknown => value,
      };

  String toStorageString() => switch (kind) {
        StateKind.affinity => 'affinity:${(amount ?? 0) >= 0 ? '+' : ''}${amount ?? 0}',
        StateKind.coupon => to != null ? 'coupon:$to:${amount ?? 0}' : 'coupon:${amount ?? 0}',
        _ => '${_kindName(kind)}:$value',
      };

  @override
  String toString() => toStorageString();
}

/// requires 강도 (시나리오구조화 6절 표기).
/// - none: 조건 없음
/// - soft: 없어도 진행, 있으면 연계 대사 (D4 순서 역행 대응)
/// - hard: 없으면 **안내 모드** — 차단이 아니라 미완료 거점 안내 (피날레 전용, D1/D2)
enum RequiresMode { none, soft, hard }

RequiresMode requiresModeOf(String? s) => switch (s) {
      'soft' => RequiresMode.soft,
      'hard' => RequiresMode.hard,
      _ => RequiresMode.none,
    };

String requiresModeName(RequiresMode m) => switch (m) {
      RequiresMode.soft => 'soft',
      RequiresMode.hard => 'hard',
      RequiresMode.none => 'none',
    };

/// 분기 선택지의 **효과**(코드 고정) + 문구(LLM 생성 슬롯).
/// 규칙 2조: 분기는 grants를 바꾸지 않는다 — rewardMod로 *양*만 조정.
class ActionChoice {
  final String id;
  final String? text; // LLM 슬롯. 생성 전이면 null
  final List<String> flags;
  final int affinity;
  final Map<String, dynamic> rewardMod;

  const ActionChoice({
    required this.id,
    this.text,
    this.flags = const [],
    this.affinity = 0,
    this.rewardMod = const {},
  });

  factory ActionChoice.fromJson(Map<String, dynamic> j) => ActionChoice(
        id: (j['id'] ?? '').toString(),
        text: j['text']?.toString(),
        flags: (j['flags'] is List) ? (j['flags'] as List).map((e) => e.toString()).toList() : const [],
        affinity: (j['affinity'] as num?)?.toInt() ?? 0,
        rewardMod: (j['reward_mod'] as Map?)?.cast<String, dynamic>() ?? const {},
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        if (text != null) 'text': text,
        if (flags.isNotEmpty) 'flags': flags,
        if (affinity != 0) 'affinity': affinity,
        if (rewardMod.isNotEmpty) 'reward_mod': rewardMod,
      };
}

/// 액션 원자 — 코드가 판정하는 최소 단위 (시나리오구조화 2-3).
/// 어휘 10종: goto·listen·answer·capture·tap·defeat·follow·purchase·combine·report.
/// 상태머신·UI는 이 어휘만 알면 된다. 미지의 `a`는 무시(전진 호환).
class ActionAtom {
  final String a;
  final Map<String, dynamic> raw;

  const ActionAtom(this.a, this.raw);

  factory ActionAtom.fromJson(Map<String, dynamic> j) =>
      ActionAtom((j['a'] ?? '').toString(), j);

  static List<ActionAtom> listFrom(dynamic v) => v is List
      ? v.whereType<Map>().map((e) => ActionAtom.fromJson(e.cast<String, dynamic>())).toList()
      : const [];

  Map<String, dynamic> toJson() => raw;

  // ── 타입별 편의 접근자 ──
  String? get place => raw['place']?.toString();
  String? get slot => raw['slot']?.toString();
  String? get object => raw['object']?.toString();
  String? get target => raw['target']?.toString();
  String? get npc => raw['npc']?.toString();
  String? get menu => raw['menu']?.toString();
  int? get steps => (raw['steps'] as num?)?.toInt();

  List<String> get targets =>
      raw['targets'] is List ? (raw['targets'] as List).map((e) => e.toString()).toList() : const [];

  List<String> get items =>
      raw['items'] is List ? (raw['items'] as List).map((e) => e.toString()).toList() : const [];

  List<ActionChoice> get choices => raw['choices'] is List
      ? (raw['choices'] as List)
          .whereType<Map>()
          .map((e) => ActionChoice.fromJson(e.cast<String, dynamic>()))
          .toList()
      : const [];

  /// `count: [1, 1]`(획득/전체) 또는 `count: 3`. 목표 개수만 뽑는다.
  int get countTarget {
    final c = raw['count'];
    if (c is num) return c.toInt();
    if (c is List && c.isNotEmpty) return (c.last as num?)?.toInt() ?? 1;
    return steps ?? (items.isNotEmpty ? items.length : 1);
  }

  /// answer 액션의 정답 인덱스(코드 고정 필드).
  int? get answerIdx {
    final q = raw['quiz'];
    if (q is Map) return (q['answer_idx'] as num?)?.toInt();
    return null;
  }

  /// 이 액션이 화면 한 단계를 차지하는가(goto/report는 전환·마감 처리).
  bool get isPlayStep => const {
        'listen', 'answer', 'capture', 'tap', 'defeat', 'follow', 'purchase', 'combine',
      }.contains(a);
}

/// 힌트 사다리 (시나리오구조화 5절). **문구=LLM 슬롯, 단수·타이밍=코드.**
/// openRule 기본값: H1 `fail1|idle60` · H2 `idle90` · H3 `button`.
class HintLadder {
  final String? h1;
  final String? h2;
  final String? h3;
  final List<String> openRule;

  const HintLadder({this.h1, this.h2, this.h3, this.openRule = defaultOpenRule});

  static const defaultOpenRule = ['fail1|idle60', 'idle90', 'button'];

  factory HintLadder.fromJson(Map<String, dynamic> j) {
    String? slot(dynamic v) {
      final s = v?.toString();
      // "slot" = 아직 LLM이 안 채운 자리표시자 → 문구 없음으로 취급
      return (s == null || s.isEmpty || s == 'slot') ? null : s;
    }

    return HintLadder(
      h1: slot(j['H1'] ?? j['h1']),
      h2: slot(j['H2'] ?? j['h2']),
      h3: slot(j['H3'] ?? j['h3']),
      openRule: (j['open_rule'] is List)
          ? (j['open_rule'] as List).map((e) => e.toString()).toList()
          : defaultOpenRule,
    );
  }

  /// 구 형식(mission.hints 3개 문자열)에서 사다리 구성 — AI 미대응 구간 폴백.
  factory HintLadder.fromLegacyHints(List<String> hints) => HintLadder(
        h1: hints.isNotEmpty ? hints[0] : null,
        h2: hints.length > 1 ? hints[1] : null,
        h3: hints.length > 2 ? hints[2] : null,
      );

  /// 1-base 단(1~3)의 문구. 없으면 null.
  String? textOf(int tier) => switch (tier) {
        1 => h1,
        2 => h2,
        3 => h3,
        _ => null,
      };

  /// 문구가 채워진 단 수.
  int get filledTiers => [h1, h2, h3].where((e) => e != null).length;

  bool get isEmpty => filledTiers == 0;

  Map<String, dynamic> toJson() => {
        if (h1 != null) 'H1': h1,
        if (h2 != null) 'H2': h2,
        if (h3 != null) 'H3': h3,
        'open_rule': openRule,
      };
}

/// `"M1+M7"` · `["M1","M7"]` 어느 쪽이든 코드 리스트로.
List<String> parseCodes(dynamic v) {
  if (v == null) return const [];
  if (v is List) return v.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList();
  return v
      .toString()
      .split(RegExp(r'[+,/]'))
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList();
}

/// `"S4_PHOTO_TRAIL"` → `"S4"`. 코드만 필요한 곳(제약 검증·아이콘)에서 사용.
String strategyCode(String s) {
  final i = s.indexOf('_');
  return i < 0 ? s : s.substring(0, i);
}

/// 동기 코드 → 한국어 라벨 (2-1 표). 표시 전용.
const motivationLabels = <String, String>{
  'M1': '기억의 수호',
  'M2': '터 지킴',
  'M3': '이름 회복',
  'M4': '평온 회복',
  'M5': '요괴 소탕',
  'M6': '살림 불림',
  'M7': '재주 시험',
  'M8': '물건 되찾기',
  'M9': '위로·전언',
};

/// 전략 코드 → 한국어 라벨 (2-2 표). 표시 전용.
const strategyLabels = <String, String>{
  'S1': '대화→수집',
  'S2': '사냥→수집',
  'S3': '퀴즈→개봉',
  'S4': '사진→추적→파편',
  'S5': '사진 인증',
  'S6': '수집 누적',
  'S7': '주문 인증',
};

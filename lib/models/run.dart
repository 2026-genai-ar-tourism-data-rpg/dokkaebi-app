// ============================================================
// [v1] 플레이 런 모델 — 서버 게임 루프 응답(runs/verify/collect/complete)
// pipeline: 모바일 클라이언트 / 모델 (서버 계약 1:1)
// 구현(요약): run 시작·조회, GPS 판정, 조각 획득, 노드 완료 응답을 타입으로 고정.
//            서버(dokkaebi-server#9) 응답 필드명을 그대로 따른다 — 이름이 어긋나면
//            런타임에 조용히 null이 되므로 여기서 한 번에 잡는다.
// 구현일: 2026-08-04 | 작성: kys (game-loop-wiring/kys/v1)
// ============================================================

/// GPS 인증 거절 사유 — 앱이 안내 문구를 고르는 기준.
enum VerifyReason {
  outOfRange,     // 반경 밖
  lowAccuracy,    // GPS 오차가 너무 큼(실내·터널)
  impossibleSpeed,// 직전 위치 대비 비현실적 이동속도 = 스푸핑 의심
  nodeHasNoCoords,// 좌표 없는 노드(합성 앵커)
  unknown,
}

VerifyReason verifyReasonOf(String? raw) => switch (raw) {
      'OUT_OF_RANGE' => VerifyReason.outOfRange,
      'LOW_ACCURACY' => VerifyReason.lowAccuracy,
      'IMPOSSIBLE_SPEED' => VerifyReason.impossibleSpeed,
      'NODE_HAS_NO_COORDS' => VerifyReason.nodeHasNoCoords,
      _ => VerifyReason.unknown,
    };

/// 사용자에게 보여줄 안내 문구 — 사유별로 다음 행동이 다르다.
String verifyMessage(VerifyReason reason, {int? distanceM, int? requiredM}) =>
    switch (reason) {
      VerifyReason.outOfRange =>
        '아직 멀었느니라. ${distanceM ?? '?'}m 떨어져 있으니 ${requiredM ?? '?'}m 안으로 들어오거라.',
      VerifyReason.lowAccuracy =>
        'GPS 신호가 흐릿하구나. 하늘이 트인 곳으로 나가 다시 시도해다오.',
      VerifyReason.impossibleSpeed =>
        '너무 빨리 움직였느니라. 잠시 후 다시 시도해다오.',
      VerifyReason.nodeHasNoCoords =>
        '이 자리는 위치를 확인할 수 없느니라.',
      VerifyReason.unknown => '위치를 확인하지 못했느니라.',
    };

/// 플레이 시작/조회 결과.
class QuestRun {
  final String runId;
  final String scenarioId;
  final String state;          // IN_PROGRESS | COMPLETED
  final String? entryNodeId;   // 시작 노드(start 응답에만)
  final int progress;          // 모은 조각 수
  final int required;          // 조각 총수
  final List<String> collectedFragmentIds;
  final List<String> verifiedNodeIds;
  final Map<String, String> choices; // 갈림길 선택 {분기노드: 갈래}

  const QuestRun({
    required this.runId,
    required this.scenarioId,
    required this.state,
    this.entryNodeId,
    this.progress = 0,
    this.required = 0,
    this.collectedFragmentIds = const [],
    this.verifiedNodeIds = const [],
    this.choices = const {},
  });

  bool get isCompleted => state == 'COMPLETED';

  factory QuestRun.fromJson(Map<String, dynamic> j) => QuestRun(
        runId: j['run_id'] as String,
        scenarioId: j['scenario_id'] as String,
        state: (j['state'] ?? 'IN_PROGRESS').toString(),
        entryNodeId: j['entry_node_id'] as String?,
        progress: (j['progress'] as num?)?.toInt() ?? 0,
        required: (j['required'] as num?)?.toInt() ?? 0,
        collectedFragmentIds:
            ((j['collected_fragment_ids'] ?? []) as List).map((e) => '$e').toList(),
        verifiedNodeIds:
            ((j['verified_node_ids'] ?? []) as List).map((e) => '$e').toList(),
        choices: ((j['choices'] ?? {}) as Map)
            .map((k, v) => MapEntry('$k', '$v')),
      );
}

/// GPS 위치 인증 결과.
class LocationVerdict {
  final bool verified;
  final int distanceM;
  final int requiredRadiusM;
  final String state;        // ARRIVED | GPS_VERIFIED
  final bool npcSpawned;
  final VerifyReason? reason; // 통과면 null

  const LocationVerdict({
    required this.verified,
    required this.distanceM,
    required this.requiredRadiusM,
    required this.state,
    required this.npcSpawned,
    this.reason,
  });

  /// 실패 시 화면에 띄울 문구(통과면 빈 문자열).
  String get message => verified
      ? ''
      : verifyMessage(reason ?? VerifyReason.unknown,
          distanceM: distanceM, requiredM: requiredRadiusM);

  factory LocationVerdict.fromJson(Map<String, dynamic> j) => LocationVerdict(
        verified: j['verified'] == true,
        distanceM: (j['distance_m'] as num?)?.round() ?? 0,
        requiredRadiusM: (j['required_radius_m'] as num?)?.toInt() ?? 0,
        state: (j['state'] ?? '').toString(),
        npcSpawned: j['npc_spawned'] == true,
        reason: j['reason'] == null ? null : verifyReasonOf('${j['reason']}'),
      );
}

/// 조각 획득 결과.
class CollectResult {
  final String fragmentId;
  final bool collected;
  final bool alreadyCollected;
  final int progress;
  final int required;

  const CollectResult({
    required this.fragmentId,
    required this.collected,
    required this.alreadyCollected,
    required this.progress,
    required this.required,
  });

  factory CollectResult.fromJson(Map<String, dynamic> j) => CollectResult(
        fragmentId: '${j['fragment_id']}',
        collected: j['collected'] == true,
        alreadyCollected: j['already_collected'] == true,
        progress: (j['progress'] as num?)?.toInt() ?? 0,
        required: (j['required'] as num?)?.toInt() ?? 0,
      );
}

/// 노드 완료·보상 결과.
class NodeReward {
  final String state;                  // REWARDED
  final int expGained;
  final bool alreadyRewarded;          // 재호출이면 true(지급 0)
  final String? memoryStoneFragmentId;
  final String? dexEntry;              // 도감에 추가된 도깨비 이름
  final List<String> titles;
  final bool regionRestored;
  final int progress;
  final int required;
  final String? nextNodeId;

  const NodeReward({
    required this.state,
    required this.expGained,
    required this.alreadyRewarded,
    this.memoryStoneFragmentId,
    this.dexEntry,
    this.titles = const [],
    this.regionRestored = false,
    this.progress = 0,
    this.required = 0,
    this.nextNodeId,
  });

  factory NodeReward.fromJson(Map<String, dynamic> j) => NodeReward(
        state: (j['state'] ?? '').toString(),
        expGained: (j['exp_gained'] as num?)?.toInt() ?? 0,
        alreadyRewarded: j['already_rewarded'] == true,
        memoryStoneFragmentId: j['memory_stone_fragment_id'] as String?,
        dexEntry: j['dex_entry'] as String?,
        titles: ((j['titles'] ?? []) as List).map((e) => '$e').toList(),
        regionRestored: j['region_restored'] == true,
        progress: (j['progress'] as num?)?.toInt() ?? 0,
        required: (j['required'] as num?)?.toInt() ?? 0,
        nextNodeId: j['next_node_id'] as String?,
      );
}

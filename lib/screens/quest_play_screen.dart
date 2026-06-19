// ============================================================
// [v1] 화면: 퀘스트 플레이 (분기 대화 + 연계, 기획 8-D·7-C)
// pipeline: 모바일 클라이언트 / 화면 (도착→분기 대화→조각 획득)
// 구현(요약): GPS 도착 → 도깨비와 선택지 분기 대화(서버→AI, 멀티턴) → 조각 획득(done).
//            inventory(이전 단서) 전달 → NPC가 인지(연계). 획득 조각을 pop으로 반환.
// 구현일: 2026-06-18 (분기 대화: 2026-06-19) | 작성: kys (rpg-dialogue/kys/v1)
// ============================================================
import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../models/scenario.dart';
import '../theme.dart';
import '../widgets/ui.dart';
import 'ar_search_screen.dart';
import 'location_verify_screen.dart';

class QuestPlayScreen extends StatefulWidget {
  final QuestNode node;
  final List<String> inventory; // 연계: 지금까지 모은 단서·조각
  const QuestPlayScreen({super.key, required this.node, this.inventory = const []});
  @override
  State<QuestPlayScreen> createState() => _QuestPlayScreenState();
}

class _QuestPlayScreenState extends State<QuestPlayScreen> {
  final _api = ApiClient();
  bool _arrived = false;
  bool _loading = false;
  bool _done = false; // 대화 종료(=힌트 받음 → 미션/AR 단계)
  bool _quizPassed = false; // 퀴즈 통과(없으면 자동 통과)
  String? _quizFeedback; // 오답 힌트
  bool _missionAcked = false; // 미션 브리핑 확인(사진/수집/탐색형)
  bool _collected = false; // AR로 조각 수집 완료
  String _line = '';
  List<DialogueChoice> _choices = [];
  final List<Map<String, String>> _history = [];
  int _turn = 0;
  List<String> _granted = [];

  bool get _needsQuiz => widget.node.quiz != null && !_quizPassed;

  /// 미션 브리핑이 필요한 타입(사진/수집/탐색/피날레). 질문형은 quiz로 처리.
  bool get _needsMissionBrief {
    final m = widget.node.mission;
    return m != null && widget.node.quiz == null && !_missionAcked;
  }

  void _answerQuiz(int i) {
    final quiz = widget.node.quiz!;
    if (i == quiz.answer) {
      setState(() => _quizPassed = true); // 정답 → AR로
    } else {
      setState(() => _quizFeedback = quiz.wrongHint); // 오답 → 힌트 후 재시도
    }
  }

  /// 대화/퀴즈/미션 후 → AR 탐색(QUEST_ACTIVE, 지령+단계힌트) → 조각 수집
  Future<void> _search() async {
    final obj = widget.node.objective;
    final m = widget.node.mission;
    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ArSearchScreen(
          placeName: widget.node.name ?? '',
          order: obj?.order ?? _line,
          hints: obj?.hints ?? const [],
          total: m?.targetCount ?? 1, // 수집/탐색형은 목표 개수만큼
        ),
      ),
    );
    if (ok == true) {
      setState(() {
        _collected = true;
        _granted = [widget.node.fragmentId]; // 조각 획득(REWARDED)
      });
    }
  }

  Future<void> _start() async {
    setState(() => _arrived = true);
    await _turnCall(null);
  }

  Future<void> _turnCall(String? choiceId) async {
    setState(() => _loading = true);
    try {
      final t = await _api.dialogueTurn(
        nodeId: widget.node.nodeId,
        nodeName: widget.node.name,
        fragmentId: widget.node.fragmentId,
        history: _history,
        inventory: widget.inventory,
        lastChoice: choiceId,
        turn: _turn,
      );
      setState(() {
        _line = t.response;
        _choices = t.choices;
        _history.add({'role': 'npc', 'text': t.response});
        _turn += 1;
        if (t.done) _done = true; // 힌트 받음 → AR 탐색 단계로
      });
    } catch (e) {
      setState(() => _line = '대화 실패 — 서버가 켜져 있나요? ($e)');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _pick(DialogueChoice c) {
    _history.add({'role': 'me', 'text': c.text});
    _turnCall(c.id);
  }

  /// 방탈출 퀴즈 UI (정답 → AR / 오답 → 힌트 후 재시도)
  Widget _quizView(Quiz quiz) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      GlowCard(
        glow: AppColors.purple,
        child: Row(children: [
          const Icon(Icons.quiz_outlined, color: AppColors.purple),
          const SizedBox(width: 8),
          Expanded(child: Text(quiz.q, style: const TextStyle(color: AppColors.textPrimary))),
        ]),
      ),
      const SizedBox(height: 10),
      ...List.generate(quiz.options.length, (i) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: OutlinedButton(
              onPressed: () => _answerQuiz(i),
              style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(46), alignment: Alignment.centerLeft),
              child: Text('${i + 1}. ${quiz.options[i]}',
                  style: const TextStyle(color: AppColors.textPrimary)),
            ),
          )),
      if (_quizFeedback != null)
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text('💡 $_quizFeedback', style: const TextStyle(color: AppColors.gold, fontSize: 13)),
        ),
    ]);
  }

  /// 미션 타입별 브리핑 카드 (사진/수집/탐색/피날레) → "시작" 누르면 AR로
  Widget _missionView(Mission m) {
    final (icon, color, title) = switch (m.type) {
      'PHOTO_FIND' => (Icons.photo_camera_outlined, AppColors.blue, '📸 사진 미션'),
      'COLLECT' => (Icons.inventory_2_outlined, AppColors.teal, '🧺 수집 미션'),
      'FIND' => (Icons.travel_explore, AppColors.purple, '🔮 탐색 미션'),
      'HUNT' => (Icons.local_fire_department, AppColors.purple, '👹 망각귀 사냥'),
      'RESTORE_AR' => (Icons.account_balance, AppColors.blue, '🏛️ 폐허 복원'),
      'PATH_TRACE' => (Icons.directions_walk, AppColors.teal, '👣 발자국 추적'),
      'DIALOGUE_COLLECT' => (Icons.auto_awesome, AppColors.gold, '🏁 기억석 복원'),
      _ => (Icons.flag_outlined, AppColors.gold, '미션'),
    };
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      GlowCard(
        glow: color,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(icon, color: color),
            const SizedBox(width: 8),
            Text(title, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
          ]),
          const SizedBox(height: 8),
          Text(m.order, style: const TextStyle(color: AppColors.textPrimary, height: 1.5)),
          // 타입별 세부
          if (m.photoTargets.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('촬영 대상: ${m.photoTargets.join(" · ")}',
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          ],
          if (m.items.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(spacing: 6, runSpacing: 6, children: [
              for (final it in m.items)
                Chip(
                  label: Text(it, style: const TextStyle(fontSize: 11)),
                  backgroundColor: AppColors.surfaceHi,
                  visualDensity: VisualDensity.compact,
                ),
            ]),
          ],
          if (m.object != null) ...[
            const SizedBox(height: 8),
            Text('찾을 것: ${m.object} ${m.count > 0 ? "×${m.count}" : ""}',
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          ],
          // HUNT: 망각귀 + 보스 + 약점
          if (m.monster != null) ...[
            const SizedBox(height: 8),
            Text('처치 대상: ${m.monster} ×${m.count}   |   보스: ${m.boss}',
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
            if (m.weakness != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('🔥 약점: ${m.weakness}', style: const TextStyle(color: AppColors.gold, fontSize: 12)),
              ),
          ],
          // RESTORE_AR: 복원할 건물 + 부재
          if (m.structure != null) ...[
            const SizedBox(height: 8),
            Text('복원: ${m.structure} (${m.era ?? ""})',
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
            if (m.parts.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Wrap(spacing: 6, runSpacing: 6, children: [
                  for (final p in m.parts)
                    Chip(
                      label: Text(p, style: const TextStyle(fontSize: 11)),
                      backgroundColor: AppColors.surfaceHi,
                      visualDensity: VisualDensity.compact,
                    ),
                ]),
              ),
          ],
          // PATH_TRACE: 발자국 단서 + 경유 지점
          if (m.trailClue != null) ...[
            const SizedBox(height: 8),
            Text('👣 ${m.trailClue}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
            for (int i = 0; i < m.steps.length; i++)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('${i + 1}. ${m.steps[i]}', style: const TextStyle(color: AppColors.teal, fontSize: 12)),
              ),
          ],
          if (m.special != null) ...[
            const SizedBox(height: 4),
            Text('⚠️ ${m.special}', style: const TextStyle(color: AppColors.gold, fontSize: 12)),
          ],
          if (m.villainLine != null) ...[
            const SizedBox(height: 8),
            Text('👹 "${m.villainLine}"',
                style: const TextStyle(color: AppColors.purple, fontSize: 13, fontStyle: FontStyle.italic)),
            if (m.guardianLine != null)
              Text('🧙 "${m.guardianLine}"',
                  style: const TextStyle(color: AppColors.gold, fontSize: 13, fontStyle: FontStyle.italic)),
          ],
        ]),
      ),
      const SizedBox(height: 12),
      FilledButton.icon(
        onPressed: () => setState(() => _missionAcked = true),
        icon: const Icon(Icons.center_focus_strong),
        label: Text(switch (m.type) {
          'PHOTO_FIND' => '📸 촬영하고 AR 탐색',
          'HUNT' => '👹 AR로 사냥 시작',
          'RESTORE_AR' => '🏛️ AR로 복원 시작',
          'PATH_TRACE' => '👣 발자국 따라가기',
          _ => '🔍 AR로 찾기 시작',
        }),
      ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final n = widget.node;
    return Scaffold(
      appBar: AppBar(title: Text(n.name ?? n.nodeId)),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: !_arrived
            ? _arrivalView(n)
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (widget.inventory.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Wrap(spacing: 6, children: [
                        for (final i in widget.inventory)
                          Chip(
                            label: Text(i, style: const TextStyle(fontSize: 11)),
                            backgroundColor: AppColors.surfaceHi,
                            visualDensity: VisualDensity.compact,
                          ),
                      ]),
                    ),
                  const Text('🧙 도깨비',
                      style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.gold)),
                  const SizedBox(height: 6),
                  Expanded(
                    child: SingleChildScrollView(
                      child: GlowCard(
                        glow: AppColors.gold,
                        child: _loading && _line.isEmpty
                            ? const Center(child: Padding(padding: EdgeInsets.all(8), child: CircularProgressIndicator()))
                            : Text(_line, style: const TextStyle(color: AppColors.textPrimary, height: 1.5)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_collected)
                    // REWARDED: 조각 획득
                    Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      GlowCard(
                        glow: AppColors.teal,
                        child: Row(children: [
                          const Icon(Icons.diamond, color: AppColors.teal),
                          const SizedBox(width: 8),
                          Expanded(child: Text('기억석 조각 획득! (${_granted.join(", ")})',
                              style: const TextStyle(color: AppColors.textPrimary))),
                        ]),
                      ),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: () => Navigator.pop(context, _granted),
                        child: Text(n.isFinale ? '🏁 기억석 복원 — 완료!' : '다음 장소로'),
                      ),
                    ])
                  else if (_done && _needsQuiz)
                    // 방탈출 퀴즈/대화선택: 정답 → AR / 오답 → 힌트 후 재시도
                    _quizView(widget.node.quiz!)
                  else if (_done && _needsMissionBrief)
                    // 미션 브리핑(사진/수집/탐색/피날레) → 확인 후 AR
                    _missionView(widget.node.mission!)
                  else if (_done)
                    // QUEST_ACTIVE: 대화·퀴즈·미션 통과 → AR 탐색으로 조각 찾기
                    FilledButton.icon(
                      onPressed: _search,
                      icon: const Icon(Icons.center_focus_strong),
                      label: const Text('🔍 AR로 기억석 찾기'),
                    )
                  else
                    ..._choices.map((c) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: OutlinedButton(
                            onPressed: _loading ? null : () => _pick(c),
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size.fromHeight(48),
                              alignment: Alignment.centerLeft,
                              side: BorderSide(
                                  color: c.id == 'collect' ? AppColors.teal : AppColors.border),
                            ),
                            child: Text(c.text,
                                style: TextStyle(
                                    color: c.id == 'collect' ? AppColors.teal : AppColors.textPrimary)),
                          ),
                        )),
                ],
              ),
      ),
    );
  }

  Widget _arrivalView(QuestNode n) => Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.place, color: AppColors.teal, size: 48),
          const SizedBox(height: 12),
          Text(n.name ?? n.nodeId,
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 20, fontWeight: FontWeight.bold)),
          Text('반경 ${n.triggerRadiusM}m 안에서 도착 인증',
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () async {
              final ok = await Navigator.push<bool>(
                context,
                MaterialPageRoute(builder: (_) => LocationVerifyScreen(placeName: n.name ?? '이곳')),
              );
              if (ok == true) _start();
            },
            icon: const Icon(Icons.my_location),
            label: const Text('도착 인증'),
          ),
        ],
      );
}

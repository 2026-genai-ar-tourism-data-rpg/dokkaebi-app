// ============================================================
// [v2] 화면: 퀘스트 플레이 — 종로의 기억석 UI 시안 1a(지령수신)/1e(분기대화)/1d(파편획득)
// pipeline: 모바일 클라이언트 / 화면 (도착→분기 대화→지령→AR→조각 획득)
// 구현(요약): AR 무대(한옥 실루엣) + 먹 도깨비 + 하단 한지 지령/대화 카드로 재구성.
//            상태 로직(대화·퀴즈·미션·AR·보상)은 v1 그대로, UI만 시안대로.
// 구현일: 2026-07-08 | 작성: kys (quest-play/kys/v2) · 시안: 종로의 기억석 UI
// ------------------------------------------------------------
// [v1] 분기 대화 + 미션 브리핑 카드 리스트 — 2026-06-18 kys (rpg-dialogue/kys/v1)
// ============================================================
import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../game/run_session.dart';
import '../models/run.dart';
import '../models/scenario.dart';
import '../theme.dart';
import '../widgets/ar_frame.dart';
import 'ar_search_screen.dart';
import 'location_verify_screen.dart';

class QuestPlayScreen extends StatefulWidget {
  final QuestNode node;
  final List<String> inventory;
  const QuestPlayScreen({super.key, required this.node, this.inventory = const []});
  @override
  State<QuestPlayScreen> createState() => _QuestPlayScreenState();
}

class _QuestPlayScreenState extends State<QuestPlayScreen> {
  final _api = ApiClient();
  bool _arrived = false;
  bool _loading = false;
  bool _done = false;
  bool _quizPassed = false;
  String? _quizFeedback;
  bool _missionAcked = false;
  bool _collected = false;
  NodeReward? _reward;      // 서버가 계산한 보상(경험치·칭호·다음 노드)
  String? _serverError;     // 조각 기록 실패 사유 — 사용자에게 보여준다
  String _line = '';
  List<DialogueChoice> _choices = [];
  final List<Map<String, String>> _history = [];
  int _turn = 0;
  List<String> _granted = [];

  bool get _needsQuiz => widget.node.quiz != null && !_quizPassed;
  bool get _needsMissionBrief {
    final m = widget.node.mission;
    return m != null && widget.node.quiz == null && !_missionAcked;
  }

  void _answerQuiz(int i) {
    final quiz = widget.node.quiz!;
    if (i == quiz.answer) {
      setState(() => _quizPassed = true);
    } else {
      setState(() => _quizFeedback = quiz.wrongHint);
    }
  }

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
          total: m?.targetCount ?? 1,
        ),
      ),
    );
    if (ok != true) return;

    // AR에서 찾았다고 곧바로 획득 처리하지 않는다 — 조각의 주인은 서버다.
    // 서버가 GPS 인증·requires·중복을 검사하고, 실패하면 사유를 돌려준다.
    if (RunSession.I.isActive) {
      final collected = await RunSession.I.collect(widget.node.nodeId);
      if (!mounted) return;
      if (collected == null) {
        setState(() => _serverError = RunSession.I.error ?? '조각을 기록하지 못했느니라.');
        return;
      }
      final reward = await RunSession.I.complete(widget.node.nodeId);
      if (!mounted) return;
      setState(() {
        _collected = true;
        _granted = [collected.fragmentId];
        _reward = reward;
        _serverError = null;
      });
      return;
    }

    // 서버 세션이 없으면(데모·미리보기) 로컬 표시만 한다.
    setState(() {
      _collected = true;
      _granted = widget.node.fragmentId.isEmpty ? [] : [widget.node.fragmentId];
    });
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
        if (t.done) _done = true;
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

  // ────────────────────────────────────────────────
  // AR 무대 composition
  // ────────────────────────────────────────────────
  bool get _quizNow => _arrived && !_collected && _done && _needsQuiz;

  @override
  Widget build(BuildContext context) {
    final n = widget.node;
    final counter = _collected
        ? '조각 ✓'
        : (n.isFinale ? '피날레' : (n.stoneNo != null ? '${n.stoneNo}번째' : '탐사'));
    return Scaffold(
      body: ArStage(children: [
        ArTopHud(
          place: n.name ?? n.nodeId,
          counter: counter,
          onBack: () => Navigator.pop(context),
        ),
        // 먹 도깨비 (도착 후, 보상·퀴즈 제외)
        if (_arrived && !_collected && !_quizNow)
          const Align(alignment: Alignment(0, -0.42), child: DokkaebiNpc(size: 150, showBadge: false)),
        // 퀴즈 = 중앙 모달 / 그 외 = 하단 시트
        if (_quizNow) ...[
          Container(color: Colors.black.withOpacity(0.72)),
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: SingleChildScrollView(child: _quizCard(widget.node.quiz!)),
            ),
          ),
        ] else
          Positioned(
            left: 14, right: 14, bottom: 30,
            child: SafeArea(
              top: false,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.6),
                child: SingleChildScrollView(child: _sheet(n)),
              ),
            ),
          ),
      ]),
    );
  }

  Widget _sheet(QuestNode n) {
    if (!_arrived) return _arrivalCard(n);
    if (_collected) return _rewardCard(n);
    if (_done && _needsQuiz) return _quizCard(widget.node.quiz!);
    if (_done && _needsMissionBrief) return _missionCard(widget.node.mission!);
    if (_done) return _searchCard();
    return _dialogueCard();
  }

  // ── 도착 전 ──────────────────────────────────
  Widget _arrivalCard(QuestNode n) => ParchmentCard(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(n.name ?? n.nodeId, style: dokkaebiTitle(size: 20, color: Hanji.ink)),
          const SizedBox(height: 6),
          Text('반경 ${n.triggerRadiusM}m 안에서 도착을 인증하거라.',
              style: const TextStyle(color: Hanji.inkSoft, fontSize: 14)),
          const SizedBox(height: 16),
          _redButton('도착 인증', onTap: () async {
            // nodeId를 넘겨야 서버 반경 판정을 탄다. 안 넘기면 좌표만 보고 통과한다.
            final ok = await Navigator.push<bool>(
              context,
              MaterialPageRoute(
                builder: (_) => LocationVerifyScreen(
                  placeName: n.name ?? '이곳',
                  nodeId: RunSession.I.isActive ? n.nodeId : null,
                ),
              ),
            );
            if (ok == true) _start();
          }),
        ]),
      );

  // ── 분기 대화 (v2 DIALOGUE) — 다크 말풍선 + A/B/C 선택지 ──
  Widget _dialogueCard() {
    const badges = [
      (Color(0xFF2A8577), Color(0xFFEAFFF9)),
      (Color(0xFFD9A441), Color(0xFF2A2118)),
      (Color(0xFF3A352E), Color(0xFFC9C1B2)),
    ];
    const letters = ['A', 'B', 'C'];
    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      // NPC 말풍선 (다크 + 금테 + 빨간 이름표)
      Stack(clipBehavior: Clip.none, children: [
        Container(
          padding: const EdgeInsets.fromLTRB(18, 22, 18, 16),
          decoration: BoxDecoration(
            color: const Color(0xFF0D0B09).withOpacity(0.92),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.goldDim.withOpacity(0.55), width: 1.5),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.6), blurRadius: 40, offset: const Offset(0, 14))],
          ),
          child: _loading && _line.isEmpty
              ? const Center(child: Padding(padding: EdgeInsets.all(6), child: CircularProgressIndicator(color: AppColors.gold)))
              : Text(_line, style: dokkaebiTitle(size: 16, weight: FontWeight.w500, color: AppColors.textPrimary, height: 1.65)),
        ),
        Positioned(
          top: -14, left: 16,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
            decoration: BoxDecoration(color: Hanji.badge, borderRadius: BorderRadius.circular(8)),
            child: const Text('먹 도깨비', style: TextStyle(color: Hanji.cream, fontSize: 13, fontWeight: FontWeight.w900)),
          ),
        ),
      ]),
      if (_choices.isNotEmpty && !_done) ...[
        const SizedBox(height: 10),
        for (var i = 0; i < _choices.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _choiceRow(letters[i % 3], badges[i % 3], _choices[i]),
          ),
      ],
    ]);
  }

  Widget _choiceRow(String letter, (Color, Color) badge, DialogueChoice c) => GestureDetector(
        onTap: _loading ? null : () => _pick(c),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
            color: const Color(0xFF181410).withOpacity(0.94),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: badge.$1.withOpacity(0.55)),
          ),
          child: Row(children: [
            Container(
              width: 28, height: 28, alignment: Alignment.center,
              decoration: BoxDecoration(color: badge.$1, borderRadius: BorderRadius.circular(8)),
              child: Text(letter, style: TextStyle(color: badge.$2, fontWeight: FontWeight.w900, fontSize: 14)),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(c.text, style: const TextStyle(color: Color(0xFFE8DCC4), fontSize: 14, fontWeight: FontWeight.w500))),
          ]),
        ),
      );

  // ── 지령 카드 (1a) — 미션 브리핑 ───────────────
  Widget _missionCard(Mission m) {
    // 체크리스트: 미션 종류별 0/N 항목
    final items = <(String, String)>[];
    if (m.photoTargets.isNotEmpty) items.add(('사진에 담기', '0/1'));
    if (m.monster != null) items.add(('${m.monster} 처치', '0/${m.count}'));
    if (m.parts.isNotEmpty) items.add(('부재 복원', '0/${m.parts.length}'));
    if (m.steps.isNotEmpty) items.add(('발자국 따라가기', '0/${m.steps.length}'));
    if (m.object != null) items.add(('${m.object} 수집', '0/${m.count > 0 ? m.count : 1}'));
    if (items.isEmpty) items.add(('글씨 파편 수집', '0/1'));

    return ParchmentCard(
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 46, height: 46, alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Hanji.badge, borderRadius: BorderRadius.circular(8),
              boxShadow: [BoxShadow(color: Hanji.cream.withOpacity(0.35), blurRadius: 0, spreadRadius: 2, blurStyle: BlurStyle.inner)],
            ),
            child: Text('지령', style: dokkaebiTitle(size: 18, color: Hanji.cream)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text('"${m.order}"',
                style: dokkaebiTitle(size: 16, color: Hanji.ink, height: 1.5)),
          ),
        ]),
        const SizedBox(height: 14),
        ...items.map((it) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(children: [
                Container(
                  width: 20, height: 20,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Hanji.line, width: 2),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(child: Text(it.$1, style: const TextStyle(color: Hanji.inkSoft, fontSize: 13.5, fontWeight: FontWeight.w500))),
                Text(it.$2, style: const TextStyle(color: Hanji.bronze, fontSize: 13.5, fontWeight: FontWeight.w700)),
              ]),
            )),
        if (m.weakness != null) ...[
          const SizedBox(height: 4),
          Text('🔥 약점: ${m.weakness}', style: const TextStyle(color: Hanji.badge, fontSize: 12)),
        ],
        const SizedBox(height: 16),
        _redButton('지령 받기 — 사냥 시작', onTap: () => setState(() => _missionAcked = true)),
      ]),
    );
  }

  // ── 퀴즈 (v2 QUIZ) — 중앙 모달 "도깨비의 시험" ──
  Widget _quizCard(Quiz quiz) => Stack(clipBehavior: Clip.none, children: [
        ParchmentCard(
          padding: const EdgeInsets.fromLTRB(20, 26, 20, 18),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(quiz.q, style: dokkaebiTitle(size: 17, color: Hanji.ink, height: 1.55)),
            const SizedBox(height: 16),
            ...List.generate(quiz.options.length, (i) => Padding(
                  padding: const EdgeInsets.only(bottom: 9),
                  child: _quizOption(i, quiz.options[i]),
                )),
            if (_quizFeedback != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Hanji.badge.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(11),
                  border: Border.all(color: Hanji.badge.withOpacity(0.4)),
                ),
                child: Text('"$_quizFeedback" — 다시 골라도 페널티는 없다',
                    style: const TextStyle(color: Color(0xFF8A3320), fontSize: 13.5)),
              ),
            ],
          ]),
        ),
        // "도깨비의 시험" 상단 뱃지
        Positioned(
          top: -15, left: 0, right: 0,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 6),
              decoration: BoxDecoration(color: Hanji.badge, borderRadius: BorderRadius.circular(999)),
              child: const Text('도깨비의 시험',
                  style: TextStyle(color: Hanji.cream, fontWeight: FontWeight.w900, fontSize: 14, letterSpacing: 1.2)),
            ),
          ),
        ),
      ]);

  Widget _quizOption(int i, String label) => GestureDetector(
        onTap: () => _answerQuiz(i),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.4),
            borderRadius: BorderRadius.circular(13),
            border: Border.all(color: Hanji.line),
          ),
          child: Row(children: [
            Container(
              width: 26, height: 26, alignment: Alignment.center,
              decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Hanji.line, width: 1.5)),
              child: Text('${i + 1}', style: const TextStyle(color: Hanji.inkSoft, fontWeight: FontWeight.w900, fontSize: 13)),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(label, style: const TextStyle(color: Hanji.ink, fontWeight: FontWeight.w700, fontSize: 15))),
          ]),
        ),
      );

  // ── AR 진입 CTA ──────────────────────────────
  /// 서버가 조각 기록을 거절했을 때의 안내(GPS 미인증·순서 미충족 등).
  Widget _serverErrorBanner() => Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Hanji.badge.withOpacity(0.12),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Hanji.badge.withOpacity(0.45)),
        ),
        child: Row(children: [
          const Icon(Icons.error_outline, size: 16, color: Hanji.badge),
          const SizedBox(width: 8),
          Expanded(
            child: Text(_serverError!,
                style: const TextStyle(color: Hanji.ink, fontSize: 12.5, height: 1.4)),
          ),
        ]),
      );

  Widget _searchCard() => ParchmentCard(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (_serverError != null) _serverErrorBanner(),
          Text('붓을 들 때가 되었구나.', style: dokkaebiTitle(size: 16, color: Hanji.ink)),
          const SizedBox(height: 14),
          _redButton('AR로 기억석 찾기', onTap: _search),
        ]),
      );

  // ── 파편 획득 (1d) ───────────────────────────
  Widget _rewardCard(QuestNode n) => ParchmentCard(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Text('✦', style: TextStyle(color: Hanji.badge, fontSize: 22)),
            const SizedBox(width: 8),
            Text('기억석 조각 획득', style: dokkaebiTitle(size: 18, color: Hanji.ink)),
          ]),
          if (_granted.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(_granted.join(', '), style: const TextStyle(color: Hanji.bronze, fontSize: 12)),
          ],
          // 서버가 계산한 보상 — 로컬 추정이 아니라 실제 지급된 값이다.
          if (_reward != null) ...[
            const SizedBox(height: 10),
            Text('경험치 +${_reward!.expGained}   ·   조각 ${_reward!.progress}/${_reward!.required}',
                style: const TextStyle(color: Hanji.inkSoft, fontSize: 13)),
            if (_reward!.dexEntry != null) ...[
              const SizedBox(height: 4),
              Text('도감에 «${_reward!.dexEntry}» 추가',
                  style: const TextStyle(color: Hanji.bronze, fontSize: 12)),
            ],
            for (final t in _reward!.titles) ...[
              const SizedBox(height: 4),
              Text('🏆 $t',
                  style: const TextStyle(
                      color: Hanji.badge, fontSize: 13, fontWeight: FontWeight.w700)),
            ],
          ],
          const SizedBox(height: 16),
          _redButton(
              _reward?.regionRestored == true
                  ? '기억석 복원 — 완료!'
                  : (n.isFinale ? '기억석 복원 — 완료!' : '다음 장소로'),
              onTap: () => Navigator.pop(context, _granted)),
        ]),
      );

  // ── 공통 조각 ────────────────────────────────
  Widget _redButton(String text, {VoidCallback? onTap}) => GestureDetector(
        onTap: onTap,
        child: Container(
          height: 48, alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Hanji.badge, borderRadius: BorderRadius.circular(12),
            boxShadow: [BoxShadow(color: Hanji.badge.withOpacity(0.4), blurRadius: 16, offset: const Offset(0, 6))],
          ),
          child: Text(text, style: const TextStyle(color: Hanji.cream, fontWeight: FontWeight.w900, fontSize: 15.5)),
        ),
      );

}

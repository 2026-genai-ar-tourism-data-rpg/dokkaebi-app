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
  bool _done = false; // 대화 종료(=힌트 받음 → AR 탐색 단계)
  bool _collected = false; // AR로 조각 수집 완료
  String _line = '';
  List<DialogueChoice> _choices = [];
  final List<Map<String, String>> _history = [];
  int _turn = 0;
  List<String> _granted = [];

  /// 대화 힌트 → AR 탐색(QUEST_ACTIVE) → 조각 수집
  Future<void> _search() async {
    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ArSearchScreen(placeName: widget.node.name ?? '', hint: _line),
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
                  else if (_done)
                    // QUEST_ACTIVE: 대화 힌트 받음 → AR 탐색으로 조각 찾기
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

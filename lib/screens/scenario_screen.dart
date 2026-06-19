// ============================================================
// [v1] 화면: 시나리오(루트) 보기 + 연계 진행 (기획 7-C)
// pipeline: 모바일 클라이언트 / 화면 (코스 = 기억석 체인)
// 구현(요약): 노드 카드 리스트 + 누적 인벤토리(획득 단서·조각) 표시. 노드 탭 → 플레이
//            → 획득물 pop으로 받아 inventory 누적(다음 노드 대화에 전달=연계). 전 노드 완료 → 복원.
// 구현일: 2026-06-18 (연계: 2026-06-19) | 작성: kys (rpg-dialogue/kys/v1)
// ============================================================
import 'package:flutter/material.dart';

import '../models/scenario.dart';
import '../theme.dart';
import '../widgets/ui.dart';
import 'quest_play_screen.dart';

class ScenarioScreen extends StatefulWidget {
  final Scenario scenario;
  const ScenarioScreen({super.key, required this.scenario});
  @override
  State<ScenarioScreen> createState() => _ScenarioScreenState();
}

class _ScenarioScreenState extends State<ScenarioScreen> {
  final List<String> _inventory = []; // 연계: 누적 단서·조각
  final Set<String> _done = {}; // 완료한 node_id

  Future<void> _play(QuestNode n) async {
    final granted = await Navigator.push<List<String>>(
      context,
      MaterialPageRoute(
        builder: (_) => QuestPlayScreen(node: n, inventory: List.of(_inventory)),
      ),
    );
    if (granted != null) {
      setState(() {
        _inventory.addAll(granted);
        _done.add(n.nodeId);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final scn = widget.scenario;
    final allDone = _done.length >= scn.nodeSequence.length && scn.nodeSequence.isNotEmpty;
    return Scaffold(
      appBar: AppBar(title: Text(scn.title)),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Text('${scn.region} · ${_done.length}/${scn.nodeSequence.length}조각',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          ProgressBar(scn.nodeSequence.isEmpty ? 0 : _done.length / scn.nodeSequence.length,
              color: AppColors.purple),
          const SizedBox(height: 10),
          // 연계: 모은 단서·조각
          if (_inventory.isNotEmpty)
            GlowCard(
              padding: const EdgeInsets.all(12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('🎒 모은 것', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                const SizedBox(height: 6),
                Wrap(spacing: 6, runSpacing: 6, children: [
                  for (final i in _inventory)
                    Chip(
                      label: Text(i, style: const TextStyle(fontSize: 11)),
                      backgroundColor: AppColors.surfaceHi,
                      visualDensity: VisualDensity.compact,
                    ),
                ]),
              ]),
            ),
          const SizedBox(height: 8),
          // TODO(정찬희): 지도(루트 핀+동선) — flutter_map
          ...scn.nodeSequence.map((n) {
            final done = _done.contains(n.nodeId);
            return Card(
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: done ? AppColors.teal.withOpacity(0.2) : null,
                  child: done
                      ? const Icon(Icons.check, color: AppColors.teal)
                      : Text('${n.order + 1}'),
                ),
                title: Row(children: [
                  Expanded(child: Text(n.name ?? n.nodeId)),
                  if (n.isFinale)
                    const Chip(label: Text('🏁 피날레'), visualDensity: VisualDensity.compact),
                ]),
                subtitle: Text(
                    '${n.distM?.toStringAsFixed(0) ?? '-'}m · ${n.fragmentId}${done ? ' · 완료' : ''}'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _play(n),
              ),
            );
          }),
          const SizedBox(height: 12),
          if (allDone)
            GlowCard(
              glow: AppColors.purple,
              child: Row(children: const [
                Icon(Icons.auto_awesome, color: AppColors.purple),
                SizedBox(width: 8),
                Expanded(
                    child: Text('기억석 복원 완료! 종로의 기억이 되살아났다.',
                        style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold))),
              ]),
            ),
        ],
      ),
    );
  }
}

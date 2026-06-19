// ============================================================
// [v1] 화면: 시나리오(루트) 보기 + 연계 진행 (기획 7-C)
// pipeline: 모바일 클라이언트 / 화면 (코스 = 기억석 체인)
// 구현(요약): 노드 카드 리스트 + 누적 인벤토리(획득 단서·조각) 표시. 노드 탭 → 플레이
//            → 획득물 pop으로 받아 inventory 누적(다음 노드 대화에 전달=연계). 전 노드 완료 → 복원.
// 구현일: 2026-06-18 (연계: 2026-06-19) | 작성: kys (rpg-dialogue/kys/v1)
// ============================================================
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/scenario.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets/ui.dart';
import 'quest_play_screen.dart';

/// 시나리오 루트 지도 — 노드 좌표를 박스에 정규화해 순번 핀으로 동선 표시.
class _RouteMap extends StatelessWidget {
  final List<QuestNode> nodes;
  final Set<String> done;
  const _RouteMap({required this.nodes, required this.done});

  @override
  Widget build(BuildContext context) {
    final pts = nodes.where((n) => n.mapX != null && n.mapY != null).toList();
    if (pts.length < 2) return const SizedBox.shrink();
    final xs = pts.map((n) => n.mapX!), ys = pts.map((n) => n.mapY!);
    final minX = xs.reduce(math.min), maxX = xs.reduce(math.max);
    final minY = ys.reduce(math.min), maxY = ys.reduce(math.max);
    double nx(double x) => (maxX - minX).abs() < 1e-9 ? 0.5 : (x - minX) / (maxX - minX);
    double ny(double y) => (maxY - minY).abs() < 1e-9 ? 0.5 : (y - minY) / (maxY - minY);

    return AspectRatio(
      aspectRatio: 1.5,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF0C1322),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        padding: const EdgeInsets.all(20),
        child: LayoutBuilder(builder: (context, box) {
          return Stack(children: [
            for (var i = 0; i < pts.length; i++)
              Align(
                // 위도(y)는 위로 갈수록 크므로 뒤집어 배치
                alignment: Alignment(nx(pts[i].mapX!) * 2 - 1, (1 - ny(pts[i].mapY!)) * 2 - 1),
                child: _pin(i, pts[i], done.contains(pts[i].nodeId)),
              ),
          ]);
        }),
      ),
    );
  }

  Widget _pin(int i, QuestNode n, bool isDone) {
    final c = n.isFinale ? AppColors.gold : (isDone ? AppColors.teal : AppColors.purple);
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Container(
        width: 30, height: 30,
        decoration: BoxDecoration(
          color: c.withOpacity(0.22),
          shape: BoxShape.circle,
          border: Border.all(color: c),
          boxShadow: [BoxShadow(color: c.withOpacity(0.4), blurRadius: 10)],
        ),
        child: Center(
          child: isDone
              ? const Icon(Icons.check, color: AppColors.teal, size: 16)
              : Text('${i + 1}', style: TextStyle(color: c, fontSize: 13, fontWeight: FontWeight.bold)),
        ),
      ),
      const SizedBox(height: 1),
      Container(
        constraints: const BoxConstraints(maxWidth: 64),
        child: Text(n.name ?? '', maxLines: 1, overflow: TextOverflow.ellipsis,
            style: TextStyle(color: c, fontSize: 9)),
      ),
    ]);
  }
}

class ScenarioScreen extends StatefulWidget {
  final Scenario scenario;
  const ScenarioScreen({super.key, required this.scenario});
  @override
  State<ScenarioScreen> createState() => _ScenarioScreenState();
}

class _ScenarioScreenState extends State<ScenarioScreen> {
  Future<void> _play(QuestNode n, List<String> inventory) async {
    final granted = await Navigator.push<List<String>>(
      context,
      MaterialPageRoute(
        builder: (_) => QuestPlayScreen(node: n, inventory: inventory),
      ),
    );
    if (granted != null) {
      // 진행 상황을 스토어에 영속 → 나가도 유지, 퀘스트 탭에 반영
      await ScenarioStore.I.completeNode(widget.scenario.scenarioId, n.nodeId, granted);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scn = widget.scenario;
    return Scaffold(
      appBar: AppBar(title: Text(scn.title)),
      body: ListenableBuilder(
        listenable: ScenarioStore.I,
        builder: (context, _) {
          final done = ScenarioStore.I.doneOf(scn.scenarioId).toSet();
          final inventory = ScenarioStore.I.inventoryOf(scn.scenarioId);
          final allDone = done.length >= scn.nodeSequence.length && scn.nodeSequence.isNotEmpty;
          return ListView(
            padding: const EdgeInsets.all(12),
            children: [
              Text('${scn.region} · ${done.length}/${scn.nodeSequence.length}조각',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              ProgressBar(scn.nodeSequence.isEmpty ? 0 : done.length / scn.nodeSequence.length,
                  color: AppColors.purple),
              const SizedBox(height: 10),
              // 연계: 모은 단서·조각
              if (inventory.isNotEmpty)
                GlowCard(
                  padding: const EdgeInsets.all(12),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('🎒 모은 것', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                    const SizedBox(height: 6),
                    Wrap(spacing: 6, runSpacing: 6, children: [
                      for (final i in inventory)
                        Chip(
                          label: Text(i, style: const TextStyle(fontSize: 11)),
                          backgroundColor: AppColors.surfaceHi,
                          visualDensity: VisualDensity.compact,
                        ),
                    ]),
                  ]),
                ),
              const SizedBox(height: 8),
              // 시나리오 루트 지도(이 코스의 노드 동선). 실 지리 지도는 flutter_map(정찬희) TODO.
              _RouteMap(nodes: scn.nodeSequence, done: done),
              const SizedBox(height: 12),
              ...scn.nodeSequence.map((n) {
                final isDone = done.contains(n.nodeId);
                return Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: isDone ? AppColors.teal.withOpacity(0.2) : null,
                      child: isDone
                          ? const Icon(Icons.check, color: AppColors.teal)
                          : Text('${n.order + 1}'),
                    ),
                    title: Row(children: [
                      Expanded(child: Text(n.name ?? n.nodeId)),
                      if (n.isFinale)
                        const Chip(label: Text('🏁 피날레'), visualDensity: VisualDensity.compact),
                    ]),
                    subtitle: Text(
                        '${n.distM?.toStringAsFixed(0) ?? '-'}m · ${n.fragmentId}${isDone ? ' · 완료' : ''}'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _play(n, inventory),
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
          );
        },
      ),
    );
  }
}

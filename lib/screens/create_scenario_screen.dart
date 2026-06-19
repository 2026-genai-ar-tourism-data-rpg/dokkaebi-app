// ============================================================
// [v1] 화면: 시나리오 만들기 (입력 contract 수집)
// pipeline: 모바일 클라이언트 / 화면 (1단계 사용자 입력)
// 구현(요약): 현재위치·끝점·이동수단·위시리스트(이름 자동완성→선택)·예산 → 서버 호출.
//            위시리스트: 타이핑하면(디바운스) 자동 검색 → 후보 탭 → content_id 확정(칩).
//            ⚠️ GPS·카카오는 TODO(정찬희) — 지금은 좌표 직접 입력.
// 구현일: 2026-06-18 | 작성: kys (app-scaffold/kys/v1)
// ============================================================
import 'dart:async';

import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../models/scenario.dart';
import '../store.dart';
import 'scenario_screen.dart';

class CreateScenarioScreen extends StatefulWidget {
  const CreateScenarioScreen({super.key});
  @override
  State<CreateScenarioScreen> createState() => _CreateScenarioScreenState();
}

class _CreateScenarioScreenState extends State<CreateScenarioScreen> {
  final _api = ApiClient();
  final _startLat = TextEditingController(text: '37.5703');
  final _startLng = TextEditingController(text: '126.9856');
  final _endLat = TextEditingController(text: '37.5547');
  final _endLng = TextEditingController(text: '126.9707');
  final _budget = TextEditingController(text: '30000');
  final _search = TextEditingController();
  String _transport = 'walk';
  bool _withDialogue = true;
  bool _loading = false;
  bool _searching = false;
  bool _searched = false; // 검색 1회 이상 수행(결과없음 안내용)
  String? _error;
  String? _searchError;
  Timer? _debounce;

  List<SearchCandidate> _results = [];
  final List<SearchCandidate> _selected = [];

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  /// 타이핑할 때마다 디바운스(400ms) 후 자동 검색.
  void _onSearchChanged(String v) {
    _debounce?.cancel();
    final kw = v.trim();
    if (kw.isEmpty) {
      setState(() {
        _results = [];
        _searched = false;
        _searchError = null;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 400), () => _runSearch(kw));
  }

  Future<void> _runSearch(String kw) async {
    setState(() {
      _searching = true;
      _searchError = null;
    });
    try {
      final r = await _api.searchAttractions(kw);
      setState(() {
        _results = r;
        _searched = true;
      });
    } catch (e) {
      setState(() => _searchError = '검색 실패 — 서버가 켜져 있나요? ($e)');
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  void _pick(SearchCandidate c) {
    if (!_selected.any((s) => s.contentId == c.contentId)) {
      _selected.add(c);
    }
    setState(() {
      _results = [];
      _searched = false;
      _search.clear();
    });
  }

  Future<void> _generate() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final scn = await _api.generateScenario(
        startLat: double.parse(_startLat.text),
        startLng: double.parse(_startLng.text),
        endLat: double.tryParse(_endLat.text),
        endLng: double.tryParse(_endLng.text),
        transport: _transport,
        wishlistContentIds: _selected.map((s) => s.contentId).toList(),
        budget: int.tryParse(_budget.text),
        withDialogue: _withDialogue,
      );
      ScenarioStore.I.add(scn); // 퀘스트 일지에 남김
      if (!mounted) return;
      Navigator.push(context,
          MaterialPageRoute(builder: (_) => ScenarioScreen(scenario: scn)));
    } catch (e) {
      setState(() => _error = '생성 실패 — 서버가 켜져 있나요? ($e)');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('도깨비 — 시나리오 만들기')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('현재 위치 (GPS — 지금은 직접 입력)',
              style: TextStyle(fontWeight: FontWeight.bold)),
          Row(children: [
            Expanded(child: _num(_startLat, '위도')),
            const SizedBox(width: 8),
            Expanded(child: _num(_startLng, '경도')),
          ]),
          const SizedBox(height: 12),
          const Text('끝 위치 (집 — 없으면 비워서 왕복)',
              style: TextStyle(fontWeight: FontWeight.bold)),
          Row(children: [
            Expanded(child: _num(_endLat, '위도')),
            const SizedBox(width: 8),
            Expanded(child: _num(_endLng, '경도')),
          ]),
          const SizedBox(height: 16),

          // --- 꼭 가고싶은 관광지: 이름 입력 → 자동 검색 → 후보 선택 ---
          const Text('꼭 가고싶은 관광지 (이름 검색)',
              style: TextStyle(fontWeight: FontWeight.bold)),
          TextField(
            controller: _search,
            onChanged: _onSearchChanged,
            decoration: InputDecoration(
              hintText: '예: 경복궁 — 입력하면 자동 검색',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searching
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(strokeWidth: 2)),
                    )
                  : null,
            ),
          ),
          // 선택된 앵커 칩
          if (_selected.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Wrap(
                spacing: 6,
                children: _selected
                    .map((c) => Chip(
                          label: Text(c.name ?? c.contentId),
                          onDeleted: () => setState(() => _selected.remove(c)),
                        ))
                    .toList(),
              ),
            ),
          // 검색 상태/결과
          if (_searchError != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(_searchError!, style: const TextStyle(color: Colors.red)),
            ),
          if (_searched && _results.isEmpty && _searchError == null)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text('검색 결과 없음', style: TextStyle(color: Colors.grey)),
            ),
          ..._results.map((c) => Card(
                margin: const EdgeInsets.only(top: 6),
                child: ListTile(
                  dense: true,
                  leading: const Icon(Icons.place_outlined),
                  title: Text(c.name ?? c.contentId),
                  subtitle: Text(c.addr ?? ''),
                  trailing: const Icon(Icons.add_circle_outline),
                  onTap: () => _pick(c),
                ),
              )),

          const SizedBox(height: 12),
          Row(children: [
            const Text('이동수단  '),
            DropdownButton<String>(
              value: _transport,
              items: const [
                DropdownMenuItem(value: 'walk', child: Text('🚶 도보')),
                DropdownMenuItem(value: 'car', child: Text('🚗 차')),
              ],
              onChanged: (v) => setState(() => _transport = v ?? 'walk'),
            ),
          ]),
          _num(_budget, '예산(원, 선택)'),
          SwitchListTile(
            title: const Text('NPC 대사 LLM 생성'),
            subtitle: const Text('끄면 빠름(고정 대사)'),
            value: _withDialogue,
            onChanged: (v) => setState(() => _withDialogue = v),
          ),
          const SizedBox(height: 8),
          if (_error != null)
            Text(_error!, style: const TextStyle(color: Colors.red)),
          FilledButton(
            onPressed: _loading ? null : _generate,
            child: _loading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('코스 생성'),
          ),
        ],
      ),
    );
  }

  Widget _num(TextEditingController c, String label) => TextField(
        controller: c,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(labelText: label),
      );
}

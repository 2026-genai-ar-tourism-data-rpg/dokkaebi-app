// ============================================================
// [v1] 화면: 가고 싶은 장소 (탐험 마법사 STEP 1/3)
// pipeline: 모바일 클라이언트 / 화면 (나만의 코스 만들기 1단계)
// 구현(요약): 장소 검색(자동완성) + 취향 태그 선택 + 건너뛰기.
//            ⚠️ "지도에서 선택하기"는 실제 지도 SDK 미구현 — 탭하면 준비중 안내만.
// 구현일: 2026-08-05 | 작성: Claude · 시안: dokkaebi-ai/docs/images/04-wishlist.png
// ============================================================
import 'dart:async';

import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../models/explore_draft.dart';
import '../models/scenario.dart';
import '../theme.dart';
import '../widgets/ui.dart';
import 'explore_conditions_screen.dart';

class ExplorePlaceScreen extends StatefulWidget {
  const ExplorePlaceScreen({super.key});
  @override
  State<ExplorePlaceScreen> createState() => _ExplorePlaceScreenState();
}

class _ExplorePlaceScreenState extends State<ExplorePlaceScreen> {
  final _draft = ExploreDraft();
  final _api = ApiClient();
  final _search = TextEditingController();
  Timer? _debounce;

  bool _searching = false;
  bool _searched = false;
  String? _searchError;
  List<SearchCandidate> _results = [];

  static const _tagOptions = ['고궁', '역사', '한옥', '전통문화', '카페', '맛집', '한적한 곳', '사진 명소'];

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

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
    if (!_draft.places.any((s) => s.contentId == c.contentId)) {
      setState(() => _draft.places.add(c));
    }
    setState(() {
      _results = [];
      _searched = false;
      _search.clear();
    });
  }

  void _onMapSelectTap() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('지도에서 선택하기는 준비 중입니다 — 장소 검색을 이용해 주세요.')),
    );
  }

  Future<void> _skip() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('장소 입력을 건너뛸까요?'),
        content: const Text('현재 위치와 여행 조건을 기반으로 시스템 추천 코스를 만들어요.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('건너뛰기')),
        ],
      ),
    );
    if (ok == true) _next();
  }

  void _next() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ExploreConditionsScreen(draft: _draft)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('가고 싶은 장소')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                children: [
                  const Text('어디를 꼭 가보고 싶나요?',
                      style: TextStyle(
                          color: AppColors.textPrimary, fontSize: 22, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  const Text('선택한 장소 주변의 숨은 명소와 도깨비 이야기를 연결해 드려요.',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.4)),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _search,
                    onChanged: _onSearchChanged,
                    decoration: InputDecoration(
                      hintText: '장소 검색',
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
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: _onMapSelectTap,
                    icon: const Icon(Icons.map_outlined, size: 18),
                    label: const Text('지도에서 선택하기'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                      side: const BorderSide(color: AppColors.border),
                    ),
                  ),
                  if (_searchError != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(_searchError!, style: const TextStyle(color: Colors.red)),
                    ),
                  if (_searched && _results.isEmpty && _searchError == null)
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Text('검색 결과 없음', style: TextStyle(color: AppColors.textMuted)),
                    ),
                  ..._results.map((c) => Card(
                        margin: const EdgeInsets.only(top: 6),
                        color: AppColors.surface,
                        elevation: 0,
                        shape: dokkaebiCardShape,
                        child: ListTile(
                          dense: true,
                          leading: const Icon(Icons.place_outlined),
                          title: Text(c.name ?? c.contentId),
                          subtitle: Text(c.addr ?? ''),
                          trailing: const Icon(Icons.add_circle_outline),
                          onTap: () => _pick(c),
                        ),
                      )),
                  const SizedBox(height: 20),
                  const Text('선택한 장소',
                      style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  if (_draft.places.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.border),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text('장소를 검색하거나 지도에서 선택해 주세요',
                          style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
                    )
                  else
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: _draft.places
                          .map((c) => Chip(
                                label: Text(c.name ?? c.contentId),
                                onDeleted: () => setState(() => _draft.places.remove(c)),
                              ))
                          .toList(),
                    ),
                  const SizedBox(height: 20),
                  const Text('추천 취향',
                      style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _tagOptions
                        .map((t) => Pill('#$t',
                            active: _draft.tags.contains(t),
                            onTap: () => setState(() =>
                                _draft.tags.contains(t) ? _draft.tags.remove(t) : _draft.tags.add(t))))
                        .toList(),
                  ),
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      onPressed: _skip,
                      child: const Text('건너뛰기', style: TextStyle(color: AppColors.textSecondary)),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
              child: Align(
                alignment: Alignment.centerRight,
                child: Text('STEP 1 / 3',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: FilledButton(onPressed: _next, child: const Text('다음')),
            ),
          ],
        ),
      ),
    );
  }
}

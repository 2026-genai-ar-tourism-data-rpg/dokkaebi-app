// ============================================================
// [v1] 빛 순서 기억하기 — 코스 진행 화면 '수집' 단계(S1·S6)의 2D 미니게임.
// pipeline: 모바일 클라이언트 / 게임 (미니게임)
// 구현(요약): 조각 N개가 둥글게 놓이고 차례로 빛난다. 같은 순서로 누르면 성공(onCleared).
//            틀리면 벌칙 없이 같은 순서를 다시 보여 준다. 빛나는 동안의 탭은 무시.
//            전엔 떠 있는 조각을 탭만 하면 끝나, AR 엽전 줍기와 같은 '모으기'로 보였다.
// 구현일: 2026-09-18
// ============================================================
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../theme.dart';
import 'memory_stone_restore.dart' show kMemoryFragmentAsset;

/// 조각 수 범위 — 2개 이하는 순서랄 게 없고, 7개 이상은 한 화면에서 외우기 버겁다.
const int kSequenceMin = 3;
const int kSequenceMax = 6;

const Duration _startDelay = Duration(milliseconds: 700);
const Duration _litDuration = Duration(milliseconds: 600);
const Duration _gapDuration = Duration(milliseconds: 250);
const Duration _tapFlash = Duration(milliseconds: 250);
const Duration _wrongPause = Duration(milliseconds: 1100);

const double _boardSize = 280;
const double _ringRadius = 100;
const double _tileSize = 72;
const Color _glow = Color(0xFFE8C268);

enum _Phase { watch, input, wrong, cleared }

class MemorySequenceGame extends StatefulWidget {
  /// AI가 준 개수(tap 원자) — kSequenceMin~kSequenceMax로 맞춘다.
  final int count;
  final VoidCallback onCleared;

  /// 테스트용 고정 순서(조각 번호 목록). null이면 무작위 순서.
  @visibleForTesting
  final List<int>? sequence;

  const MemorySequenceGame({super.key, required this.count, required this.onCleared, this.sequence});

  @override
  State<MemorySequenceGame> createState() => _MemorySequenceGameState();
}

class _MemorySequenceGameState extends State<MemorySequenceGame> {
  late final List<int> _seq;
  _Phase _phase = _Phase.watch;
  int _input = 0; // 지금까지 맞게 누른 수
  int? _lit; // 지금 빛나는 조각
  Timer? _timer;
  Timer? _flashTimer;

  int get _tiles => widget.count.clamp(kSequenceMin, kSequenceMax);

  @override
  void initState() {
    super.initState();
    _seq = widget.sequence ?? (List<int>.generate(_tiles, (i) => i)..shuffle());
    _showSequence();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _flashTimer?.cancel();
    super.dispose();
  }

  /// 다시 보기·틀린 뒤 — 입력을 비우고 순서를 처음부터 다시 보여 준다.
  void _replay() {
    if (!mounted) return;
    setState(() {
      _phase = _Phase.watch;
      _input = 0;
      _lit = null;
    });
    _showSequence();
  }

  /// 조각을 순서대로 하나씩 빛낸 뒤 입력 단계로 넘어간다.
  void _showSequence() {
    _timer?.cancel();
    var step = 0;
    void next() {
      if (!mounted) return;
      if (step >= _seq.length) {
        setState(() {
          _lit = null;
          _phase = _Phase.input;
        });
        return;
      }
      setState(() => _lit = _seq[step]);
      _timer = Timer(_litDuration, () {
        if (!mounted) return;
        setState(() => _lit = null);
        step++;
        _timer = Timer(_gapDuration, next);
      });
    }

    _timer = Timer(_startDelay, next);
  }

  void _tap(int tile) {
    if (_phase != _Phase.input) return;
    if (_seq[_input] != tile) {
      setState(() => _phase = _Phase.wrong);
      _timer = Timer(_wrongPause, _replay);
      return;
    }
    _flashTimer?.cancel();
    setState(() {
      _input++;
      _lit = tile;
      if (_input == _seq.length) _phase = _Phase.cleared;
    });
    _flashTimer = Timer(_tapFlash, () {
      if (mounted) setState(() => _lit = null);
    });
    if (_phase == _Phase.cleared) widget.onCleared();
  }

  String get _status => switch (_phase) {
        _Phase.watch => '빛나는 순서를 기억하거라…',
        _Phase.input => '같은 순서로 눌러 보거라 ($_input/${_seq.length})',
        _Phase.wrong => '순서가 어긋났느니라 — 다시 보거라',
        _Phase.cleared => '기억이 되살아났느니라!',
      };

  @override
  Widget build(BuildContext context) {
    final n = _tiles;
    return Column(mainAxisSize: MainAxisSize.min, children: [
      SizedBox(
        width: _boardSize,
        height: _boardSize,
        child: Stack(alignment: Alignment.center, children: [
          for (var i = 0; i < n; i++)
            Transform.translate(
              offset: Offset.fromDirection(2 * math.pi * i / n - math.pi / 2, _ringRadius),
              child: _tile(i),
            ),
        ]),
      ),
      const SizedBox(height: 8),
      Text(_status,
          textAlign: TextAlign.center,
          style: dokkaebiTitle(size: 14, color: _phase == _Phase.wrong ? const Color(0xFFE59A7A) : const Color(0xFFE8DCC4))),
      const SizedBox(height: 6),
      // 입력 중에만 — 순서를 다시 볼 수 있다(처음부터 다시 누른다).
      Opacity(
        opacity: _phase == _Phase.input ? 1 : 0,
        child: IgnorePointer(
          ignoring: _phase != _Phase.input,
          child: TextButton(
            onPressed: _replay,
            child: const Text('다시 보기', style: TextStyle(color: Color(0xFFB3A892))),
          ),
        ),
      ),
    ]);
  }

  Widget _tile(int i) {
    final lit = _lit == i;
    return GestureDetector(
      key: ValueKey('seq-tile-$i'),
      onTap: () => _tap(i),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: _tileSize,
        height: _tileSize,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: lit ? [BoxShadow(color: _glow.withValues(alpha: 0.85), blurRadius: 28, spreadRadius: 6)] : null,
        ),
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 150),
          opacity: lit ? 1 : 0.45,
          child: AnimatedScale(
            duration: const Duration(milliseconds: 150),
            scale: lit ? 1.18 : 1,
            child: Image.asset(kMemoryFragmentAsset),
          ),
        ),
      ),
    );
  }
}

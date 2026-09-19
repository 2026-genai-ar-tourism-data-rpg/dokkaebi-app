// ============================================================
// [v1] 도깨비불 길들이기 상태기계 테스트 — 가짜 시계·각도를 주입해 3회 수집을 끝까지 돈다.
// 구현일: 2026-09-19 | 작성: kys (fire-capture/kys/v1)
// ============================================================
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';

import 'package:dokkaebi_app/game/fire_capture_controller.dart';

/// 수동으로 흐르는 시계.
class _Clock {
  DateTime t = DateTime(2026, 9, 19, 12);
  DateTime now() => t;
  void add(int ms) => t = t.add(Duration(milliseconds: ms));
}

double _deg(double d) => d * math.pi / 180;

FireObservation _aimed({double err = 0, double yaw = 0, bool tracking = true}) =>
    FireObservation(aimErrorRad: _deg(err), yawDeltaRad: _deg(yaw), tracking: tracking);

/// 조준한 채 100ms 간격으로 관측을 넣어 첫 관측(hold 시작)부터 [ms]가 흐르게 한다
/// (네이티브 10Hz와 같은 리듬). 첫 관측이 t=0이므로 관측 수는 ms/100 + 1.
void _holdFor(FireCaptureController c, _Clock k, int ms, {double err = 0}) {
  for (var t = 0; t <= ms; t += 100) {
    k.add(100);
    c.observe(_aimed(err: err));
  }
}

void main() {
  group('정상 플레이', () {
    test('3마리를 각 2초 유지하면 초롱 점등(sync) — 완료 콜백은 정확히 1회', () {
      final k = _Clock();
      final got = <String>[];
      var all = 0;
      final c = FireCaptureController(now: k.now, onCaptured: got.add, onAllCaptured: () => all++);
      expect(c.state, FireState.intro);
      c.start();
      expect(c.state, FireState.seek);
      expect(c.progress.activeId, 'fire_1');

      for (var i = 1; i <= 3; i++) {
        _holdFor(c, k, 2000);
        expect(c.state, FireState.capture, reason: 'fire_$i 수집 직후는 흡수 연출');
        expect(got.last, 'fire_$i');
        k.add(kFireCaptureMs);
        c.tick();
      }
      expect(got, ['fire_1', 'fire_2', 'fire_3']);
      expect(c.state, FireState.sync);
      expect(all, 1);
      expect(c.progress.collected, 3);

      c.markSynced();
      expect(c.state, FireState.done);
      expect(c.progress.status, contains('초롱이 깨어났'));
    });

    test('동시에 1마리만 활성 — 첫 불꽃을 모으기 전엔 활성 목표가 fire_1이고, 모으면 fire_2로 넘어간다', () {
      final k = _Clock();
      final c = FireCaptureController(now: k.now)..start();
      expect(c.activeTarget!.id, 'fire_1');
      _holdFor(c, k, 2000);
      k.add(kFireCaptureMs);
      c.tick();
      expect(c.activeTarget!.id, 'fire_2');
    });

    test('게이지는 실제 경과시간으로 찬다 — 관측 횟수와 무관(10Hz 리듬 안에서)', () {
      final k = _Clock();
      final c = FireCaptureController(now: k.now)..start();
      _holdFor(c, k, 1000);             // hold 시작부터 1000ms
      expect(c.progress.holdRatio, closeTo(0.5, 0.01));
      // 200ms 간격(공백 아님)으로 띄엄띄엄 관측해도 시계 기준으로 찬다
      k.add(200); c.observe(_aimed());
      expect(c.progress.holdRatio, closeTo(0.6, 0.01));
      k.add(50); c.observe(_aimed());
      expect(c.progress.holdRatio, closeTo(0.625, 0.01));
    });
  });

  group('경계·중복', () {
    test('6°를 넘으면 유지 초기화, 다시 들어오면 0부터', () {
      final k = _Clock();
      final c = FireCaptureController(now: k.now)..start();
      _holdFor(c, k, 1500);
      expect(c.progress.holdRatio, greaterThan(0.7));
      k.add(100);
      c.observe(_aimed(err: 7));        // 경계 밖
      expect(c.state, FireState.seek);
      expect(c.progress.holdRatio, 0);
      k.add(100);
      c.observe(_aimed(err: 5.9));      // 다시 안 — 0부터
      expect(c.progress.holdRatio, lessThan(0.1));
      expect(c.progress.collected, 0);
    });

    test('정확히 6°는 유효, 6.01°는 무효', () {
      final k = _Clock();
      final c = FireCaptureController(now: k.now)..start();
      c.observe(_aimed(err: 6.0));
      expect(c.state, FireState.hold);
      k.add(100);
      c.observe(_aimed(err: 6.01));
      expect(c.state, FireState.seek);
    });

    test('수집 완료 프레임에 관측이 반복돼도 한 마리만 증가하고 onCaptured는 1회', () {
      final k = _Clock();
      final got = <String>[];
      final c = FireCaptureController(now: k.now, onCaptured: got.add)..start();
      _holdFor(c, k, 2000);
      // 같은 시각에 관측이 여러 번 더 들어온다(흡수 연출 중)
      c.observe(_aimed());
      c.observe(_aimed());
      c.observe(_aimed());
      expect(got, ['fire_1']);
      expect(c.progress.collected, 1);
      expect(c.state, FireState.capture);
    });

    test('흡수 연출 800ms 동안은 다음 불꽃 판정이 잠긴다', () {
      final k = _Clock();
      final c = FireCaptureController(now: k.now)..start();
      _holdFor(c, k, 2000);
      for (var t = 100; t <= 700; t += 100) {   // 연출 중에도 네이티브는 10Hz로 계속 보낸다
        k.add(100);
        c.observe(_aimed());
        expect(c.state, FireState.capture, reason: '$t ms — 아직 잠금');
      }
      expect(c.progress.collected, 1);
      k.add(100);
      c.observe(_aimed());              // 800ms 지남 → seek 전이 후 이 관측부터 곧바로 hold
      expect(c.state, FireState.hold);
      expect(c.activeTarget!.id, 'fire_2');
    });
  });

  group('추적·화면 전환', () {
    test('관측이 300ms 넘게 끊기면 유지 시간을 버린다', () {
      final k = _Clock();
      final c = FireCaptureController(now: k.now)..start();
      _holdFor(c, k, 1200);
      expect(c.progress.holdRatio, closeTo(0.6, 0.01));
      k.add(400);                       // 공백 400ms
      c.observe(_aimed());
      // 초기화 = 유지 시간을 버리고 이 관측부터 다시 센다(관측을 삼키지 않는다)
      expect(c.state, FireState.hold);
      expect(c.progress.holdRatio, 0);
    });

    test('tracking 불안정이면 누적하지 않고 초기화', () {
      final k = _Clock();
      final c = FireCaptureController(now: k.now)..start();
      _holdFor(c, k, 1000);
      k.add(100);
      c.observe(_aimed(tracking: false));
      expect(c.state, FireState.seek);
      expect(c.progress.holdRatio, 0);
      expect(c.progress.status, contains('멈춰'));
    });

    test('일시정지 중엔 시간이 누적되지 않고, 복귀하면 수집 수는 유지·게이지는 초기화', () {
      final k = _Clock();
      final c = FireCaptureController(now: k.now)..start();
      _holdFor(c, k, 2000);
      k.add(kFireCaptureMs);
      c.tick();                         // fire_1 완료 → seek(fire_2)
      _holdFor(c, k, 1500);             // fire_2 75%
      c.pause();
      expect(c.state, FireState.paused);
      k.add(5000);
      c.observe(_aimed());              // 정지 중 관측은 무시
      expect(c.progress.collected, 1);
      c.resume();
      expect(c.state, FireState.seek);
      expect(c.progress.holdRatio, 0);
      expect(c.progress.collected, 1);
      expect(c.activeTarget!.id, 'fire_2');
    });
  });

  group('복원·기록', () {
    test('저장된 수집 수를 복원해 남은 목표부터 진행한다', () {
      final k = _Clock();
      final c = FireCaptureController(now: k.now, restoredCollected: {'fire_1', 'fire_2'})..start();
      expect(c.progress.collected, 2);
      expect(c.activeTarget!.id, 'fire_3');
      _holdFor(c, k, 2000);
      k.add(kFireCaptureMs);
      c.tick();
      expect(c.state, FireState.sync);
    });

    test('이미 3마리가 복원돼 있으면 start()가 곧장 sync로 가고 완료 콜백 1회', () {
      var all = 0;
      final c = FireCaptureController(
        now: _Clock().now,
        restoredCollected: {'fire_1', 'fire_2', 'fire_3'},
        onAllCaptured: () => all++,
      )..start();
      expect(c.state, FireState.sync);
      expect(all, 1);
    });

    test('기록 실패는 결과를 보존하고 sync에 머문다 — 재시도 후 done', () {
      final k = _Clock();
      final c = FireCaptureController(now: k.now)..start();
      for (var i = 0; i < 3; i++) {
        _holdFor(c, k, 2000);
        k.add(kFireCaptureMs);
        c.tick();
      }
      c.markSyncFailed();
      expect(c.state, FireState.sync);
      expect(c.progress.collected, 3);
      expect(c.progress.status, contains('실패'));
      c.markSynced();
      expect(c.state, FireState.done);
    });

    test('로컬 키는 userId·runId·nodeId·게임 버전을 전부 담는다', () {
      final key = fireProgressKey(userId: 'guest_a', runId: 'run-1', nodeId: 'tour_9');
      expect(key, contains('guest_a'));
      expect(key, contains('run-1'));
      expect(key, contains('tour_9'));
      expect(key, contains(kFireGameVersion));
    });
  });

  group('힌트', () {
    test('목표가 오른쪽이면 오른쪽 힌트, 왼쪽이면 왼쪽, 조준 안이면 center', () {
      final k = _Clock();
      final c = FireCaptureController(now: k.now)..start();
      c.observe(_aimed(err: 30, yaw: 30));
      expect(c.progress.hint, FireHint.right);
      expect(c.progress.status, contains('오른쪽'));
      k.add(100);
      c.observe(_aimed(err: 30, yaw: -30));
      expect(c.progress.hint, FireHint.left);
      k.add(100);
      c.observe(_aimed(err: 2, yaw: 2));
      expect(c.progress.hint, FireHint.center);
    });

    test('8초간 진전이 없으면 stalled', () {
      final k = _Clock();
      final c = FireCaptureController(now: k.now)..start();
      expect(c.progress.stalled, isFalse);
      for (var t = 0; t < 8100; t += 100) {
        k.add(100);
        c.observe(_aimed(err: 40, yaw: 40));
      }
      expect(c.progress.stalled, isTrue);
      // 하나 모으면 다시 false
      _holdFor(c, k, 2000);
      expect(c.progress.stalled, isFalse);
    });

    test('기본 배치는 3개, +32° -26° +12°', () {
      final t = FireTarget.defaults();
      expect(t.map((e) => e.id), ['fire_1', 'fire_2', 'fire_3']);
      expect(t[0].yawRad, closeTo(_deg(32), 1e-9));
      expect(t[1].yawRad, closeTo(_deg(-26), 1e-9));
      expect(t[2].yawRad, closeTo(_deg(12), 1e-9));
    });
  });
}

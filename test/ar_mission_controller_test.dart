// ============================================================
// [v1] AR 미션 상태기계 테스트 — 실기기 없이 판정 로직을 검증한다.
// pipeline: 모바일 클라이언트 / 테스트
// 구현(요약): ARKit은 시뮬레이터에서 안 도니, 네이티브가 보내올 거리·조준각을
//            직접 만들어 먹여서 상태기계만 따로 검증한다. 실기기에서 확인해야 하는
//            것은 "숫자가 그럴듯한가"(튜닝)이지 "로직이 맞는가"가 아니게 만드는 것.
// 구현일: 2026-09-16 | 작성: kys (ar-realtime/kys/v1)
// ------------------------------------------------------------
// [v2] HUNT를 엽전 줍기로 — 반짝임·탭·바로 앞 자동 줍기·배치(그림) 테스트.
// 구현일: 2026-09-18 | 작성: ljs (npc-character-set/ljs/v1)
// ============================================================
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dokkaebi_app/game/ar_mission_controller.dart';
import 'package:dokkaebi_app/widgets/native_ar_view.dart';

ArMarkerDef _m(String id, {ArMarkerKind kind = ArMarkerKind.beacon}) =>
    ArMarkerDef(id: id, label: id, color: const Color(0xFF2E7E76), kind: kind);

/// 거리·조준각을 한 번에 먹이는 헬퍼. aim 기본값은 정면(0).
Map<String, ArMarkerReading> _read(Map<String, double> dists, {double aim = 0}) =>
    dists.map((k, d) => MapEntry(k, ArMarkerReading(distance: d, aimError: aim)));

void main() {
  group('미션 타입 매핑', () {
    test('AI가 내는 8종이 전부 네 연출 중 하나로 떨어진다', () {
      expect(arMissionTypeOf('HUNT'), ArMissionType.hunt);
      expect(arMissionTypeOf('RESTORE_AR'), ArMissionType.restore);
      expect(arMissionTypeOf('PHOTO_FIND'), ArMissionType.photo);
      expect(arMissionTypeOf('PATH_TRACE'), ArMissionType.photo);
      expect(arMissionTypeOf('FIND'), ArMissionType.find);
      expect(arMissionTypeOf('QUIZ_FIND'), ArMissionType.find);
      expect(arMissionTypeOf('DIALOGUE_FIND'), ArMissionType.find);
      // 모르는 타입·null도 화면이 비지 않게 HUNT로 떨어진다.
      expect(arMissionTypeOf('COLLECT'), ArMissionType.hunt);
      expect(arMissionTypeOf(null), ArMissionType.hunt);
    });
  });

  group('HUNT — 도깨비가 흘린 엽전을 줍는다', () {
    test('멀면 기척만, 가까우면 반짝이고, 바로 앞까지 가면 줍는다', () {
      final c = ArMissionController(
        type: ArMissionType.hunt,
        markers: [_m('f1'), _m('f2'), _m('f3')],
      );

      c.onTelemetry(_read({'f1': 20, 'f2': 22, 'f3': 24}));
      expect(c.progress.done, 0);
      expect(c.progress.status, contains('기척이 희미'));

      // f1은 반짝이는 거리지만 아직 줍지 않았다.
      c.onTelemetry(_read({'f1': 1.5, 'f2': 4.0, 'f3': 5.5}));
      expect(c.progress.done, 0);
      expect(c.progress.status, contains('주워 보거라'));

      // 바로 앞까지 가면 줍는다.
      c.onTelemetry(_read({'f1': 1.0, 'f2': 4.0, 'f3': 5.5}));
      expect(c.progress.done, 1);
      expect(c.progress.status, contains('1/3'));
      expect(c.progress.complete, isFalse);
    });

    test('반짝이는 엽전은 탭으로 줍고, 흐릿한 엽전은 탭해도 안 줍힌다', () {
      final got = <String>[];
      final c = ArMissionController(
        type: ArMissionType.hunt,
        markers: [_m('f1'), _m('f2')],
        onCollected: got.add,
      );
      c.onTelemetry(_read({'f1': 2.0, 'f2': 5.0})); // f1 반짝, f2 흐릿

      c.onTapped('f2');
      expect(got, isEmpty, reason: '멀리서 탭해 건너뛰지 못한다');
      expect(c.progress.status, contains('더 가까이'));

      c.onTapped('f1');
      expect(got, ['f1']);
      c.onTapped('f1');
      expect(got, ['f1'], reason: '같은 엽전을 두 번 세지 않는다');
    });

    test('가까운 엽전일수록 크게 보인다(원근)', () {
      expect(coinScaleFor(kCoinPickM), closeTo(kCoinScaleNear, 1e-9));
      expect(coinScaleFor(kTrailWakeM), closeTo(kCoinScaleFar, 1e-9));
      expect(coinScaleFor(2.0), greaterThan(coinScaleFor(4.0)));
      expect(coinScaleFor(4.0), greaterThan(coinScaleFor(5.5)));
    });

    test('범위 밖 거리는 양 끝 크기로 묶인다', () {
      expect(coinScaleFor(30), kCoinScaleFar, reason: '아주 멀어도 더 작아지지 않는다');
      expect(coinScaleFor(0), kCoinScaleNear, reason: '코앞이어도 더 커지지 않는다');
    });

    test('엽전은 바닥 배치에 그림이 붙고, 그 그림 파일이 등록돼 있다', () {
      final markers = buildArMarkers(
          type: ArMissionType.hunt, primary: const Color(0xFF2E7E76), accent: const Color(0xFF6B4FA0), count: 3);
      expect(markers, hasLength(3));
      for (final m in markers) {
        expect(m.kind, ArMarkerKind.coin);
        expect(m.toMap()['image'], kCoinImageAsset);
      }
      expect(File(kCoinImageAsset).existsSync(), isTrue);
      expect(File('pubspec.yaml').readAsStringSync(), contains('- assets/game/ar/'));
    });

    test('전부 가까워지면 미션이 끝난다', () {
      var completed = false;
      final c = ArMissionController(
        type: ArMissionType.hunt,
        markers: [_m('f1'), _m('f2')],
        onComplete: () => completed = true,
      );
      c.onTelemetry(_read({'f1': 1.0, 'f2': 1.2}));
      expect(completed, isTrue);
      expect(c.progress.complete, isTrue);
    });

    test('가장 가까운 거리를 HUD용으로 노출한다', () {
      final c = ArMissionController(type: ArMissionType.hunt, markers: [_m('a'), _m('b')]);
      c.onTelemetry(_read({'a': 9.0, 'b': 3.5}));
      expect(c.progress.nearestM, 3.5);
    });
  });

  group('RESTORE_AR — 부재까지 걸어가야 줍힌다', () {
    test('멀면 안 줍히고, 팔 닿는 거리에서 수집된다', () {
      final got = <String>[];
      final c = ArMissionController(
        type: ArMissionType.restore,
        markers: [_m('p1', kind: ArMarkerKind.part), _m('p2', kind: ArMarkerKind.part)],
        onCollected: got.add,
      );

      c.onTelemetry(_read({'p1': 3.0, 'p2': 4.0}));
      expect(got, isEmpty);
      expect(c.progress.status, contains('2점'));

      c.onTelemetry(_read({'p1': 0.9, 'p2': 4.0}));
      expect(got, ['p1']);
      expect(c.progress.status, contains('1점'));

      c.onTelemetry(_read({'p1': 0.9, 'p2': 1.0}));
      expect(got, ['p1', 'p2']);
      expect(c.progress.complete, isTrue);
    });

    test('같은 부재를 두 번 세지 않는다', () {
      final got = <String>[];
      final c = ArMissionController(
        type: ArMissionType.restore,
        markers: [_m('p1'), _m('p2')],
        onCollected: got.add,
      );
      c.onTelemetry(_read({'p1': 0.5, 'p2': 9}));
      c.onTelemetry(_read({'p1': 0.5, 'p2': 9}));
      c.onTelemetry(_read({'p1': 0.5, 'p2': 9}));
      expect(got, ['p1']);
    });
  });

  group('PHOTO_FIND — 가까이서 정면으로 머물러야 스캔된다', () {
    test('멀면 진행률이 0이다', () {
      final c = ArMissionController(
        type: ArMissionType.photo,
        markers: [_m('t', kind: ArMarkerKind.pattern)],
      );
      c.onTelemetry(_read({'t': 8.0}));
      expect(c.progress.ratio, 0);
      expect(c.progress.status, contains('멀어'));
    });

    test('가까워도 조준이 빗나가면 진행률이 0이다', () {
      final c = ArMissionController(type: ArMissionType.photo, markers: [_m('t')]);
      c.onTelemetry(_read({'t': 1.5}, aim: 1.2)); // 약 69° — 화면 밖
      expect(c.progress.ratio, 0);
      expect(c.progress.status, contains('한가운데'));
    });

    test('가까이서 정면으로 머물면 진행률이 오르고 결국 완료된다', () async {
      var completed = false;
      final c = ArMissionController(
        type: ArMissionType.photo,
        markers: [_m('t')],
        onComplete: () => completed = true,
      );
      c.onTelemetry(_read({'t': 1.2})); // 조준 시작 시각이 여기서 찍힌다
      expect(c.progress.ratio, lessThan(0.2));

      // 최근접(1.2m)이면 2배속 → kScanHoldSec(2.5s)의 절반인 1.25초면 찬다.
      await Future<void>.delayed(const Duration(milliseconds: 1400));
      c.onTelemetry(_read({'t': 1.2}));
      expect(c.progress.ratio, 1.0);
      expect(completed, isTrue);
    });

    test('중간에 조준이 풀리면 진행률이 리셋된다', () async {
      final c = ArMissionController(type: ArMissionType.photo, markers: [_m('t')]);
      c.onTelemetry(_read({'t': 2.0}));
      await Future<void>.delayed(const Duration(milliseconds: 300));
      c.onTelemetry(_read({'t': 2.0}));
      expect(c.progress.ratio, greaterThan(0));

      c.onTelemetry(_read({'t': 2.0}, aim: 1.0)); // 시선을 돌림
      expect(c.progress.ratio, 0);
    });
  });

  group('FIND — 풀이 흔들리고, 겨누고 머물면 드러난다', () {
    test('아주 멀면 기척조차 없다', () {
      final c = ArMissionController(
        type: ArMissionType.find,
        markers: [_m('g', kind: ArMarkerKind.hidden)],
      );
      c.onTelemetry(_read({'g': 20}));
      expect(c.progress.status, contains('아무 기척'));
      expect(c.progress.done, 0);
    });

    test('기척 구간에선 다가가라고 하고, 아직 드러나지 않는다', () {
      final c = ArMissionController(type: ArMissionType.find, markers: [_m('g')]);
      c.onTelemetry(_read({'g': 6.0}));
      expect(c.progress.status, contains('흔들린다'));
      expect(c.progress.done, 0);
    });

    test('가까이서 겨누고 머물면 드러난다', () async {
      final got = <String>[];
      final c = ArMissionController(
        type: ArMissionType.find,
        markers: [_m('g')],
        onCollected: got.add,
      );
      c.onTelemetry(_read({'g': 2.0}));
      expect(got, isEmpty);

      await Future<void>.delayed(const Duration(milliseconds: 1900));
      c.onTelemetry(_read({'g': 2.0}));
      expect(got, ['g']);
      expect(c.progress.complete, isTrue);
    });

    test('가까워도 시선을 돌리면 드러나지 않는다', () async {
      final c = ArMissionController(type: ArMissionType.find, markers: [_m('g')]);
      c.onTelemetry(_read({'g': 2.0}, aim: 0.9));
      await Future<void>.delayed(const Duration(milliseconds: 1900));
      c.onTelemetry(_read({'g': 2.0}, aim: 0.9));
      expect(c.progress.done, 0);
      expect(c.progress.status, contains('응시'));
    });
  });

  group('참조 이미지 인식(Augmented Images)', () {
    test('PHOTO_FIND는 인식 한 번으로 찾기 단계가 끝난다', () {
      var completed = false;
      final got = <String>[];
      final c = ArMissionController(
        type: ArMissionType.photo,
        markers: [_m('pattern', kind: ArMarkerKind.pattern)],
        onCollected: got.add,
        onComplete: () => completed = true,
      );
      c.onTelemetry(_read({'pattern': 9.0}));       // 멀어서 스캔은 0
      expect(c.progress.ratio, 0);
      c.onImageDetected('ref0|https://tong…/안내판.jpg');
      expect(c.progress.imageDetected, isTrue);
      expect(c.progress.ratio, 1.0);
      expect(got, ['pattern']);
      expect(completed, isTrue);
      expect(c.progress.status, contains('담아'));
    });

    test('두 번 인식돼도 한 번만 처리한다', () {
      var completes = 0;
      final c = ArMissionController(type: ArMissionType.photo, markers: [_m('p')], onComplete: () => completes++);
      c.onImageDetected('a');
      c.onImageDetected('a');
      expect(completes, 1);
    });

    test('다른 미션 타입은 인식 이벤트를 무시한다', () {
      final c = ArMissionController(type: ArMissionType.hunt, markers: [_m('f1'), _m('f2')]);
      c.onImageDetected('x');
      expect(c.progress.imageDetected, isFalse);
      expect(c.progress.done, 0);
    });
  });

  group('공통 동작', () {
    test('완료된 뒤 들어오는 텔레메트리는 무시한다', () {
      var completes = 0;
      final c = ArMissionController(
        type: ArMissionType.hunt,
        markers: [_m('f1')],
        onComplete: () => completes++,
      );
      c.onTelemetry(_read({'f1': 1.0}));
      c.onTelemetry(_read({'f1': 1.0}));
      c.onTelemetry(_read({'f1': 1.0}));
      expect(completes, 1);
    });

    test('빈 텔레메트리로는 아무 일도 일어나지 않는다', () {
      final c = ArMissionController(type: ArMissionType.hunt, markers: [_m('f1')]);
      c.onTelemetry(const {});
      expect(c.progress.done, 0);
      expect(c.progress.complete, isFalse);
    });

    test('마커가 없는 미션이 완료로 오인되지 않는다', () {
      var completed = false;
      final c = ArMissionController(
        type: ArMissionType.hunt,
        markers: const [],
        onComplete: () => completed = true,
      );
      c.onTelemetry(_read({'없는놈': 1.0}));
      expect(completed, isFalse);
    });

    test('탭 수집은 RESTORE·HUNT에서만 동작한다', () {
      final gotFind = <String>[];
      final find = ArMissionController(
        type: ArMissionType.find,
        markers: [_m('g')],
        onCollected: gotFind.add,
      );
      find.onTapped('g');
      expect(gotFind, isEmpty, reason: 'FIND는 겨눠서 드러내야 한다 — 탭으로 건너뛸 수 없다');

      final gotPart = <String>[];
      final restore = ArMissionController(
        type: ArMissionType.restore,
        markers: [_m('p')],
        onCollected: gotPart.add,
      );
      restore.onTapped('p');
      expect(gotPart, ['p']);
    });
  });
}

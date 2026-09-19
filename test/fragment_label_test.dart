// ============================================================
// [v1] 기억석 조각 표시 이름 — AI 식별자('관악구_stone_1of5') 대신 '첫째 조각 · 자매공원'.
// pipeline: 모바일 클라이언트 / 테스트
// 구현일: 2026-09-19
// ============================================================
import 'package:dokkaebi_app/models/scenario.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _node(String id, String name, int no, {String? fragmentId, bool finale = false}) => {
      'node_id': id,
      'name': name,
      'kind': 'spot',
      'fragment_id': fragmentId ?? '관악구_stone_${no}of3',
      'stone_no': no,
      'grants': const [],
      'requires': const [],
      'requires_mode': 'none',
      'is_finale': finale,
    };

void main() {
  group('fragmentDisplayName', () {
    test('순서와 장소로 짓는다', () {
      expect(fragmentDisplayName(1, '자매공원', fallback: 'x'), '첫째 조각 · 자매공원');
      expect(fragmentDisplayName(5, '관악산', fallback: 'x'), '다섯째 조각 · 관악산');
      expect(fragmentDisplayName(13, '먼 곳', fallback: 'x'), '13번째 조각 · 먼 곳', reason: '열두째 너머는 숫자');
    });

    test('순서나 장소가 없으면 있는 것만, 둘 다 없으면 식별자', () {
      expect(fragmentDisplayName(null, '자매공원', fallback: 'x'), '기억석 조각 · 자매공원');
      expect(fragmentDisplayName(2, null, fallback: 'x'), '둘째 조각');
      expect(fragmentDisplayName(null, '', fallback: '관악구_stone_1of5'), '관악구_stone_1of5');
    });
  });

  group('Scenario.fragmentLabel', () {
    final sc = Scenario.fromJson({
      'scenario_id': 's',
      'title': '관악구의 기억석',
      'region': '관악구',
      'node_sequence': [
        _node('m1', '자매공원', 1),
        _node('m2', '노들나루공원', 2),
        // 갈림길 대체 장소 — 본선 m2와 같은 조각을 준다
        _node('b1', '사육신공원', 2, fragmentId: '관악구_stone_2of3'),
        _node('m3', '관악산', 3, finale: true),
      ],
    });

    test('조각을 준 장소와 순서로 부른다', () {
      expect(sc.fragmentLabel('관악구_stone_1of3'), '첫째 조각 · 자매공원');
      expect(sc.fragmentLabel('관악구_stone_3of3'), '셋째 조각 · 관악산');
    });

    test('갈림길로 다녀왔으면 실제로 간 장소 이름, 모르는 조각은 식별자 그대로', () {
      expect(sc.fragmentLabel('관악구_stone_2of3', played: {'m1', 'b1'}), '둘째 조각 · 사육신공원');
      expect(sc.fragmentLabel('관악구_stone_2of3'), '둘째 조각 · 노들나루공원');
      expect(sc.fragmentLabel('글씨조각1'), '글씨조각1');
    });
  });
}

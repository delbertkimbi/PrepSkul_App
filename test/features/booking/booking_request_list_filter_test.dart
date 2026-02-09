import 'package:flutter_test/flutter_test.dart';

/// Unit tests for My Requests list filtering: cancelled (and optionally rejected) excluded.
void main() {
  group('Booking request list filter', () {
    test('cancelled requests are excluded from active list', () {
      final requests = [
        {'id': '1', 'status': 'pending'},
        {'id': '2', 'status': 'approved'},
        {'id': '3', 'status': 'cancelled'},
        {'id': '4', 'status': 'pending'},
      ];
      final active = requests.where((r) => r['status'] != 'cancelled').toList();
      expect(active.length, 3);
      expect(active.map((r) => r['id']).toList(), ['1', '2', '4']);
    });

    test('empty list when all are cancelled', () {
      final requests = [
        {'id': '1', 'status': 'cancelled'},
        {'id': '2', 'status': 'cancelled'},
      ];
      final active = requests.where((r) => r['status'] != 'cancelled').toList();
      expect(active, isEmpty);
    });

    test('rejected can be included (only cancelled excluded)', () {
      final requests = [
        {'id': '1', 'status': 'rejected'},
        {'id': '2', 'status': 'cancelled'},
      ];
      final active = requests.where((r) => r['status'] != 'cancelled').toList();
      expect(active.length, 1);
      expect(active.first['status'], 'rejected');
    });

    test('scheduled and in_progress tutor requests stay', () {
      final statuses = ['pending', 'in_progress', 'scheduled', 'approved'];
      final filtered = statuses.where((s) => s != 'cancelled').toList();
      expect(filtered, equals(['pending', 'in_progress', 'scheduled', 'approved']));
    });
  });
}

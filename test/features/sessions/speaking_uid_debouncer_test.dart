import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prepskul/features/sessions/domain/speaking_uid_debouncer.dart';

void main() {
  group('SpeakingUidDebouncer', () {
    test('emits once when multiple uids start in the same sample', () {
      final d = SpeakingUidDebouncer();
      var calls = 0;
      d.applyRaw({1, 2, 3}, (_) {
        calls++;
      });
      expect(calls, 1);
    });

    test('holds speaking state until release delay after last positive sample', () {
      fakeAsync((async) {
        final d = SpeakingUidDebouncer(
          releaseDelay: const Duration(milliseconds: 300),
        );
        final sets = <Set<int>>[];
        d.applyRaw({1}, (s) => sets.add(Set<int>.from(s)));
        expect(sets, [{1}]);

        d.applyRaw(<int>{}, (s) => sets.add(Set<int>.from(s)));
        expect(sets.length, 1);

        async.elapse(const Duration(milliseconds: 299));
        expect(sets.length, 1);
        async.elapse(const Duration(milliseconds: 2));
        expect(sets.length, 2);
        expect(sets.last, isEmpty);
      });
    });

    test('reset clears pending timers', () {
      fakeAsync((async) {
        final d = SpeakingUidDebouncer(
          releaseDelay: const Duration(milliseconds: 300),
        );
        var calls = 0;
        d.applyRaw({1}, (_) => calls++);
        d.applyRaw(<int>{}, (_) {});
        d.reset();
        async.elapse(const Duration(seconds: 1));
        expect(calls, 1);
      });
    });
  });
}

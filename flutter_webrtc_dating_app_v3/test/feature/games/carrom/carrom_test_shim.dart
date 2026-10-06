// ignore_for_file: avoid_print
// Minimal stand-in for flutter_test so the pure-Dart Carrom tests also run with
// `dart run test/feature/games/carrom/<file>.dart` (where `flutter test` can't
// run). Test files pick it via a conditional import; under `flutter test` the
// real package:flutter_test is used instead.
import 'dart:async';
import 'dart:io' show exitCode;

int _passed = 0;
int _failed = 0;
bool _summaryScheduled = false;
final List<String> _groups = [];

void group(String description, void Function() body) {
  _groups.add(description);
  try {
    body();
  } finally {
    _groups.removeLast();
  }
}

void test(String description, dynamic Function() body) {
  if (!_summaryScheduled) {
    _summaryScheduled = true;
    Timer.run(() {
      print('\n$_passed passed, $_failed failed');
      if (_failed > 0) exitCode = 1;
    });
  }
  final name = [..._groups, description].join(' ');
  try {
    final r = body();
    if (r is Future) {
      throw StateError('async tests are not supported by the shim');
    }
    _passed++;
    print('ok   $name');
  } catch (e) {
    _failed++;
    print('FAIL $name\n     $e');
  }
}

class TestFailure implements Exception {
  TestFailure(this.message);
  final String message;
  @override
  String toString() => message;
}

abstract class Matcher {
  const Matcher();
  bool matches(dynamic item);
  String get description;
}

class _Fn extends Matcher {
  const _Fn(this.description, this.test);
  @override
  final String description;
  final bool Function(dynamic) test;
  @override
  bool matches(dynamic item) => test(item);
}

bool _deepEquals(dynamic a, dynamic b) {
  if (a is List && b is List) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (!_deepEquals(a[i], b[i])) return false;
    }
    return true;
  }
  if (a is Map && b is Map) {
    if (a.length != b.length) return false;
    for (final k in a.keys) {
      if (!b.containsKey(k) || !_deepEquals(a[k], b[k])) return false;
    }
    return true;
  }
  if (a is Set && b is Set) {
    return a.length == b.length && a.containsAll(b);
  }
  return a == b;
}

Matcher equals(dynamic expected) =>
    _Fn('equals $expected', (v) => _deepEquals(v, expected));
Matcher greaterThan(num n) => _Fn('> $n', (v) => (v as num) > n);
Matcher greaterThanOrEqualTo(num n) => _Fn('>= $n', (v) => (v as num) >= n);
Matcher lessThan(num n) => _Fn('< $n', (v) => (v as num) < n);
Matcher lessThanOrEqualTo(num n) => _Fn('<= $n', (v) => (v as num) <= n);
Matcher closeTo(num value, num delta) =>
    _Fn('$value ± $delta', (v) => ((v as num) - value).abs() <= delta);
Matcher contains(dynamic item) =>
    _Fn('contains $item', (v) => (v as dynamic).contains(item) as bool);
Matcher hasLength(int n) =>
    _Fn('length $n', (v) => ((v as dynamic).length as int) == n);
Matcher isNot(dynamic m) {
  final inner = _wrap(m);
  return _Fn('not ${inner.description}', (v) => !inner.matches(v));
}

const Matcher isTrue = _Fn('true', _isTrue);
const Matcher isFalse = _Fn('false', _isFalse);
const Matcher isNull = _Fn('null', _isNull);
const Matcher isNotNull = _Fn('not null', _isNotNull);
const Matcher isEmpty = _Fn('empty', _isEmpty);
const Matcher isNotEmpty = _Fn('not empty', _isNotEmpty);

bool _isTrue(dynamic v) => v == true;
bool _isFalse(dynamic v) => v == false;
bool _isNull(dynamic v) => v == null;
bool _isNotNull(dynamic v) => v != null;
bool _isEmpty(dynamic v) => (v as dynamic).isEmpty as bool;
bool _isNotEmpty(dynamic v) => (v as dynamic).isNotEmpty as bool;

Matcher _wrap(dynamic m) => m is Matcher ? m : equals(m);

void expect(dynamic actual, dynamic matcher, {String? reason}) {
  final m = _wrap(matcher);
  if (m.matches(actual)) return;
  throw TestFailure(
    'Expected: ${m.description}\n     Actual: $actual'
    '${reason == null ? '' : '\n     Reason: $reason'}',
  );
}

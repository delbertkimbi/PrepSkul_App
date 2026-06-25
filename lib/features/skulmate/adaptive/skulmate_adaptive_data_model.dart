import 'package:flutter/foundation.dart';

/// Observable store for adaptive UI state (mirrors genui [DataModel]).
class SkulMateAdaptiveDataModel extends ChangeNotifier {
  final Map<String, Object?> _values = {};

  Object? get(String path) => _values[path];

  String? getString(String path) => _values[path]?.toString();

  bool getBool(String path, {bool fallback = false}) {
    final v = _values[path];
    if (v is bool) return v;
    if (v == 'true') return true;
    if (v == 'false') return false;
    return fallback;
  }

  void set(String path, Object? value) {
    if (_values[path] == value) return;
    _values[path] = value;
    notifyListeners();
  }

  void applyAll(Map<String, Object?> data) {
    var changed = false;
    for (final entry in data.entries) {
      if (_values[entry.key] != entry.value) {
        _values[entry.key] = entry.value;
        changed = true;
      }
    }
    if (changed) notifyListeners();
  }

  void clear() {
    if (_values.isEmpty) return;
    _values.clear();
    notifyListeners();
  }
}

import 'package:flutter/foundation.dart';

import 'skulmate_adaptive_data_model.dart';
import 'skulmate_adaptive_types.dart';

/// Manages adaptive surfaces and reactive data (genui [SurfaceController] analogue).
class SkulMateAdaptiveSurfaceController extends ChangeNotifier {
  final SkulMateAdaptiveDataModel dataModel = SkulMateAdaptiveDataModel();
  final Map<String, SkulMateAdaptiveSurfaceSpec> _surfaces = {};

  Iterable<SkulMateAdaptiveSurfaceSpec> get surfaces => _surfaces.values;

  SkulMateAdaptiveSurfaceSpec? surface(String id) => _surfaces[id];

  void upsertSurface(SkulMateAdaptiveSurfaceSpec spec) {
    _surfaces[spec.surfaceId] = spec;
    dataModel.applyAll(spec.initialData);
    notifyListeners();
  }

  void updateSurfaceData(String surfaceId, Map<String, Object?> patch) {
    if (!_surfaces.containsKey(surfaceId)) return;
    dataModel.applyAll(patch);
    notifyListeners();
  }

  void removeSurface(String surfaceId) {
    if (_surfaces.remove(surfaceId) != null) {
      notifyListeners();
    }
  }

  void clear() {
    _surfaces.clear();
    dataModel.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    dataModel.dispose();
    super.dispose();
  }
}

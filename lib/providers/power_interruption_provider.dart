import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:suga/models/power_interruption.dart';
import 'package:suga/services/interruption_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Shared power interruption state for every screen.
// Screens read it with context.watch<PowerInterruptionProvider>() and call its
// methods with context.read<PowerInterruptionProvider>().
class PowerInterruptionProvider extends ChangeNotifier {
  PowerInterruptionProvider({InterruptionService? service})
    : _service = service ?? InterruptionService() {
    _preferencesLoad = _loadAreaPreferences();
  }

  final InterruptionService _service;
  static const _kSavedAreaIds = 'areas.savedAreaIds';
  static const _kMainAreaId = 'areas.mainAreaId';

  SharedPreferences? _prefs;
  Future<void>? _preferencesLoad;

  List<PowerInterruption> _all = [];
  int? _selectedAreaId;
  final Set<int> _savedAreaIds = {};
  bool _isLoading = false;
  bool _isSaving = false;
  bool _hasLoaded = false;
  String? _error;
  String? _actionError;
  Map<String, String> _fieldErrors = const {};
  Future<void>? _pendingLoad;
  bool _disposed = false;

  Future<void> _loadAreaPreferences() async {
    try {
      _prefs = await SharedPreferences.getInstance();

      final savedIds = (_prefs!.getStringList(_kSavedAreaIds) ?? [])
          .map(int.tryParse)
          .nonNulls
          .toSet();

      final mainAreaId = _prefs!.getInt(_kMainAreaId);

      if (_savedAreaIds.isEmpty && _selectedAreaId == null) {
        _savedAreaIds.addAll(savedIds);

        _selectedAreaId = mainAreaId != null && savedIds.contains(mainAreaId)
            ? mainAreaId
            : null;
      }

      _notify();
    } catch (e) {
      debugPrint('Could not load saved areas: $e');
    }
  }

  Future<void> _saveAreaPreferences() async {
    try {
      await _preferencesLoad;

      final prefs = _prefs ??= await SharedPreferences.getInstance();

      await prefs.setStringList(
        _kSavedAreaIds,
        _savedAreaIds.map((id) => id.toString()).toList(),
      );

      if (_selectedAreaId != null) {
        await prefs.setInt(_kMainAreaId, _selectedAreaId!);
      } else {
        await prefs.remove(_kMainAreaId);
      }
    } catch (e) {
      debugPrint('Could not save area preferences: $e');
    }
  }

  // Every interruption, soonest first.
  UnmodifiableListView<PowerInterruption> get allInterruptions =>
      UnmodifiableListView(_all);

  // The interruptions for the selected area, or all of them when no area is selected.
  List<PowerInterruption> get interruptions {
    final areaId = _selectedAreaId;
    return areaId == null ? allInterruptions : interruptionsForArea(areaId);
  }

  int? get selectedAreaId => _selectedAreaId;
  Set<int> get savedAreaIds => Set.unmodifiable(_savedAreaIds);
  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  bool get hasLoaded => _hasLoaded;

  // Why the last load failed. The list keeps the last data that loaded successfully.
  String? get error => _error;

  // Why the last add, update or delete failed, e.g. for a SnackBar.
  String? get actionError => _actionError;

  // Per-field messages from the API when the last add or update was rejected.
  Map<String, String> get fieldErrors => _fieldErrors;

  // Needed for add, update and delete. main.dart copies it from AuthProvider.
  set authToken(String? token) => _service.authToken = token;

  // Called when the server rejects an add, update or delete with 401, e.g. because
  // the admin's session expired. main.dart points it at AuthProvider.handleUnauthorized.
  void Function(ApiException error)? onUnauthorized;

  List<PowerInterruption> interruptionsForArea(int areaId) =>
      _all.where((item) => item.areaIds.contains(areaId)).toList();

  bool hasPowerInArea(int areaId) {
    final now = DateTime.now();

    return !interruptionsForArea(areaId).any((item) {
      if (item.status.toLowerCase() != 'active') return false;

      final date = DateTime.tryParse(item.date);
      final start = item.startTime.split(':');
      final end = item.endTime.split(':');

      if (date == null || start.length < 2 || end.length < 2) {
        return false;
      }

      final startTime = DateTime(
        date.year,
        date.month,
        date.day,
        int.tryParse(start[0]) ?? 0,
        int.tryParse(start[1]) ?? 0,
      );

      final endTime = DateTime(
        date.year,
        date.month,
        date.day,
        int.tryParse(end[0]) ?? 0,
        int.tryParse(end[1]) ?? 0,
      );

      return !now.isBefore(startTime) && now.isBefore(endTime);
    });
  }

  PowerInterruption? findById(String id) {
    for (final item in _all) {
      if (item.id == id) return item;
    }
    return null;
  }

  // Shows only one area's interruptions in [interruptions]. Pass null to show all.
  void setAreaFilter(int? areaId) {
    bool changed = false;

    if (areaId != null) {
      changed = _savedAreaIds.add(areaId);
    }

    if (_selectedAreaId != areaId) {
      _selectedAreaId = areaId;
      changed = true;
    }

    if (changed) {
      _notify();
      _saveAreaPreferences();
    }
  }

  void setMainArea(int areaId) {
    if (!_savedAreaIds.contains(areaId)) return;

    if (_selectedAreaId != areaId) {
      _selectedAreaId = areaId;
      _notify();
      _saveAreaPreferences();
    }
  }

  void removeSavedArea(int areaId) {
    // Prevent removing the current main area.
    if (_selectedAreaId == areaId) return;

    if (_savedAreaIds.remove(areaId)) {
      _notify();
      _saveAreaPreferences();
    }
  }

  void toggleSavedArea(int areaId) {
    if (_savedAreaIds.contains(areaId)) {
      // Keep the main area saved.
      if (_selectedAreaId == areaId) return;

      _savedAreaIds.remove(areaId);
    } else {
      _savedAreaIds.add(areaId);
    }

    _notify();
    _saveAreaPreferences();
  }

  void clearActionError() {
    if (_actionError == null && _fieldErrors.isEmpty) return;
    _actionError = null;
    _fieldErrors = const {};
    _notify();
  }

  // Loads every interruption from the API. Calling it again while a load is running
  // waits for that load instead of starting a second request.
  Future<void> loadInterruptions() =>
      _pendingLoad ??= _load().whenComplete(() => _pendingLoad = null);

  Future<void> _load() async {
    _isLoading = true;
    _error = null;
    _notify();
    try {
      _all = _sorted(await _service.fetchInterruptions());
      _hasLoaded = true;
    } on ApiException catch (e) {
      _error = e.message;
    } finally {
      _isLoading = false;
      _notify();
    }
  }

  // Returns true when the server saved it. On false, see [actionError] and [fieldErrors].
  Future<bool> addInterruption(PowerInterruption interruption) {
    return _save(() async {
      final created = await _service.createInterruption(interruption);
      _all = _sorted([..._all, created]);
    });
  }

  Future<bool> updateInterruption(PowerInterruption interruption) {
    final id = int.tryParse(interruption.id);
    if (id == null) return _fail('This interruption has no valid id');
    return _save(() async {
      final updated = await _service.updateInterruption(id, interruption);
      _all = _sorted([
        for (final item in _all) item.id == updated.id ? updated : item,
      ]);
    });
  }

  // The item is only removed from the list after the server confirms the delete.
  Future<bool> deleteInterruption(String interruptionId) {
    final id = int.tryParse(interruptionId);
    if (id == null) return _fail('This interruption has no valid id');
    return _save(() async {
      await _service.deleteInterruption(id);
      _all = _all.where((item) => item.id != interruptionId).toList();
    });
  }

  Future<bool> _save(Future<void> Function() action) async {
    _isSaving = true;
    _actionError = null;
    _fieldErrors = const {};
    _notify();
    try {
      await action();
      return true;
    } on ApiException catch (e) {
      _actionError = e.message;
      _fieldErrors = e.details;
      if (e.isUnauthorized) onUnauthorized?.call(e);
      return false;
    } finally {
      _isSaving = false;
      _notify();
    }
  }

  Future<bool> _fail(String message) async {
    _actionError = message;
    _fieldErrors = const {};
    _notify();
    return false;
  }

  // Dates are YYYY-MM-DD and times HH:MM, so comparing the text sorts them correctly.
  static List<PowerInterruption> _sorted(List<PowerInterruption> list) {
    return [...list]..sort((a, b) {
      final byDate = a.date.compareTo(b.date);
      return byDate != 0 ? byDate : a.startTime.compareTo(b.startTime);
    });
  }

  // A request can finish after the screen that owns the provider is gone.
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

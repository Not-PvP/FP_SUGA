import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:suga/models/power_interruption.dart';
import 'package:suga/services/interruption_service.dart';
import 'package:suga/utils/advisory_time.dart';

// Shared power interruption state for every screen.
// Screens read it with context.watch<PowerInterruptionProvider>() and call its
// methods with context.read<PowerInterruptionProvider>().
class PowerInterruptionProvider extends ChangeNotifier {
  PowerInterruptionProvider({InterruptionService? service})
    : _service = service ?? InterruptionService();

  final InterruptionService _service;

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
  DateTime? _lastUpdated;
  bool _areasRestored = true;

  static const _kHomeArea = 'areas.homeId';
  static const _kSavedAreas = 'areas.savedIds';

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

  // When the advisories last loaded successfully. Shown as "Updated 2:14 PM".
  DateTime? get lastUpdated => _lastUpdated;

  // False while the saved home area is being read at startup.
  bool get areasRestored => _areasRestored;

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

  // A brownout is happening now when an admin marked it ongoing, or when a
  // scheduled one has reached its start time and not yet ended.
  static bool isOutageNow(PowerInterruption item, DateTime now) {
    final status = item.status.toLowerCase();
    if (status == 'ongoing') return true;
    if (status != 'scheduled') return false;
    final start = advisoryStart(item);
    var end = advisoryEnd(item);
    if (start == null || end == null) return false;
    // An end time earlier than the start means it runs past midnight.
    if (!end.isAfter(start)) end = end.add(const Duration(days: 1));
    return !now.isBefore(start) && now.isBefore(end);
  }

  // The brownout happening in this area right now, if any.
  PowerInterruption? currentOutage(int areaId) {
    final now = DateTime.now();
    for (final item in interruptionsForArea(areaId)) {
      if (isOutageNow(item, now)) return item;
    }
    return null;
  }

  // The next scheduled brownout in this area that has not started yet.
  PowerInterruption? nextOutage(int areaId) {
    final now = DateTime.now();
    for (final item in interruptionsForArea(areaId)) {
      if (item.status.toLowerCase() != 'scheduled') continue;
      final start = advisoryStart(item);
      if (start != null && start.isAfter(now)) return item;
    }
    return null;
  }

  bool hasPowerInArea(int areaId) => currentOutage(areaId) == null;

  PowerInterruption? findById(String id) {
    for (final item in _all) {
      if (item.id == id) return item;
    }
    return null;
  }

  // Sets the home area (also saving it). Pass null to show every area.
  void setAreaFilter(int? areaId) {
    bool changed = false;

    if (areaId != null) {
      changed = _savedAreaIds.add(areaId);
    }

    if (_selectedAreaId != areaId) {
      _selectedAreaId = areaId;
      changed = true;
    }

    if (changed) _areasChanged();
  }

  void setMainArea(int areaId) {
    if (!_savedAreaIds.contains(areaId)) return;

    if (_selectedAreaId != areaId) {
      _selectedAreaId = areaId;
      _areasChanged();
    }
  }

  void removeSavedArea(int areaId) {
    // Prevent removing the current home area.
    if (_selectedAreaId == areaId) return;

    if (_savedAreaIds.remove(areaId)) {
      _areasChanged();
    }
  }

  void toggleSavedArea(int areaId) {
    if (_savedAreaIds.contains(areaId)) {
      // Keep the home area saved.
      if (_selectedAreaId == areaId) return;

      _savedAreaIds.remove(areaId);
    } else {
      _savedAreaIds.add(areaId);
    }

    _areasChanged();
  }

  // Reads the home and saved areas kept on the phone. main.dart calls it once at
  // startup, so people do not have to pick their area again every launch.
  Future<void> restoreAreas() async {
    _areasRestored = false;
    try {
      final prefs = await SharedPreferences.getInstance();
      final home = prefs.getInt(_kHomeArea);
      final saved = prefs.getStringList(_kSavedAreas) ?? const [];
      // A choice made while this was loading wins over the stored one.
      _selectedAreaId ??= home;
      _savedAreaIds.addAll(saved.map(int.tryParse).nonNulls);
      final selected = _selectedAreaId;
      if (selected != null) _savedAreaIds.add(selected);
    } catch (_) {
      // Nothing stored or storage unavailable: start without an area.
    }
    _areasRestored = true;
    _notify();
  }

  void _areasChanged() {
    _notify();
    unawaited(_storeAreas());
  }

  Future<void> _storeAreas() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final home = _selectedAreaId;
      if (home == null) {
        await prefs.remove(_kHomeArea);
      } else {
        await prefs.setInt(_kHomeArea, home);
      }
      await prefs.setStringList(_kSavedAreas, [for (final id in _savedAreaIds) '$id']);
    } catch (_) {
      // Not saved; the choice still applies until the app closes.
    }
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
      _lastUpdated = DateTime.now();
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

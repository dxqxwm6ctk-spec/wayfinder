import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../../core/services/firestore_data_service.dart';
import '../../domain/entities/zone.dart';
import '../../domain/usecases/get_transit_dashboard.dart';

class RequestExecutionSummary {
  const RequestExecutionSummary({
    required this.area,
    required this.studentsWaiting,
    required this.busNumber,
  });

  final String area;
  final int studentsWaiting;
  final String? busNumber;
}

class TransitProvider extends ChangeNotifier {
  TransitProvider(this._getTransitDashboard);

  static const int _moderateThreshold = 10;
  static const int _criticalThreshold = 20;
  static const Duration _departedAutoRemoveDelay = Duration(minutes: 1);

  final GetTransitDashboard _getTransitDashboard;
  final FirestoreDataService _firestoreDataService = FirestoreDataService();
  StreamSubscription<QuerySnapshot>? _zonesSubscription;
  Timer? _zonesPollingTimer;
  final Map<String, Timer> _departedAutoRemoveTimers = <String, Timer>{};
  bool _isRealtimeSyncReady = false;

  bool _loading = false;
  bool _hasLoaded = false;
  int _waitingStudents = 0;
  String _fleetStatus = 'BUS #12 READY';
  String _systemStatus = 'System Live';
  String _campusConnectivity = '98% Uptime';
  bool _immediatePickup = true;
  List<String> _pickupAreas = <String>[];
  String _selectedPickupArea = '';
  List<Zone> _zones = <Zone>[];
  List<Zone> _deletedZones = <Zone>[];
  final Map<String, List<String>> _assignedBusesByZone =
      <String, List<String>>{};
    final Map<String, Set<String>> _departedBusesByZone =
      <String, Set<String>>{};
    final Map<String, Map<String, int>> _departedAtByBusByZone =
      <String, Map<String, int>>{};
      final Map<String, int> _requestsClearedAtByZone = <String, int>{};
      final Map<String, int> _lastHandledClearedAtByZone = <String, int>{};
  final Map<String, int> _boardedStudentsByZone = <String, int>{};
  bool _hasActiveStudentRequest = false;
  String? _activeRequestArea;
  DateTime? _lastUpdatedAt;

  bool get loading => _loading;
  int get waitingStudents => _zones.fold<int>(
    0,
    (int sum, Zone zone) => sum + zone.studentsWaiting,
  );
  String get fleetStatus {
    final Zone? zone = _zoneByPickupArea(_selectedPickupArea);
    if (zone?.assignedBus != null && zone!.assignedBus!.isNotEmpty) {
      return 'BUS #${zone.assignedBus!.toUpperCase()} READY';
    }
    return _fleetStatus;
  }

  String get systemStatus => _systemStatus;
  String get campusConnectivity => _campusConnectivity;
  bool get immediatePickup => _immediatePickup;
  List<String> get pickupAreas => _pickupAreas;
  String get selectedPickupArea => _selectedPickupArea;
  List<Zone> get zones => _zones;
  List<Zone> get deletedZones => _deletedZones;
  List<String> assignedBusesForZone(String zoneId) {
    return List<String>.unmodifiable(_assignedBusesByZone[zoneId] ?? <String>[]);
  }

  bool get hasActiveStudentRequest => _hasActiveStudentRequest;
  String? get activeRequestArea => _activeRequestArea;
  DateTime? get lastUpdatedAt => _lastUpdatedAt;
  Map<String, int> get boardedStudentsByZone =>
      Map<String, int>.unmodifiable(_boardedStudentsByZone);

  RequestExecutionSummary? get activeRequestSummary {
    if (!_hasActiveStudentRequest || _activeRequestArea == null) {
      return null;
    }

    final String area = _activeRequestArea!;
    return RequestExecutionSummary(
      area: area,
      studentsWaiting: waitingStudentsForArea(area),
      busNumber: assignedBusForArea(area),
    );
  }

  String get studentCurrentArea {
    if (_hasActiveStudentRequest && _activeRequestArea != null) {
      return _activeRequestArea!;
    }
    return _selectedPickupArea;
  }

  String? get busForStudentArea {
    final String? bus = assignedBusForArea(studentCurrentArea);
    if (bus == null || bus.isEmpty) {
      return null;
    }
    return bus;
  }

  List<String> get busesForStudentArea {
    return busesForArea(studentCurrentArea);
  }

  int waitingStudentsForArea(String area) {
    final List<Zone> matches = _zonesByPickupArea(area);
    if (matches.isEmpty) {
      return 0;
    }
    return matches.fold<int>(
      0,
      (int sum, Zone zone) => sum + zone.studentsWaiting,
    );
  }

  bool get shouldPromptStudentBoarding {
    if (!_hasActiveStudentRequest || _activeRequestArea == null) {
      return false;
    }
    final Zone? zone = _zoneByPickupArea(_activeRequestArea!);
    if (zone == null) {
      return false;
    }
    return isBusDeparted(zone.id) &&
        zone.assignedBus != null &&
        zone.assignedBus!.trim().isNotEmpty;
  }

  int? get estimatedArrivalMinutesForStudentArea {
    final Zone? zone = _zoneByPickupArea(studentCurrentArea);
    if (zone == null ||
        zone.assignedBus == null ||
        zone.assignedBus!.trim().isEmpty) {
      return null;
    }

    // Simple ETA heuristic based on queue load for the zone.
    final int eta = 4 + ((zone.studentsWaiting / 3).ceil() * 2);
    if (eta < 4) {
      return 4;
    }
    if (eta > 30) {
      return 30;
    }
    return eta;
  }

  Future<void> load({bool force = false}) async {
    if (_hasLoaded && !force) {
      return;
    }

    _loading = true;
    notifyListeners();

    try {
      await _migrateLegacyActiveRequestCacheIfNeeded();

      final TransitDashboardData dashboard = await _getTransitDashboard();
      _waitingStudents = dashboard.waitingStudents;
      _fleetStatus = dashboard.fleetStatus;
      _pickupAreas = dashboard.pickupAreas;
      _selectedPickupArea = dashboard.pickupAreas.isNotEmpty
          ? dashboard.pickupAreas.first
          : '';
      _systemStatus = dashboard.systemStatus;
      _campusConnectivity = dashboard.campusConnectivity;
      _zones = dashboard.zones;
      _recomputeZoneSeverityAndSort();
      await _restoreActiveRequestFromRemote();
      _hasLoaded = true;
      _touchUpdatedAt();

      // Realtime startup should not block the UI from rendering.
      unawaited(_startRealtimeSync());
    } catch (e) {
      debugPrint('Transit load failed: $e');
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  void toggleImmediatePickup(bool value) {
    _immediatePickup = value;
    _touchUpdatedAt();
    notifyListeners();
  }

  void selectPickupArea(String value) {
    _selectedPickupArea = value;
    _touchUpdatedAt();
    notifyListeners();
  }

  bool assignBus(String zoneId, String busNumber) {
    final String normalizedBus = busNumber
        .toUpperCase()
        .replaceAll('BUS #', '')
        .trim();
    if (normalizedBus.isEmpty) {
      return false;
    }
    if (normalizedBus.startsWith('0')) {
      return false;
    }

    final List<String> buses = <String>[normalizedBus];
    _zones = _zones
        .map(
          (Zone zone) => zone.id == zoneId
              ? zone.copyWith(assignedBus: normalizedBus)
              : zone,
        )
        .toList();
    _assignedBusesByZone[zoneId] = buses;
    _departedBusesByZone.remove(zoneId);
    _departedAtByBusByZone.remove(zoneId);
    _cancelAutoRemoveTimersForZone(zoneId);
    _touchUpdatedAt();
    notifyListeners();
    _persistAssignedBusesToCache();
    _syncZoneUpdate(zoneId, _buildZoneBusSyncData(zoneId));
    return true;
  }

  bool addBusToZone(String zoneId, String busNumber) {
    final String normalizedBus = busNumber
        .toUpperCase()
        .replaceAll('BUS #', '')
        .trim();
    if (normalizedBus.isEmpty) {
      return false;
    }
    if (normalizedBus.startsWith('0')) {
      return false;
    }

    final List<String> current = List<String>.from(
      _assignedBusesByZone[zoneId] ?? <String>[],
    );

    if (current.any((String bus) => _normalize(bus) == _normalize(normalizedBus))) {
      return false;
    }

    current.add(normalizedBus);
    _assignedBusesByZone[zoneId] = current;

    _zones = _zones
        .map(
          (Zone zone) => zone.id == zoneId
              ? zone.copyWith(assignedBus: current.first)
              : zone,
        )
        .toList();

    _touchUpdatedAt();
    notifyListeners();
    _persistAssignedBusesToCache();
    _syncZoneUpdate(zoneId, _buildZoneBusSyncData(zoneId));
    return true;
  }

  void removeBus(String zoneId) {
    _zones = _zones
        .map(
          (Zone zone) =>
              zone.id == zoneId ? zone.copyWith(clearAssignedBus: true) : zone,
        )
        .toList();
    _assignedBusesByZone.remove(zoneId);
    _departedBusesByZone.remove(zoneId);
    _departedAtByBusByZone.remove(zoneId);
    _cancelAutoRemoveTimersForZone(zoneId);
    _touchUpdatedAt();
    notifyListeners();
    _persistAssignedBusesToCache();
    _syncZoneUpdate(zoneId, _buildZoneBusSyncData(zoneId));
  }

  void markBusDeparted(String zoneId) {
    final List<String> buses = _assignedBusesByZone[zoneId] ?? <String>[];
    if (buses.isEmpty) {
      return;
    }
    markSpecificBusDeparted(zoneId, buses.first);
  }

  void markSpecificBusDeparted(String zoneId, String busNumber) {
    final String normalizedBus =
        busNumber.toUpperCase().replaceAll('BUS #', '').trim();
    final List<String> buses = _assignedBusesByZone[zoneId] ?? <String>[];
    if (normalizedBus.isEmpty ||
        !buses.any((String bus) => _normalize(bus) == _normalize(normalizedBus))) {
      return;
    }

    final Set<String> departed = Set<String>.from(
      _departedBusesByZone[zoneId] ?? <String>{},
    );
    departed.add(normalizedBus);
    _departedBusesByZone[zoneId] = departed;

    final Map<String, int> departedAtByBus = Map<String, int>.from(
      _departedAtByBusByZone[zoneId] ?? <String, int>{},
    );
    departedAtByBus[normalizedBus] = DateTime.now().millisecondsSinceEpoch;
    _departedAtByBusByZone[zoneId] = departedAtByBus;

    _scheduleAutoRemoveBus(zoneId, normalizedBus);
    _touchUpdatedAt();
    notifyListeners();
    _persistAssignedBusesToCache();
    _syncZoneUpdate(zoneId, _buildZoneBusSyncData(zoneId));
  }

  void removeSpecificBus(String zoneId, String busNumber) {
    final String normalizedBus =
        busNumber.toUpperCase().replaceAll('BUS #', '').trim();
    final List<String> current = List<String>.from(
      _assignedBusesByZone[zoneId] ?? <String>[],
    );
    if (current.isEmpty || normalizedBus.isEmpty) {
      return;
    }

    current.removeWhere(
      (String bus) => _normalize(bus) == _normalize(normalizedBus),
    );

    final Set<String> departed = Set<String>.from(
      _departedBusesByZone[zoneId] ?? <String>{},
    )..removeWhere((String bus) => _normalize(bus) == _normalize(normalizedBus));

    final Map<String, int> departedAt = Map<String, int>.from(
      _departedAtByBusByZone[zoneId] ?? <String, int>{},
    )..removeWhere((String bus, _) => _normalize(bus) == _normalize(normalizedBus));

    if (current.isEmpty) {
      _assignedBusesByZone.remove(zoneId);
      _departedBusesByZone.remove(zoneId);
      _departedAtByBusByZone.remove(zoneId);
      _zones = _zones
          .map(
            (Zone zone) => zone.id == zoneId
                ? zone.copyWith(clearAssignedBus: true)
                : zone,
          )
          .toList();
    } else {
      _assignedBusesByZone[zoneId] = current;
      if (departed.isEmpty) {
        _departedBusesByZone.remove(zoneId);
      } else {
        _departedBusesByZone[zoneId] = departed;
      }
      if (departedAt.isEmpty) {
        _departedAtByBusByZone.remove(zoneId);
      } else {
        _departedAtByBusByZone[zoneId] = departedAt;
      }
      _zones = _zones
          .map(
            (Zone zone) => zone.id == zoneId
                ? zone.copyWith(assignedBus: current.first)
                : zone,
          )
          .toList();
    }

    _cancelAutoRemoveTimer(zoneId, normalizedBus);
    _touchUpdatedAt();
    notifyListeners();
    _persistAssignedBusesToCache();
    _syncZoneUpdate(zoneId, _buildZoneBusSyncData(zoneId));
  }

  void _scheduleAutoRemoveBus(String zoneId, String busNumber) {
    final String key = _busTimerKey(zoneId, busNumber);
    _cancelAutoRemoveTimer(zoneId, busNumber);
    _departedAutoRemoveTimers[key] = Timer(_departedAutoRemoveDelay, () {
      _autoRemoveDepartedBus(zoneId, busNumber);
    });
  }

  void _cancelAutoRemoveTimer(String zoneId, String busNumber) {
    _departedAutoRemoveTimers.remove(_busTimerKey(zoneId, busNumber))?.cancel();
  }

  void _cancelAutoRemoveTimersForZone(String zoneId) {
    final List<String> keys = _departedAutoRemoveTimers.keys
        .where((String key) => key.startsWith('$zoneId|'))
        .toList();
    for (final String key in keys) {
      _departedAutoRemoveTimers.remove(key)?.cancel();
    }
  }

  String _busTimerKey(String zoneId, String busNumber) {
    return '$zoneId|${_normalize(busNumber)}';
  }

  void _autoRemoveDepartedBus(String zoneId, String busNumber) {
    final String normalizedBus =
        busNumber.toUpperCase().replaceAll('BUS #', '').trim();
    final Zone? zone = _firstWhereOrNull((Zone z) => z.id == zoneId);
    final List<String> current = List<String>.from(
      _assignedBusesByZone[zoneId] ?? <String>[],
    );

    if (zone == null ||
        normalizedBus.isEmpty ||
        current.isEmpty ||
        !current.any((String bus) => _normalize(bus) == _normalize(normalizedBus)) ||
        !isSpecificBusDeparted(zoneId, normalizedBus)) {
      return;
    }

    current.removeWhere((String bus) => _normalize(bus) == _normalize(normalizedBus));

    final Set<String> departed = Set<String>.from(
      _departedBusesByZone[zoneId] ?? <String>{},
    )..removeWhere((String bus) => _normalize(bus) == _normalize(normalizedBus));
    final Map<String, int> departedAt = Map<String, int>.from(
      _departedAtByBusByZone[zoneId] ?? <String, int>{},
    )..removeWhere((String bus, _) => _normalize(bus) == _normalize(normalizedBus));

    final String? nextPrimary = current.isEmpty ? null : current.first;
    _zones = _zones
        .map(
          (Zone item) => item.id == zoneId
              ? (nextPrimary == null
                    ? item.copyWith(clearAssignedBus: true)
                    : item.copyWith(assignedBus: nextPrimary))
              : item,
        )
        .toList();

    if (current.isEmpty) {
      _assignedBusesByZone.remove(zoneId);
    } else {
      _assignedBusesByZone[zoneId] = current;
    }
    if (departed.isEmpty) {
      _departedBusesByZone.remove(zoneId);
    } else {
      _departedBusesByZone[zoneId] = departed;
    }
    if (departedAt.isEmpty) {
      _departedAtByBusByZone.remove(zoneId);
    } else {
      _departedAtByBusByZone[zoneId] = departedAt;
    }
    _cancelAutoRemoveTimer(zoneId, normalizedBus);
    _touchUpdatedAt();
    notifyListeners();
    _persistAssignedBusesToCache();

    _syncZoneUpdate(zoneId, _buildZoneBusSyncData(zoneId));
  }

  bool isBusDeparted(String zoneId) {
    final List<String> buses = _assignedBusesByZone[zoneId] ?? <String>[];
    if (buses.isEmpty) {
      return false;
    }
    return isSpecificBusDeparted(zoneId, buses.first);
  }

  bool isSpecificBusDeparted(String zoneId, String busNumber) {
    final Set<String> departed = _departedBusesByZone[zoneId] ?? <String>{};
    return departed.any((String bus) => _normalize(bus) == _normalize(busNumber));
  }

  RequestExecutionSummary executeImmediateRequest() {
    String effectiveArea = _selectedPickupArea;
    Zone? zone = _zoneByPickupArea(effectiveArea);

    // Recover from transient UI state by falling back to the first available area.
    if (zone == null && _pickupAreas.isNotEmpty) {
      effectiveArea = _pickupAreas.first;
      _selectedPickupArea = effectiveArea;
      zone = _zoneByPickupArea(effectiveArea);
    }

    // Final recovery: if areas are out of sync with zones, use the first zone directly.
    if (zone == null && _zones.isNotEmpty) {
      zone = _zones.first;
      effectiveArea = zone.name;
      _selectedPickupArea = effectiveArea;
    }

    final bool hasValidActiveForArea =
        _hasActiveStudentRequest &&
        _activeRequestArea != null &&
        _normalize(_activeRequestArea!) == _normalize(effectiveArea) &&
        zone != null &&
        zone.studentsWaiting > 0;

    // Allow re-confirming when the previous active request became stale (e.g. leader cleared it).
    if (zone != null && !hasValidActiveForArea) {
      final Zone targetZone = zone;
      final int nextWaiting = targetZone.studentsWaiting + 1;

      _zones = _zones
          .map(
            (Zone item) => item.id == targetZone.id
                ? item.copyWith(studentsWaiting: nextWaiting)
                : item,
          )
          .toList();
      _waitingStudents += 1;

      _syncZoneUpdate(targetZone.id, <String, dynamic>{
        'studentsWaiting': FieldValue.increment(1),
      });
    }

    _hasActiveStudentRequest = true;
    _activeRequestArea = effectiveArea;
    if (zone != null) {
      _lastHandledClearedAtByZone[zone.id] =
          _requestsClearedAtByZone[zone.id] ?? 0;
    }
    _recomputeZoneSeverityAndSort();
    _touchUpdatedAt();
    _syncActiveRequestToRemote();
    notifyListeners();

    final Zone? updatedZone = _zoneByPickupArea(effectiveArea);
    return RequestExecutionSummary(
      area: effectiveArea,
      studentsWaiting: updatedZone?.studentsWaiting ?? _waitingStudents,
      busNumber: updatedZone?.assignedBus,
    );
  }

  RequestExecutionSummary? cancelRequestForArea(String area) {
    final Zone? zone = _zoneByPickupArea(area);

    if (zone != null) {
      if (zone.studentsWaiting <= 0) {
        if (_hasActiveStudentRequest && _activeRequestArea == area) {
          _hasActiveStudentRequest = false;
          _activeRequestArea = null;
          _syncActiveRequestToRemote();
          _touchUpdatedAt();
          notifyListeners();
        }
        return null;
      }

      _zones = _zones
          .map(
            (Zone item) => item.id == zone.id
                ? item.copyWith(studentsWaiting: item.studentsWaiting - 1)
                : item,
          )
          .toList();

      _syncZoneUpdate(zone.id, <String, dynamic>{
        'studentsWaiting': FieldValue.increment(-1),
      });

      if (_waitingStudents > 0) {
        _waitingStudents -= 1;
      }

      if (_hasActiveStudentRequest && _activeRequestArea == area) {
        _hasActiveStudentRequest = false;
        _activeRequestArea = null;
        _syncActiveRequestToRemote();
      }

      _recomputeZoneSeverityAndSort();
      _touchUpdatedAt();
      notifyListeners();

      final Zone? updatedZone = _zoneByPickupArea(area);
      return RequestExecutionSummary(
        area: area,
        studentsWaiting: updatedZone?.studentsWaiting ?? 0,
        busNumber: updatedZone?.assignedBus,
      );
    }

    if (_waitingStudents <= 0) {
      return null;
    }

    _waitingStudents -= 1;
    if (_hasActiveStudentRequest && _activeRequestArea == area) {
      _hasActiveStudentRequest = false;
      _activeRequestArea = null;
      _syncActiveRequestToRemote();
    }
    _touchUpdatedAt();
    notifyListeners();
    return RequestExecutionSummary(
      area: area,
      studentsWaiting: _waitingStudents,
      busNumber: null,
    );
  }

  bool markCurrentStudentBoarded() {
    if (!_hasActiveStudentRequest || _activeRequestArea == null) {
      return false;
    }

    final Zone? zone = _zoneByPickupArea(_activeRequestArea!);
    if (zone == null || !isBusDeparted(zone.id) || zone.studentsWaiting <= 0) {
      return false;
    }

    _zones = _zones
        .map(
          (Zone item) => item.id == zone.id
              ? item.copyWith(studentsWaiting: item.studentsWaiting - 1)
              : item,
        )
        .toList();

    _syncZoneUpdate(zone.id, <String, dynamic>{
      'studentsWaiting': FieldValue.increment(-1),
    });

    if (_waitingStudents > 0) {
      _waitingStudents -= 1;
    }

    _boardedStudentsByZone[zone.id] =
        (_boardedStudentsByZone[zone.id] ?? 0) + 1;

    _hasActiveStudentRequest = false;
    _activeRequestArea = null;
    _recomputeZoneSeverityAndSort();
    _touchUpdatedAt();
    _syncActiveRequestToRemote();
    notifyListeners();
    return true;
  }

  int leaderMarkStudentsBoarded(String zoneId, int count) {
    final Zone? zone = _firstWhereOrNull((Zone z) => z.id == zoneId);
    if (zone == null || zone.studentsWaiting <= 0 || count <= 0) {
      return 0;
    }

    final int applied = count > zone.studentsWaiting
        ? zone.studentsWaiting
        : count;
    final int nextWaiting = zone.studentsWaiting - applied;

    _zones = _zones
        .map(
          (Zone item) => item.id == zoneId
              ? item.copyWith(studentsWaiting: item.studentsWaiting - applied)
              : item,
        )
        .toList();

    final Map<String, dynamic> syncData = <String, dynamic>{
      'studentsWaiting': nextWaiting,
    };
    if (nextWaiting <= 0) {
      final int clearedAt = DateTime.now().millisecondsSinceEpoch;
      _requestsClearedAtByZone[zoneId] = clearedAt;
      syncData['requestsClearedAt'] = clearedAt;
    }
    _syncZoneUpdate(zoneId, syncData);

    _waitingStudents = (_waitingStudents - applied).clamp(0, _waitingStudents);

    _boardedStudentsByZone[zoneId] =
        (_boardedStudentsByZone[zoneId] ?? 0) + applied;

    _recomputeZoneSeverityAndSort();
    _touchUpdatedAt();
    notifyListeners();
    return applied;
  }

  int boardedCountForZone(String zoneId) {
    return _boardedStudentsByZone[zoneId] ?? 0;
  }

  int waitingCountForZone(String zoneId) {
    final Zone? zone = _firstWhereOrNull((Zone z) => z.id == zoneId);
    return zone?.studentsWaiting ?? 0;
  }

  int clearWaitingStudentsForZone(String zoneId) {
    final Zone? zone = _firstWhereOrNull((Zone z) => z.id == zoneId);
    if (zone == null || zone.studentsWaiting <= 0) {
      return 0;
    }

    final int removed = zone.studentsWaiting;
    _zones = _zones
        .map(
          (Zone item) =>
              item.id == zoneId ? item.copyWith(studentsWaiting: 0) : item,
        )
        .toList();

    _waitingStudents = (_waitingStudents - removed).clamp(0, _waitingStudents);
    _recomputeZoneSeverityAndSort();
    _touchUpdatedAt();
    notifyListeners();

    final int clearedAt = DateTime.now().millisecondsSinceEpoch;
    _requestsClearedAtByZone[zoneId] = clearedAt;
    _syncZoneUpdate(zoneId, <String, dynamic>{
      'studentsWaiting': 0,
      'requestsClearedAt': clearedAt,
    });
    return removed;
  }

  int clearWaitingStudentsForAllZones() {
    final List<Zone> zonesWithWaiting = _zones
        .where((Zone zone) => zone.studentsWaiting > 0)
        .toList();
    if (zonesWithWaiting.isEmpty) {
      return 0;
    }

    final int removed = zonesWithWaiting.fold<int>(
      0,
      (int sum, Zone zone) => sum + zone.studentsWaiting,
    );

    _zones = _zones
        .map(
          (Zone zone) => zone.studentsWaiting > 0
              ? zone.copyWith(studentsWaiting: 0)
              : zone,
        )
        .toList();

    _waitingStudents = 0;
    _recomputeZoneSeverityAndSort();
    _touchUpdatedAt();
    notifyListeners();

    final int clearedAt = DateTime.now().millisecondsSinceEpoch;
    for (final Zone zone in zonesWithWaiting) {
      _requestsClearedAtByZone[zone.id] = clearedAt;
      _syncZoneUpdate(zone.id, <String, dynamic>{
        'studentsWaiting': 0,
        'requestsClearedAt': clearedAt,
      });
    }

    return removed;
  }

  bool softDeleteZone(String zoneId) {
    final Zone? zone = _firstWhereOrNull((Zone z) => z.id == zoneId);
    if (zone == null) {
      return false;
    }

    _zones = _zones.where((Zone item) => item.id != zoneId).toList();
    _deletedZones = <Zone>[
      ..._deletedZones.where((Zone item) => item.id != zoneId),
      zone,
    ]..sort((Zone a, Zone b) => a.name.compareTo(b.name));

    _removeZoneOperationalState(zoneId);
    if (_activeRequestArea != null &&
        _normalize(_activeRequestArea!) == _normalize(zone.name)) {
      _hasActiveStudentRequest = false;
      _activeRequestArea = null;
      _syncActiveRequestToRemote();
    }

    _refreshZoneDerivedState(previousArea: _selectedPickupArea);
    _touchUpdatedAt();
    notifyListeners();
    _syncZoneDeletionState(zone: zone, isDeleted: true);
    return true;
  }

  bool restoreDeletedZone(String zoneId) {
    final Zone? zone = _deletedZoneById(zoneId);
    if (zone == null) {
      return false;
    }

    _deletedZones = _deletedZones.where((Zone item) => item.id != zoneId).toList();
    _zones = <Zone>[
      ..._zones.where((Zone item) => item.id != zoneId),
      zone,
    ];

    _refreshZoneDerivedState(
      previousArea: _selectedPickupArea,
      preferredArea: zone.name,
    );
    _touchUpdatedAt();
    notifyListeners();
    _syncZoneDeletionState(zone: zone, isDeleted: false);
    return true;
  }

  bool deleteZonePermanently(String zoneId) {
    final Zone? active = _firstWhereOrNull((Zone zone) => zone.id == zoneId);
    final Zone? deleted = _deletedZoneById(zoneId);

    if (active == null && deleted == null) {
      return false;
    }

    final String? zoneName = active?.name ?? deleted?.name;
    _zones = _zones.where((Zone zone) => zone.id != zoneId).toList();
    _deletedZones = _deletedZones.where((Zone zone) => zone.id != zoneId).toList();
    _removeZoneOperationalState(zoneId);

    if (_activeRequestArea != null &&
        zoneName != null &&
        _normalize(_activeRequestArea!) == _normalize(zoneName)) {
      _hasActiveStudentRequest = false;
      _activeRequestArea = null;
      _syncActiveRequestToRemote();
    }

    _refreshZoneDerivedState(previousArea: _selectedPickupArea);
    _touchUpdatedAt();
    notifyListeners();
    _syncZonePermanentDelete(zoneId);
    return true;
  }

  String? assignedBusForArea(String area) {
    final List<Zone> matches = _zonesByPickupArea(area);
    for (final Zone zone in matches) {
      final String? bus = zone.assignedBus?.trim();
      if (bus != null && bus.isNotEmpty) {
        return bus;
      }
    }
    return null;
  }

  List<String> busesForArea(String area) {
    final List<Zone> matches = _zonesByPickupArea(area);
    if (matches.isEmpty) {
      return <String>[];
    }

    final Set<String> result = <String>{};
    for (final Zone zone in matches) {
      final List<String> buses = List<String>.from(
        _assignedBusesByZone[zone.id] ?? <String>[],
      );
      if (buses.isNotEmpty) {
        result.addAll(buses.map((String bus) => bus.trim()).where((String bus) => bus.isNotEmpty));
      }

      final String? bus = zone.assignedBus?.trim();
      if (bus != null && bus.isNotEmpty) {
        result.add(bus);
      }
    }

    return result.toList();
  }

  List<Zone> _zonesByPickupArea(String area) {
    final String normalizedArea = _normalize(area);
    return _zones.where((Zone zone) {
      final bool byName = _normalize(zone.name) == normalizedArea;
      final bool byId = _normalize(zone.id) == normalizedArea;
      return byName || byId;
    }).toList();
  }

  Zone? _zoneByPickupArea(String area) {
    final String normalizedArea = _normalize(area);
    return _firstWhereOrNull(
      (Zone zone) =>
          _normalize(zone.name) == normalizedArea ||
          _normalize(zone.id) == normalizedArea,
    );
  }

  String _normalize(String input) {
    return input.trim().toLowerCase();
  }

  void _touchUpdatedAt() {
    _lastUpdatedAt = DateTime.now();
  }

  void _removeZoneOperationalState(String zoneId) {
    _assignedBusesByZone.remove(zoneId);
    _departedBusesByZone.remove(zoneId);
    _departedAtByBusByZone.remove(zoneId);
    _requestsClearedAtByZone.remove(zoneId);
    _lastHandledClearedAtByZone.remove(zoneId);
    _boardedStudentsByZone.remove(zoneId);
    _cancelAutoRemoveTimersForZone(zoneId);
  }

  void _refreshZoneDerivedState({String? previousArea, String? preferredArea}) {
    _recomputeZoneSeverityAndSort();
    _pickupAreas = _zones.map((Zone zone) => zone.name).toList();
    _waitingStudents = _zones.fold<int>(
      0,
      (int sum, Zone zone) => sum + zone.studentsWaiting,
    );

    if (_pickupAreas.isEmpty) {
      _selectedPickupArea = '';
      return;
    }

    final String targetArea = preferredArea ?? previousArea ?? _selectedPickupArea;
    final bool stillExists = _pickupAreas.any(
      (String area) => _normalize(area) == _normalize(targetArea),
    );
    _selectedPickupArea = stillExists ? targetArea : _pickupAreas.first;
  }

  Zone? _firstWhereOrNull(bool Function(Zone zone) predicate) {
    for (final Zone zone in _zones) {
      if (predicate(zone)) {
        return zone;
      }
    }
    return null;
  }

  Zone? _deletedZoneById(String zoneId) {
    for (final Zone zone in _deletedZones) {
      if (zone.id == zoneId) {
        return zone;
      }
    }
    return null;
  }

  ZoneSeverity _severityFromWaitingCount(int waitingCount) {
    if (waitingCount >= _criticalThreshold) {
      return ZoneSeverity.critical;
    }
    if (waitingCount >= _moderateThreshold) {
      return ZoneSeverity.moderate;
    }
    return ZoneSeverity.stable;
  }

  int _severityRank(ZoneSeverity severity) {
    switch (severity) {
      case ZoneSeverity.critical:
        return 3;
      case ZoneSeverity.moderate:
        return 2;
      case ZoneSeverity.stable:
        return 1;
    }
  }

  void _recomputeZoneSeverityAndSort() {
    _zones = _zones
        .map(
          (Zone zone) => zone.copyWith(
            severity: _severityFromWaitingCount(zone.studentsWaiting),
          ),
        )
        .toList()
      ..sort((Zone a, Zone b) {
        final int severityCmp =
            _severityRank(b.severity).compareTo(_severityRank(a.severity));
        if (severityCmp != 0) {
          return severityCmp;
        }

        final int waitingCmp =
            b.studentsWaiting.compareTo(a.studentsWaiting);
        if (waitingCmp != 0) {
          return waitingCmp;
        }

        return a.name.compareTo(b.name);
      });
  }

  String _severityToString(ZoneSeverity severity) {
    switch (severity) {
      case ZoneSeverity.critical:
        return 'critical';
      case ZoneSeverity.moderate:
        return 'moderate';
      case ZoneSeverity.stable:
        return 'stable';
    }
  }

  Future<void> _startRealtimeSync() async {
    if (_isRealtimeSyncReady) {
      return;
    }

    try {
      _firestoreDataService.initialize();
      await _ensureZonesSeeded();

      _zonesSubscription = _firestoreDataService.getZonesStream().listen((
        QuerySnapshot snapshot,
      ) {
        // Realtime stream active, so stop fallback polling to avoid quota spikes.
        _zonesPollingTimer?.cancel();
        _zonesPollingTimer = null;

        if (snapshot.docs.isEmpty) {
          return;
        }

        final List<Zone> incoming = <Zone>[];
        final List<Zone> deletedZones = <Zone>[];

        final Map<String, List<String>> assignedBusesByZone =
            <String, List<String>>{};
        final Map<String, Set<String>> departedBusesByZone =
            <String, Set<String>>{};
        final Map<String, Map<String, int>> departedAtByBusByZone =
            <String, Map<String, int>>{};
        final Map<String, int> requestsClearedAtByZone = <String, int>{};
        for (final QueryDocumentSnapshot doc in snapshot.docs) {
          final Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
          final String zoneName = (data['name'] as String?) ?? doc.id;
          final int studentsWaiting = _toNonNegativeInt(data['studentsWaiting']);

          final Zone zone = Zone(
            id: doc.id,
            name: zoneName,
            studentsWaiting: studentsWaiting,
            severity: _severityFromWaitingCount(studentsWaiting),
            assignedBus:
                (data['assignedBus'] as String?)?.trim().isEmpty == true
                ? null
                : data['assignedBus'] as String?,
          );

          if (_isZoneDeleted(data['isDeleted'])) {
            deletedZones.add(zone);
            continue;
          }

          incoming.add(zone);
          final dynamic rawBuses = data['assignedBuses'];
          final List<String> buses = _normalizeAssignedBuses(
            rawBuses,
            fallback: data['assignedBus'] as String?,
          );
          if (buses.isNotEmpty) {
            assignedBusesByZone[doc.id] = buses;
          }

          final Set<String> departedBuses = _normalizeDepartedBuses(
            data['departedBuses'],
            fallbackDeparted: (data['departed'] as bool?) ?? false,
            fallbackPrimaryBus: data['assignedBus'] as String?,
          );
          if (departedBuses.isNotEmpty) {
            departedBusesByZone[doc.id] = departedBuses;
          }

          final Map<String, int> departedAtByBus = _normalizeDepartedAtByBus(
            data['departedAtByBus'],
            fallbackPrimaryBus: data['assignedBus'] as String?,
            fallbackDepartedAt: data['departedAt'],
            fallbackDeparted: (data['departed'] as bool?) ?? false,
          );
          if (departedAtByBus.isNotEmpty) {
            departedAtByBusByZone[doc.id] = departedAtByBus;
          }

          final int? requestsClearedAt = _timestampToMillis(
            data['requestsClearedAt'],
          );
          if (requestsClearedAt != null) {
            requestsClearedAtByZone[doc.id] = requestsClearedAt;
          }
        }

        _applyIncomingZones(
          incoming,
          assignedBusesByZone,
          departedBusesByZone,
          departedAtByBusByZone,
          requestsClearedAtByZone,
          deletedZones,
        );
      }, onError: (Object error) {
        debugPrint('Zones stream error: $error');
        _startPollingFallback();
      });

      _isRealtimeSyncReady = true;
    } catch (e) {
      debugPrint('Realtime sync unavailable: $e');
      _startPollingFallback();
    }
  }

  void _applyIncomingZones(
    List<Zone> incoming,
    Map<String, List<String>> assignedBusesByZone,
    Map<String, Set<String>> departedBusesByZone,
    Map<String, Map<String, int>> departedAtByBusByZone,
    Map<String, int> requestsClearedAtByZone,
    List<Zone> deletedZones,
  ) {
    final String previousArea = _selectedPickupArea;

    _zones = incoming;
    _deletedZones = deletedZones..sort((Zone a, Zone b) => a.name.compareTo(b.name));
    _assignedBusesByZone
      ..clear()
      ..addAll(assignedBusesByZone);
    _departedBusesByZone
      ..clear()
      ..addAll(departedBusesByZone);
    _departedAtByBusByZone
      ..clear()
      ..addAll(departedAtByBusByZone);
    _requestsClearedAtByZone
      ..clear()
      ..addAll(requestsClearedAtByZone);

    final DateTime now = DateTime.now();
    for (final Zone zone in _zones) {
      final List<String> buses = assignedBusesByZone[zone.id] ?? <String>[];
      final Set<String> departed = departedBusesByZone[zone.id] ?? <String>{};
      final Map<String, int> departedAt =
          departedAtByBusByZone[zone.id] ?? <String, int>{};

      if (buses.isEmpty || departed.isEmpty) {
        _cancelAutoRemoveTimersForZone(zone.id);
        continue;
      }

      for (final String bus in departed) {
        final int? departedAtMillis = departedAt[bus];
        if (departedAtMillis != null) {
          final DateTime departedAtTime =
              DateTime.fromMillisecondsSinceEpoch(departedAtMillis);
          if (now.difference(departedAtTime) >= _departedAutoRemoveDelay) {
            _autoRemoveDepartedBus(zone.id, bus);
            continue;
          }
        }
        _scheduleAutoRemoveBus(zone.id, bus);
      }
    }

    _refreshZoneDerivedState(previousArea: previousArea);

    _handleLeaderClearedRequests();
    _ensureActiveRequestWaitingInvariant(syncToRemote: true);

    _touchUpdatedAt();
    notifyListeners();
    _persistAssignedBusesToCache();
  }

  void _startPollingFallback() {
    _zonesPollingTimer ??= Timer.periodic(const Duration(seconds: 30), (
      Timer timer,
    ) {
      Future<void>.microtask(() async {
        try {
          final QuerySnapshot<Map<String, dynamic>> snapshot =
              await _firestoreDataService.getZonesSnapshot();
          final List<Zone> incoming = <Zone>[];
          final List<Zone> deletedZones = <Zone>[];

          final Map<String, List<String>> assignedBusesByZone =
              <String, List<String>>{};
          final Map<String, Set<String>> departedBusesByZone =
              <String, Set<String>>{};
          final Map<String, Map<String, int>> departedAtByBusByZone =
              <String, Map<String, int>>{};
            final Map<String, int> requestsClearedAtByZone = <String, int>{};
          for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
              in snapshot.docs) {
            final Map<String, dynamic> data = doc.data();
            final int studentsWaiting = _toNonNegativeInt(data['studentsWaiting']);
            final Zone zone = Zone(
              id: doc.id,
              name: (data['name'] as String?) ?? doc.id,
              studentsWaiting: studentsWaiting,
              severity: _severityFromWaitingCount(studentsWaiting),
              assignedBus:
                  (data['assignedBus'] as String?)?.trim().isEmpty == true
                  ? null
                  : data['assignedBus'] as String?,
            );

            if (_isZoneDeleted(data['isDeleted'])) {
              deletedZones.add(zone);
              continue;
            }

            incoming.add(zone);
            final List<String> buses = _normalizeAssignedBuses(
              data['assignedBuses'],
              fallback: data['assignedBus'] as String?,
            );
            if (buses.isNotEmpty) {
              assignedBusesByZone[doc.id] = buses;
            }

            final Set<String> departedBuses = _normalizeDepartedBuses(
              data['departedBuses'],
              fallbackDeparted: (data['departed'] as bool?) ?? false,
              fallbackPrimaryBus: data['assignedBus'] as String?,
            );
            if (departedBuses.isNotEmpty) {
              departedBusesByZone[doc.id] = departedBuses;
            }

            final Map<String, int> departedAtByBus = _normalizeDepartedAtByBus(
              data['departedAtByBus'],
              fallbackPrimaryBus: data['assignedBus'] as String?,
              fallbackDepartedAt: data['departedAt'],
              fallbackDeparted: (data['departed'] as bool?) ?? false,
            );
            if (departedAtByBus.isNotEmpty) {
              departedAtByBusByZone[doc.id] = departedAtByBus;
            }

            final int? requestsClearedAt = _timestampToMillis(
              data['requestsClearedAt'],
            );
            if (requestsClearedAt != null) {
              requestsClearedAtByZone[doc.id] = requestsClearedAt;
            }
          }

          _applyIncomingZones(
            incoming,
            assignedBusesByZone,
            departedBusesByZone,
            departedAtByBusByZone,
            requestsClearedAtByZone,
            deletedZones,
          );
        } catch (e) {
          debugPrint('Zones polling fallback failed: $e');
        }
      });
    });
  }

  List<String> _normalizeAssignedBuses(dynamic raw, {String? fallback}) {
    final Set<String> unique = <String>{};

    if (raw is List) {
      for (final dynamic item in raw) {
        final String value = item.toString().trim();
        if (value.isEmpty) {
          continue;
        }
        unique.add(value.toUpperCase().replaceAll('BUS #', '').trim());
      }
    }

    final String fallbackValue = (fallback ?? '').trim();
    if (fallbackValue.isNotEmpty) {
      unique.add(fallbackValue.toUpperCase().replaceAll('BUS #', '').trim());
    }

    return unique.where((String value) => value.isNotEmpty).toList();
  }

  int _toNonNegativeInt(dynamic raw) {
    if (raw == null) {
      return 0;
    }
    if (raw is int) {
      return raw < 0 ? 0 : raw;
    }
    if (raw is num) {
      final int value = raw.toInt();
      return value < 0 ? 0 : value;
    }
    if (raw is String) {
      final String value = raw.trim();
      if (value.isEmpty) {
        return 0;
      }
      final int? asInt = int.tryParse(value);
      if (asInt != null) {
        return asInt < 0 ? 0 : asInt;
      }
      final double? asDouble = double.tryParse(value);
      if (asDouble != null) {
        final int parsed = asDouble.toInt();
        return parsed < 0 ? 0 : parsed;
      }
    }
    return 0;
  }

  Set<String> _normalizeDepartedBuses(
    dynamic raw, {
    required bool fallbackDeparted,
    String? fallbackPrimaryBus,
  }) {
    final Set<String> result = <String>{};

    if (raw is List) {
      for (final dynamic item in raw) {
        final String value = item.toString().trim();
        if (value.isEmpty) {
          continue;
        }
        result.add(value.toUpperCase().replaceAll('BUS #', '').trim());
      }
    }

    final String primary = (fallbackPrimaryBus ?? '').trim();
    if (fallbackDeparted && primary.isNotEmpty) {
      result.add(primary.toUpperCase().replaceAll('BUS #', '').trim());
    }

    return result;
  }

  Map<String, int> _normalizeDepartedAtByBus(
    dynamic raw, {
    String? fallbackPrimaryBus,
    dynamic fallbackDepartedAt,
    required bool fallbackDeparted,
  }) {
    final Map<String, int> result = <String, int>{};

    if (raw is Map) {
      raw.forEach((dynamic key, dynamic value) {
        final String bus = key.toString().trim();
        if (bus.isEmpty) {
          return;
        }

        int? millis;
        if (value is int) {
          millis = value;
        } else if (value is num) {
          millis = value.toInt();
        } else if (value is Timestamp) {
          millis = value.millisecondsSinceEpoch;
        }

        if (millis != null) {
          result[bus.toUpperCase().replaceAll('BUS #', '').trim()] = millis;
        }
      });
    }

    final String primary = (fallbackPrimaryBus ?? '').trim();
    if (fallbackDeparted && primary.isNotEmpty && !result.containsKey(primary)) {
      int millis = DateTime.now().millisecondsSinceEpoch;
      if (fallbackDepartedAt is Timestamp) {
        millis = fallbackDepartedAt.millisecondsSinceEpoch;
      } else if (fallbackDepartedAt is int) {
        millis = fallbackDepartedAt;
      }
      result[primary.toUpperCase().replaceAll('BUS #', '').trim()] = millis;
    }

    return result;
  }

  int? _timestampToMillis(dynamic raw) {
    if (raw == null) {
      return null;
    }
    if (raw is Timestamp) {
      return raw.millisecondsSinceEpoch;
    }
    if (raw is int) {
      return raw;
    }
    if (raw is num) {
      return raw.toInt();
    }
    return null;
  }

  bool _isZoneDeleted(dynamic raw) {
    if (raw is bool) {
      return raw;
    }
    if (raw is num) {
      return raw != 0;
    }
    if (raw is String) {
      final String value = raw.trim().toLowerCase();
      return value == 'true' || value == '1';
    }
    return false;
  }

  void _handleLeaderClearedRequests() {
    if (!_hasActiveStudentRequest || _activeRequestArea == null) {
      return;
    }

    final Zone? zone = _zoneByPickupArea(_activeRequestArea!);
    if (zone == null) {
      return;
    }

    final int? clearedAt = _requestsClearedAtByZone[zone.id];
    if (clearedAt == null) {
      return;
    }

    final int lastHandled = _lastHandledClearedAtByZone[zone.id] ?? 0;
    if (clearedAt <= lastHandled) {
      return;
    }

    _lastHandledClearedAtByZone[zone.id] = clearedAt;
    _hasActiveStudentRequest = false;
    _activeRequestArea = null;
    _syncActiveRequestToRemote();
  }

  Map<String, dynamic> _buildZoneBusSyncData(String zoneId) {
    final List<String> buses = _assignedBusesByZone[zoneId] ?? <String>[];
    final Set<String> departedSet = _departedBusesByZone[zoneId] ?? <String>{};
    final Map<String, int> departedAtByBus =
        _departedAtByBusByZone[zoneId] ?? <String, int>{};

    final String? primaryBus = buses.isEmpty ? null : buses.first;
    final bool primaryDeparted = primaryBus != null &&
        departedSet.any((String bus) => _normalize(bus) == _normalize(primaryBus));
    final int? primaryDepartedAt = primaryBus == null
        ? null
        : departedAtByBus[primaryBus];

    return <String, dynamic>{
      'assignedBus': primaryBus ?? FieldValue.delete(),
      'assignedBuses': buses.isEmpty ? FieldValue.delete() : buses,
      'departed': primaryDeparted,
      'departedAt': primaryDepartedAt ?? FieldValue.delete(),
      'departedBuses': departedSet.isEmpty ? FieldValue.delete() : departedSet.toList(),
      'departedAtByBus': departedAtByBus.isEmpty
          ? FieldValue.delete()
          : departedAtByBus,
    };
  }

  void _ensureActiveRequestWaitingInvariant({required bool syncToRemote}) {
    if (!_hasActiveStudentRequest || _activeRequestArea == null) {
      return;
    }

    final Zone? zone = _zoneByPickupArea(_activeRequestArea!);
    if (zone == null) {
      return;
    }

    if (zone.studentsWaiting > 0) {
      return;
    }

    // Do not clear active request state here.
    // studentsWaiting can momentarily appear as 0 while Firestore updates propagate.
    // Active request lifecycle should be controlled by explicit cancel/board actions
    // and leader-cleared signals.
    return;
  }

  void _persistAssignedBusesToCache() {
    // Disabled intentionally: source of truth is Firestore.
  }

  Future<void> _migrateLegacyActiveRequestCacheIfNeeded() async {
    // Disabled intentionally: source of truth is Firestore.
  }

  Future<void> _restoreActiveRequestFromRemote() async {
    final User? user = FirebaseAuth.instance.currentUser;
    final String uid = (user?.uid ?? '').trim();
    if (uid.isEmpty) {
      _hasActiveStudentRequest = false;
      _activeRequestArea = null;
      return;
    }

    try {
      _firestoreDataService.initialize();
      final DocumentSnapshot profile = await _firestoreDataService.getUserProfile(uid);
      final Map<String, dynamic> data =
          profile.data() as Map<String, dynamic>? ?? <String, dynamic>{};
      final String remoteArea = (data['activeRequestArea'] as String? ?? '').trim();
      final bool hasRemoteRequest = (data['hasActiveRequest'] as bool?) ?? false;

      if (hasRemoteRequest && remoteArea.isNotEmpty) {
        _hasActiveStudentRequest = true;
        _activeRequestArea = remoteArea;
        final Zone? zone = _zoneByPickupArea(remoteArea);
        if (zone != null) {
          _selectedPickupArea = zone.name;
        }
      } else {
        _hasActiveStudentRequest = false;
        _activeRequestArea = null;
      }
    } catch (e) {
      debugPrint('Active request remote restore failed: $e');
    }
  }

  void _syncActiveRequestToRemote() {
    unawaited(_syncActiveRequestToRemoteNow());
  }

  Future<void> _syncActiveRequestToRemoteNow() async {
    final User? user = FirebaseAuth.instance.currentUser;
    final String uid = (user?.uid ?? '').trim();
    final String email = (user?.email ?? '').trim();
    if (uid.isEmpty) {
      return;
    }

    try {
      _firestoreDataService.initialize();
      await _firestoreDataService.saveUserProfile(
        uid: uid,
        email: email,
        additionalData: <String, dynamic>{
          'hasActiveRequest': _hasActiveStudentRequest,
          'activeRequestArea': _hasActiveStudentRequest
              ? (_activeRequestArea ?? '').trim()
              : '',
        },
      );
    } catch (e) {
      debugPrint('Active request remote sync failed: $e');
    }
  }

  Future<void> _ensureZonesSeeded() async {
    final List<Map<String, dynamic>> existing = await _firestoreDataService
        .getZones();
    final Set<String> existingNames = existing
        .map((Map<String, dynamic> data) => _normalize((data['name'] ?? '').toString()))
        .where((String value) => value.isNotEmpty)
        .toSet();

    for (final Zone zone in _zones) {
      if (existingNames.contains(_normalize(zone.name))) {
        continue;
      }
      await _firestoreDataService.updateZone(zone.id, <String, dynamic>{
        'name': zone.name,
        'studentsWaiting': zone.studentsWaiting,
        'severity': _severityToString(zone.severity),
        'assignedBus': zone.assignedBus,
        'departed': false,
      });
    }
  }

  void _syncZoneUpdate(String zoneId, Map<String, dynamic> data) {
    unawaited(_syncZoneUpdateNow(zoneId, data));
  }

  void _syncZoneDeletionState({required Zone zone, required bool isDeleted}) {
    unawaited(_syncZoneDeletionStateNow(zone: zone, isDeleted: isDeleted));
  }

  Future<void> _syncZoneDeletionStateNow({
    required Zone zone,
    required bool isDeleted,
  }) async {
    try {
      _firestoreDataService.initialize();

      final Map<String, dynamic> payload = <String, dynamic>{
        'name': zone.name,
        'isDeleted': isDeleted,
        'deletedAt': isDeleted
            ? DateTime.now().millisecondsSinceEpoch
            : FieldValue.delete(),
        if (isDeleted) ...<String, dynamic>{
          'studentsWaiting': 0,
          'assignedBus': FieldValue.delete(),
          'assignedBuses': FieldValue.delete(),
          'departed': false,
          'departedAt': FieldValue.delete(),
          'departedBuses': FieldValue.delete(),
          'departedAtByBus': FieldValue.delete(),
        },
      };

      await _firestoreDataService.updateZone(zone.id, payload);
      await _firestoreDataService.updateZonesByName(zone.name, payload);
    } catch (e) {
      debugPrint('Zone deletion-state sync failed for ${zone.id}: $e');
    }
  }

  void _syncZonePermanentDelete(String zoneId) {
    unawaited(_syncZonePermanentDeleteNow(zoneId));
  }

  Future<void> _syncZonePermanentDeleteNow(String zoneId) async {
    try {
      _firestoreDataService.initialize();
      await _firestoreDataService.deleteZonePermanently(zoneId);
    } catch (e) {
      debugPrint('Zone permanent delete failed for $zoneId: $e');
    }
  }

  Future<void> _syncZoneUpdateNow(String zoneId, Map<String, dynamic> data) async {
    try {
      _firestoreDataService.initialize();

      final Zone? zone = _firstWhereOrNull((Zone z) => z.id == zoneId);
      
      // Check if data contains a FieldValue operation (like increment/decrement)
      // If so, use ONLY that operation, don't merge with zone properties
      final bool hasFieldValueOp = data.entries.any(
        (MapEntry<String, dynamic> e) =>
          e.key == 'studentsWaiting' &&
          e.value != null &&
          e.value.runtimeType.toString().contains('FieldValue'),
      );

      final Map<String, dynamic> payload = hasFieldValueOp
          ? data  // Send ONLY the FieldValue operation
          : <String, dynamic>{
              if (zone != null) ...<String, dynamic>{
                'name': zone.name,
                'studentsWaiting': zone.studentsWaiting,
                'severity': _severityToString(zone.severity),
                'assignedBus': zone.assignedBus,
              },
              ...data,
            };

      await _firestoreDataService.updateZone(zoneId, payload);

      final String? zoneName = zone?.name.trim();
      // Do not fan out FieldValue counter operations by name, otherwise
      // one student request may increment multiple same-name documents.
      if (!hasFieldValueOp && zoneName != null && zoneName.isNotEmpty) {
        await _firestoreDataService.updateZonesByName(zoneName, payload);
      }
    } catch (e) {
      debugPrint('Zone sync failed for $zoneId: $e');
    }
  }

  @override
  void dispose() {
    _zonesSubscription?.cancel();
    _zonesPollingTimer?.cancel();
    for (final Timer timer in _departedAutoRemoveTimers.values) {
      timer.cancel();
    }
    _departedAutoRemoveTimers.clear();
    super.dispose();
  }
}

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
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

  final GetTransitDashboard _getTransitDashboard;
  final FirestoreDataService _firestoreDataService = FirestoreDataService();
  StreamSubscription<QuerySnapshot>? _zonesSubscription;
  Timer? _zonesPollingTimer;
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
  final Set<String> _departedZoneIds = <String>{};
  final Map<String, int> _boardedStudentsByZone = <String, int>{};
  bool _hasActiveStudentRequest = false;
  String? _activeRequestArea;
  DateTime? _lastUpdatedAt;

  bool get loading => _loading;
  int get waitingStudents => _waitingStudents;
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
  bool get hasActiveStudentRequest => _hasActiveStudentRequest;
  String? get activeRequestArea => _activeRequestArea;
  DateTime? get lastUpdatedAt => _lastUpdatedAt;
  Map<String, int> get boardedStudentsByZone =>
      Map<String, int>.unmodifiable(_boardedStudentsByZone);

  RequestExecutionSummary? get activeRequestSummary {
    if (!_hasActiveStudentRequest || _activeRequestArea == null) {
      return null;
    }

    final Zone? zone = _zoneByPickupArea(_activeRequestArea!);
    return RequestExecutionSummary(
      area: _activeRequestArea!,
      studentsWaiting: zone?.studentsWaiting ?? 0,
      busNumber: zone?.assignedBus,
    );
  }

  String get studentCurrentArea {
    if (_hasActiveStudentRequest && _activeRequestArea != null) {
      return _activeRequestArea!;
    }
    return _selectedPickupArea;
  }

  String? get busForStudentArea {
    final Zone? zone = _zoneByPickupArea(studentCurrentArea);
    final String? bus = zone?.assignedBus?.trim();
    if (bus == null || bus.isEmpty) {
      return null;
    }
    return bus;
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

  void assignBus(String zoneId, String busNumber) {
    final String normalizedBus = busNumber
        .toUpperCase()
        .replaceAll('BUS #', '')
        .trim();
    _zones = _zones
        .map(
          (Zone zone) => zone.id == zoneId
              ? zone.copyWith(assignedBus: normalizedBus)
              : zone,
        )
        .toList();
    _departedZoneIds.remove(zoneId);
    _touchUpdatedAt();
    notifyListeners();
    _syncZoneUpdate(zoneId, <String, dynamic>{
      'assignedBus': normalizedBus,
      'departed': false,
    });
  }

  void removeBus(String zoneId) {
    _zones = _zones
        .map(
          (Zone zone) =>
              zone.id == zoneId ? zone.copyWith(clearAssignedBus: true) : zone,
        )
        .toList();
    _departedZoneIds.remove(zoneId);
    _touchUpdatedAt();
    notifyListeners();
    _syncZoneUpdate(zoneId, <String, dynamic>{
      'assignedBus': FieldValue.delete(),
      'departed': false,
    });
  }

  void markBusDeparted(String zoneId) {
    final Zone? zone = _firstWhereOrNull((Zone z) => z.id == zoneId);
    if (zone == null ||
        zone.assignedBus == null ||
        zone.assignedBus!.trim().isEmpty) {
      return;
    }
    _departedZoneIds.add(zoneId);
    _touchUpdatedAt();
    notifyListeners();
    _syncZoneUpdate(zoneId, <String, dynamic>{'departed': true});
  }

  bool isBusDeparted(String zoneId) {
    return _departedZoneIds.contains(zoneId);
  }

  RequestExecutionSummary executeImmediateRequest() {
    final Zone? zone = _zoneByPickupArea(_selectedPickupArea);

    if (!_hasActiveStudentRequest && zone != null) {
      final int nextWaiting = zone.studentsWaiting + 1;
      _zones = _zones
          .map(
            (Zone item) => item.id == zone.id
                ? item.copyWith(studentsWaiting: nextWaiting)
                : item,
          )
          .toList();
      _waitingStudents += 1;
      _syncZoneUpdate(zone.id, <String, dynamic>{
        'studentsWaiting': nextWaiting,
      });
    }

    _hasActiveStudentRequest = true;
    _activeRequestArea = _selectedPickupArea;
    _touchUpdatedAt();
    notifyListeners();

    final Zone? updatedZone = _zoneByPickupArea(_selectedPickupArea);
    return RequestExecutionSummary(
      area: _selectedPickupArea,
      studentsWaiting: updatedZone?.studentsWaiting ?? _waitingStudents,
      busNumber: updatedZone?.assignedBus,
    );
  }

  RequestExecutionSummary? cancelRequestForArea(String area) {
    final Zone? zone = _zoneByPickupArea(area);

    if (zone != null) {
      if (zone.studentsWaiting <= 0) {
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
        'studentsWaiting': zone.studentsWaiting - 1,
      });

      if (_waitingStudents > 0) {
        _waitingStudents -= 1;
      }

      if (_hasActiveStudentRequest && _activeRequestArea == area) {
        _hasActiveStudentRequest = false;
        _activeRequestArea = null;
      }

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
      'studentsWaiting': zone.studentsWaiting - 1,
    });

    if (_waitingStudents > 0) {
      _waitingStudents -= 1;
    }

    _boardedStudentsByZone[zone.id] =
        (_boardedStudentsByZone[zone.id] ?? 0) + 1;

    _hasActiveStudentRequest = false;
    _activeRequestArea = null;
    _touchUpdatedAt();
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

    _zones = _zones
        .map(
          (Zone item) => item.id == zoneId
              ? item.copyWith(studentsWaiting: item.studentsWaiting - applied)
              : item,
        )
        .toList();

    _syncZoneUpdate(zoneId, <String, dynamic>{
      'studentsWaiting': zone.studentsWaiting - applied,
    });

    _waitingStudents = (_waitingStudents - applied).clamp(0, _waitingStudents);

    _boardedStudentsByZone[zoneId] =
        (_boardedStudentsByZone[zoneId] ?? 0) + applied;

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

  String? assignedBusForArea(String area) {
    final Zone? zone = _zoneByPickupArea(area);
    final String? bus = zone?.assignedBus?.trim();
    if (bus == null || bus.isEmpty) {
      return null;
    }
    return bus;
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

  Zone? _firstWhereOrNull(bool Function(Zone zone) predicate) {
    for (final Zone zone in _zones) {
      if (predicate(zone)) {
        return zone;
      }
    }
    return null;
  }

  ZoneSeverity _severityFromString(String? value) {
    switch ((value ?? '').toLowerCase()) {
      case 'critical':
        return ZoneSeverity.critical;
      case 'moderate':
        return ZoneSeverity.moderate;
      default:
        return ZoneSeverity.stable;
    }
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
      _startPollingFallback();
      return;
    }

    try {
      _firestoreDataService.initialize();
      await _ensureZonesSeeded();

      _zonesSubscription = _firestoreDataService.getZonesStream().listen((
        QuerySnapshot snapshot,
      ) {
        if (snapshot.docs.isEmpty) {
          return;
        }

        final List<Zone> incoming = snapshot.docs.map((
          QueryDocumentSnapshot doc,
        ) {
          final Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
          return Zone(
            id: doc.id,
            name: (data['name'] as String?) ?? doc.id,
            studentsWaiting: (data['studentsWaiting'] as int?) ?? 0,
            severity: _severityFromString(data['severity'] as String?),
            assignedBus:
                (data['assignedBus'] as String?)?.trim().isEmpty == true
                ? null
                : data['assignedBus'] as String?,
          );
        }).toList();

        _applyIncomingZones(incoming);
      }, onError: (Object error) {
        debugPrint('Zones stream error: $error');
      });

      _isRealtimeSyncReady = true;
      _startPollingFallback();
    } catch (e) {
      debugPrint('Realtime sync unavailable: $e');
      _startPollingFallback();
    }
  }

  void _applyIncomingZones(List<Zone> incoming) {
    if (incoming.isEmpty) {
      return;
    }

    final String previousArea = _selectedPickupArea;
    _zones = incoming;
    _pickupAreas = incoming.map((Zone zone) => zone.name).toList();
    _waitingStudents = incoming.fold<int>(
      0,
      (int sum, Zone zone) => sum + zone.studentsWaiting,
    );

    if (_pickupAreas.isNotEmpty) {
      final bool stillExists = _pickupAreas.any(
        (String area) => _normalize(area) == _normalize(previousArea),
      );
      _selectedPickupArea = stillExists ? previousArea : _pickupAreas.first;
    }

    _touchUpdatedAt();
    notifyListeners();
  }

  void _startPollingFallback() {
    _zonesPollingTimer ??= Timer.periodic(const Duration(seconds: 2), (
      Timer timer,
    ) {
      Future<void>.microtask(() async {
        try {
          final QuerySnapshot<Map<String, dynamic>> snapshot =
              await _firestoreDataService.getZonesSnapshot();
          final List<Zone> incoming = snapshot.docs.map((
            QueryDocumentSnapshot<Map<String, dynamic>> doc,
          ) {
            final Map<String, dynamic> data = doc.data();
            return Zone(
              id: doc.id,
              name: (data['name'] as String?) ?? doc.id,
              studentsWaiting: (data['studentsWaiting'] as int?) ?? 0,
              severity: _severityFromString(data['severity'] as String?),
              assignedBus:
                  (data['assignedBus'] as String?)?.trim().isEmpty == true
                  ? null
                  : data['assignedBus'] as String?,
            );
          }).toList();
          _applyIncomingZones(incoming);
        } catch (e) {
          debugPrint('Zones polling fallback failed: $e');
        }
      });
    });
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
    Future<void>.microtask(() async {
      try {
        await _firestoreDataService.updateZone(zoneId, data);

        final Zone? zone = _firstWhereOrNull((Zone z) => z.id == zoneId);
        final String? zoneName = zone?.name.trim();
        if (zoneName != null && zoneName.isNotEmpty) {
          await _firestoreDataService.updateZonesByName(zoneName, data);
        }
      } catch (e) {
        debugPrint('Zone sync failed for $zoneId: $e');
      }
    });
  }

  @override
  void dispose() {
    _zonesSubscription?.cancel();
    _zonesPollingTimer?.cancel();
    super.dispose();
  }
}

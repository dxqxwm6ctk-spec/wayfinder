import 'package:cloud_firestore/cloud_firestore.dart';

/// Firestore database service for transit data
class FirestoreDataService {
  static final FirestoreDataService _instance =
      FirestoreDataService._internal();

  late final FirebaseFirestore _firestore;
  bool _isInitialized = false;

  FirestoreDataService._internal();

  factory FirestoreDataService() {
    return _instance;
  }

  void initialize() {
    if (_isInitialized) {
      return;
    }
    _firestore = FirebaseFirestore.instance;
    _isInitialized = true;
  }

  void _ensureInitialized() {
    if (!_isInitialized) {
      initialize();
    }
  }

  // ==================== USERS ====================

  /// Save or update user profile
  Future<void> saveUserProfile({
    required String uid,
    required String email,
    String? name,
    String? role,
    Map<String, dynamic>? additionalData,
  }) async {
    _ensureInitialized();
    final data = {
      'email': email,
      'name': name,
      'role': role ?? 'student',
      'updatedAt': FieldValue.serverTimestamp(),
      ...?additionalData,
    };

    await _firestore
        .collection('users')
        .doc(uid)
        .set(data, SetOptions(merge: true));
  }

  Future<DocumentSnapshot> getUserProfile(String uid) {
    _ensureInitialized();
    return _firestore.collection('users').doc(uid).get();
  }

  /// Stream of user profile changes
  Stream<DocumentSnapshot> getUserProfileStream(String uid) {
    _ensureInitialized();
    return _firestore.collection('users').doc(uid).snapshots();
  }

  // ==================== ZONES ====================

  /// Get all zones
  Future<List<Map<String, dynamic>>> getZones() async {
    _ensureInitialized();
    final snapshot = await _firestore.collection('zones').get();
    return snapshot.docs.map((doc) => doc.data()).toList();
  }

  /// Stream of zones (real-time updates)
  Stream<QuerySnapshot> getZonesStream() {
    _ensureInitialized();
    return _firestore.collection('zones').snapshots();
  }

  /// Pull zones snapshot on demand.
  Future<QuerySnapshot<Map<String, dynamic>>> getZonesSnapshot() {
    _ensureInitialized();
    return _firestore.collection('zones').get();
  }

  /// Create new zone
  Future<String> createZone(Map<String, dynamic> zonData) async {
    _ensureInitialized();
    final docRef = await _firestore.collection('zones').add({
      ...zonData,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return docRef.id;
  }

  /// Update zone
  Future<void> updateZone(String zoneId, Map<String, dynamic> data) async {
    _ensureInitialized();
    await _firestore.collection('zones').doc(zoneId).set({
      ...data,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Update all zone docs with a matching name (fallback when ids differ across clients).
  Future<void> updateZonesByName(String zoneName, Map<String, dynamic> data) async {
    _ensureInitialized();
    final QuerySnapshot<Map<String, dynamic>> snapshot = await _firestore
        .collection('zones')
        .where('name', isEqualTo: zoneName)
        .get();

    if (snapshot.docs.isEmpty) {
      return;
    }

    final WriteBatch batch = _firestore.batch();
    for (final QueryDocumentSnapshot<Map<String, dynamic>> doc in snapshot.docs) {
      batch.set(
        doc.reference,
        <String, dynamic>{
          ...data,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    }
    await batch.commit();
  }

  // ==================== BUSES ====================

  /// Get all buses
  Future<List<Map<String, dynamic>>> getBuses() async {
    final snapshot = await _firestore.collection('buses').get();
    return snapshot.docs.map((doc) => doc.data()).toList();
  }

  /// Stream of buses by zone
  Stream<QuerySnapshot> getBusesByZoneStream(String zoneId) {
    return _firestore
        .collection('buses')
        .where('zoneId', isEqualTo: zoneId)
        .snapshots();
  }

  /// Create new bus
  Future<String> createBus(Map<String, dynamic> busData) async {
    final docRef = await _firestore.collection('buses').add({
      ...busData,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return docRef.id;
  }

  /// Update bus status or assignment
  Future<void> updateBus(String busId, Map<String, dynamic> data) async {
    await _firestore.collection('buses').doc(busId).update({
      ...data,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // ==================== RIDE REQUESTS ====================

  /// Create ride request
  Future<String> createRideRequest({
    required String studentId,
    required String zoneId,
    required Map<String, dynamic> requestData,
  }) async {
    final docRef = await _firestore.collection('rideRequests').add({
      'studentId': studentId,
      'zoneId': zoneId,
      ...requestData,
      'createdAt': FieldValue.serverTimestamp(),
      'status': 'pending',
    });
    return docRef.id;
  }

  /// Get active ride requests for zone
  Stream<QuerySnapshot> getActiveRequestsByZone(String zoneId) {
    return _firestore
        .collection('rideRequests')
        .where('zoneId', isEqualTo: zoneId)
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  /// Get user's ride requests
  Stream<QuerySnapshot> getUserRideRequests(String userId) {
    return _firestore
        .collection('rideRequests')
        .where('studentId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  /// Update ride request status
  Future<void> updateRideRequestStatus(
    String requestId,
    String newStatus,
  ) async {
    await _firestore.collection('rideRequests').doc(requestId).update({
      'status': newStatus,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Assign bus to ride request
  Future<void> assignBusToRequest(String requestId, String busId) async {
    await _firestore.collection('rideRequests').doc(requestId).update({
      'busId': busId,
      'status': 'assigned',
      'assignedAt': FieldValue.serverTimestamp(),
    });
  }

  // ==================== ANALYTICS & LOGS ====================

  /// Log user activity
  Future<void> logActivity({
    required String userId,
    required String action,
    Map<String, dynamic>? additionalData,
  }) async {
    await _firestore.collection('activityLogs').add({
      'userId': userId,
      'action': action,
      'timestamp': FieldValue.serverTimestamp(),
      ...?additionalData,
    });
  }

  /// Log trip completion
  Future<void> logTripCompletion({
    required String studentId,
    required String zoneId,
    required String busId,
    required Duration duration,
    Map<String, dynamic>? additionalData,
  }) async {
    await _firestore.collection('tripLogs').add({
      'studentId': studentId,
      'zoneId': zoneId,
      'busId': busId,
      'durationSeconds': duration.inSeconds,
      'completedAt': FieldValue.serverTimestamp(),
      ...?additionalData,
    });
  }

  // ==================== BATCH OPERATIONS ====================

  /// Batch update multiple zones
  Future<void> batchUpdateZones(
    Map<String, Map<String, dynamic>> updates,
  ) async {
    final batch = _firestore.batch();

    updates.forEach((zoneId, data) {
      batch.update(_firestore.collection('zones').doc(zoneId), {
        ...data,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });

    await batch.commit();
  }

  /// Delete ride request
  Future<void> deleteRideRequest(String requestId) async {
    await _firestore.collection('rideRequests').doc(requestId).delete();
  }

  /// Query helper - get document by custom field
  Future<List<Map<String, dynamic>>> queryByField(
    String collection,
    String fieldName,
    dynamic fieldValue,
  ) async {
    final snapshot = await _firestore
        .collection(collection)
        .where(fieldName, isEqualTo: fieldValue)
        .get();
    return snapshot.docs.map((doc) => doc.data()).toList();
  }

  /// Real-time sync for specific collection
  Stream<QuerySnapshot> syncCollection(
    String collection, {
    List<String>? orderBy,
    bool descending = false,
  }) {
    Query query = _firestore.collection(collection);

    if (orderBy != null && orderBy.isNotEmpty) {
      for (final field in orderBy) {
        query = query.orderBy(field, descending: descending);
      }
    }

    return query.snapshots();
  }
}

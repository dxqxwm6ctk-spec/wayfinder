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
    
    // Check if contains FieldValue operations (increment/decrement/etc)
    final bool hasFieldValueOp = data.values.any(
      (dynamic v) => v?.runtimeType.toString().contains('FieldValue') ?? false,
    );
    
    // Use update() for FieldValue operations, set() for regular values
    if (hasFieldValueOp) {
      try {
        await _firestore
            .collection('zones')
            .doc(zoneId)
            .update({
              ...data,
              'updatedAt': FieldValue.serverTimestamp(),
            });
      } catch (e) {
        // If document doesn't exist, create it instead
        if (e.toString().contains('not-found')) {
          await _firestore
              .collection('zones')
              .doc(zoneId)
              .set({
                ...data,
                'updatedAt': FieldValue.serverTimestamp(),
              }, SetOptions(merge: true));
        } else {
          rethrow;
        }
      }
    } else {
      await _firestore.collection('zones').doc(zoneId).set({
        ...data,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
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

  /// Permanently delete zone document.
  Future<void> deleteZonePermanently(String zoneId) async {
    _ensureInitialized();
    await _firestore.collection('zones').doc(zoneId).delete();
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

  // ==================== STUDENT REQUESTS ====================

  /// Save the student's current active request in a deterministic document.
  ///
  /// Document path: studentRequests/{uid}
  /// This keeps exactly one live request record per student.
  Future<void> saveStudentActiveRequest({
    required String uid,
    required String email,
    required bool hasActiveRequest,
    String? activeRequestArea,
    String? zoneId,
    String? studentName,
    String? photoUrl,
  }) async {
    _ensureInitialized();

    final String normalizedArea = (activeRequestArea ?? '').trim();
    final String normalizedZoneId = (zoneId ?? '').trim();
    final String normalizedName = (studentName ?? '').trim();
    final String normalizedPhotoUrl = (photoUrl ?? '').trim();

    await _firestore.collection('studentRequests').doc(uid).set({
      'uid': uid,
      'userId': uid,
      'studentId': uid,
      'studentUid': uid,
      'email': email,
      'hasActiveRequest': hasActiveRequest,
      'activeRequestArea': hasActiveRequest
          ? normalizedArea
          : FieldValue.delete(),
      'pickupArea': hasActiveRequest
          ? normalizedArea
          : FieldValue.delete(),
      'zoneId': hasActiveRequest
          ? normalizedZoneId
          : FieldValue.delete(),
      'name': normalizedName.isEmpty ? FieldValue.delete() : normalizedName,
      'photoUrl': normalizedPhotoUrl.isEmpty
          ? FieldValue.delete()
          : normalizedPhotoUrl,
      'status': hasActiveRequest ? 'pending' : 'inactive',
      'confirmedAt': hasActiveRequest
          ? FieldValue.serverTimestamp()
          : FieldValue.delete(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Read the student's deterministic active request document.
  Future<DocumentSnapshot<Map<String, dynamic>>> getStudentActiveRequest(
    String uid,
  ) {
    _ensureInitialized();
    return _firestore.collection('studentRequests').doc(uid).get();
  }

  /// Stream the student's deterministic active request document.
  Stream<DocumentSnapshot<Map<String, dynamic>>> getStudentActiveRequestStream(
    String uid,
  ) {
    _ensureInitialized();
    return _firestore.collection('studentRequests').doc(uid).snapshots();
  }

  /// Stream pending requests by zone for student/leader views.
  Stream<QuerySnapshot<Map<String, dynamic>>> getPendingStudentRequestsByZone(
    String zoneId,
  ) {
    _ensureInitialized();
    return _firestore
        .collection('studentRequests')
        .where('zoneId', isEqualTo: zoneId)
        .where('status', isEqualTo: 'pending')
        .snapshots();
  }

  /// Mark all pending requests in a zone as inactive.
  Future<void> clearPendingStudentRequestsByZone(String zoneId) async {
    _ensureInitialized();
    final QuerySnapshot<Map<String, dynamic>> snapshot = await _firestore
        .collection('studentRequests')
        .where('zoneId', isEqualTo: zoneId)
        .where('status', isEqualTo: 'pending')
        .get();

    if (snapshot.docs.isEmpty) {
      return;
    }

    final WriteBatch batch = _firestore.batch();
    for (final QueryDocumentSnapshot<Map<String, dynamic>> doc in snapshot.docs) {
      batch.set(doc.reference, <String, dynamic>{
        'hasActiveRequest': false,
        'status': 'inactive',
        'activeRequestArea': FieldValue.delete(),
        'pickupArea': FieldValue.delete(),
        'zoneId': FieldValue.delete(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
    await batch.commit();
  }

  /// Mark all pending student requests as inactive.
  Future<void> clearAllPendingStudentRequests() async {
    _ensureInitialized();
    final QuerySnapshot<Map<String, dynamic>> snapshot = await _firestore
        .collection('studentRequests')
        .where('status', isEqualTo: 'pending')
        .get();

    if (snapshot.docs.isEmpty) {
      return;
    }

    final WriteBatch batch = _firestore.batch();
    for (final QueryDocumentSnapshot<Map<String, dynamic>> doc in snapshot.docs) {
      batch.set(doc.reference, <String, dynamic>{
        'hasActiveRequest': false,
        'status': 'inactive',
        'activeRequestArea': FieldValue.delete(),
        'pickupArea': FieldValue.delete(),
        'zoneId': FieldValue.delete(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
    await batch.commit();
  }

  /// Legacy API kept for backward compatibility.
  Future<void> updateRideRequestStatus(
    String requestId,
    String newStatus,
  ) async {
    await _firestore.collection('studentRequests').doc(requestId).update({
      'status': newStatus,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Legacy API kept for backward compatibility.
  Future<void> assignBusToRequest(String requestId, String busId) async {
    await _firestore.collection('studentRequests').doc(requestId).update({
      'busId': busId,
      'status': 'assigned',
      'assignedAt': FieldValue.serverTimestamp(),
    });
  }

  // ==================== REQUEST STATUS MANAGEMENT (LEADER/ADMIN) ====================

  /// Update a student request status by the leader/admin.
  /// 
  /// Valid statuses: 'pending', 'accepted', 'rejected', 'cancelled'
  /// This method is used by leaders to manage student ride requests.
  Future<void> updateStudentRequestStatus({
    required String studentUid,
    required String newStatus,
    String? rejectionReason,
    String? assignedBusId,
  }) async {
    _ensureInitialized();

    final Map<String, dynamic> updateData = {
      'status': newStatus,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    // Add timestamp based on status
    switch (newStatus) {
      case 'accepted':
        updateData['acceptedAt'] = FieldValue.serverTimestamp();
        if (assignedBusId != null) {
          updateData['assignedBusId'] = assignedBusId;
        }
        break;
      case 'rejected':
        updateData['rejectedAt'] = FieldValue.serverTimestamp();
        if (rejectionReason != null && rejectionReason.isNotEmpty) {
          updateData['rejectionReason'] = rejectionReason;
        }
        break;
      case 'cancelled':
        updateData['cancelledAt'] = FieldValue.serverTimestamp();
        updateData['hasActiveRequest'] = false;
        break;
      default:
        break;
    }

    await _firestore
        .collection('studentRequests')
        .doc(studentUid)
        .update(updateData);
  }

  /// Get all active pending requests for a specific zone.
  Future<List<Map<String, dynamic>>> getActivePendingRequestsByZone(
    String zoneId,
  ) async {
    _ensureInitialized();

    final QuerySnapshot<Map<String, dynamic>> snapshot = await _firestore
        .collection('studentRequests')
        .where('zoneId', isEqualTo: zoneId)
        .where('status', isEqualTo: 'pending')
        .orderBy('confirmedAt', descending: false)
        .get();

    return snapshot.docs.map((doc) => doc.data()).toList();
  }

  /// Get request history for analytics and auditing.
  Future<List<Map<String, dynamic>>> getRequestHistoryForZone(
    String zoneId, {
    int limitDays = 30,
  }) async {
    _ensureInitialized();

    final DateTime cutoffDate =
        DateTime.now().subtract(Duration(days: limitDays));

    final QuerySnapshot<Map<String, dynamic>> snapshot = await _firestore
        .collection('studentRequests')
        .where('zoneId', isEqualTo: zoneId)
        .where('updatedAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(cutoffDate))
        .orderBy('updatedAt', descending: true)
        .get();

    return snapshot.docs.map((doc) => doc.data()).toList();
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

  /// Legacy API kept for backward compatibility.
  Future<void> deleteRideRequest(String requestId) async {
    await _firestore.collection('studentRequests').doc(requestId).delete();
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

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Save or update user profile data
  Future<void> saveUserProfile(String uid, Map<String, dynamic> data) async {
    await _db.collection('users').doc(uid).set(data, SetOptions(merge: true));
  }

  // Get user profile data stream
  Stream<DocumentSnapshot<Map<String, dynamic>>> getUserProfile(String uid) {
    return _db.collection('users').doc(uid).snapshots();
  }

  // Add a new place for a user
  Future<void> addPlace(String uid, Map<String, dynamic> placeData) async {
    await _db.collection('users').doc(uid).collection('places').add(placeData);
  }

  // Get all places for a user
  Stream<QuerySnapshot<Map<String, dynamic>>> getPlaces(String uid) {
    return _db.collection('users').doc(uid).collection('places').snapshots();
  }

  // Update a device status under a specific place for a user
  Future<void> updateDevice(
    String uid,
    String placeId,
    String deviceId,
    Map<String, dynamic> data,
  ) async {
    final deviceRef = _db
        .collection('users')
        .doc(uid)
        .collection('places')
        .doc(placeId)
        .collection('devices')
        .doc(deviceId);

    // Update Firestore
    await deviceRef.set(data, SetOptions(merge: true));

    // Add update timestamp
    await deviceRef.update({
      'lastUpdated': FieldValue.serverTimestamp(),
    });
  }

  Stream<DocumentSnapshot> getDeviceStream(
    String uid,
    String placeId,
    String deviceId,
  ) {
    return _db
        .collection('users')
        .doc(uid)
        .collection('places')
        .doc(placeId)
        .collection('devices')
        .doc(deviceId)
        .snapshots();
  }

  // Save log data
  Future<void> saveLog(Map<String, dynamic> logData) async {
    await _db.collection('logs').add(logData);
  }

  // Get logs for a specific day
  Stream<QuerySnapshot<Object?>> getLogsForDay(DateTime date,
      {String? filter}) {
    try {
      final startOfDay = DateTime(date.year, date.month, date.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      Query query = _db
          .collection('logs')
          .where('timestamp', isGreaterThanOrEqualTo: startOfDay)
          .where('timestamp', isLessThan: endOfDay)
          .orderBy('timestamp', descending: true);

      if (filter != null) {
        query = query.where('type', isEqualTo: filter);
      }

      return query.snapshots();
    } catch (e) {
      debugPrint('Error in getLogsForDay: $e');
      // Return an empty stream in case of error
      return Stream.empty();
    }
  }

  Future<List<DateTime>> getDaysWithLogs() async {
    try {
      final QuerySnapshot querySnapshot = await _db
          .collection('logs')
          .orderBy('timestamp', descending: true)
          .get();

      Set<DateTime> uniqueDays = {};
      for (var doc in querySnapshot.docs) {
        final timestamp = (doc['timestamp'] as Timestamp).toDate();
        uniqueDays
            .add(DateTime(timestamp.year, timestamp.month, timestamp.day));
      }

      return uniqueDays.toList();
    } catch (e) {
      debugPrint('Error getting days with logs: $e');
      return [];
    }
  }
}

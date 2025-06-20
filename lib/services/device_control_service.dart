import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:teemo/services/firestore_service.dart';
import 'package:teemo/services/realtime_database_service.dart';

class DeviceControlService {
  final FirestoreService _firestoreService = FirestoreService();
  final RealtimeDatabaseService _realtimeDbService = RealtimeDatabaseService();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<void> toggleDevice(
      String placeId, String deviceId, bool newStatus) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw Exception('User not authenticated');

    try {
      // Update Firestore
      await _firestoreService.updateDevice(uid, placeId, deviceId, {
        'isOn': newStatus,
        'lastUpdated': FieldValue.serverTimestamp(),
      });

      // Update Realtime Database
      await _realtimeDbService.updateDeviceState(
          uid, placeId, deviceId, newStatus);
    } catch (e) {
      print("Error toggling device: $e");
      throw Exception('Failed to toggle device: $e');
    }
  }

  Future<void> setDeviceStatus(
      String userId, String placeId, String deviceId, bool isOn) async {
    try {
      await _realtimeDbService.updateDeviceState(
          userId, placeId, deviceId, isOn);
    } catch (e) {
      print('Error setting device status: $e');
      rethrow;
    }
  }

  Future<void> setDeviceOffline(
      String userId, String placeId, String deviceId) async {
    try {
      await _realtimeDbService.setDeviceOffline(userId, placeId, deviceId);
    } catch (e) {
      print('Error setting device offline: $e');
      rethrow;
    }
  }
}

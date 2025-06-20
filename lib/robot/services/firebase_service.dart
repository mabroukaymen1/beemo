import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/beemo_robot.dart';

class FirebaseService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseDatabase _database = FirebaseDatabase.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<String?> signIn(String email, String password) async {
    try {
      final UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return result.user?.uid;
    } catch (e) {
      print('Sign in error: $e');
      return null;
    }
  }

  Future<bool> pairWithRobot(String robotId) async {
    final user = _auth.currentUser;
    if (user == null) return false;

    try {
      // Update robot connection status
      await _database.ref('robots/$robotId').update({
        'connectedUser': user.uid,
        'status': 'paired',
        'lastSeen': ServerValue.timestamp,
      });

      // Create robot connection entry for user
      await _database.ref('robot_connections/${user.uid}').set({
        'robotId': robotId,
        'status': 'paired',
        'lastSeen': ServerValue.timestamp,
        'isOnline': true,
        'data': {'name': 'Beemo', 'type': 'home_assistant'}
      });

      return true;
    } catch (e) {
      print('Error pairing with robot: $e');
      return false;
    }
  }

  Stream<BeemoRobot?> robotStatusStream(String robotId) {
    return _database.ref('beemo_robots/$robotId').onValue.map((event) {
      if (event.snapshot.value == null) return null;
      final data = Map<String, dynamic>.from(event.snapshot.value as Map);
      return BeemoRobot.fromMap(robotId, data);
    });
  }

  Future<void> sendCommandToRobot(String robotId, String command) async {
    final user = _auth.currentUser;
    if (user == null) return;

    await _database.ref('robot_commands/$robotId').push().set({
      'type': 'command',
      'value': command,
      'timestamp': ServerValue.timestamp,
      'userId': user.uid
    });
  }

  Future<void> sendEmotionCommand(String robotId, String emotion) async {
    final user = _auth.currentUser;
    if (user == null) return;

    await _database.ref('robot_commands/$robotId').push().set({
      'type': 'emotion',
      'value': emotion,
      'timestamp': ServerValue.timestamp,
      'userId': user.uid
    });
  }

  Future<BeemoRobot?> getConnectedRobot() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    try {
      final connection =
          await _database.ref('robot_connections/${user.uid}').get();

      if (!connection.exists) return null;

      final data = Map<String, dynamic>.from(connection.value as Map);
      final robotId = data['robotId'] as String;

      final robotSnapshot = await _database.ref('beemo_robots/$robotId').get();

      if (!robotSnapshot.exists) return null;

      final robotData = Map<String, dynamic>.from(robotSnapshot.value as Map);
      return BeemoRobot.fromMap(robotId, robotData);
    } catch (e) {
      print('Error getting connected robot: $e');
      return null;
    }
  }

  Future<void> toggleVoiceCommand(String robotId, bool enabled) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      await _database.ref('beemo_robots/$robotId/settings').update({
        'voiceCommandEnabled': enabled,
        'lastUpdated': ServerValue.timestamp,
      });
    } catch (e) {
      print('Error toggling voice command: $e');
      throw e;
    }
  }

  Future<void> refreshRobotStatus(String robotId) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      await _database.ref('beemo_robots/$robotId').update({
        'lastPing': ServerValue.timestamp,
        'statusCheck': true,
      });
    } catch (e) {
      print('Error refreshing robot status: $e');
      throw e;
    }
  }

  Future<void> disconnectRobot(String robotId) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      // Update robot connection status
      await _database.ref('robots/$robotId').update({
        'connectedUser': null,
        'status': 'disconnected',
        'lastSeen': ServerValue.timestamp,
      });

      // Remove user's robot connection
      await _database.ref('robot_connections/${user.uid}').remove();
    } catch (e) {
      print('Error disconnecting robot: $e');
      throw e;
    }
  }

  Future<void> updateRobotStatus(String robotId, String status) async {
    final user = _auth.currentUser;
    if (user == null) return;

    await _database.ref('robots/$robotId').update({
      'status': status,
      'lastUpdated': ServerValue.timestamp,
    });
  }

  Future<String?> getRobotStatus(String robotId) async {
    final snapshot = await _database.ref('robots/$robotId/status').get();
    return snapshot.value as String?;
  }
}

import 'package:firebase_database/firebase_database.dart';

class RealtimeDatabaseService {
  static final RealtimeDatabaseService _instance =
      RealtimeDatabaseService._internal();
  final FirebaseDatabase _database = FirebaseDatabase.instance;

  factory RealtimeDatabaseService() {
    return _instance;
  }

  RealtimeDatabaseService._internal();

  Future<void> updateDeviceState(
    String userId,
    String placeId,
    String deviceId,
    bool isOn,
  ) async {
    try {
      if (userId.isEmpty) throw Exception('Invalid user ID');

      final deviceRef = _database
          .ref()
          .child('device_states')
          .child(userId)
          .child(placeId)
          .child(deviceId);

      await deviceRef.update({
        'isOn': isOn,
        'lastUpdated': ServerValue.timestamp,
        'status': 'online'
      });
    } catch (e) {
      print('Error updating device state: $e');
      throw Exception('Failed to update device state: $e');
    }
  }

  Future<void> setDeviceOffline(
      String userId, String placeId, String deviceId) async {
    try {
      await _database.ref('device_states/$userId/$placeId/$deviceId').update({
        'status': 'offline',
        'lastUpdated': ServerValue.timestamp,
      });
    } catch (e) {
      print('Error setting device offline: $e');
      rethrow;
    }
  }

  Stream<DatabaseEvent> getDeviceStateStream(
      String userId, String placeId, String deviceId) {
    return _database.ref('device_states/$userId/$placeId/$deviceId').onValue;
  }

  Stream<DatabaseEvent> getPlaceDevicesStateStream(
      String userId, String placeId) {
    return _database.ref('device_states/$userId/$placeId').onValue;
  }

  Future<void> setDeviceStatus(
      String userId, String placeId, String deviceId, String status) async {
    try {
      await _database.ref('device_states/$userId/$placeId/$deviceId').update({
        'status': status,
        'lastUpdated': ServerValue.timestamp,
      });
    } catch (e) {
      print('Error setting device status: $e');
      rethrow;
    }
  }

  Future<DataSnapshot> getDeviceStatus(
      String userId, String placeId, String deviceId) async {
    try {
      return await _database
          .ref('device_states/$userId/$placeId/$deviceId')
          .get();
    } catch (e) {
      print('Error getting device status: $e');
      rethrow;
    }
  }

  Future<void> updateDeviceProperties(
    String userId,
    String placeId,
    String deviceId,
    Map<String, dynamic> properties,
  ) async {
    try {
      if (userId.isEmpty) throw Exception('Invalid user ID');

      final deviceRef = _database
          .ref()
          .child('device_states')
          .child(userId)
          .child(placeId)
          .child(deviceId);

      // First check if device exists
      final snapshot = await deviceRef.get();
      if (!snapshot.exists) {
        throw Exception('Device does not exist');
      }

      // Update properties
      await deviceRef.update({
        'properties': properties,
        'lastUpdated': ServerValue.timestamp,
      });
    } catch (e) {
      print('Error updating device properties in realtime database: $e');
      rethrow;
    }
  }

  Future<void> initializeDeviceState(
    String userId,
    String placeId,
    String deviceId,
    Map<String, dynamic> initialState,
  ) async {
    try {
      if (userId.isEmpty) throw Exception('Invalid user ID');

      // First check if the path exists
      _database
          .ref()
          .child('device_states')
          .child(userId)
          .child(placeId)
          .child(deviceId);

      // ignore: unused_local_variable
      final deviceConfigRef =
          _database.ref().child('device_configs').child(userId).child(deviceId);

      // Create initial state
      final Map<String, dynamic> stateData = {
        'isOn': false,
        'status': 'online',
        'properties': initialState,
        'lastUpdated': ServerValue.timestamp,
      };

      // Create initial config
      final Map<String, dynamic> configData = {
        'configured': true,
        'lastSeen': ServerValue.timestamp,
        'type': initialState['type'],
        'category': initialState['category'],
        'placeId': placeId
      };

      // Use transaction to ensure atomic write
      await _database.ref().update({
        'device_states/$userId/$placeId/$deviceId': stateData,
        'device_configs/$userId/$deviceId': configData,
      });
    } catch (e) {
      print('Error initializing device state: $e');
      throw Exception('Failed to initialize device state: $e');
    }
  }

  Stream<DatabaseEvent> getDeviceStatusStream(
      String userId, String placeId, String deviceId) {
    return _database
        .ref('device_states/$userId/$placeId/$deviceId')
        .child('status')
        .onValue;
  }

  Future<Map<String, dynamic>?> getRobotStatus(String robotId) async {
    try {
      final snapshot =
          await _database.ref('_ping_robot_startup/$robotId').get();
      if (!snapshot.exists) {
        return null;
      }
      return Map<String, dynamic>.from(snapshot.value as Map);
    } catch (e) {
      print('Error getting robot status: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> waitForRobotConnection(String robotId,
      {int timeoutSeconds = 30}) async {
    try {
      final startTime = DateTime.now();
      while (DateTime.now().difference(startTime).inSeconds < timeoutSeconds) {
        final status = await getRobotStatus(robotId);
        if (status != null &&
            status['status'] != null &&
            status['status'] != 'connecting') {
          return status;
        }
        await Future.delayed(const Duration(seconds: 1));
      }
      return null;
    } catch (e) {
      print('Error waiting for robot connection: $e');
      return null;
    }
  }

  Stream<Map<String, dynamic>?> getRobotPingStatusStream(String robotId) {
    try {
      return _database.ref('_ping_robot_startup/$robotId').onValue.map((event) {
        if (!event.snapshot.exists || event.snapshot.value == null) {
          return null;
        }
        return Map<String, dynamic>.from(event.snapshot.value as Map);
      });
    } catch (e) {
      print('Error getting robot ping status stream: $e');
      return Stream.value(null);
    }
  }

  Future<void> updateRobotPingStatus(String robotId, String status) async {
    try {
      await _database.ref('_ping_robot_startup/$robotId').update({
        'status': status,
        'timestamp': ServerValue.timestamp,
      });
    } catch (e) {
      print('Error updating robot ping status: $e');
      rethrow;
    }
  }

  Future<bool> pairRobot(String robotId) async {
    try {
      final robotRef = _database.ref('robots/$robotId');
      final snapshot = await robotRef.get();

      if (!snapshot.exists) {
        throw Exception('Robot not found');
      }

      await robotRef.update({
        'status': 'paired',
        'lastUpdated': ServerValue.timestamp,
        'isPaired': true
      });

      await _database.ref('_ping_robot_startup/$robotId').update({
        'status': 'paired',
        'timestamp': ServerValue.timestamp,
      });

      return true;
    } catch (e) {
      print('Error pairing robot: $e');
      return false;
    }
  }

  Future<bool> unpairRobot(String robotId) async {
    try {
      final robotRef = _database.ref('robots/$robotId');

      await robotRef.update({
        'status': 'not_connected',
        'lastUpdated': ServerValue.timestamp,
        'isPaired': false
      });

      await _database.ref('_ping_robot_startup/$robotId').update({
        'status': 'disconnected',
        'timestamp': ServerValue.timestamp,
      });

      return true;
    } catch (e) {
      print('Error unpairing robot: $e');
      return false;
    }
  }

  Stream<bool> getRobotPairingStatus(String robotId) {
    return _database.ref('robots/$robotId/isPaired').onValue.map((event) {
      return event.snapshot.value as bool? ?? false;
    });
  }

  Future<void> sendRobotCommand(
      String robotId, String command, Map<String, dynamic> payload) async {
    try {
      final commandRef = _database.ref('beemo_commands/$robotId/queue').push();
      await commandRef.set({
        'command': command,
        'payload': payload,
        'timestamp': ServerValue.timestamp,
      });
    } catch (e) {
      print('Error sending robot command: $e');
      throw Exception('Failed to send robot command: $e');
    }
  }

  Future<void> updateRobotEmotion(String robotId, String emotion) async {
    try {
      await _database.ref('beemo_robots/$robotId').update({
        'currentEmotion': emotion,
        'lastCommand': {
          'timestamp': ServerValue.timestamp,
          'type': 'emotion_change'
        }
      });
    } catch (e) {
      print('Error updating robot emotion: $e');
      throw Exception('Failed to update robot emotion: $e');
    }
  }

  Future<void> updateRobotStatus(String robotId, String status,
      {Map<String, dynamic>? additionalData}) async {
    try {
      final updates = {
        'status': status,
        'lastUpdated': ServerValue.timestamp,
        ...?additionalData,
      };
      await _database.ref('beemo_robots/$robotId').update(updates);
    } catch (e) {
      print('Error updating robot status: $e');
      throw Exception('Failed to update robot status: $e');
    }
  }

  Future<void> updateRobotServiceRequest(
      String robotId, String service, Map<String, dynamic> params) async {
    final ref = _database.ref('beemo_robots/$robotId/service_requests').push();
    await ref.set({
      'service': service,
      'params': params,
      'timestamp': ServerValue.timestamp,
    });
  }

  Stream<Map<String, dynamic>> getRobotSensorsStream(String robotId) {
    return _database
        .ref('beemo_robots/$robotId/sensors')
        .onValue
        .map((event) => event.snapshot.value as Map<String, dynamic>? ?? {});
  }

  Stream<List<Map<String, dynamic>>> getRobotCommandHistory(String robotId) {
    return _database
        .ref('beemo_robots/$robotId/command_history')
        .onValue
        .map((event) {
      final data = event.snapshot.value as Map?;
      if (data == null) return [];
      return data.entries
          .map((e) => Map<String, dynamic>.from(e.value as Map))
          .toList();
    });
  }

  Future<void> clearRobotCommandHistory(String robotId) async {
    await _database.ref('beemo_robots/$robotId/command_history').remove();
  }

  Stream<Map<String, dynamic>> getRobotPlatformStatusStream(String robotId) {
    return _database
        .ref('beemo_robots/$robotId/platform_status')
        .onValue
        .map((event) => event.snapshot.value as Map<String, dynamic>? ?? {});
  }

  Future<Map<String, dynamic>> getRobotCapabilities(String robotId) async {
    final snapshot =
        await _database.ref('beemo_robots/$robotId/capabilities').get();
    return Map<String, dynamic>.from(snapshot.value as Map? ?? {});
  }

  Future<void> updateRobotSensorData(
      String robotId, Map<String, dynamic> sensorData) async {
    await _database.ref('beemo_robots/$robotId/sensors').update({
      ...sensorData,
      'lastUpdate': ServerValue.timestamp,
    });
  }
}

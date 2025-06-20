import 'package:firebase_database/firebase_database.dart';
import '../models/robot_connection.dart';

class RobotService {
  final _database = FirebaseDatabase.instance;

  Stream<RobotConnection?> getRobotConnectionStream(String userId) {
    return _database.ref('robot_connections/$userId').onValue.map((event) {
      if (!event.snapshot.exists || event.snapshot.value == null) return null;

      final data = Map<String, dynamic>.from(event.snapshot.value as Map);
      return RobotConnection.fromMap(data);
    });
  }

  Future<void> disconnectRobot(String robotId, String userId) async {
    try {
      await _database.ref('robot_connections/$userId').remove();
      await _database.ref('robots/$robotId').update({
        'status': 'disconnected',
        'connectedUser': null,
        'lastSeen': ServerValue.timestamp,
      });
    } catch (e) {
      print('Error disconnecting robot: $e');
      throw e;
    }
  }
}

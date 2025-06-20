class RobotConnection {
  final String robotId;
  final String? name;
  final bool isConnected;
  final bool isOnline;
  final String status;
  final DateTime lastSeen;
  final List<String> capabilities;
  final String type;

  RobotConnection({
    required this.robotId,
    this.name,
    required this.isConnected,
    required this.isOnline,
    required this.status,
    required this.lastSeen,
    this.capabilities = const [],
    this.type = 'beemo',
  });

  factory RobotConnection.fromMap(Map<String, dynamic> data) {
    return RobotConnection(
      robotId: data['robotId'] ?? '',
      name: data['data']?['name'],
      isConnected: data['status'] == 'paired',
      isOnline: data['isOnline'] ?? false,
      status: data['status'] ?? 'disconnected',
      lastSeen: DateTime.fromMillisecondsSinceEpoch(data['lastSeen'] ?? 0),
      capabilities: List<String>.from(data['capabilities'] ?? []),
      type: data['data']?['type'] ?? 'beemo',
    );
  }
}

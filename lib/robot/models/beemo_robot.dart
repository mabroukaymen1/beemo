class BeemoRobot {
  final String id;
  final String status;
  final String currentEmotion;
  final bool isOnline;
  final Map<String, dynamic>? lastCommand;
  final DateTime lastSeen;
  final String? softwareVersion;

  BeemoRobot({
    required this.id,
    required this.status,
    required this.currentEmotion,
    required this.isOnline,
    this.lastCommand,
    required this.lastSeen,
    this.softwareVersion,
  });

  factory BeemoRobot.fromMap(String id, Map<String, dynamic> data) {
    return BeemoRobot(
      id: id,
      status: data['status'] ?? 'offline',
      currentEmotion: data['currentEmotion'] ?? 'neutral',
      isOnline: data['isOnline'] ?? false,
      lastCommand: data['lastCommand'],
      lastSeen: data['lastSeen'] != null
          ? DateTime.fromMillisecondsSinceEpoch(data['lastSeen'])
          : DateTime.now(),
      softwareVersion: data['softwareVersion'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'status': status,
      'currentEmotion': currentEmotion,
      'isOnline': isOnline,
      'lastCommand': lastCommand,
      'lastSeen': lastSeen.millisecondsSinceEpoch,
    };
  }

  BeemoRobot copyWith({
    String? id,
    String? status,
    String? currentEmotion,
    bool? isOnline,
    Map<String, dynamic>? lastCommand,
    DateTime? lastSeen,
    String? softwareVersion,
  }) {
    return BeemoRobot(
      id: id ?? this.id,
      status: status ?? this.status,
      currentEmotion: currentEmotion ?? this.currentEmotion,
      isOnline: isOnline ?? this.isOnline,
      lastCommand: lastCommand ?? this.lastCommand,
      lastSeen: lastSeen ?? this.lastSeen,
      softwareVersion: softwareVersion ?? this.softwareVersion,
    );
  }
}

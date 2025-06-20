import 'dart:convert';

class QrCodeData {
  final String deviceId;
  final String deviceName;

  QrCodeData({required this.deviceId, required this.deviceName});
}

class QrCodeService {
  static QrCodeData? parseQrCode(String rawValue) {
    try {
      // JSON format
      if (rawValue.startsWith('{') && rawValue.endsWith('}')) {
        final json = jsonDecode(rawValue) as Map<String, dynamic>;
        if (_validateJsonFields(json)) {
          return QrCodeData(
            deviceId: json['id'].toString(),
            deviceName: json['name'].toString(),
          );
        }
      }

      // URI format
      if (rawValue.contains('=')) {
        final uri = Uri.tryParse('dummy://dummy?$rawValue');
        if (uri != null && _validateUriParameters(uri.queryParameters)) {
          return QrCodeData(
            deviceId: uri.queryParameters['id']!,
            deviceName: uri.queryParameters['name'] ?? 'Unknown Device',
          );
        }
      }

      // Simple ID format
      if (_validateSimpleId(rawValue)) {
        return QrCodeData(
          deviceId: rawValue.trim(),
          deviceName: 'Unknown Device',
        );
      }

      return null;
    } catch (e) {
      print('Error parsing QR code: $e');
      return null;
    }
  }

  static bool _validateJsonFields(Map<String, dynamic> json) {
    return json.containsKey('id') &&
        json['id'].toString().length >= 6 &&
        json.containsKey('name');
  }

  static bool _validateUriParameters(Map<String, String> params) {
    return params.containsKey('id') && params['id']!.length >= 6;
  }

  static bool _validateSimpleId(String value) {
    return RegExp(r'^[a-zA-Z0-9_-]{6,}$').hasMatch(value.trim());
  }
}

class RobotQRData extends QrCodeData {
  final DateTime expirationTime;
  final String robotType;
  final String ip;
  final String regCode;
  final String version;

  RobotQRData({
    required String deviceId,
    required String deviceName,
    required this.expirationTime,
    required this.robotType,
    required this.ip,
    required this.regCode,
    required this.version,
  }) : super(deviceId: deviceId, deviceName: deviceName);

  bool isExpired() {
    return DateTime.now().isAfter(expirationTime);
  }

  static RobotQRData? parseQR(String rawValue) {
    try {
      // Try to parse as JSON first
      if (rawValue.startsWith('{') && rawValue.endsWith('}')) {
        final data = jsonDecode(rawValue);
        return RobotQRData(
          deviceId: data['deviceId'] ?? '',
          deviceName: data['deviceName'] ?? '',
          robotType: data['deviceType'] ?? 'unknown',
          ip: data['ip'] ?? '',
          regCode: data['regCode'] ?? '',
          version: data['version'] ?? '',
          expirationTime: DateTime.now()
              .add(const Duration(minutes: 5)), // 5-minute expiration
        );
      }

      // Fallback to query string parsing
      final Map<String, dynamic> data = Map<String, dynamic>.from(
        Uri.decodeFull(rawValue).split('&').fold({}, (map, element) {
          final parts = element.split('=');
          if (parts.length == 2) map[parts[0]] = parts[1];
          return map;
        }),
      );

      return RobotQRData(
        deviceId: data['id'] ?? '',
        deviceName: data['name'] ?? '',
        robotType: data['type'] ?? 'unknown',
        ip: data['ip'] ?? '',
        regCode: data['regCode'] ?? '',
        version: data['version'] ?? '',
        expirationTime: DateTime.fromMillisecondsSinceEpoch(
          int.parse(data['exp'] ??
              DateTime.now()
                  .add(const Duration(minutes: 5))
                  .millisecondsSinceEpoch
                  .toString()),
        ),
      );
    } catch (e) {
      print('Error parsing Robot QR: $e');
      return null;
    }
  }
}

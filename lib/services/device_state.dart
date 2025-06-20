import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

enum DeviceConnectionState {
  disconnected,
  connecting,
  connected,
  configuring,
  ready,
  error
}

class DeviceState extends ChangeNotifier {
  DeviceConnectionState _state = DeviceConnectionState.disconnected;
  String _error = '';
  double _progress = 0.0;
  BluetoothDevice? _device;

  DeviceConnectionState get state => _state;
  String get error => _error;
  double get progress => _progress;
  BluetoothDevice? get device => _device;

  void updateState(DeviceConnectionState newState) {
    _state = newState;
    notifyListeners();
  }

  void updateProgress(double value) {
    _progress = value;
    notifyListeners();
  }

  void setError(String message) {
    _error = message;
    _state = DeviceConnectionState.error;
    notifyListeners();
  }

  void setDevice(BluetoothDevice? device) {
    _device = device;
    notifyListeners();
  }

  void reset() {
    _state = DeviceConnectionState.disconnected;
    _error = '';
    _progress = 0.0;
    _device = null;
    notifyListeners();
  }
}

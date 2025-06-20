import 'package:flutter/material.dart';
import 'package:teemo/services/device_service.dart';

abstract class DeviceBottomSheet extends StatefulWidget {
  final String deviceId;

  const DeviceBottomSheet({
    Key? key,
    required this.deviceId,
  }) : super(key: key);

  void updateDeviceState(String deviceId, Map<String, dynamic> properties) {
    final deviceService = DeviceService();
    deviceService.updateDeviceProperties(deviceId, properties);
  }
}

mixin DeviceStateMixin<T extends DeviceBottomSheet> on State<T> {
  final DeviceService _deviceService = DeviceService();
  bool isOnline = true;

  @override
  void initState() {
    super.initState();
    _listenToDeviceStatus();
  }

  void _listenToDeviceStatus() {
    String? placeId;
    final places = _deviceService.getAllPlaces();
    for (var place in places) {
      if (place.devices.any((d) => d.id == widget.deviceId)) {
        placeId = place.id;
        break;
      }
    }

    if (placeId != null) {
      _deviceService
          .getDeviceStatusStream(placeId, widget.deviceId)
          .listen((status) {
        if (mounted) {
          setState(() {
            isOnline = status == 'online';
          });
        }
      });
    }
  }

  Future<void> updateDeviceState(Map<String, dynamic> properties) async {
    try {
      await _deviceService.updateDeviceProperties(widget.deviceId, properties);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to update device. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:teemo/home/qrcode/addevice.dart';
import 'package:teemo/services/models.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firestore_service.dart';
import 'device_control_service.dart'; // Import the new service
import 'realtime_database_service.dart'; // Import RealtimeDatabaseService
import 'package:teemo/home/device_typescreen/tv.dart';
import 'package:teemo/home/device_typescreen/speaker.dart';
import 'package:teemo/home/device_typescreen/lamp.dart';
import 'package:teemo/home/device_typescreen/aircondition.dart';

class DeviceService {
  static final DeviceService _instance = DeviceService._internal();
  factory DeviceService() => _instance;
  DeviceService._internal() {
    _initFirestoreListener();
  }

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirestoreService _firestoreService = FirestoreService();
  final DeviceControlService _deviceControlService = DeviceControlService();
  final RealtimeDatabaseService _realtimeService =
      RealtimeDatabaseService(); // Add RealtimeDatabaseService
  final Map<String, Place> _places = {};
  final _placesController = StreamController<List<Place>>.broadcast();
  bool _isInitialized = false;
  StreamSubscription? _placesSubscription;

  Stream<List<Place>> get placesStream => _placesController.stream;

  void _initFirestoreListener() {
    if (_isInitialized) return;
    _isInitialized = true;

    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) throw Exception('User not authenticated');

      _placesSubscription = _firestoreService.getPlaces(uid).listen(
        (snapshot) {
          _handlePlacesUpdate(snapshot, uid);
        },
        onError: (error) {
          print('Error in places stream: $error');
          _placesController.addError(error);
        },
      );
    } catch (e) {
      print('Error initializing device service: $e');
      _placesController.addError(e);
    }
  }

  void _handlePlacesUpdate(QuerySnapshot snapshot, String uid) async {
    try {
      _places.clear();
      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final placeRef = _firestore
            .collection('users')
            .doc(uid)
            .collection('places')
            .doc(doc.id);

        // Get devices for this place
        final devicesSnapshot = await placeRef.collection('devices').get();
        print(
            'Found ${devicesSnapshot.docs.length} devices for place ${doc.id}'); // Debug print

        final devices = devicesSnapshot.docs
            .map((deviceDoc) => Device.fromJson(deviceDoc.data()))
            .toList();

        // Listen for real-time updates for each device
        for (var device in devices) {
          _realtimeService
              .getDeviceStateStream(uid, doc.id, device.id)
              .listen((event) {
            if (event.snapshot.value != null) {
              final data = event.snapshot.value as Map<dynamic, dynamic>;
              final isOn = data['isOn'] as bool? ?? device.isOn;
              final status = data['status'] as String? ?? device.status;
              final properties = data['properties'] != null
                  ? Map<String, dynamic>.from(data['properties'])
                  : device.properties;

              // Update the device in the local cache
              if (_places.containsKey(doc.id)) {
                final place = _places[doc.id]!;
                final updatedDevices = place.devices.map((d) {
                  if (d.id == device.id) {
                    return Device(
                      id: d.id,
                      name: d.name,
                      type: d.type,
                      category: d.category,
                      isOn: isOn,
                      status: status,
                      properties: properties,
                    );
                  }
                  return d;
                }).toList();

                _places[doc.id] = place.copyWith(devices: updatedDevices);
                _placesController.add(_places.values.toList());
              }
            }
          });
        }

        _places[doc.id] = Place(
          id: doc.id,
          name: data['name'] ?? 'Unnamed Place',
          image: data['image'] ?? '',
          type: data['type'] ?? '',
          devices: devices,
        );
      }
      _placesController.add(_places.values.toList());
    } catch (e) {
      print('Error handling places update: $e');
      _placesController.addError(e);
    }
  }

  Future<void> addPlace(Place place) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    try {
      await _firestoreService.addPlace(uid, place.toJson());
    } catch (e) {
      print("Error adding place: $e");
      // Handle error appropriately (e.g., show a snackbar)
    }
  }

  Future<Place> getPlace(String placeId) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw Exception('User not authenticated');

    final placeDoc = await _firestore
        .collection('users')
        .doc(uid)
        .collection('places')
        .doc(placeId)
        .get();

    if (!placeDoc.exists) throw Exception('Place not found');

    final devicesSnapshot =
        await placeDoc.reference.collection('devices').get();
    final devices = devicesSnapshot.docs
        .map((deviceDoc) => Device.fromJson(deviceDoc.data()))
        .toList();

    return Place(
      id: placeDoc.id,
      name: placeDoc.data()?['name'] ?? 'Unnamed Place',
      image: placeDoc.data()?['image'] ?? 'assets/images/logo.png',
      type: '', // Provide a default value for the 'type' parameter
      devices: devices,
    );
  }

  Future<Place> addDevice(
    String placeId,
    String deviceName,
    String deviceType, {
    String? deviceId,
    String category = '',
    Map<String, dynamic> initialProperties = const {},
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw Exception('User not authenticated');

    try {
      if (deviceName.trim().isEmpty) {
        throw Exception('Device name cannot be empty');
      }

      final actualDeviceId =
          deviceId ?? '${deviceType}_${DateTime.now().millisecondsSinceEpoch}';

      // First create Firestore document
      final deviceRef = _firestore
          .collection('users')
          .doc(uid)
          .collection('places')
          .doc(placeId)
          .collection('devices')
          .doc(actualDeviceId);

      final newDevice = Device(
        id: actualDeviceId,
        name: deviceName,
        type: deviceType,
        category: category,
        isOn: false,
        properties: {
          'name': deviceName,
          'type': deviceType,
          'category': category,
          ...initialProperties,
        },
      );

      // Create Firestore document first
      await deviceRef.set(newDevice.toJson());

      // Then initialize Realtime Database state
      await _realtimeService.initializeDeviceState(
        uid,
        placeId,
        actualDeviceId,
        newDevice.properties,
      );

      // Log and update cache
      await _logDeviceAddition(uid, placeId, newDevice);
      _updateLocalCache(placeId, newDevice);

      return await getPlace(placeId);
    } catch (e) {
      print('Error adding device: $e');
      // Cleanup if partial creation occurred
      try {
        await _cleanupFailedDevice(uid, placeId, deviceId);
      } catch (_) {}
      throw Exception('Failed to add device: $e');
    }
  }

  Future<void> _cleanupFailedDevice(
      String uid, String placeId, String? deviceId) async {
    if (deviceId != null) {
      try {
        await _firestore
            .collection('users')
            .doc(uid)
            .collection('places')
            .doc(placeId)
            .collection('devices')
            .doc(deviceId)
            .delete();

        final updates = {
          'device_states/$uid/$placeId/$deviceId': null,
          'device_configs/$uid/$deviceId': null,
        };
        await FirebaseDatabase.instance.ref().update(updates);
      } catch (e) {
        print('Error during cleanup: $e');
      }
    }
  }

  Future<void> _logDeviceAddition(
      String uid, String placeId, Device device) async {
    final place = await getPlace(placeId);
    await _firestoreService.saveLog({
      'timestamp': FieldValue.serverTimestamp(),
      'userId': uid,
      'placeId': placeId,
      'placeName': place.name,
      'deviceId': device.id,
      'deviceName': device.name,
      'deviceType': device.type,
      'category': device.category,
      'action': 'add_device',
      'type': 'device_management',
      'properties': device.properties,
    });
  }

  void _updateLocalCache(String placeId, Device newDevice) {
    if (_places.containsKey(placeId)) {
      final updatedDevices = List<Device>.from(_places[placeId]!.devices)
        ..add(newDevice);

      _places[placeId] = _places[placeId]!.copyWith(devices: updatedDevices);
      _placesController.add(_places.values.toList());
    }
  }

  Future<void> toggleDevice(
      String placeId, String deviceId, bool newStatus) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw Exception('User not authenticated');

    try {
      // First update Realtime Database
      await _realtimeService.updateDeviceState(
          uid, placeId, deviceId, newStatus);

      // Then update Firestore
      await _firestoreService.updateDevice(uid, placeId, deviceId, {
        'isOn': newStatus,
        'lastUpdated': FieldValue.serverTimestamp(),
      });

      // Update local cache
      if (_places.containsKey(placeId)) {
        final place = _places[placeId]!;
        final updatedDevices = place.devices.map((d) {
          if (d.id == deviceId) {
            return Device(
              id: d.id,
              name: d.name,
              type: d.type,
              category: d.category,
              isOn: newStatus,
              status: 'online',
              properties: d.properties,
            );
          }
          return d;
        }).toList();

        _places[placeId] = place.copyWith(devices: updatedDevices);
        _placesController.add(_places.values.toList());
      }
    } catch (e) {
      print('Error toggling device: $e');

      // Try to set device to error state
      try {
        await _realtimeService.setDeviceStatus(uid, placeId, deviceId, 'error');
      } catch (_) {
        // Ignore error from error status update
      }

      throw Exception('Failed to toggle device: $e');
    }
  }

  List<Device> getDevices(String placeId) {
    return _places[placeId]?.devices ?? [];
  }

  List<Place> getAllPlaces() {
    return _places.values.toList();
  }

  Device? getDeviceById(String deviceId) {
    for (var place in _places.values) {
      for (var device in place.devices) {
        if (device.id == deviceId) {
          return device;
        }
      }
    }
    return null;
  }

  Future<void> updateDeviceProperties(
    String deviceId,
    Map<String, dynamic> properties,
  ) async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) throw Exception('User not authenticated');

      // Convert numeric values to ensure proper type
      final processedProperties = properties.map((key, value) {
        if (value is int) return MapEntry(key, value.toDouble());
        return MapEntry(key, value);
      });

      String? placeId;
      for (var place in _places.values) {
        if (place.devices.any((d) => d.id == deviceId)) {
          placeId = place.id;
          break;
        }
      }

      if (placeId == null) throw Exception('Device not found in any place');

      await _realtimeService.updateDeviceProperties(
        uid,
        placeId,
        deviceId,
        processedProperties,
      );
    } catch (e) {
      print('Error updating device properties: $e');
      throw Exception('Failed to update device properties: $e');
    }
  }

  Future<DataSnapshot> getDeviceStatus(String placeId, String deviceId) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw Exception('User not authenticated');

    try {
      return await _realtimeService.getDeviceStatus(uid, placeId, deviceId);
    } catch (e) {
      print('Error getting device status: $e');
      throw Exception('Failed to get device status: $e');
    }
  }

  Stream<DatabaseEvent> getDeviceStateStream(String placeId, String deviceId) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw Exception('User not authenticated');

    return _realtimeService.getDeviceStateStream(uid, placeId, deviceId);
  }

  Stream<String?> getDeviceStatusStream(String placeId, String deviceId) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw Exception('User not authenticated');

    return _realtimeService
        .getDeviceStatusStream(uid, placeId, deviceId)
        .map((event) => event.snapshot.value?.toString());
  }

  Future<void> setDeviceStatus(
      String placeId, String deviceId, String status) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw Exception('User not authenticated');

    try {
      await _realtimeService.setDeviceStatus(uid, placeId, deviceId, status);

      // Update local cache
      if (_places.containsKey(placeId)) {
        final place = _places[placeId]!;
        final updatedDevices = place.devices.map((d) {
          if (d.id == deviceId) {
            return Device(
              id: d.id,
              name: d.name,
              type: d.type,
              category: d.category,
              isOn: d.isOn,
              status: status,
              properties: d.properties,
            );
          }
          return d;
        }).toList();

        _places[placeId] = place.copyWith(devices: updatedDevices);
        _placesController.add(_places.values.toList());
      }
    } catch (e) {
      print('Error setting device status: $e');
      throw Exception('Failed to set device status: $e');
    }
  }

  /// Returns the correct device bottom sheet widget for the given device.
  /// Checks the device category first, then falls back to type.
  Widget? getDeviceBottomSheet(String deviceId, String deviceType,
      {String? category}) {
    final cat = (category ?? '').toLowerCase();
    final type = deviceType.toLowerCase();

    // Prefer category if provided
    switch (cat) {
      case 'speakers':
        return SpeakerBottomSheet(deviceId: deviceId);
      case 'lighting':
        return SmartLampBottomSheet(deviceId: deviceId);
      case 'climate':
        return AirConditionerBottomSheet(deviceId: deviceId);
      case 'tv':
      case 'media':
        return SmartRemoteBottomSheet(deviceId: deviceId);
    }

    // Fallback to type-based
    switch (type) {
      case 'tv':
      case 'smart_tv':
        return SmartRemoteBottomSheet(deviceId: deviceId);
      case 'speaker':
      case 'smart_speaker':
        return SpeakerBottomSheet(deviceId: deviceId);
      case 'lamp':
      case 'smart_lamp':
      case 'desk_lamp':
      case 'outdoor_lamp':
      case 'light_bulb':
        return SmartLampBottomSheet(deviceId: deviceId);
      case 'ac':
      case 'aircondition':
      case 'air_conditioner':
        return AirConditionerBottomSheet(deviceId: deviceId);
      default:
        return null;
    }
  }

  void dispose() {
    _placesSubscription?.cancel();
    _placesController.close();
  }
}

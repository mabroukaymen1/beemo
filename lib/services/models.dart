import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:teemo/widgets/icons.dart';
import 'package:flutter/material.dart';

// Models
class Place {
  final String id;
  final String name;
  final String image; // merged field from rooms.dart
  final String type; // Add type field
  final List<Device> devices;
  bool isActive;

  Place({
    required this.id,
    required this.name,
    required this.image,
    this.type = '', // Default empty string
    this.devices = const [],
    this.isActive = true,
  });

  // Serialization for Firestore
  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'image': image,
        'type': type,
        // Devices may be stored in a subcollection so you may not serialize here.
      };

  factory Place.fromJson(Map<String, dynamic> json) => Place(
        id: json['id'] as String,
        name: json['name'] as String,
        image: json['image'] as String,
        type: json['type'] as String,
        devices: [],
      );

  factory Place.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    return Place(
      id: doc.id,
      name: data['name'] ?? '',
      image: data['image'] ?? 'assets/images/logo.png',
      type: data['type'] ?? '',
      devices: (data['devices'] as List<dynamic>?)
              ?.map((item) => Device.fromJson(item as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  Place copyWith({
    String? id,
    String? name,
    String? image,
    String? type,
    List<Device>? devices,
  }) {
    return Place(
      id: id ?? this.id,
      name: name ?? this.name,
      image: image ?? this.image,
      type: type ?? this.type,
      devices: devices ?? this.devices,
    );
  }
}

class Device {
  final String id;
  final String name;
  final String type;
  final String category; // Add category field
  bool isOn;
  String status;
  Map<String, dynamic> properties;

  Device({
    required this.id,
    required this.name,
    required this.type,
    this.category = '', // Default empty string
    this.isOn = false,
    this.status = 'Connected',
    this.properties = const {},
  });

  String get deviceType =>
      properties['type']?.toString().toLowerCase() ?? type.toLowerCase();

  IconData get icon => DeviceIcons.getIconForType(type);

  // Serialization for Firestore
  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'type': type,
        'category': category,
        'isOn': isOn,
        'status': status,
        'properties': {
          'type': type,
          'temperature': properties['temperature'] ?? 19,
          'brightness': properties['brightness'] ?? 0.7,
          'volume': properties['volume'] ?? 50,
          ...properties,
        },
      };

  factory Device.fromJson(Map<String, dynamic> json) => Device(
        id: json['id'] as String,
        name: json['name'] as String,
        type: json['type'] as String,
        category: json['category'] as String? ?? '',
        isOn: json['isOn'] as bool? ?? false,
        status: json['status'] as String? ?? 'Connected',
        properties: (json['properties'] as Map<String, dynamic>? ?? {}).map(
          (key, value) => MapEntry(key.toString(), value),
        ),
      );
}

class DeviceConfiguration {
  final String id;
  final String type;
  final String category;
  final Map<String, dynamic> initialProperties;
  final DateTime registrationTime;
  final String status;

  DeviceConfiguration({
    required this.id,
    required this.type,
    required this.category,
    this.initialProperties = const {},
    DateTime? registrationTime,
    this.status = 'pending',
  }) : registrationTime = registrationTime ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'category': category,
        'initialProperties': initialProperties,
        'registrationTime': registrationTime.toIso8601String(),
        'status': status,
      };

  factory DeviceConfiguration.fromJson(Map<String, dynamic> json) {
    return DeviceConfiguration(
      id: json['id'],
      type: json['type'],
      category: json['category'],
      initialProperties: json['initialProperties'] ?? {},
      registrationTime: DateTime.parse(json['registrationTime']),
      status: json['status'] ?? 'pending',
    );
  }
}

// Optionally add a user profile model
class UserProfile {
  final String uid;
  final String displayName;
  final String email;

  UserProfile(
      {required this.uid, required this.displayName, required this.email});

  Map<String, dynamic> toJson() => {
        'uid': uid,
        'displayName': displayName,
        'email': email,
      };

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
        uid: json['uid'],
        displayName: json['displayName'],
        email: json['email'],
      );
}

// Add App model
class App {
  final String id;
  final String name;
  final String description;
  App({required this.id, required this.name, required this.description});
}

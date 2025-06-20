import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class DeviceIcons {
  static Map<String, IconData> typeIcons = {
    // Categories
    'lighting': FontAwesomeIcons.lightbulb,
    'security': FontAwesomeIcons.shield,
    'climate': FontAwesomeIcons.temperatureHalf,

    // Lighting devices
    'smart_lamp': FontAwesomeIcons.lightbulb,
    'desk_lamp': FontAwesomeIcons.lightbulb,
    'outdoor_lamp': FontAwesomeIcons.sun,
    'light_bulb': FontAwesomeIcons.lightbulb,

    // Security devices
    'camera': FontAwesomeIcons.camera,
    'door_lock': FontAwesomeIcons.lock,

    // Climate devices
    'ac': FontAwesomeIcons.snowflake,
    'heater': FontAwesomeIcons.fire,

    // Speaker devices
    'smart_speaker': FontAwesomeIcons.speakap,
    'bluetooth_speaker': FontAwesomeIcons.bluetooth,
    // Added new speaker icons:
    'ceiling_speaker': FontAwesomeIcons.volumeUp,
    'portable_speaker': FontAwesomeIcons.volumeDown,
  };

  static IconData getIconForType(String type) {
    final lookupType = type.toLowerCase().replaceAll(' ', '_');
    return typeIcons[lookupType] ?? FontAwesomeIcons.question;
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class Schedule {
  final String? id;
  final List<String> days;
  final TimeOfDay time;
  final DateTime date;
  final String period;
  final Map<String, dynamic>? conditions;
  final Map<String, dynamic>? tasks;

  Schedule({
    this.id,
    required this.days,
    required this.time,
    required this.date,
    required this.period,
    this.conditions,
    this.tasks,
  });

  // Helper to convert TimeOfDay to a map.
  Map<String, int> get timeMap => {'hour': time.hour, 'minute': time.minute};

  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        'days': days,
        'time': timeMap,
        'date': Timestamp.fromDate(date),
        'period': period,
        'conditions': conditions ?? {'items': []},
        'tasks': tasks ?? {'items': []},
      };

  factory Schedule.fromJson(Map<String, dynamic> json) {
    final timeData = json['time'] as Map<String, dynamic>;
    return Schedule(
      id: json['id'] as String?,
      days: List<String>.from(json['days'] as List),
      time: TimeOfDay(
        hour: timeData['hour'] as int,
        minute: timeData['minute'] as int,
      ),
      date: (json['date'] as Timestamp).toDate(),
      period: json['period'] as String,
      conditions: json['conditions'] as Map<String, dynamic>?,
      tasks: json['tasks'] as Map<String, dynamic>?,
    );
  }
}

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class Schedule {
  final String? id;
  final List<String> days;
  final TimeOfDay time;
  final String period; // AM/PM
  final DateTime date;
  final Map<String, dynamic> conditions;
  final Map<String, dynamic> tasks;
  final Timestamp? createdAt;
  final Timestamp? updatedAt;
  final bool isActive;

  Schedule({
    this.id,
    required this.days,
    required this.time,
    required this.period,
    required this.date,
    this.conditions = const {},
    this.tasks = const {},
    this.createdAt,
    this.updatedAt,
    this.isActive = true,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'days': days,
      'time': {
        'hour': time.hour,
        'minute': time.minute,
      },
      'period': period,
      'date': Timestamp.fromDate(date),
      'conditions': conditions,
      'tasks': tasks,
      'createdAt': createdAt ?? Timestamp.now(),
      'updatedAt': updatedAt ?? Timestamp.now(),
      'isActive': isActive,
    };
  }

  factory Schedule.fromJson(Map<String, dynamic> json) {
    final timeData = json['time'] as Map<String, dynamic>;

    return Schedule(
      id: json['id'],
      days: List<String>.from(json['days']),
      time: TimeOfDay(
        hour: timeData['hour'],
        minute: timeData['minute'],
      ),
      period: json['period'],
      date: (json['date'] as Timestamp).toDate(),
      conditions: json['conditions'] ?? {},
      tasks: json['tasks'] ?? {},
      createdAt: json['createdAt'],
      updatedAt: json['updatedAt'],
      isActive: json['isActive'] ?? true,
    );
  }

  // Create a copy of the schedule with some attributes changed
  Schedule copyWith({
    String? id,
    List<String>? days,
    TimeOfDay? time,
    String? period,
    DateTime? date,
    Map<String, dynamic>? conditions,
    Map<String, dynamic>? tasks,
    Timestamp? createdAt,
    Timestamp? updatedAt,
    bool? isActive,
  }) {
    return Schedule(
      id: id ?? this.id,
      days: days ?? this.days,
      time: time ?? this.time,
      period: period ?? this.period,
      date: date ?? this.date,
      conditions: conditions ?? this.conditions,
      tasks: tasks ?? this.tasks,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isActive: isActive ?? this.isActive,
    );
  }

  // Get a friendly representation of the schedule days
  String getFormattedDays() {
    if (days.isEmpty) return 'No days selected';
    if (days.length == 7) return 'Every day';

    // Sort days in week order
    final weekOrder = {
      'Mon': 0,
      'Tue': 1,
      'Wed': 2,
      'Thu': 3,
      'Fri': 4,
      'Sat': 5,
      'Sun': 6
    };
    final sortedDays = [...days]
      ..sort((a, b) => (weekOrder[a] ?? 99).compareTo(weekOrder[b] ?? 99));

    return sortedDays.join(', ');
  }

  // Get a display name for the schedule
  String getDisplayName() {
    final dayText = getFormattedDays();
    final timeFormatted =
        '${time.hourOfPeriod}:${time.minute.toString().padLeft(2, '0')} ${period}';

    return '$dayText at $timeFormatted';
  }

  // Check if the schedule should run today
  bool shouldRunToday() {
    final now = DateTime.now();
    final today = _getDayShortName(now.weekday);

    return days.contains(today) && isActive;
  }

  // Get short day name from weekday number (1-7)
  String _getDayShortName(int weekday) {
    switch (weekday) {
      case 1:
        return 'Mon';
      case 2:
        return 'Tue';
      case 3:
        return 'Wed';
      case 4:
        return 'Thu';
      case 5:
        return 'Fri';
      case 6:
        return 'Sat';
      case 7:
        return 'Sun';
      default:
        return '';
    }
  }

  // Check if schedule is due to run soon (within the next 15 minutes)
  bool isDueSoon() {
    if (!shouldRunToday()) return false;

    final now = DateTime.now();
    final scheduledTime = DateTime(
      now.year,
      now.month,
      now.day,
      time.hour,
      time.minute,
    );

    final difference = scheduledTime.difference(now);
    return difference.inMinutes >= 0 && difference.inMinutes <= 15;
  }
}

import 'dart:ui';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:teemo/home/tasks/delay_action_screen.dart';
import 'package:teemo/home/tasks/location_selection_screen.dart';
import 'package:teemo/home/tasks/run_automations_screen.dart';
import 'package:teemo/home/tasks/send_notification_screen.dart';
import 'package:teemo/home/tasks/set_alarm_screen.dart';
import 'package:teemo/models/schedule.dart';
import 'package:teemo/widgets/colors.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:teemo/home/logs.dart';
import 'package:uuid/uuid.dart';

// Data models for better type safety and structure
class Condition {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color iconColor;
  final dynamic data;

  Condition({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.iconColor,
    this.data,
  });

  Map<String, dynamic> toJson() {
    return {
      'icon': icon.codePoint,
      'title': title,
      'subtitle': subtitle,
      'iconColor': iconColor.value,
      'data': data is Schedule ? (data as Schedule).toJson() : data,
    };
  }

  factory Condition.fromJson(Map<String, dynamic> json) {
    return Condition(
      icon: IconData(json['icon'], fontFamily: 'MaterialIcons'),
      title: json['title'],
      subtitle: json['subtitle'],
      iconColor: Color(json['iconColor'] ?? 0xFF9C27B0),
      data: json['data'],
    );
  }
}

class Task {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color iconColor;
  final dynamic data;
  final String? id;

  Task({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.iconColor,
    this.data,
    this.id,
  });

  Map<String, dynamic> toJson() {
    return {
      'icon': icon.codePoint,
      'title': title,
      'subtitle': subtitle,
      'iconColor': iconColor.value,
      'data': data,
      'id': id ?? const Uuid().v4(),
    };
  }

  factory Task.fromJson(Map<String, dynamic> json) {
    return Task(
      icon: IconData(json['icon'], fontFamily: 'MaterialIcons'),
      title: json['title'],
      subtitle: json['subtitle'],
      iconColor: Color(json['iconColor'] ?? 0xFF2196F3),
      data: json['data'],
      id: json['id'],
    );
  }

  Task copyWith({
    IconData? icon,
    String? title,
    String? subtitle,
    Color? iconColor,
    dynamic data,
    String? id,
  }) {
    return Task(
      icon: icon ?? this.icon,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      iconColor: iconColor ?? this.iconColor,
      data: data ?? this.data,
      id: id ?? this.id,
    );
  }
}

class AutomationScreen extends StatefulWidget {
  final String title;
  final Schedule? schedule;

  const AutomationScreen({
    Key? key,
    required this.title,
    this.schedule,
  }) : super(key: key);

  @override
  _AutomationScreenState createState() => _AutomationScreenState();
}

class _AutomationScreenState extends State<AutomationScreen>
    with SingleTickerProviderStateMixin {
  List<Condition> conditions = [];
  List<Task> tasks = [];
  bool isEdited = false;
  bool _isInitialized = false;
  bool _isLoading = false;

  // For animations
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOut,
      ),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.05),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOutCubic,
      ),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    if (!_isInitialized) {
      _loadInitialSchedule(); // Now safe to use context.
      _isInitialized = true;
    }
    super.didChangeDependencies();
  }

  // Load initial schedule if available
  void _loadInitialSchedule() {
    if (widget.schedule != null) {
      // Use the schedule's days and time or populate from conditions if available
      if ((widget.schedule!.conditions.isEmpty ||
              widget.schedule!.conditions['items'] == null) &&
          (widget.schedule!.tasks.isEmpty ||
              widget.schedule!.tasks['items'] == null)) {
        conditions = [
          Condition(
            icon: Icons.schedule,
            title: 'Schedule',
            subtitle:
                '${widget.schedule!.days.join(', ')} - ${widget.schedule!.time.format(context)}',
            iconColor: const Color(0xFF9C27B0),
            data: widget.schedule,
          ),
        ];
      } else {
        if (widget.schedule!.conditions['items'] != null) {
          try {
            conditions = (widget.schedule!.conditions['items'] as List)
                .map((item) => Condition(
                      icon: IconData(item['icon'], fontFamily: 'MaterialIcons'),
                      title: item['title'],
                      subtitle: item['subtitle'],
                      iconColor: _getColorForCondition(item['title']),
                      data: item['data'],
                    ))
                .toList();
          } catch (e) {
            debugPrint('Error loading conditions: $e');
            // Fallback to default condition
            conditions = [
              Condition(
                icon: Icons.schedule,
                title: 'Schedule',
                subtitle: widget.title,
                iconColor: const Color(0xFF9C27B0),
                data: widget.schedule,
              ),
            ];
          }
        }

        if (widget.schedule!.tasks['items'] != null) {
          try {
            tasks = (widget.schedule!.tasks['items'] as List)
                .map((item) => Task(
                      icon: IconData(item['icon'], fontFamily: 'MaterialIcons'),
                      title: item['title'],
                      subtitle: item['subtitle'],
                      iconColor: Color(item['iconColor'] ??
                          _getColorForTask(item['title']).value),
                      data: item['data'],
                      id: item['id'] ?? const Uuid().v4(),
                    ))
                .toList();
          } catch (e) {
            debugPrint('Error loading tasks: $e');
            tasks = [];
          }
        }
      }
    }
  }

  // Helper function to get color for conditions
  Color _getColorForCondition(String conditionType) {
    switch (conditionType) {
      case 'Location':
        return Colors.orange.shade700;
      case 'Schedule':
      case 'New Schedule':
        return const Color(0xFF9C27B0);
      default:
        return Colors.grey;
    }
  }

  // Helper function to get color for tasks
  Color _getColorForTask(String taskType) {
    switch (taskType) {
      case 'Run devices':
        return Colors.blue;
      case 'Run automations':
        return Colors.green;
      case 'Send notification':
        return Colors.orange;
      case 'Delay the action':
        return Colors.purple;
      case 'Set alarm':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  // Helper to get task priority indicator
  String _getTaskPriorityText(int index) {
    if (tasks.isEmpty) return '';

    if (index == 0) return 'First';
    if (index == tasks.length - 1) return 'Last';

    return 'Step ${index + 1}';
  }

  // Reusable helper to build a dialog option
  Widget _dialogOption(
    String title,
    IconData icon,
    VoidCallback onTap, {
    Color iconColor = Colors.white,
    String? description,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withOpacity(0.05),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          splashColor: iconColor.withOpacity(0.1),
          highlightColor: iconColor.withOpacity(0.05),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: iconColor, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (description != null)
                        Text(
                          description,
                          style: const TextStyle(
                            color: Colors.white60,
                            fontSize: 13,
                          ),
                        ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  color: iconColor.withOpacity(0.7),
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _addCondition() async {
    HapticFeedback.lightImpact();

    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          margin: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface.withOpacity(0.95),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 16),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[600],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.add_circle_outline,
                  color: AppColors.primary,
                  size: 24,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Add Condition',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Choose a condition type to trigger your automation',
                style: TextStyle(color: Colors.grey, fontSize: 14),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    _dialogOption(
                      'Schedule',
                      Icons.schedule,
                      () => Navigator.pop(context, 'Schedule'),
                      iconColor: const Color(0xFF9C27B0),
                      description: 'Execute on specific days and times',
                    ),
                    _dialogOption(
                      'Location',
                      Icons.location_on,
                      () => Navigator.pop(context, 'Location'),
                      iconColor: Colors.orange.shade700,
                      description: 'Execute when entering or leaving an area',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Divider(color: Colors.grey[800], height: 1),
              InkWell(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  alignment: Alignment.center,
                  child: const Text(
                    'Cancel',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (result == 'Location') {
      final locationData = await Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => LocationSelectionScreen()),
      );

      if (locationData != null && mounted) {
        setState(() {
          final newCondition = Condition(
            icon: Icons.location_on,
            title: 'Location',
            subtitle: locationData['name'],
            iconColor: Colors.orange.shade700,
            data: locationData,
          );

          conditions.add(newCondition);
          isEdited = true;
        });
      }
    } else if (result == 'Schedule') {
      setState(() {
        conditions.add(
          Condition(
            icon: Icons.schedule,
            title: 'New Schedule',
            subtitle: 'Select time',
            iconColor: const Color(0xFF9C27B0),
          ),
        );
        isEdited = true;
      });
    }
  }

  void _addTask() async {
    HapticFeedback.lightImpact();

    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          margin: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface.withOpacity(0.95),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 16),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[600],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.add_task,
                  color: AppColors.primary,
                  size: 24,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Add Task',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Choose an action to perform when conditions are met',
                style: TextStyle(color: Colors.grey, fontSize: 14),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    _dialogOption(
                      'Run devices',
                      Icons.devices,
                      () => Navigator.pop(context, 'Run devices'),
                      iconColor: Colors.blue,
                      description: 'Control connected smart devices',
                    ),
                    _dialogOption(
                      'Run automations',
                      Icons.autorenew,
                      () => Navigator.pop(context, 'Run automations'),
                      iconColor: Colors.green,
                      description: 'Trigger other automation workflows',
                    ),
                    _dialogOption(
                      'Send notification',
                      Icons.notifications,
                      () => Navigator.pop(context, 'Send notification'),
                      iconColor: Colors.orange,
                      description: 'Get a message on your device',
                    ),
                    _dialogOption(
                      'Delay the action',
                      Icons.timer,
                      () => Navigator.pop(context, 'Delay the action'),
                      iconColor: Colors.purple,
                      description: 'Wait before executing next tasks',
                    ),
                    _dialogOption(
                      'Set alarm',
                      Icons.alarm,
                      () => Navigator.pop(context, 'Set alarm'),
                      iconColor: Colors.red,
                      description: 'Schedule an alarm on your device',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Divider(color: Colors.grey[800], height: 1),
              InkWell(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  alignment: Alignment.center,
                  child: const Text(
                    'Cancel',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (result != null) {
      dynamic taskData;
      Widget? configScreen;

      switch (result) {
        case 'Run automations':
          configScreen = RunAutomationsScreen();
          break;
        case 'Send notification':
          configScreen = SendNotificationScreen();
          break;
        case 'Delay the action':
          configScreen = DelayActionScreen();
          break;
        case 'Set alarm':
          configScreen = SetAlarmScreen();
          break;
      }

      if (configScreen != null) {
        taskData = await Navigator.push(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) =>
                configScreen!,
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
              const begin = Offset(1.0, 0.0);
              const end = Offset.zero;
              const curve = Curves.easeInOutCubic;

              var tween =
                  Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
              var offsetAnimation = animation.drive(tween);

              return SlideTransition(position: offsetAnimation, child: child);
            },
            transitionDuration: const Duration(milliseconds: 300),
          ),
        );
      }

      if (taskData != null && mounted) {
        setState(() {
          final newTask = Task(
            icon: _getIconForTask(result),
            title: result,
            subtitle: _getTaskSubtitle(result, taskData),
            iconColor: _getColorForTask(result),
            data: taskData,
            id: const Uuid().v4(),
          );

          tasks.add(newTask);
          isEdited = true;
        });
      }
    }
  }

  // Helper to generate a meaningful subtitle based on task configuration
  String _getTaskSubtitle(String taskType, dynamic taskData) {
    if (taskData == null) return 'Configured';

    try {
      switch (taskType) {
        case 'Run devices':
          if (taskData['deviceName'] != null) {
            return 'Device: ${taskData['deviceName']}';
          }
          return 'Control devices';

        case 'Run automations':
          if (taskData['automationName'] != null) {
            return 'Run: ${taskData['automationName']}';
          }
          return 'Run automations';

        case 'Send notification':
          if (taskData['message'] != null) {
            final message = taskData['message'] as String;
            if (message.length > 25) {
              return '${message.substring(0, 22)}...';
            }
            return message;
          }
          return 'Send notification';

        case 'Delay the action':
          if (taskData['minutes'] != null) {
            final minutes = taskData['minutes'];
            return 'Wait for $minutes minutes';
          }
          return 'Delay execution';

        case 'Set alarm':
          if (taskData['time'] != null) {
            return 'Alarm at ${taskData['time']}';
          }
          return 'Set alarm';

        default:
          return 'Configured';
      }
    } catch (e) {
      debugPrint('Error parsing task data: $e');
      return 'Configured';
    }
  }

  // Helper functions to get icon for tasks
  IconData _getIconForTask(String taskType) {
    switch (taskType) {
      case 'Run devices':
        return Icons.devices;
      case 'Run automations':
        return Icons.autorenew;
      case 'Send notification':
        return Icons.notifications;
      case 'Delay the action':
        return Icons.timer;
      case 'Set alarm':
        return Icons.alarm;
      default:
        return Icons.settings;
    }
  }

  void _removeCondition(int index) {
    if (index >= 0 && index < conditions.length) {
      setState(() {
        conditions.removeAt(index);
        isEdited = true;
      });

      // Give haptic feedback for deletion
      HapticFeedback.mediumImpact();
    }
  }

  void _removeTask(int index) {
    if (index >= 0 && index < tasks.length) {
      setState(() {
        tasks.removeAt(index);
        isEdited = true;
      });

      // Give haptic feedback for deletion
      HapticFeedback.mediumImpact();
    }
  }

  void _reorderTasks(int oldIndex, int newIndex) {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }

    setState(() {
      final Task item = tasks.removeAt(oldIndex);
      tasks.insert(newIndex, item);
      isEdited = true;
    });

    // Give haptic feedback for reordering
    HapticFeedback.selectionClick();
  }

  Future<bool> _onWillPop() async {
    if (!isEdited) return true;

    final result = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
        child: AlertDialog(
          backgroundColor: AppColors.surface,
          elevation: 24,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(
              color: Colors.white.withOpacity(0.1),
              width: 1,
            ),
          ),
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 24),
              SizedBox(width: 12),
              Text(
                'Discard changes?',
                style: TextStyle(color: Colors.white, fontSize: 18),
              ),
            ],
          ),
          content: const Text(
            'You have unsaved changes. Are you sure you want to discard them?',
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              style: TextButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
              child: Text(
                'Cancel',
                style: TextStyle(color: Colors.grey[400]),
              ),
            ),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red[400],
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
              icon: const Icon(Icons.delete_outline, size: 18),
              label: const Text(
                'Discard',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: _buildAppBar(),
        body: _buildBody(),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: AppColors.background,
      elevation: 0,
      leading: Container(
        margin: const EdgeInsets.only(left: 8),
        child: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new,
              color: AppColors.white, size: 20),
          onPressed: () => Navigator.maybePop(context),
          splashRadius: 24,
        ),
      ),
      title: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.15),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Text(
          'STEP 2 / 2',
          style: TextStyle(
            color: AppColors.primary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.2,
          ),
        ),
      ),
      centerTitle: true,
      actions: [
        IconButton(
          icon: const Icon(Icons.help_outline, color: Colors.white, size: 20),
          onPressed: () => _showHelpModal(),
          splashRadius: 24,
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  void _showHelpModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          padding: const EdgeInsets.only(top: 20),
          decoration: BoxDecoration(
            color: AppColors.surface.withOpacity(0.95),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 20,
                offset: const Offset(0, -5),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[600],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.lightbulb_outline,
                  color: AppColors.primary,
                  size: 32,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Automation Tips',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    _buildTipRow(
                      Icons.add_circle_outline,
                      'Add conditions to trigger your automation',
                    ),
                    const SizedBox(height: 16),
                    _buildTipRow(
                      Icons.playlist_add_check,
                      'Add tasks to execute when conditions are met',
                    ),
                    const SizedBox(height: 16),
                    _buildTipRow(
                      Icons.drag_indicator,
                      'Reorder tasks by dragging them up or down',
                    ),
                    const SizedBox(height: 16),
                    _buildTipRow(
                      Icons.save,
                      'Save your automation to activate it',
                    ),
                    const SizedBox(height: 16),
                    _buildTipRow(
                      Icons.assignment,
                      'You\'ll see your automation in the Logs section',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),
              const Divider(height: 1, color: Colors.white24),
              InkWell(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  alignment: Alignment.center,
                  child: const Text(
                    'Got it',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTipRow(IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            color: AppColors.primary,
            size: 20,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBody() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.background,
            AppColors.background.withBlue(AppColors.background.blue + 15),
          ],
        ),
      ),
      child: Stack(
        children: [
          SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 12),
                      _buildHeader(),
                      const SizedBox(height: 32),
                      _buildSectionTitle(
                        'Conditions',
                        'Add condition',
                        _addCondition,
                        Icons.add_circle_outline,
                        'Set what triggers this automation',
                      ),
                      const SizedBox(height: 16),
                      _buildConditionsList(),
                      const SizedBox(height: 36),
                      _buildSectionTitle(
                        'Tasks',
                        'Add task',
                        _addTask,
                        Icons.add_task,
                        'Define what happens when triggered',
                      ),
                      const SizedBox(height: 16),
                      _buildTasksList(),
                      const SizedBox(height: 40),
                      _buildSaveButton(),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (_isLoading)
            BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
              child: Container(
                color: Colors.black.withOpacity(0.4),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 16,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(
                          valueColor:
                              AlwaysStoppedAnimation<Color>(AppColors.primary),
                          strokeWidth: 3,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Saving automation...',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.autorenew,
                color: AppColors.primary,
                size: 28,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                widget.title,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withOpacity(0.1),
              width: 1,
            ),
          ),
          child: const Text(
            'Configure your automation workflow',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white70,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(
    String title,
    String buttonText,
    VoidCallback onPressed,
    IconData buttonIcon,
    String subtitle,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            TextButton.icon(
              onPressed: onPressed,
              icon: Icon(
                buttonIcon,
                color: AppColors.primary,
                size: 18,
              ),
              label: Text(
                buttonText,
                style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              style: TextButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                backgroundColor: AppColors.primary.withOpacity(0.1),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildConditionsList() {
    if (conditions.isEmpty) {
      return _buildEmptyState(
        'No conditions added',
        'Add a condition to trigger your automation',
        Icons.schedule,
      );
    }

    return AnimatedSize(
      duration: const Duration(milliseconds: 300),
      child: Column(
        children: List.generate(conditions.length, (index) {
          final condition = conditions[index];
          return _buildCard(
            condition.icon,
            condition.title,
            condition.subtitle,
            condition.iconColor,
            () => _removeCondition(index),
            index: index,
            isCondition: true,
          );
        }),
      ),
    );
  }

  Widget _buildTasksList() {
    if (tasks.isEmpty) {
      return _buildEmptyState(
        'No tasks added',
        'Add a task to execute when conditions are met',
        Icons.assignment_outlined,
      );
    }

    return ReorderableList(
      itemCount: tasks.length,
      onReorder: _reorderTasks,
      itemBuilder: (context, index) {
        final task = tasks[index];
        return _buildCard(
          task.icon,
          task.title,
          task.subtitle,
          task.iconColor,
          () => _removeTask(index),
          index: index,
          isCondition: false,
          key: ValueKey(task.id ?? '$index'),
          showIndex: true,
        );
      },
      proxyDecorator: (child, index, animation) {
        return AnimatedBuilder(
          animation: animation,
          builder: (BuildContext context, Widget? child) {
            final double animValue =
                Curves.easeInOut.transform(animation.value);
            final double elevation = lerpDouble(0, 12, animValue)!;
            final double scale = 0.95 + (0.1 * animValue);

            return Transform.scale(
              scale: scale,
              child: Material(
                elevation: elevation,
                color: Colors.transparent,
                shadowColor: Colors.black.withOpacity(0.4),
                borderRadius: BorderRadius.circular(16),
                child: child,
              ),
            );
          },
          child: child,
        );
      },
    );
  }

  Widget _buildEmptyState(String title, String subtitle, IconData icon) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
      decoration: BoxDecoration(
        color: AppColors.surface.withOpacity(0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.cardBorder.withOpacity(0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 48,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 20),
          Text(
            title,
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildCard(
    IconData icon,
    String title,
    String subtitle,
    Color iconColor,
    VoidCallback onRemove, {
    int index = 0,
    bool isCondition = false,
    Key? key,
    bool showIndex = false,
  }) {
    return Container(
      key: key,
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: iconColor.withOpacity(0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Priority indicator for tasks
          if (showIndex && !isCondition)
            Positioned(
              top: 0,
              right: 0,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.2),
                  borderRadius: const BorderRadius.only(
                    topRight: Radius.circular(16),
                    bottomLeft: Radius.circular(10),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _getPriorityIcon(index, tasks.length),
                      color: AppColors.primary,
                      size: 14,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _getTaskPriorityText(index),
                      style: TextStyle(
                        color: AppColors.primary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Main content
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  // Could implement edit functionality here
                  // Will just show feedback for now
                  HapticFeedback.lightImpact();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Row(
                        children: [
                          Icon(Icons.info_outline,
                              color: Colors.white, size: 20),
                          const SizedBox(width: 12),
                          Text(
                            'Edit ${isCondition ? 'condition' : 'task'} (coming soon)',
                          ),
                        ],
                      ),
                      backgroundColor: AppColors.primary,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      margin: const EdgeInsets.all(16),
                      duration: const Duration(seconds: 1),
                      action: SnackBarAction(
                        label: 'OK',
                        textColor: Colors.white,
                        onPressed: () =>
                            ScaffoldMessenger.of(context).hideCurrentSnackBar(),
                      ),
                    ),
                  );
                },
                splashColor: iconColor.withOpacity(0.1),
                highlightColor: iconColor.withOpacity(0.05),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(16),
                    leading: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: iconColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(icon, color: iconColor, size: 24),
                    ),
                    title: Text(
                      title,
                      style: const TextStyle(
                        color: AppColors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        subtitle,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    trailing: IconButton(
                      icon: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.close_rounded, size: 16),
                      ),
                      color: Colors.red[300],
                      onPressed: onRemove,
                      splashRadius: 20,
                      tooltip: 'Remove',
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Reorder indicator for tasks
          if (!isCondition)
            Positioned(
              bottom: 12,
              right: 12,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Icon(
                  Icons.drag_handle,
                  size: 18,
                  color: Colors.grey.withOpacity(0.7),
                ),
              ),
            ),
        ],
      ),
    );
  }

  IconData _getPriorityIcon(int index, int total) {
    if (index == 0) return Icons.first_page;
    if (index == total - 1) return Icons.last_page;
    return Icons.more_horiz;
  }

  void _handleSave() async {
    if (conditions.isEmpty) {
      _showErrorSnackBar('Please add at least one condition');
      return;
    }

    if (tasks.isEmpty) {
      _showErrorSnackBar('Please add at least one task');
      return;
    }

    // Add haptic feedback
    HapticFeedback.mediumImpact();

    setState(() {
      _isLoading = true;
    });

    try {
      final automationsCollection =
          FirebaseFirestore.instance.collection('automations');

      // Add a unique ID to the schedule if it doesn't have one
      final scheduleId = widget.schedule?.id ?? const Uuid().v4();

      // Convert conditions and tasks to maps using model methods
      final conditionsMap = {
        'items': conditions.map((c) => c.toJson()).toList()
      };

      final tasksMap = {'items': tasks.map((t) => t.toJson()).toList()};

      // Create updated schedule with conditions and tasks
      final updatedSchedule = Schedule(
        id: scheduleId,
        days: widget.schedule!.days,
        time: widget.schedule!.time,
        period: widget.schedule!.period,
        date: widget.schedule!.date,
        conditions: conditionsMap,
        tasks: tasksMap,
        createdAt: widget.schedule!.createdAt ?? Timestamp.now(),
        updatedAt: Timestamp.now(),
      );

      // Log the JSON payload for inspection if in debug mode
      if (kDebugMode) {
        final scheduleJson = updatedSchedule.toJson();
        debugPrint("Saving schedule: $scheduleJson");
      }

      // Get the authenticated user
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      // Check if we're updating or creating
      DocumentReference docRef;
      if (widget.schedule?.id != null) {
        // Update existing automation
        docRef = automationsCollection.doc(widget.schedule!.id);
        await docRef.update(updatedSchedule.toJson());
      } else {
        // Create new automation
        docRef = automationsCollection.doc(scheduleId);
        await docRef.set({
          ...updatedSchedule.toJson(),
          'userId': currentUser.uid,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      // Calculate scheduled DateTime combining date and time from the schedule
      final taskDateTime = DateTime(
        updatedSchedule.date.year,
        updatedSchedule.date.month,
        updatedSchedule.date.day,
        updatedSchedule.time.hour,
        updatedSchedule.time.minute,
      );

      // Add notification record (5 minutes before scheduled time)
      final notificationTime =
          taskDateTime.subtract(const Duration(minutes: 5));

      await FirebaseFirestore.instance
          .collection('scheduled_notifications')
          .add({
        'userId': currentUser.uid,
        'scheduleId': scheduleId,
        'notificationTime': notificationTime,
        'message': 'Your automation will start in 5 minutes!',
        'title': widget.title,
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Add a log document
      await FirebaseFirestore.instance.collection('logs').add({
        'userId': currentUser.uid,
        'timestamp': Timestamp.fromDate(taskDateTime),
        'message':
            'Automation scheduled for ${_formatDate(updatedSchedule.date)} at ${_formatTime(updatedSchedule.time)}',
        'type': 'schedule',
        'automationId': scheduleId,
        'automationTitle': widget.title,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Show success animation and navigate
      if (mounted) {
        _showSuccessDialog();
      }
    } catch (e) {
      debugPrint('Error saving automation: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        _showErrorSnackBar('Error saving automation: $e');
      }
    }
  }

  // Format date for display (e.g., "May 5, 2025")
  String _formatDate(DateTime date) {
    return DateFormat.yMMMMd().format(date);
  }

  // Format time for display (e.g., "3:30 PM")
  String _formatTime(TimeOfDay time) {
    final now = DateTime.now();
    final dateTime = DateTime(
      now.year,
      now.month,
      now.day,
      time.hour,
      time.minute,
    );
    return DateFormat.jm().format(dateTime);
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.7),
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: Colors.white.withOpacity(0.1),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 24,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Success animation - could use a Lottie animation here
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_circle_outline,
                    color: Colors.green,
                    size: 56,
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Automation Saved!',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Your automation has been scheduled for ${_formatDate(widget.schedule!.date)} at ${widget.schedule!.time.format(context)}.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.of(context).pop();
                          Navigator.of(context).pop(widget.schedule);
                        },
                        icon: const Icon(Icons.arrow_back, size: 18),
                        label: const Text('Close'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.white24),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.of(context).pop();
                          Navigator.pushReplacement(
                            context,
                            PageRouteBuilder(
                              pageBuilder:
                                  (context, animation, secondaryAnimation) =>
                                      AutomationLogsScreen(),
                              transitionsBuilder: (context, animation,
                                  secondaryAnimation, child) {
                                const begin = Offset(1.0, 0.0);
                                const end = Offset.zero;
                                const curve = Curves.easeOutCubic;

                                var tween = Tween(begin: begin, end: end)
                                    .chain(CurveTween(curve: curve));
                                var offsetAnimation = animation.drive(tween);

                                return SlideTransition(
                                    position: offsetAnimation, child: child);
                              },
                              transitionDuration:
                                  const Duration(milliseconds: 400),
                            ),
                          );
                        },
                        icon: const Icon(Icons.assignment, size: 18),
                        label: const Text('View Logs'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.red.shade800,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'Dismiss',
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [
              AppColors.primary,
              Color.lerp(AppColors.primary, Colors.purpleAccent, 0.6) ??
                  AppColors.primary,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.4),
              blurRadius: 12,
              offset: const Offset(0, 6),
              spreadRadius: -2,
            ),
          ],
        ),
        child: ElevatedButton.icon(
          onPressed: _isLoading ? null : _handleSave,
          icon: _isLoading
              ? Container(
                  width: 20,
                  height: 20,
                  padding: const EdgeInsets.all(2),
                  child: const CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    strokeWidth: 2,
                  ),
                )
              : const Icon(Icons.save_alt, size: 20),
          label: Text(
            _isLoading ? 'Saving...' : 'Save Automation',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            disabledBackgroundColor: Colors.transparent,
            disabledForegroundColor: Colors.white70,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
        ),
      ),
    );
  }
}

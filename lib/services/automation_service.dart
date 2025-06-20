import 'package:cloud_firestore/cloud_firestore.dart';
import 'schedule.dart'; // Import the Schedule model

class AutomationService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<void> saveAutomation(
      Map<String, dynamic> automationData, Schedule schedule) async {
    // Serialize the schedule before saving
    automationData['schedule'] = schedule.toJson();
    await _db.collection('automations').add(automationData);
  }
}

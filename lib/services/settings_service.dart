import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SettingsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<void> updateUserSettings(Map<String, dynamic> settings) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('No authenticated user found');

      await _firestore
          .collection('users')
          .doc(user.uid)
          .set({'settings': settings}, SetOptions(merge: true));
    } catch (e) {
      throw _handleError(e);
    }
  }

  Stream<DocumentSnapshot> getUserSettings() {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('No authenticated user found');

      return _firestore
          .collection('users')
          .doc(user.uid)
          .snapshots()
          .handleError((error) {
        throw _handleError(error);
      });
    } catch (e) {
      throw _handleError(e);
    }
  }

  Exception _handleError(dynamic error) {
    print('Settings service error: $error');
    if (error is FirebaseException) {
      return Exception('Firebase error: ${error.message}');
    }
    return Exception('An unexpected error occurred: $error');
  }

  // Initialize default settings
  Future<void> initializeDefaultSettings() async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('No authenticated user found');

      final settingsDoc =
          await _firestore.collection('users').doc(user.uid).get();

      if (!settingsDoc.exists) {
        await updateUserSettings({
          'language': 'English',
          'notifications': true,
          'darkMode': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      throw _handleError(e);
    }
  }
}

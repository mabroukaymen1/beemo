import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:developer' as developer;

class FirebaseService {
  static final FirebaseService _instance = FirebaseService._internal();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  factory FirebaseService() {
    return _instance;
  }

  FirebaseService._internal();

  // User related methods
  User? get currentUser => _auth.currentUser;

  Future<DocumentSnapshot?> getCurrentUserProfile() async {
    final user = currentUser;
    if (user == null) return null;

    try {
      return await _firestore.collection('users').doc(user.uid).get();
    } catch (e) {
      developer.log('Error getting user profile', error: e);
      return null;
    }
  }

  Future<void> updateUserProfile(Map<String, dynamic> data) async {
    final user = currentUser;
    if (user == null) throw Exception('No user signed in');

    try {
      // Add timestamp to track when profile was last updated
      data['lastUpdated'] = FieldValue.serverTimestamp();

      await _firestore.collection('users').doc(user.uid).set({
        'name': data['name'],
        'email': data['email'],
        'isOnline': true,
        'lastSeen': FieldValue.serverTimestamp(),
        ...data,
      }, SetOptions(merge: true));
    } catch (e) {
      developer.log('Error updating user profile', error: e);
      throw Exception('Failed to update profile: $e');
    }
  }

  Future<void> updateUserOnlineStatus(bool isOnline) async {
    final user = currentUser;
    if (user != null) {
      try {
        await _firestore.collection('users').doc(user.uid).update({
          'isOnline': isOnline,
          'lastSeen': FieldValue.serverTimestamp(),
        });
      } catch (e) {
        developer.log('Error updating online status', error: e);
      }
    }
  }

  Stream<DocumentSnapshot> getUserStream(String userId) {
    return _firestore.collection('users').doc(userId).snapshots();
  }

  // Authentication methods
  Future<void> signOut() async {
    await _auth.signOut();
  }

  // Firestore stream methods
  Stream<QuerySnapshot> getCollectionStream(
    String collection, {
    List<Query Function(Query)> queryModifiers = const [],
  }) {
    Query query = _firestore.collection(collection);

    for (var modifier in queryModifiers) {
      query = modifier(query);
    }

    return query.snapshots();
  }

  // Generic document operations
  Future<void> setDocument(
    String collection,
    String? documentId,
    Map<String, dynamic> data, {
    bool merge = true,
  }) async {
    try {
      final docRef = documentId != null
          ? _firestore.collection(collection).doc(documentId)
          : _firestore.collection(collection).doc();

      await docRef.set(data, SetOptions(merge: merge));
    } catch (e) {
      developer.log('Error setting document', error: e);
      throw Exception('Failed to set document: $e');
    }
  }

  Future<void> updateDocument(
    String collection,
    String documentId,
    Map<String, dynamic> data,
  ) async {
    try {
      await _firestore.collection(collection).doc(documentId).update(data);
    } catch (e) {
      developer.log('Error updating document', error: e);
      throw Exception('Failed to update document: $e');
    }
  }

  Future<void> deleteDocument(String collection, String documentId) async {
    try {
      await _firestore.collection(collection).doc(documentId).delete();
    } catch (e) {
      developer.log('Error deleting document', error: e);
      throw Exception('Failed to delete document: $e');
    }
  }

  Future<DocumentSnapshot> getDocument(
    String collection,
    String documentId,
  ) async {
    try {
      return await _firestore.collection(collection).doc(documentId).get();
    } catch (e) {
      developer.log('Error getting document', error: e);
      throw Exception('Failed to get document: $e');
    }
  }

  // Transaction helper
  Future<void> runTransaction(
    Future<void> Function(Transaction) transactionHandler,
  ) async {
    try {
      await _firestore.runTransaction(transactionHandler);
    } catch (e) {
      developer.log('Error running transaction', error: e);
      throw Exception('Failed to complete transaction: $e');
    }
  }

  // Store data to specified collection.
  Future<void> storeData(String collection, Map<String, dynamic> data,
      {String? docId}) async {
    if (docId != null) {
      await _firestore.collection(collection).doc(docId).set(data);
    } else {
      await _firestore.collection(collection).add(data);
    }
  }

  // Retrieve data from specified collection.
  Stream<QuerySnapshot> getData(String collection) {
    return _firestore.collection(collection).snapshots();
  }
}

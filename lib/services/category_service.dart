import 'package:cloud_firestore/cloud_firestore.dart';
import '../home/qrcode/addevice.dart';

class CategoryService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> syncCategories() async {
    try {
      final batch = _firestore.batch();
      final collectionRef = _firestore.collection('deviceCategories');

      DeviceDataProvider.deviceTypes.forEach((key, deviceType) {
        final docRef = collectionRef.doc(key);
        batch.set(docRef, {
          'id': deviceType.id,
          'name': deviceType.name,
          'color': deviceType.color.value,
          'icon': deviceType.icon.codePoint,
          'devices': deviceType.devices
              .map((device) => {
                    'id': device.id,
                    'name': device.name,
                    'icon': device.icon.codePoint,
                    'description': device.description,
                  })
              .toList(),
        });
      });

      await batch.commit();
    } catch (e) {
      print('Error syncing categories: $e');
      rethrow;
    }
  }

  Stream<QuerySnapshot> categoriesStream() {
    return _firestore.collection('deviceCategories').snapshots();
  }
}

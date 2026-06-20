import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';

/// Uploads meal photos to Cloud Storage under meal_photos/{uid}/...
class StorageService {
  StorageService(this._storage);
  final FirebaseStorage _storage;

  Future<String> uploadMealPhoto(String uid, File file) async {
    final name = '${DateTime.now().millisecondsSinceEpoch}.jpg';
    final ref = _storage.ref('meal_photos/$uid/$name');
    final task = await ref.putFile(
      file,
      SettableMetadata(contentType: 'image/jpeg'),
    );
    return task.ref.getDownloadURL();
  }
}

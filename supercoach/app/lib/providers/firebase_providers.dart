import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../services/functions_service.dart';
import '../services/storage_service.dart';
import '../services/speech_service.dart';

// Raw Firebase singletons.
final firebaseAuthProvider = Provider((_) => FirebaseAuth.instance);
final firestoreProvider = Provider((_) => FirebaseFirestore.instance);
final storageProvider = Provider((_) => FirebaseStorage.instance);
final functionsProvider = Provider((_) => FirebaseFunctions.instance);

// Service wrappers.
final authServiceProvider =
    Provider((ref) => AuthService(ref.watch(firebaseAuthProvider)));
final firestoreServiceProvider =
    Provider((ref) => FirestoreService(ref.watch(firestoreProvider)));
final storageServiceProvider =
    Provider((ref) => StorageService(ref.watch(storageProvider)));
final functionsServiceProvider =
    Provider((ref) => FunctionsService(ref.watch(functionsProvider)));
final speechServiceProvider = Provider((_) => SpeechService());

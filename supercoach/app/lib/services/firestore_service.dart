import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/user_profile.dart';
import '../models/meal.dart';
import '../models/workout.dart';
import '../models/chat_message.dart';

/// All Firestore reads/writes for a single user live here.
class FirestoreService {
  FirestoreService(this._db);
  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> _userDoc(String uid) =>
      _db.collection('users').doc(uid);

  CollectionReference<Map<String, dynamic>> _meals(String uid) =>
      _userDoc(uid).collection('meals');
  CollectionReference<Map<String, dynamic>> _workouts(String uid) =>
      _userDoc(uid).collection('workouts');
  CollectionReference<Map<String, dynamic>> _chat(String uid) =>
      _userDoc(uid).collection('chat');

  // ---- Profile ----
  Stream<UserProfile> watchProfile(String uid) =>
      _userDoc(uid).snapshots().map(UserProfile.fromDoc);

  Future<void> ensureProfile(String uid, {String? email, String? name}) async {
    final snap = await _userDoc(uid).get();
    if (!snap.exists) {
      await _userDoc(uid).set({
        'email': email,
        'displayName': name,
        'onboardingComplete': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }

  Future<void> saveProfile(UserProfile profile) =>
      _userDoc(profile.uid).set(profile.toMap(), SetOptions(merge: true));

  /// Partial merge of arbitrary profile fields (used by onboarding).
  Future<void> mergeProfile(String uid, Map<String, dynamic> patch) =>
      _userDoc(uid).set(patch, SetOptions(merge: true));

  Future<void> updateFcmToken(String uid, String token) =>
      _userDoc(uid).set({'fcmToken': token}, SetOptions(merge: true));

  // ---- Meals ----
  Stream<List<Meal>> watchMealsForDay(String uid, DateTime day) {
    final start = DateTime(day.year, day.month, day.day);
    final end = start.add(const Duration(days: 1));
    return _meals(uid)
        .where('timestamp',
            isGreaterThanOrEqualTo: Timestamp.fromDate(start),
            isLessThan: Timestamp.fromDate(end))
        .orderBy('timestamp')
        .snapshots()
        .map((s) => s.docs.map(Meal.fromDoc).toList());
  }

  Future<void> addMeal(String uid, Meal meal) =>
      _meals(uid).add(meal.toMap());

  // ---- Workouts ----
  Stream<List<Workout>> watchWorkoutsForDay(String uid, DateTime day) {
    final start = DateTime(day.year, day.month, day.day);
    final end = start.add(const Duration(days: 1));
    return _workouts(uid)
        .where('timestamp',
            isGreaterThanOrEqualTo: Timestamp.fromDate(start),
            isLessThan: Timestamp.fromDate(end))
        .orderBy('timestamp')
        .snapshots()
        .map((s) => s.docs.map(Workout.fromDoc).toList());
  }

  Future<void> addWorkout(String uid, Workout workout) =>
      _workouts(uid).add(workout.toMap());

  // ---- Chat ----
  Stream<List<ChatMessage>> watchChat(String uid, {int limit = 100}) =>
      _chat(uid)
          .orderBy('timestamp')
          .limitToLast(limit)
          .snapshots()
          .map((s) => s.docs.map(ChatMessage.fromDoc).toList());

  Future<void> addChatMessage(String uid, ChatMessage message) =>
      _chat(uid).add(message.toMap());
}

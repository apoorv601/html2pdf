import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/user_profile.dart';
import 'auth_provider.dart';
import 'firebase_providers.dart';

/// Streams the signed-in user's profile document.
final profileProvider = StreamProvider<UserProfile?>((ref) {
  final uid = ref.watch(uidProvider);
  if (uid == null) return Stream.value(null);
  return ref.watch(firestoreServiceProvider).watchProfile(uid);
});

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/chat_message.dart';
import 'auth_provider.dart';
import 'firebase_providers.dart';

/// Streams the persistent coach chat thread.
final chatProvider = StreamProvider<List<ChatMessage>>((ref) {
  final uid = ref.watch(uidProvider);
  if (uid == null) return Stream.value(const []);
  return ref.watch(firestoreServiceProvider).watchChat(uid);
});

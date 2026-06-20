import 'package:cloud_firestore/cloud_firestore.dart';

class ChatMessage {
  final String id;
  final String role; // "user" | "coach"
  final String text;
  final DateTime timestamp;

  const ChatMessage({
    required this.id,
    required this.role,
    required this.text,
    required this.timestamp,
  });

  bool get isUser => role == 'user';

  factory ChatMessage.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? <String, dynamic>{};
    return ChatMessage(
      id: doc.id,
      role: d['role'] as String? ?? 'coach',
      text: d['text'] as String? ?? '',
      timestamp: (d['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
        'role': role,
        'text': text,
        'timestamp': Timestamp.fromDate(timestamp),
      };
}

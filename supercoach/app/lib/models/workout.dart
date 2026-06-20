import 'package:cloud_firestore/cloud_firestore.dart';

class Workout {
  final String id;
  final String activity; // "running", "strength", etc.
  final DateTime timestamp;
  final int durationMin;
  final int caloriesBurned;
  final String? rawInput;
  final String source; // "manual" | "health"

  const Workout({
    required this.id,
    required this.activity,
    required this.timestamp,
    required this.durationMin,
    required this.caloriesBurned,
    this.rawInput,
    this.source = 'manual',
  });

  factory Workout.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? <String, dynamic>{};
    return Workout(
      id: doc.id,
      activity: d['activity'] as String? ?? 'Workout',
      timestamp: (d['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      durationMin: (d['durationMin'] as num?)?.toInt() ?? 0,
      caloriesBurned: (d['caloriesBurned'] as num?)?.toInt() ?? 0,
      rawInput: d['rawInput'] as String?,
      source: d['source'] as String? ?? 'manual',
    );
  }

  Map<String, dynamic> toMap() => {
        'activity': activity,
        'timestamp': Timestamp.fromDate(timestamp),
        'durationMin': durationMin,
        'caloriesBurned': caloriesBurned,
        'rawInput': rawInput,
        'source': source,
      };
}

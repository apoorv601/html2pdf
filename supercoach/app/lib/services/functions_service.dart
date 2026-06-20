import 'package:cloud_functions/cloud_functions.dart';

import '../models/meal.dart';
import '../models/workout.dart';

/// Calls the Gemini-backed Cloud Functions. The app NEVER talks to Gemini
/// directly — all AI calls go through Cloud Functions so the API key stays
/// server-side.
class FunctionsService {
  FunctionsService(this._functions);
  final FirebaseFunctions _functions;

  /// Estimate a meal from free text and/or a photo URL.
  /// Returns the AI's best guess as a list of [FoodItem]s + confidence.
  Future<({List<FoodItem> items, double confidence})> estimateMeal({
    String? text,
    String? photoUrl,
  }) async {
    final res = await _functions.httpsCallable('estimateMeal').call({
      'text': text,
      'photoUrl': photoUrl,
    });
    final data = Map<String, dynamic>.from(res.data as Map);
    final items = ((data['items'] as List?) ?? [])
        .map((e) => FoodItem.fromMap(Map<String, dynamic>.from(e)))
        .toList();
    return (
      items: items,
      confidence: (data['confidence'] as num?)?.toDouble() ?? 0,
    );
  }

  /// Estimate a workout from free text like "ran 3km in 25 min".
  Future<Workout> estimateWorkout({required String text}) async {
    final res = await _functions.httpsCallable('estimateWorkout').call({
      'text': text,
    });
    final d = Map<String, dynamic>.from(res.data as Map);
    return Workout(
      id: '',
      activity: d['activity'] as String? ?? 'Workout',
      timestamp: DateTime.now(),
      durationMin: (d['durationMin'] as num?)?.toInt() ?? 0,
      caloriesBurned: (d['caloriesBurned'] as num?)?.toInt() ?? 0,
      rawInput: text,
    );
  }

  /// Send a chat message to the coach; returns the coach's reply text.
  /// The function pulls profile + recent stats + history server-side.
  Future<String> coachChat({required String message}) async {
    final res = await _functions.httpsCallable('coachChat').call({
      'message': message,
    });
    final d = Map<String, dynamic>.from(res.data as Map);
    return d['reply'] as String? ?? '';
  }

  /// Run the onboarding interview turn-by-turn. Pass the full transcript so
  /// far; the coach replies and, when it has enough info, returns a structured
  /// profile patch + done=true.
  Future<({String reply, bool done, Map<String, dynamic>? profilePatch})>
      onboardingTurn({
    required List<Map<String, String>> transcript,
  }) async {
    final res = await _functions.httpsCallable('onboardingTurn').call({
      'transcript': transcript,
    });
    final d = Map<String, dynamic>.from(res.data as Map);
    return (
      reply: d['reply'] as String? ?? '',
      done: d['done'] as bool? ?? false,
      profilePatch: d['profilePatch'] == null
          ? null
          : Map<String, dynamic>.from(d['profilePatch'] as Map),
    );
  }
}

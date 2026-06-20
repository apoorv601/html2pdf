import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/daily_stats.dart';
import '../models/meal.dart';
import '../models/workout.dart';
import 'auth_provider.dart';
import 'firebase_providers.dart';
import 'profile_provider.dart';

final _mealsTodayProvider = StreamProvider<List<Meal>>((ref) {
  final uid = ref.watch(uidProvider);
  if (uid == null) return Stream.value(const []);
  return ref
      .watch(firestoreServiceProvider)
      .watchMealsForDay(uid, DateTime.now());
});

final _workoutsTodayProvider = StreamProvider<List<Workout>>((ref) {
  final uid = ref.watch(uidProvider);
  if (uid == null) return Stream.value(const []);
  return ref
      .watch(firestoreServiceProvider)
      .watchWorkoutsForDay(uid, DateTime.now());
});

/// Combines today's meals, workouts and the calorie target into [DailyStats].
final dailyStatsProvider = Provider<DailyStats>((ref) {
  final meals = ref.watch(_mealsTodayProvider).asData?.value ?? const [];
  final workouts = ref.watch(_workoutsTodayProvider).asData?.value ?? const [];
  final target =
      ref.watch(profileProvider).asData?.value?.dailyCalorieTarget;
  return DailyStats(
    day: DateTime.now(),
    meals: meals,
    workouts: workouts,
    calorieTarget: target,
  );
});

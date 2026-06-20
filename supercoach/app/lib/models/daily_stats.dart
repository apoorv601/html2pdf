import 'meal.dart';
import 'workout.dart';

/// Client-side roll-up of a single day's meals + workouts, used by the
/// dashboard. (A server-maintained mirror lives in Firestore at
/// users/{uid}/dailyStats/{yyyy-mm-dd} for fast reads / notifications.)
class DailyStats {
  final DateTime day;
  final List<Meal> meals;
  final List<Workout> workouts;
  final int? calorieTarget;

  const DailyStats({
    required this.day,
    this.meals = const [],
    this.workouts = const [],
    this.calorieTarget,
  });

  int get caloriesIn => meals.fold(0, (s, m) => s + m.totalCalories);
  int get caloriesOut => workouts.fold(0, (s, w) => s + w.caloriesBurned);
  int get netCalories => caloriesIn - caloriesOut;

  double get protein => meals.fold(0.0, (s, m) => s + m.totalProtein);
  double get carbs => meals.fold(0.0, (s, m) => s + m.totalCarbs);
  double get fat => meals.fold(0.0, (s, m) => s + m.totalFat);

  bool get hasWorkout => workouts.isNotEmpty;

  bool hasMeal(MealType type) => meals.any((m) => m.type == type);

  /// 0..1 progress toward the calorie target (capped at 1).
  double get calorieProgress {
    final target = calorieTarget ?? 2000;
    if (target <= 0) return 0;
    return (caloriesIn / target).clamp(0.0, 1.0);
  }
}

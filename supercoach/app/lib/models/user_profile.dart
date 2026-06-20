import 'package:cloud_firestore/cloud_firestore.dart';

/// A preferred daily time window (stored as "HH:mm").
class TimeWindow {
  final String label; // e.g. "Breakfast", "Workout"
  final String time; // "08:00"

  const TimeWindow({required this.label, required this.time});

  factory TimeWindow.fromMap(Map<String, dynamic> m) =>
      TimeWindow(label: m['label'] as String, time: m['time'] as String);

  Map<String, dynamic> toMap() => {'label': label, 'time': time};
}

enum Goal { loseFat, buildMuscle, stayFit, improveStamina }

extension GoalLabel on Goal {
  String get label => switch (this) {
        Goal.loseFat => 'Lose fat',
        Goal.buildMuscle => 'Build muscle',
        Goal.stayFit => 'Stay fit',
        Goal.improveStamina => 'Improve stamina',
      };
}

class UserProfile {
  final String uid;
  final String? displayName;
  final String? email;

  // Body metrics
  final int? age;
  final String? sex; // "male" | "female" | "other"
  final double? heightCm;
  final double? weightKg;
  final double? targetWeightKg;

  // Coaching
  final Goal? goal;
  final String fitnessLevel; // "beginner" | "intermediate" | "advanced"
  final int? dailyCalorieTarget;
  final List<TimeWindow> mealWindows;
  final List<String> workoutDays; // ["Mon","Wed","Fri"]
  final TimeWindow? workoutWindow;
  final List<String> dietaryRestrictions;
  final String? equipment; // "home" | "gym" | "none"
  final String? notes; // injuries / constraints

  // Notification prefs
  final String quietHoursStart; // "22:00"
  final String quietHoursEnd; // "07:00"
  final bool notificationsEnabled;
  final String? fcmToken;

  final bool onboardingComplete;

  const UserProfile({
    required this.uid,
    this.displayName,
    this.email,
    this.age,
    this.sex,
    this.heightCm,
    this.weightKg,
    this.targetWeightKg,
    this.goal,
    this.fitnessLevel = 'beginner',
    this.dailyCalorieTarget,
    this.mealWindows = const [],
    this.workoutDays = const [],
    this.workoutWindow,
    this.dietaryRestrictions = const [],
    this.equipment,
    this.notes,
    this.quietHoursStart = '22:00',
    this.quietHoursEnd = '07:00',
    this.notificationsEnabled = true,
    this.fcmToken,
    this.onboardingComplete = false,
  });

  factory UserProfile.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? <String, dynamic>{};
    return UserProfile(
      uid: doc.id,
      displayName: d['displayName'] as String?,
      email: d['email'] as String?,
      age: (d['age'] as num?)?.toInt(),
      sex: d['sex'] as String?,
      heightCm: (d['heightCm'] as num?)?.toDouble(),
      weightKg: (d['weightKg'] as num?)?.toDouble(),
      targetWeightKg: (d['targetWeightKg'] as num?)?.toDouble(),
      goal: d['goal'] != null
          ? Goal.values.firstWhere((g) => g.name == d['goal'],
              orElse: () => Goal.stayFit)
          : null,
      fitnessLevel: d['fitnessLevel'] as String? ?? 'beginner',
      dailyCalorieTarget: (d['dailyCalorieTarget'] as num?)?.toInt(),
      mealWindows: ((d['mealWindows'] as List?) ?? [])
          .map((e) => TimeWindow.fromMap(Map<String, dynamic>.from(e)))
          .toList(),
      workoutDays: List<String>.from(d['workoutDays'] ?? const []),
      workoutWindow: d['workoutWindow'] != null
          ? TimeWindow.fromMap(Map<String, dynamic>.from(d['workoutWindow']))
          : null,
      dietaryRestrictions:
          List<String>.from(d['dietaryRestrictions'] ?? const []),
      equipment: d['equipment'] as String?,
      notes: d['notes'] as String?,
      quietHoursStart: d['quietHoursStart'] as String? ?? '22:00',
      quietHoursEnd: d['quietHoursEnd'] as String? ?? '07:00',
      notificationsEnabled: d['notificationsEnabled'] as bool? ?? true,
      fcmToken: d['fcmToken'] as String?,
      onboardingComplete: d['onboardingComplete'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() => {
        'displayName': displayName,
        'email': email,
        'age': age,
        'sex': sex,
        'heightCm': heightCm,
        'weightKg': weightKg,
        'targetWeightKg': targetWeightKg,
        'goal': goal?.name,
        'fitnessLevel': fitnessLevel,
        'dailyCalorieTarget': dailyCalorieTarget,
        'mealWindows': mealWindows.map((e) => e.toMap()).toList(),
        'workoutDays': workoutDays,
        'workoutWindow': workoutWindow?.toMap(),
        'dietaryRestrictions': dietaryRestrictions,
        'equipment': equipment,
        'notes': notes,
        'quietHoursStart': quietHoursStart,
        'quietHoursEnd': quietHoursEnd,
        'notificationsEnabled': notificationsEnabled,
        'fcmToken': fcmToken,
        'onboardingComplete': onboardingComplete,
      };

  UserProfile copyWith({
    String? displayName,
    int? age,
    String? sex,
    double? heightCm,
    double? weightKg,
    double? targetWeightKg,
    Goal? goal,
    String? fitnessLevel,
    int? dailyCalorieTarget,
    List<TimeWindow>? mealWindows,
    List<String>? workoutDays,
    TimeWindow? workoutWindow,
    List<String>? dietaryRestrictions,
    String? equipment,
    String? notes,
    String? fcmToken,
    bool? onboardingComplete,
  }) {
    return UserProfile(
      uid: uid,
      displayName: displayName ?? this.displayName,
      email: email,
      age: age ?? this.age,
      sex: sex ?? this.sex,
      heightCm: heightCm ?? this.heightCm,
      weightKg: weightKg ?? this.weightKg,
      targetWeightKg: targetWeightKg ?? this.targetWeightKg,
      goal: goal ?? this.goal,
      fitnessLevel: fitnessLevel ?? this.fitnessLevel,
      dailyCalorieTarget: dailyCalorieTarget ?? this.dailyCalorieTarget,
      mealWindows: mealWindows ?? this.mealWindows,
      workoutDays: workoutDays ?? this.workoutDays,
      workoutWindow: workoutWindow ?? this.workoutWindow,
      dietaryRestrictions: dietaryRestrictions ?? this.dietaryRestrictions,
      equipment: equipment ?? this.equipment,
      notes: notes ?? this.notes,
      quietHoursStart: quietHoursStart,
      quietHoursEnd: quietHoursEnd,
      notificationsEnabled: notificationsEnabled,
      fcmToken: fcmToken ?? this.fcmToken,
      onboardingComplete: onboardingComplete ?? this.onboardingComplete,
    );
  }
}

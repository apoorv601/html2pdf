import 'package:cloud_firestore/cloud_firestore.dart';

/// One estimated food item within a meal.
class FoodItem {
  final String name;
  final String portion; // free text, e.g. "1 cup", "2 rotis"
  final int calories;
  final double protein; // grams
  final double carbs;
  final double fat;

  const FoodItem({
    required this.name,
    required this.portion,
    required this.calories,
    this.protein = 0,
    this.carbs = 0,
    this.fat = 0,
  });

  factory FoodItem.fromMap(Map<String, dynamic> m) => FoodItem(
        name: m['name'] as String? ?? 'Food',
        portion: m['portion'] as String? ?? '',
        calories: (m['calories'] as num?)?.toInt() ?? 0,
        protein: (m['protein'] as num?)?.toDouble() ?? 0,
        carbs: (m['carbs'] as num?)?.toDouble() ?? 0,
        fat: (m['fat'] as num?)?.toDouble() ?? 0,
      );

  Map<String, dynamic> toMap() => {
        'name': name,
        'portion': portion,
        'calories': calories,
        'protein': protein,
        'carbs': carbs,
        'fat': fat,
      };
}

enum MealType { breakfast, lunch, dinner, snack }

class Meal {
  final String id;
  final MealType type;
  final DateTime timestamp;
  final String? rawInput; // what the user typed/said
  final String? photoUrl;
  final List<FoodItem> items;
  final double confidence; // 0..1 from the AI estimate
  final bool userConfirmed;

  const Meal({
    required this.id,
    required this.type,
    required this.timestamp,
    this.rawInput,
    this.photoUrl,
    this.items = const [],
    this.confidence = 0,
    this.userConfirmed = false,
  });

  int get totalCalories =>
      items.fold(0, (sum, i) => sum + i.calories);
  double get totalProtein =>
      items.fold(0.0, (sum, i) => sum + i.protein);
  double get totalCarbs => items.fold(0.0, (sum, i) => sum + i.carbs);
  double get totalFat => items.fold(0.0, (sum, i) => sum + i.fat);

  factory Meal.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? <String, dynamic>{};
    return Meal(
      id: doc.id,
      type: MealType.values.firstWhere(
        (t) => t.name == d['type'],
        orElse: () => MealType.snack,
      ),
      timestamp: (d['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      rawInput: d['rawInput'] as String?,
      photoUrl: d['photoUrl'] as String?,
      items: ((d['items'] as List?) ?? [])
          .map((e) => FoodItem.fromMap(Map<String, dynamic>.from(e)))
          .toList(),
      confidence: (d['confidence'] as num?)?.toDouble() ?? 0,
      userConfirmed: d['userConfirmed'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() => {
        'type': type.name,
        'timestamp': Timestamp.fromDate(timestamp),
        'rawInput': rawInput,
        'photoUrl': photoUrl,
        'items': items.map((e) => e.toMap()).toList(),
        'confidence': confidence,
        'userConfirmed': userConfirmed,
        'totalCalories': totalCalories,
      };
}

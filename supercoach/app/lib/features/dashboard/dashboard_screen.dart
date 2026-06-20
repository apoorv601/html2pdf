import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../models/daily_stats.dart';
import '../../models/meal.dart';
import '../../providers/auth_provider.dart';
import '../../providers/dashboard_provider.dart';
import '../../providers/firebase_providers.dart';
import '../../providers/profile_provider.dart';
import '../../services/notification_service.dart';
import '../../widgets/calorie_ring.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    // Register this device for push notifications once we're on the dashboard.
    WidgetsBinding.instance.addPostFrameCallback((_) => _registerFcm());
  }

  Future<void> _registerFcm() async {
    final uid = ref.read(uidProvider);
    if (uid == null) return;
    try {
      final token = await NotificationService.instance.getToken();
      if (token != null) {
        await ref.read(firestoreServiceProvider).updateFcmToken(uid, token);
      }
    } catch (_) {
      // Messaging may be unsupported (e.g. iOS simulator) — ignore.
    }
  }

  @override
  Widget build(BuildContext context) {
    final stats = ref.watch(dailyStatsProvider);
    final profile = ref.watch(profileProvider).asData?.value;
    final name = profile?.displayName?.split(' ').first ?? 'there';
    final target = profile?.dailyCalorieTarget ?? 2000;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Today'),
        actions: [
          IconButton(
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout),
            onPressed: () => ref.read(authServiceProvider).signOut(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/chat'),
        icon: const Icon(Icons.chat_bubble),
        label: const Text('Coach'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
          children: [
            Text('Hi $name 👋',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold)),
            Text(DateFormat('EEEE, MMM d').format(DateTime.now()),
                style: TextStyle(color: Colors.grey.shade600)),
            const SizedBox(height: 16),
            Center(
              child: CalorieRing(
                consumed: stats.caloriesIn,
                target: target,
                burned: stats.caloriesOut,
              ),
            ),
            const SizedBox(height: 16),
            _MacrosCard(
              protein: stats.protein,
              carbs: stats.carbs,
              fat: stats.fat,
            ),
            const SizedBox(height: 12),
            _MealsCard(stats: stats),
            const SizedBox(height: 12),
            _WorkoutCard(
                hasWorkout: stats.hasWorkout, burned: stats.caloriesOut),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => context.push('/log-meal'),
                    icon: const Icon(Icons.restaurant),
                    label: const Text('Log meal'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.tonalIcon(
                    onPressed: () => context.push('/log-workout'),
                    icon: const Icon(Icons.directions_run),
                    label: const Text('Log workout'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MacrosCard extends StatelessWidget {
  final double protein, carbs, fat;
  const _MacrosCard(
      {required this.protein, required this.carbs, required this.fat});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _Macro(label: 'Protein', grams: protein, color: Colors.blue),
            _Macro(label: 'Carbs', grams: carbs, color: Colors.orange),
            _Macro(label: 'Fat', grams: fat, color: Colors.purple),
          ],
        ),
      ),
    );
  }
}

class _Macro extends StatelessWidget {
  final String label;
  final double grams;
  final Color color;
  const _Macro(
      {required this.label, required this.grams, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text('${grams.round()}g',
            style: TextStyle(
                fontSize: 20, fontWeight: FontWeight.bold, color: color)),
        Text(label, style: TextStyle(color: Colors.grey.shade600)),
      ],
    );
  }
}

class _MealsCard extends StatelessWidget {
  final DailyStats stats;
  const _MealsCard({required this.stats});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Meals',
                style:
                    TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: MealType.values.map((t) {
                final logged = stats.hasMeal(t);
                return Chip(
                  avatar: Icon(
                    logged ? Icons.check_circle : Icons.radio_button_unchecked,
                    size: 18,
                    color: logged ? Colors.green : Colors.grey,
                  ),
                  label: Text(_label(t)),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  String _label(MealType t) =>
      t.name[0].toUpperCase() + t.name.substring(1);
}

class _WorkoutCard extends StatelessWidget {
  final bool hasWorkout;
  final int burned;
  const _WorkoutCard({required this.hasWorkout, required this.burned});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(
          hasWorkout ? Icons.check_circle : Icons.directions_run,
          color: hasWorkout ? Colors.green : Colors.grey,
        ),
        title: const Text('Exercise'),
        subtitle: Text(hasWorkout
            ? '$burned kcal burned today — nice work!'
            : "No workout logged yet today"),
      ),
    );
  }
}

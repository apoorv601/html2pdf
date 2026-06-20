import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/workout.dart';
import '../../providers/auth_provider.dart';
import '../../providers/firebase_providers.dart';

/// Log a workout via text/voice. Gemini estimates activity, duration and
/// calories burned; the user can adjust before saving.
class LogWorkoutScreen extends ConsumerStatefulWidget {
  const LogWorkoutScreen({super.key});

  @override
  ConsumerState<LogWorkoutScreen> createState() => _LogWorkoutScreenState();
}

class _LogWorkoutScreenState extends ConsumerState<LogWorkoutScreen> {
  final _textController = TextEditingController();
  final _activityController = TextEditingController();
  final _durationController = TextEditingController();
  final _caloriesController = TextEditingController();
  bool _listening = false;
  bool _estimating = false;
  bool _saving = false;
  bool _hasEstimate = false;

  @override
  void dispose() {
    _textController.dispose();
    _activityController.dispose();
    _durationController.dispose();
    _caloriesController.dispose();
    super.dispose();
  }

  Future<void> _toggleVoice() async {
    final speech = ref.read(speechServiceProvider);
    if (_listening) {
      await speech.stop();
      setState(() => _listening = false);
      return;
    }
    final ok = await speech.init();
    if (!ok) return;
    setState(() => _listening = true);
    await speech.listen(
      onResult: (t) => setState(() => _textController.text = t),
      onDone: () => setState(() => _listening = false),
    );
  }

  Future<void> _estimate() async {
    if (_textController.text.trim().isEmpty) return;
    setState(() => _estimating = true);
    try {
      final w = await ref
          .read(functionsServiceProvider)
          .estimateWorkout(text: _textController.text.trim());
      setState(() {
        _activityController.text = w.activity;
        _durationController.text = w.durationMin.toString();
        _caloriesController.text = w.caloriesBurned.toString();
        _hasEstimate = true;
      });
    } catch (e) {
      _snack('Could not estimate: $e');
    } finally {
      if (mounted) setState(() => _estimating = false);
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final uid = ref.read(uidProvider)!;
      final workout = Workout(
        id: '',
        activity: _activityController.text.trim().isEmpty
            ? 'Workout'
            : _activityController.text.trim(),
        timestamp: DateTime.now(),
        durationMin: int.tryParse(_durationController.text) ?? 0,
        caloriesBurned: int.tryParse(_caloriesController.text) ?? 0,
        rawInput: _textController.text.trim(),
      );
      await ref.read(firestoreServiceProvider).addWorkout(uid, workout);
      if (mounted) context.pop();
    } catch (e) {
      _snack('Could not save: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _snack(String m) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Log workout')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextField(
              controller: _textController,
              minLines: 2,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'e.g. "ran 3km in 25 minutes" or "45 min weights"',
                suffixIcon: IconButton(
                  icon: Icon(_listening ? Icons.mic : Icons.mic_none,
                      color: _listening ? Colors.red : null),
                  onPressed: _toggleVoice,
                ),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _estimating ? null : _estimate,
              icon: _estimating
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.auto_awesome),
              label: Text(_estimating ? 'Estimating…' : 'Estimate'),
            ),
            if (_hasEstimate) ...[
              const SizedBox(height: 20),
              TextField(
                controller: _activityController,
                decoration: const InputDecoration(labelText: 'Activity'),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _durationController,
                      keyboardType: TextInputType.number,
                      decoration:
                          const InputDecoration(labelText: 'Minutes'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _caloriesController,
                      keyboardType: TextInputType.number,
                      decoration:
                          const InputDecoration(labelText: 'Calories burned'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _saving ? null : _save,
                child: Text(_saving ? 'Saving…' : 'Save workout'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

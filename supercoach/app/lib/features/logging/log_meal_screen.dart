import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../models/meal.dart';
import '../../providers/auth_provider.dart';
import '../../providers/firebase_providers.dart';

/// Log a meal via photo, voice, or text. Gemini estimates the food + calories;
/// the user reviews/edits before saving.
class LogMealScreen extends ConsumerStatefulWidget {
  const LogMealScreen({super.key});

  @override
  ConsumerState<LogMealScreen> createState() => _LogMealScreenState();
}

class _LogMealScreenState extends ConsumerState<LogMealScreen> {
  MealType _type = _defaultMealType();
  final _textController = TextEditingController();
  File? _photo;
  String? _uploadedPhotoUrl; // cached after first upload to avoid re-uploading
  bool _estimating = false;
  bool _listening = false;
  List<FoodItem> _items = [];
  double _confidence = 0;
  bool _saving = false;

  static MealType _defaultMealType() {
    final h = DateTime.now().hour;
    if (h < 11) return MealType.breakfast;
    if (h < 15) return MealType.lunch;
    if (h < 21) return MealType.dinner;
    return MealType.snack;
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto(ImageSource source) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: source,
      imageQuality: 70,
      maxWidth: 1280,
    );
    if (picked != null) {
      setState(() {
        _photo = File(picked.path);
        _uploadedPhotoUrl = null; // new photo → must re-upload
      });
    }
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
      onResult: (text) => setState(() => _textController.text = text),
      onDone: () => setState(() => _listening = false),
    );
  }

  Future<void> _estimate() async {
    if (_photo == null && _textController.text.trim().isEmpty) return;
    setState(() => _estimating = true);
    try {
      final uid = ref.read(uidProvider)!;
      String? photoUrl = _uploadedPhotoUrl;
      if (_photo != null && photoUrl == null) {
        photoUrl = await ref
            .read(storageServiceProvider)
            .uploadMealPhoto(uid, _photo!);
        _uploadedPhotoUrl = photoUrl;
      }
      final res = await ref.read(functionsServiceProvider).estimateMeal(
            text: _textController.text.trim().isEmpty
                ? null
                : _textController.text.trim(),
            photoUrl: photoUrl,
          );
      setState(() {
        _items = res.items;
        _confidence = res.confidence;
      });
    } catch (e) {
      _snack('Could not estimate: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _estimating = false);
    }
  }

  Future<void> _save() async {
    if (_items.isEmpty) return;
    setState(() => _saving = true);
    try {
      final uid = ref.read(uidProvider)!;
      String? photoUrl = _uploadedPhotoUrl;
      if (_photo != null && photoUrl == null) {
        photoUrl = await ref
            .read(storageServiceProvider)
            .uploadMealPhoto(uid, _photo!);
        _uploadedPhotoUrl = photoUrl;
      }
      final meal = Meal(
        id: '',
        type: _type,
        timestamp: DateTime.now(),
        rawInput: _textController.text.trim().isEmpty
            ? null
            : _textController.text.trim(),
        photoUrl: photoUrl,
        items: _items,
        confidence: _confidence,
        userConfirmed: true,
      );
      await ref.read(firestoreServiceProvider).addMeal(uid, meal);
      if (mounted) context.pop();
    } catch (e) {
      _snack('Could not save: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _snack(String msg) {
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  int get _totalCalories => _items.fold(0, (s, i) => s + i.calories);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Log meal')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Meal type selector
            SegmentedButton<MealType>(
              segments: MealType.values
                  .map((t) => ButtonSegment(
                        value: t,
                        label: Text(
                            t.name[0].toUpperCase() + t.name.substring(1)),
                      ))
                  .toList(),
              selected: {_type},
              onSelectionChanged: (s) => setState(() => _type = s.first),
              showSelectedIcon: false,
            ),
            const SizedBox(height: 16),

            if (_photo != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.file(_photo!,
                    height: 180, width: double.infinity, fit: BoxFit.cover),
              ),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pickPhoto(ImageSource.camera),
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('Camera'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pickPhoto(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library),
                    label: const Text('Gallery'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            TextField(
              controller: _textController,
              minLines: 2,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'Describe it — e.g. "2 eggs, toast and a banana"',
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
              label: Text(_estimating ? 'Estimating…' : 'Estimate calories'),
            ),

            if (_items.isNotEmpty) ...[
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Review & edit',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold)),
                  Text('$_totalCalories kcal',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
              if (_confidence > 0 && _confidence < 0.6)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    "I'm not fully sure on this one — tweak anything that's off.",
                    style: TextStyle(
                        color: Colors.orange.shade700, fontSize: 12),
                  ),
                ),
              const SizedBox(height: 8),
              ..._items.asMap().entries.map((e) => _FoodItemTile(
                    item: e.value,
                    onChanged: (updated) =>
                        setState(() => _items[e.key] = updated),
                    onDelete: () => setState(() => _items.removeAt(e.key)),
                  )),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _saving ? null : _save,
                child: Text(_saving ? 'Saving…' : 'Save meal'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _FoodItemTile extends StatelessWidget {
  final FoodItem item;
  final ValueChanged<FoodItem> onChanged;
  final VoidCallback onDelete;

  const _FoodItemTile({
    required this.item,
    required this.onChanged,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(item.name,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: onDelete,
                ),
              ],
            ),
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextFormField(
                    initialValue: item.portion,
                    decoration: const InputDecoration(
                        labelText: 'Portion', isDense: true),
                    onChanged: (v) => onChanged(FoodItem(
                      name: item.name,
                      portion: v,
                      calories: item.calories,
                      protein: item.protein,
                      carbs: item.carbs,
                      fat: item.fat,
                    )),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    initialValue: item.calories.toString(),
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                        labelText: 'kcal', isDense: true),
                    onChanged: (v) => onChanged(FoodItem(
                      name: item.name,
                      portion: item.portion,
                      calories: int.tryParse(v) ?? item.calories,
                      protein: item.protein,
                      carbs: item.carbs,
                      fat: item.fat,
                    )),
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

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/auth_provider.dart';
import '../../providers/firebase_providers.dart';

/// Conversational onboarding: the coach interviews the user to learn goals,
/// schedule and preferences, then writes a structured profile and flips
/// onboardingComplete=true.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _controller = TextEditingController();
  final _scroll = ScrollController();
  final List<Map<String, String>> _transcript = [];
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _transcript.add({
      'role': 'coach',
      'text':
          "Hey! I'm your SuperCoach 💪 Before we start, tell me a bit about "
              "yourself — what's your main goal right now, and where are you at "
              "with your fitness?",
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;
    _controller.clear();
    setState(() {
      _transcript.add({'role': 'user', 'text': text});
      _sending = true;
    });
    _scrollToBottom();

    try {
      final res = await ref
          .read(functionsServiceProvider)
          .onboardingTurn(transcript: _transcript);
      setState(() => _transcript.add({'role': 'coach', 'text': res.reply}));

      if (res.done && res.profilePatch != null) {
        final uid = ref.read(uidProvider);
        if (uid != null) {
          final patch = {...res.profilePatch!, 'onboardingComplete': true};
          await ref.read(firestoreServiceProvider).mergeProfile(uid, patch);
        }
        // Router redirect will move us to the dashboard once profile updates.
      }
    } catch (e) {
      setState(() => _transcript.add({
            'role': 'coach',
            'text': "Hmm, I had trouble there. Mind saying that again?",
          }));
    } finally {
      if (mounted) setState(() => _sending = false);
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Let's get set up")),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scroll,
              padding: const EdgeInsets.all(16),
              itemCount: _transcript.length + (_sending ? 1 : 0),
              itemBuilder: (context, i) {
                if (i >= _transcript.length) {
                  return const _Bubble(role: 'coach', text: '…');
                }
                final m = _transcript[i];
                return _Bubble(role: m['role']!, text: m['text']!);
              },
            ),
          ),
          _Composer(controller: _controller, onSend: _send, enabled: !_sending),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  final String role;
  final String text;
  const _Bubble({required this.role, required this.text});

  @override
  Widget build(BuildContext context) {
    final isUser = role == 'user';
    final scheme = Theme.of(context).colorScheme;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: const BoxConstraints(maxWidth: 280),
        decoration: BoxDecoration(
          color: isUser ? scheme.primary : Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(text,
            style: TextStyle(color: isUser ? Colors.white : Colors.black87)),
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onSend;
  final bool enabled;
  const _Composer(
      {required this.controller, required this.onSend, required this.enabled});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                enabled: enabled,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => onSend(),
                decoration: const InputDecoration(hintText: 'Type your reply…'),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              onPressed: enabled ? onSend : null,
              icon: const Icon(Icons.send),
            ),
          ],
        ),
      ),
    );
  }
}

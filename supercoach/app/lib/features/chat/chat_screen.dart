import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/chat_message.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chat_provider.dart';
import '../../providers/firebase_providers.dart';

/// Persistent conversation with the SuperCoach. The user's message is written
/// to Firestore immediately; the Cloud Function writes the coach's reply.
class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _controller = TextEditingController();
  final _scroll = ScrollController();
  bool _sending = false;

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
    setState(() => _sending = true);

    final uid = ref.read(uidProvider)!;
    final firestore = ref.read(firestoreServiceProvider);
    try {
      // Persist the user's message so it appears immediately via the stream.
      await firestore.addChatMessage(
        uid,
        ChatMessage(
            id: '', role: 'user', text: text, timestamp: DateTime.now()),
      );
      // Ask the coach. The Cloud Function writes the coach's reply to Firestore,
      // so the chat stream will surface it — no need to add it here.
      await ref.read(functionsServiceProvider).coachChat(message: text);
    } catch (e) {
      await firestore.addChatMessage(
        uid,
        ChatMessage(
          id: '',
          role: 'coach',
          text: "I'm having trouble responding right now — try again in a sec.",
          timestamp: DateTime.now(),
        ),
      );
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
    final chat = ref.watch(chatProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Coach')),
      body: Column(
        children: [
          Expanded(
            child: chat.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (messages) {
                _scrollToBottom();
                if (messages.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Text(
                        "Say hi to your coach 👋\nAsk for advice, motivation, "
                        "or just check in.",
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }
                return ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length + (_sending ? 1 : 0),
                  itemBuilder: (context, i) {
                    if (i >= messages.length) {
                      return const _Bubble(isUser: false, text: '…');
                    }
                    final m = messages[i];
                    return _Bubble(isUser: m.isUser, text: m.text);
                  },
                );
              },
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      decoration:
                          const InputDecoration(hintText: 'Message your coach…'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _sending ? null : _send,
                    icon: const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  final bool isUser;
  final String text;
  const _Bubble({required this.isUser, required this.text});

  @override
  Widget build(BuildContext context) {
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

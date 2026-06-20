import 'package:speech_to_text/speech_to_text.dart';

/// Wraps speech_to_text for "speak what I ate / did" voice logging.
class SpeechService {
  final SpeechToText _stt = SpeechToText();
  bool _available = false;

  Future<bool> init() async {
    _available = await _stt.initialize();
    return _available;
  }

  bool get isListening => _stt.isListening;

  /// Starts listening and streams recognized words via [onResult].
  Future<void> listen({
    required void Function(String text) onResult,
    required void Function() onDone,
  }) async {
    if (!_available) {
      _available = await _stt.initialize();
      if (!_available) return;
    }
    await _stt.listen(
      onResult: (r) => onResult(r.recognizedWords),
      listenOptions: SpeechListenOptions(
        listenMode: ListenMode.dictation,
        partialResults: true,
      ),
      onSoundLevelChange: null,
    );
    _stt.statusListener = (status) {
      if (status == 'done' || status == 'notListening') onDone();
    };
  }

  Future<void> stop() => _stt.stop();
}

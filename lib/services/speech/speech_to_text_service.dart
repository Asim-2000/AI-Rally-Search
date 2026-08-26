import '../../models/supported_language.dart';
import '../../models/voice_state.dart';

/// Provider-agnostic interface for speech-to-text recording and transcription services.
abstract class ISpeechToTextService {
  /// Current active microphone interaction state.
  VoiceState get currentState;

  /// Stream of voice state changes for UI reactivity.
  Stream<VoiceState> get stateStream;

  /// Checks if speech transcription service is initialized and available.
  Future<bool> initialize();

  /// Checks if microphone permission has been granted.
  Future<bool> hasPermission();

  /// Requests microphone permission from the operating system or browser.
  Future<bool> requestPermission();

  /// Begins recording audio stream for transcription.
  Future<void> startListening({
    required SupportedLanguage language,
    required void Function(String text, bool isFinal) onResult,
    required void Function(VoiceState state) onStateChanged,
    required void Function(VoiceError error) onError,
  });

  /// Stops recording, triggers transcription, and returns final transcript text.
  Future<String?> stopListening();

  /// Cancels active recording without executing transcription.
  Future<void> cancelListening();

  /// Disposes underlying audio recorders and stream controllers.
  void dispose();
}

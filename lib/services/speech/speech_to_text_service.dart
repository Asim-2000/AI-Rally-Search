import '../../models/speech/speech_transcription_result.dart';
import '../../models/speech/speech_transcription_context.dart';
import '../../models/supported_language.dart';
import '../../models/voice_state.dart';

/// Provider-agnostic interface for speech-to-text recording and transcription services.
abstract class ISpeechToTextService {
  SpeechTranscriptionCapabilities get transcriptionCapabilities;

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

  /// Stops recording, triggers transcription, and returns rich transcription result
  /// including optional hypotheses, timestamps, and retained audio context.
  Future<SpeechTranscriptionResult?> stopListeningDetailed();

  /// Cancels active recording without executing transcription.
  Future<void> cancelListening();

  /// Directly transcribes in-memory audio bytes using the configured STT provider.
  Future<String?> transcribeAudioBytes(
    List<int> bytes, {
    required SupportedLanguage language,
    String filename = 'audio.m4a',
    SpeechTranscriptionContext? context,
  });

  /// Directly transcribes in-memory audio bytes returning rich transcription result.
  Future<SpeechTranscriptionResult?> transcribeAudioBytesDetailed(
    List<int> bytes, {
    required SupportedLanguage language,
    String filename = 'audio.m4a',
    SpeechTranscriptionContext? context,
  });

  /// Directly transcribes a local audio file using the configured STT provider.
  Future<String?> transcribeAudioFile(
    dynamic file, {
    required SupportedLanguage language,
    SpeechTranscriptionContext? context,
  });

  /// Disposes underlying audio recorders and stream controllers.
  void dispose();
}

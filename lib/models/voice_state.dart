/// Represents the lifecycle states of the voice search microphone interaction.
enum VoiceState {
  /// Microphone is idle and ready to record.
  idle,

  /// Prompting system/browser for microphone permission.
  requestingPermission,

  /// Actively recording microphone audio stream.
  listening,

  /// Processing recorded audio via Speech-to-Text service.
  processing,

  /// An error occurred during permission, recording, or transcription.
  error;

  bool get isIdle => this == VoiceState.idle;
  bool get isListening => this == VoiceState.listening;
  bool get isProcessing => this == VoiceState.processing;
  bool get isError => this == VoiceState.error;
}

/// Structured error representing voice search failure reasons.
class VoiceError {
  final String code;
  final String message;
  final dynamic details;

  const VoiceError({
    required this.code,
    required this.message,
    this.details,
  });

  static const String permissionDenied = 'PERMISSION_DENIED';
  static const String speechUnavailable = 'SPEECH_UNAVAILABLE';
  static const String noSpeechDetected = 'NO_SPEECH_DETECTED';
  static const String timeout = 'TIMEOUT';
  static const String networkError = 'NETWORK_ERROR';
  static const String unsupportedLocale = 'UNSUPPORTED_LOCALE';
  static const String recordingFailed = 'RECORDING_FAILED';
  static const String transcriptionFailed = 'TRANSCRIPTION_FAILED';

  @override
  String toString() => 'VoiceError($code: $message)';
}

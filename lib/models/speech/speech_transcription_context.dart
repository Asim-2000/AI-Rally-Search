enum TranscriptionOrigin { baseline, staticContext, dynamicBiased }

class SpeechTranscriptionContext {
  final TranscriptionOrigin origin;
  final String? prompt;
  final List<String> keywords;
  final List<String> languageHints;

  const SpeechTranscriptionContext({
    required this.origin,
    this.prompt,
    this.keywords = const [],
    this.languageHints = const [],
  });

  bool get hasBias =>
      (prompt?.trim().isNotEmpty ?? false) || keywords.isNotEmpty;
}

class SpeechTranscriptionCapabilities {
  final bool freeFormContext;
  final bool keywordHints;
  final bool multipleLanguageHints;

  const SpeechTranscriptionCapabilities({
    this.freeFormContext = false,
    this.keywordHints = false,
    this.multipleLanguageHints = false,
  });
}

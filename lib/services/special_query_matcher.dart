import 'friendly_response_service.dart';

class SpecialQueryMatch {
  final FriendlyResponseCategory category;
  const SpecialQueryMatch(this.category);
}

/// Deliberately small, conservative matcher. It is not a general chatbot.
class SpecialQueryMatcher {
  const SpecialQueryMatcher();

  SpecialQueryMatch? match(String query) {
    final normalized = _normalize(query);
    if (normalized.isEmpty) return null;

    if (_oneOf(normalized, const [
      'weather',
      "what's the weather",
      'what is the weather',
      'how is the weather',
    ])) {
      return const SpecialQueryMatch(FriendlyResponseCategory.weather);
    }
    if (_oneOf(normalized, const [
      'hi',
      'hello',
      'hey',
      'good morning',
      'good afternoon',
      'good evening',
    ])) {
      return const SpecialQueryMatch(FriendlyResponseCategory.greeting);
    }
    if (_oneOf(normalized, const [
      'thanks',
      'thank you',
      'cheers',
      'thanks a lot',
    ])) {
      return const SpecialQueryMatch(FriendlyResponseCategory.thanks);
    }
    if (_oneOf(normalized, const [
      'who are you',
      'what are you',
      'what is your name',
    ])) {
      return const SpecialQueryMatch(FriendlyResponseCategory.identity);
    }
    if (_oneOf(normalized, const [
      'what can you do',
      'help',
      'how can you help',
      'what do you do',
    ])) {
      return const SpecialQueryMatch(FriendlyResponseCategory.capabilities);
    }
    if (_oneOf(normalized, const [
      'tell me a joke',
      'say something funny',
      'rally joke',
    ])) {
      return const SpecialQueryMatch(FriendlyResponseCategory.joke);
    }
    if (_oneOf(normalized, const ['are you alive', 'are you real'])) {
      return const SpecialQueryMatch(FriendlyResponseCategory.alive);
    }
    if (RegExp(
      r'^who (?:is|was) the (?:best|greatest) rally (?:driver|racer)(?: of all time)?$',
    ).hasMatch(normalized)) {
      return const SpecialQueryMatch(FriendlyResponseCategory.rallyOpinion);
    }

    // Only unmistakable, narrow examples are redirected before query understanding.
    if (RegExp(r'^(?:what is|what\x27s) the capital of [a-z ]+$')
            .hasMatch(normalized) ||
        RegExp(r'^(?:how do i|how to) (?:cook|bake|make)\b')
            .hasMatch(normalized)) {
      return const SpecialQueryMatch(FriendlyResponseCategory.unsupported);
    }
    return null;
  }

  static bool _oneOf(String value, List<String> phrases) =>
      phrases.contains(value);

  static String _normalize(String input) => input
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[?!.,;:]+$'), '')
      .replaceAll(RegExp(r'\s+'), ' ');
}

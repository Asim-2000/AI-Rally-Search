import 'llm_provider_config.dart';
import 'query_parse_result.dart';

/// Contextual metadata passed into LLM query parsers to disambiguate relative queries and provide locale hints.
class SearchContext {
  final int? currentYear;
  final String? activeRally;
  final String? activeDriver;
  final String? locale;
  final String? languageCode;
  final Map<String, dynamic> extra;

  const SearchContext({
    this.currentYear,
    this.activeRally,
    this.activeDriver,
    this.locale,
    this.languageCode,
    this.extra = const {},
  });
}


/// Abstract provider-agnostic interface for translating natural-language queries
/// into structured QueryParseResult / canonical SearchQuery.
abstract class LlmQueryParser {
  /// The provider identifying this parser adapter.
  LlmProvider get provider;

  /// Parses a natural-language query into a structured QueryParseResult.
  Future<QueryParseResult> parse(
    String userQuery, {
    SearchContext? context,
  });
}

import '../../models/result_referent_context.dart';
import '../../models/search_query.dart';
import 'llm_provider_config.dart';
import 'query_parse_result.dart';

/// Contextual metadata passed into LLM query parsers to disambiguate relative queries,
/// resolve coreferences/pronouns (e.g. "him", "it", "that rally"), and provide locale hints.
class SearchContext {
  final int? currentYear;
  final String? activeRally;
  final String? activeDriver;
  final String? locale;
  final String? languageCode;
  final ResultReferentContext referents;
  final SearchQuery? previousQuery;
  final Map<String, dynamic> extra;

  const SearchContext({
    this.currentYear,
    this.activeRally,
    this.activeDriver,
    this.locale,
    this.languageCode,
    this.referents = ResultReferentContext.empty,
    this.previousQuery,
    this.extra = const {},
  });

  /// Formats compact referent context into clear, concise prompt annotations for LLMs.
  String formatPromptContext() {
    final StringBuffer sb = StringBuffer();
    if (currentYear != null) {
      sb.writeln('[Context: current calendar year is $currentYear]');
    }

    final rally = activeRally ?? referents.activeRally ?? referents.lastSelectedRally;
    if (rally != null && rally.isNotEmpty) {
      sb.writeln('[Context: active rally is "$rally"]');
    }

    final driver = activeDriver ?? referents.activeDriver ?? referents.lastSelectedDriver;
    if (driver != null && driver.isNotEmpty) {
      final roleInfo = (referents.activePersonRole != null && referents.activePersonRole != PersonRole.any)
          ? ' (role: ${referents.activePersonRole!.toRoleString()})'
          : '';
      sb.writeln('[Context: active driver is "$driver"$roleInfo]');
    }

    if (referents.lastWinner != null && referents.lastWinner!.isNotEmpty) {
      final winnerIdInfo = referents.lastWinnerDriverId != null ? ' (driverId: ${referents.lastWinnerDriverId})' : '';
      sb.writeln('[Context: last winner is "${referents.lastWinner}"$winnerIdInfo]');
    }

    if (referents.activeDrivers.isNotEmpty && referents.activeDrivers.length > 1) {
      sb.writeln('[Context: candidate active drivers are: ${referents.activeDrivers.map((d) => '"$d"').join(', ')}]');
    }

    if (referents.activeRallies.isNotEmpty && referents.activeRallies.length > 1) {
      sb.writeln('[Context: candidate active rallies are: ${referents.activeRallies.map((r) => '"$r"').join(', ')}]');
    }

    if (previousQuery != null) {
      final prevFilters = <String>[];
      if (previousQuery!.rallyNames.isNotEmpty) prevFilters.add('rally: ${previousQuery!.rallyNames.join(', ')}');
      if (previousQuery!.driverNames.isNotEmpty) prevFilters.add('driver: ${previousQuery!.driverNames.join(', ')}');
      if (previousQuery!.personRole != PersonRole.any) prevFilters.add('role: ${previousQuery!.personRole.toRoleString()}');
      if (previousQuery!.countries.isNotEmpty) prevFilters.add('countries: ${previousQuery!.countries.join(', ')}');
      if (previousQuery!.years.isNotEmpty) prevFilters.add('years: ${previousQuery!.years.join(', ')}');
      if (previousQuery!.actionTypes.isNotEmpty) prevFilters.add('actions: ${previousQuery!.actionTypes.join(', ')}');
      if (prevFilters.isNotEmpty) {
        sb.writeln('[Context: previous query filters were: ${prevFilters.join(' | ')}]');
      }
    }

    final effectiveLocale = locale ?? languageCode;
    if (effectiveLocale != null && effectiveLocale.isNotEmpty) {
      sb.writeln('[Context: app locale is "$effectiveLocale"]');
    }

    return sb.toString();
  }
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

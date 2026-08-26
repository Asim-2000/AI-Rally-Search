import '../../../models/search_intent.dart';
import '../../../models/search_query.dart';
import '../llm_query_parser.dart';

/// Single test case item in the evaluation benchmark suite.
class BenchmarkTestCase {
  final String id;
  final String input;
  final String category;
  final String description;
  final SearchQuery? expectedQuery;
  final bool expectClarification;
  final SearchContext? context;

  const BenchmarkTestCase({
    required this.id,
    required this.input,
    required this.category,
    required this.description,
    this.expectedQuery,
    this.expectClarification = false,
    this.context,
  });
}

/// Standardized golden benchmark dataset for Rally Search natural language evaluation.
class BenchmarkDataset {
  BenchmarkDataset._();

  static const List<BenchmarkTestCase> testCases = [
    // --- Category: Action Highlights ---
    BenchmarkTestCase(
      id: 'ACT-01',
      input: 'Show jump highlights from Moonraker.',
      category: 'Action Highlights',
      description: 'Action jump with rally name filter',
      expectedQuery: SearchQuery(
        intent: SearchIntent.searchVideoActions,
        actionType: 'jump',
        rallyName: 'Moonraker',
        limit: 20,
      ),
    ),
    BenchmarkTestCase(
      id: 'ACT-02',
      input: 'Show jump highlights featuring Josh Moffett from Moonraker.',
      category: 'Action Highlights',
      description: 'Action jump with driver and rally filters',
      expectedQuery: SearchQuery(
        intent: SearchIntent.searchVideoActions,
        actionType: 'jump',
        driverName: 'Josh Moffett',
        rallyName: 'Moonraker',
        limit: 20,
      ),
    ),
    BenchmarkTestCase(
      id: 'ACT-03',
      input: 'Show drift highlights from Trackrod Rally on Gale Rigg.',
      category: 'Action Highlights',
      description: 'Action drift with rally and stage filters',
      expectedQuery: SearchQuery(
        intent: SearchIntent.searchVideoActions,
        actionType: 'drift',
        rallyName: 'Trackrod Rally',
        stageName: 'Gale Rigg',
        limit: 20,
      ),
    ),
    BenchmarkTestCase(
      id: 'ACT-04',
      input: 'Show drift highlights featuring Philip Squires from Get Jerky.',
      category: 'Action Highlights',
      description: 'Action drift with driver and rally name',
      expectedQuery: SearchQuery(
        intent: SearchIntent.searchVideoActions,
        actionType: 'drift',
        driverName: 'Philip Squires',
        rallyName: 'Get Jerky',
        limit: 20,
      ),
    ),
    BenchmarkTestCase(
      id: 'ACT-05',
      input: 'Show crashes in Ireland in 2025.',
      category: 'Action Highlights',
      description: 'Action crash with country and year',
      expectedQuery: SearchQuery(
        intent: SearchIntent.searchVideoActions,
        actionType: 'crash',
        country: 'Ireland',
        year: 2025,
        limit: 20,
      ),
    ),
    BenchmarkTestCase(
      id: 'ACT-06',
      input: 'Show spins and doughnuts in Killarney.',
      category: 'Action Highlights',
      description: 'Action spin alias matching with city/rally',
      expectedQuery: SearchQuery(
        intent: SearchIntent.searchVideoActions,
        actionType: 'spin',
        rallyName: 'Killarney',
        limit: 20,
      ),
    ),
    BenchmarkTestCase(
      id: 'ACT-07',
      input: 'Show close calls and saves from Donegal.',
      category: 'Action Highlights',
      description: 'Action near miss alias matching',
      expectedQuery: SearchQuery(
        intent: SearchIntent.searchVideoActions,
        actionType: 'near miss',
        rallyName: 'Donegal',
        limit: 20,
      ),
    ),

    // --- Category: Driver Participations & Wins ---
    BenchmarkTestCase(
      id: 'DRV-01',
      input: 'Which rallies did Josh Moffett participate in in 2025?',
      category: 'Driver Participation',
      description: 'Driver participation with year filter',
      expectedQuery: SearchQuery(
        intent: SearchIntent.searchDriverRallies,
        driverName: 'Josh Moffett',
        year: 2025,
        limit: 20,
      ),
    ),
    BenchmarkTestCase(
      id: 'DRV-02',
      input: 'Show rallies in Ireland in 2025 where Josh Moffett participated.',
      category: 'Driver Participation',
      description: 'Driver participation with country and year',
      expectedQuery: SearchQuery(
        intent: SearchIntent.searchDriverRallies,
        driverName: 'Josh Moffett',
        country: 'Ireland',
        year: 2025,
        limit: 20,
      ),
    ),
    BenchmarkTestCase(
      id: 'DRV-03',
      input: 'Which rallies did Josh Moffett win?',
      category: 'Driver Wins',
      description: 'Driver career victories query',
      expectedQuery: SearchQuery(
        intent: SearchIntent.searchDriverWins,
        driverName: 'Josh Moffett',
        limit: 20,
      ),
    ),
    BenchmarkTestCase(
      id: 'DRV-04',
      input: 'Which rallies did Josh Moffett win in 2025?',
      category: 'Driver Wins',
      description: 'Driver victories with year',
      expectedQuery: SearchQuery(
        intent: SearchIntent.searchDriverWins,
        driverName: 'Josh Moffett',
        year: 2025,
        limit: 20,
      ),
    ),
    BenchmarkTestCase(
      id: 'DRV-05',
      input: 'Show videos featuring Josh Moffett.',
      category: 'Driver Videos',
      description: 'Driver video appearances query',
      expectedQuery: SearchQuery(
        intent: SearchIntent.searchDriverVideos,
        driverName: 'Josh Moffett',
        limit: 20,
      ),
    ),

    // --- Category: Rally Exploration & Results ---
    BenchmarkTestCase(
      id: 'RAL-01',
      input: 'Show all rallies in Ireland.',
      category: 'Rally Search',
      description: 'Country filter for rallies',
      expectedQuery: SearchQuery(
        intent: SearchIntent.searchRallies,
        country: 'Ireland',
        limit: 20,
      ),
    ),
    BenchmarkTestCase(
      id: 'RAL-02',
      input: 'show me rallies in poland',
      category: 'Rally Search',
      description: 'Lower case country query',
      expectedQuery: SearchQuery(
        intent: SearchIntent.searchRallies,
        country: 'Poland',
        limit: 20,
      ),
    ),
    BenchmarkTestCase(
      id: 'RAL-03',
      input: 'Show rallies in Ireland in 2025.',
      category: 'Rally Search',
      description: 'Country and year filter',
      expectedQuery: SearchQuery(
        intent: SearchIntent.searchRallies,
        country: 'Ireland',
        year: 2025,
        limit: 20,
      ),
    ),
    BenchmarkTestCase(
      id: 'RAL-04',
      input: 'Who finished first in Moonraker?',
      category: 'Rally Winner',
      description: 'Rally 1st place winner query',
      expectedQuery: SearchQuery(
        intent: SearchIntent.getRallyResults,
        rallyName: 'Moonraker',
        limit: 20,
      ),
    ),
    BenchmarkTestCase(
      id: 'RAL-05',
      input: 'Show the top 10 finishers from Moonraker.',
      category: 'Rally Leaderboard',
      description: 'Rally top finishers with explicit limit',
      expectedQuery: SearchQuery(
        intent: SearchIntent.getRallyTopFinishers,
        rallyName: 'Moonraker',
        limit: 10,
      ),
    ),

    // --- Category: Aggregations & Leaderboards ---
    BenchmarkTestCase(
      id: 'LEAD-01',
      input: 'Who are the top uploaders for Moonraker?',
      category: 'Leaderboards',
      description: 'Top video uploaders for a rally',
      expectedQuery: SearchQuery(
        intent: SearchIntent.getTopUploaders,
        rallyName: 'Moonraker',
        limit: 20,
      ),
    ),
    BenchmarkTestCase(
      id: 'LEAD-02',
      input: 'Show the drivers with the most wins.',
      category: 'Leaderboards',
      description: 'Career victories leaderboard',
      expectedQuery: SearchQuery(
        intent: SearchIntent.getTopDriversByWins,
        limit: 20,
      ),
    ),

    // --- Category: Context & Edge Cases ---
    BenchmarkTestCase(
      id: 'CTX-01',
      input: 'Show jump highlights',
      category: 'Contextual Queries',
      description: 'Query with active rally and driver in context',
      context: SearchContext(
        activeRally: 'Moonraker',
        activeDriver: 'Josh Moffett',
        currentYear: 2025,
      ),
      expectedQuery: SearchQuery(
        intent: SearchIntent.searchVideoActions,
        actionType: 'jump',
        rallyName: 'Moonraker',
        driverName: 'Josh Moffett',
        year: 2025,
        limit: 20,
      ),
    ),
    BenchmarkTestCase(
      id: 'AMB-01',
      input: 'Show results',
      category: 'Ambiguity & Clarification',
      description: 'Under-specified search lacking rally or driver context',
      expectClarification: true,
    ),
  ];
}

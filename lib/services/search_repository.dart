import '../models/search_intent.dart';
import '../models/search_query.dart';
import '../models/search_results.dart';
import '../models/video_action.dart';
import '../models/video_action_search_query.dart';
import 'database_service.dart';

abstract class ISearchRepository {
  /// General dispatch method executing any search query and returning typed response
  Future<SearchResponse<dynamic>> search(SearchQuery query);

  Future<SearchResponse<RallySearchResult>> searchRallies(SearchQuery query);
  Future<SearchResponse<RallyParticipationResult>> searchDriverRallies(SearchQuery query);
  Future<SearchResponse<RallyParticipationResult>> searchDriverWins(SearchQuery query);
  Future<SearchResponse<RallyResult>> getRallyResults(SearchQuery query);
  Future<SearchResponse<RallyResult>> getRallyTopFinishers(SearchQuery query);
  Future<SearchResponse<VideoAction>> searchVideoActions(SearchQuery query);
  Future<SearchResponse<VideoSearchResult>> searchDriverVideos(SearchQuery query);
  Future<SearchResponse<UploaderSearchResult>> getTopUploaders(SearchQuery query);
  Future<SearchResponse<DriverWinResult>> getTopDriversByWins(SearchQuery query);
}

class SearchRepository implements ISearchRepository {
  final DatabaseService _dbService;

  SearchRepository({DatabaseService? dbService})
      : _dbService = dbService ?? DatabaseService();

  @override
  Future<SearchResponse<dynamic>> search(SearchQuery query) async {
    switch (query.intent) {
      case SearchIntent.searchRallies:
        return await searchRallies(query);
      case SearchIntent.searchDriverRallies:
        return await searchDriverRallies(query);
      case SearchIntent.searchDriverWins:
        return await searchDriverWins(query);
      case SearchIntent.getRallyResults:
        return await getRallyResults(query);
      case SearchIntent.getRallyTopFinishers:
        return await getRallyTopFinishers(query);
      case SearchIntent.searchVideoActions:
        return await searchVideoActions(query);
      case SearchIntent.searchDriverVideos:
        return await searchDriverVideos(query);
      case SearchIntent.getTopUploaders:
        return await getTopUploaders(query);
      case SearchIntent.getTopDriversByWins:
        return await getTopDriversByWins(query);
    }
  }

  @override
  Future<SearchResponse<RallySearchResult>> searchRallies(SearchQuery query) async {
    final count = await _dbService.countRallies(query);
    final rows = await _dbService.searchRallies(query);
    final results = rows.map((r) => RallySearchResult.fromMap(r)).toList();

    return SearchResponse<RallySearchResult>(
      intent: SearchIntent.searchRallies,
      results: results,
      totalCount: count,
      hasMore: (query.offset + results.length) < count,
      limit: query.limit,
      offset: query.offset,
    );
  }

  @override
  Future<SearchResponse<RallyParticipationResult>> searchDriverRallies(SearchQuery query) async {
    final count = await _dbService.countDriverRallies(query);
    final rows = await _dbService.searchDriverRallies(query);
    final results = rows.map((r) => RallyParticipationResult.fromMap(r)).toList();

    return SearchResponse<RallyParticipationResult>(
      intent: SearchIntent.searchDriverRallies,
      results: results,
      totalCount: count,
      hasMore: (query.offset + results.length) < count,
      limit: query.limit,
      offset: query.offset,
    );
  }

  @override
  Future<SearchResponse<RallyParticipationResult>> searchDriverWins(SearchQuery query) async {
    final count = await _dbService.countDriverWins(query);
    final rows = await _dbService.searchDriverWins(query);
    final results = rows.map((r) => RallyParticipationResult.fromMap(r)).toList();

    return SearchResponse<RallyParticipationResult>(
      intent: SearchIntent.searchDriverWins,
      results: results,
      totalCount: count,
      hasMore: (query.offset + results.length) < count,
      limit: query.limit,
      offset: query.offset,
    );
  }

  @override
  Future<SearchResponse<RallyResult>> getRallyResults(SearchQuery query) async {
    final rows = await _dbService.getRallyResults(query);
    final results = rows.map((r) => RallyResult.fromMap(r)).toList();

    return SearchResponse<RallyResult>(
      intent: SearchIntent.getRallyResults,
      results: results,
      totalCount: results.length,
      hasMore: false,
      limit: query.limit,
      offset: query.offset,
    );
  }

  @override
  Future<SearchResponse<RallyResult>> getRallyTopFinishers(SearchQuery query) async {
    final count = await _dbService.countRallyTopFinishers(query);
    final rows = await _dbService.getRallyTopFinishers(query);
    final results = rows.map((r) => RallyResult.fromMap(r)).toList();

    return SearchResponse<RallyResult>(
      intent: SearchIntent.getRallyTopFinishers,
      results: results,
      totalCount: count,
      hasMore: (query.offset + results.length) < count,
      limit: query.limit,
      offset: query.offset,
    );
  }

  @override
  Future<SearchResponse<VideoAction>> searchVideoActions(SearchQuery query) async {
    final count = await _dbService.countVideoActions(query);
    final rows = await _dbService.searchVideoActions(query);
    final results = rows.map((r) => VideoAction.fromMap(r)).toList();

    return SearchResponse<VideoAction>(
      intent: SearchIntent.searchVideoActions,
      results: results,
      totalCount: count,
      hasMore: (query.offset + results.length) < count,
      limit: query.limit,
      offset: query.offset,
    );
  }


  @override
  Future<SearchResponse<VideoSearchResult>> searchDriverVideos(SearchQuery query) async {
    final count = await _dbService.countDriverVideos(query);
    final rows = await _dbService.searchDriverVideos(query);
    final results = rows.map((r) => VideoSearchResult.fromMap(r)).toList();

    return SearchResponse<VideoSearchResult>(
      intent: SearchIntent.searchDriverVideos,
      results: results,
      totalCount: count,
      hasMore: (query.offset + results.length) < count,
      limit: query.limit,
      offset: query.offset,
    );
  }

  @override
  Future<SearchResponse<UploaderSearchResult>> getTopUploaders(SearchQuery query) async {
    final count = await _dbService.countTopUploaders(query);
    final rows = await _dbService.getTopUploaders(query);
    final results = rows.map((r) => UploaderSearchResult.fromMap(r)).toList();

    return SearchResponse<UploaderSearchResult>(
      intent: SearchIntent.getTopUploaders,
      results: results,
      totalCount: count,
      hasMore: (query.offset + results.length) < count,
      limit: query.limit,
      offset: query.offset,
    );
  }

  @override
  Future<SearchResponse<DriverWinResult>> getTopDriversByWins(SearchQuery query) async {
    final count = await _dbService.countTopDriversByWins(query);
    final rows = await _dbService.getTopDriversByWins(query);
    final results = rows.map((r) => DriverWinResult.fromMap(r)).toList();

    return SearchResponse<DriverWinResult>(
      intent: SearchIntent.getTopDriversByWins,
      results: results,
      totalCount: count,
      hasMore: (query.offset + results.length) < count,
      limit: query.limit,
      offset: query.offset,
    );
  }
}

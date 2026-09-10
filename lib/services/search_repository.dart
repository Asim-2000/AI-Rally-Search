import '../models/search_query.dart';
import '../models/search_results.dart';
import '../models/video_action.dart';

/// Contract implemented by the FastAPI-backed [PythonSearchRepository]
/// (see python_search_api_client.dart). The device never talks to the
/// database directly; all search goes over HTTPS to the backend.
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

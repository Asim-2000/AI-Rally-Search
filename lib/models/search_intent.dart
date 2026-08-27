/// Defines the supported deterministic search intents in AI Rally Search.
enum SearchIntent {
  /// Search rally events by country, city, year, or event name
  searchRallies,

  /// Search rallies that a driver participated in
  searchDriverRallies,

  /// Search rallies that a driver won
  searchDriverWins,

  /// Get first-place winner / result of a specific rally
  getRallyResults,

  /// Get ranked top finishers (leaderboard) for a rally
  getRallyTopFinishers,

  /// Search video action highlights (jumps, drifts, crashes, etc.)
  searchVideoActions,

  /// Search videos featuring a specific driver
  searchDriverVideos,

  /// Get top video uploaders for a rally or globally
  getTopUploaders,

  /// Get ranked leaderboard of drivers with most career wins
  getTopDriversByWins;

  /// Human readable display name for UI dropdowns and chips
  String get displayName {
    switch (this) {
      case SearchIntent.searchRallies:
        return 'Search Rallies';
      case SearchIntent.searchDriverRallies:
        return 'Driver Participations';
      case SearchIntent.searchDriverWins:
        return 'Driver Wins';
      case SearchIntent.getRallyResults:
        return 'Rally Winner';
      case SearchIntent.getRallyTopFinishers:
        return 'Rally Top Finishers';
      case SearchIntent.searchVideoActions:
        return 'Action Highlights';
      case SearchIntent.searchDriverVideos:
        return 'Driver Videos';
      case SearchIntent.getTopUploaders:
        return 'Top Uploaders';
      case SearchIntent.getTopDriversByWins:
        return 'Most Career Wins';
    }
  }

  /// Serializes the enum to standard SCREAMING_SNAKE_CASE string
  String toIntentString() {
    switch (this) {
      case SearchIntent.searchRallies:
        return 'SEARCH_RALLIES';
      case SearchIntent.searchDriverRallies:
        return 'SEARCH_DRIVER_RALLIES';
      case SearchIntent.searchDriverWins:
        return 'SEARCH_DRIVER_WINS';
      case SearchIntent.getRallyResults:
        return 'GET_RALLY_RESULTS';
      case SearchIntent.getRallyTopFinishers:
        return 'GET_RALLY_TOP_FINISHERS';
      case SearchIntent.searchVideoActions:
        return 'SEARCH_VIDEO_ACTIONS';
      case SearchIntent.searchDriverVideos:
        return 'SEARCH_DRIVER_VIDEOS';
      case SearchIntent.getTopUploaders:
        return 'GET_TOP_UPLOADERS';
      case SearchIntent.getTopDriversByWins:
        return 'GET_TOP_DRIVERS_BY_WINS';
    }
  }

  /// Parses a string into a SearchIntent
  static SearchIntent fromString(String raw) {
    final normalized = raw.trim().toUpperCase().replaceAll(' ', '_');
    switch (normalized) {
      case 'SEARCH_RALLIES':
      case 'SEARCHRALLIES':
      case 'RALLIES':
        return SearchIntent.searchRallies;
      case 'SEARCH_DRIVER_RALLIES':
      case 'SEARCHDRIVERRALLIES':
      case 'DRIVER_RALLIES':
        return SearchIntent.searchDriverRallies;
      case 'SEARCH_DRIVER_WINS':
      case 'SEARCHDRIVERWINS':
      case 'DRIVER_WINS':
        return SearchIntent.searchDriverWins;
      case 'GET_RALLY_RESULTS':
      case 'GETRALLYRESULTS':
      case 'RALLY_WINNER':
      case 'RALLY_RESULTS':
        return SearchIntent.getRallyResults;
      case 'GET_RALLY_TOP_FINISHERS':
      case 'GETRALLYTOPFINISHERS':
      case 'TOP_FINISHERS':
      case 'RALLY_LEADERBOARD':
        return SearchIntent.getRallyTopFinishers;
      case 'SEARCH_VIDEO_ACTIONS':
      case 'SEARCHVIDEOACTIONS':
      case 'VIDEO_ACTIONS':
      case 'ACTION_MOMENTS':
        return SearchIntent.searchVideoActions;
      case 'SEARCH_DRIVER_VIDEOS':
      case 'SEARCHDRIVERVIDEOS':
      case 'DRIVER_VIDEOS':
        return SearchIntent.searchDriverVideos;
      case 'GET_TOP_UPLOADERS':
      case 'GETTOPUPLOADERS':
      case 'TOP_UPLOADERS':
        return SearchIntent.getTopUploaders;
      case 'GET_TOP_DRIVERS_BY_WINS':
      case 'GETTOPDRIVERSBYWINS':
      case 'MOST_WINS':
      case 'TOP_DRIVERS':
        return SearchIntent.getTopDriversByWins;
      default:
        return SearchIntent.searchRallies;
    }
  }
}

import '../models/video_action.dart';
import '../models/video_action_search_query.dart';
import 'database_service.dart';

abstract class IVideoActionRepository {
  Future<List<VideoAction>> getVideoActionsForVideo(
    int videoId, {
    String? defaultVideoUrl,
    int? defaultStreamId,
    double? defaultClipStartTime,
    double? defaultClipDuration,
  });

  Future<List<VideoAction>> getVideoActionsForStream(
    int streamId, {
    String? defaultVideoUrl,
    double? defaultClipStartTime,
    double? defaultClipDuration,
  });

  Future<List<VideoAction>> getRecentVideoActions({
    int limit = 20,
    int offset = 0,
    String? actionType,
  });

  Future<List<VideoAction>> searchVideoActions(
    VideoActionSearchQuery query,
  );

  Future<int> countVideoActions(
    VideoActionSearchQuery query,
  );
}

class VideoActionRepository implements IVideoActionRepository {
  final DatabaseService _dbService;

  VideoActionRepository({DatabaseService? dbService})
      : _dbService = dbService ?? DatabaseService();

  @override
  Future<List<VideoAction>> getVideoActionsForVideo(
    int videoId, {
    String? defaultVideoUrl,
    int? defaultStreamId,
    double? defaultClipStartTime,
    double? defaultClipDuration,
  }) async {
    final rows = await _dbService.getVideoActionsForVideo(videoId);
    return rows
        .map((row) => VideoAction.fromMap(
              row,
              defaultVideoUrl: defaultVideoUrl,
              defaultStreamId: defaultStreamId,
              defaultClipStartTime: defaultClipStartTime,
              defaultClipDuration: defaultClipDuration,
            ))
        .toList();
  }

  @override
  Future<List<VideoAction>> getVideoActionsForStream(
    int streamId, {
    String? defaultVideoUrl,
    double? defaultClipStartTime,
    double? defaultClipDuration,
  }) async {
    final rows = await _dbService.getVideoActionsForStream(streamId);
    return rows
        .map((row) => VideoAction.fromMap(
              row,
              defaultVideoUrl: defaultVideoUrl,
              defaultStreamId: streamId,
              defaultClipStartTime: defaultClipStartTime,
              defaultClipDuration: defaultClipDuration,
            ))
        .toList();
  }

  @override
  Future<List<VideoAction>> getRecentVideoActions({
    int limit = 20,
    int offset = 0,
    String? actionType,
  }) async {
    final rows = await _dbService.getRecentVideoActions(
      limit: limit,
      offset: offset,
      actionType: actionType,
    );
    return rows.map((row) => VideoAction.fromMap(row)).toList();
  }

  @override
  Future<List<VideoAction>> searchVideoActions(
    VideoActionSearchQuery query,
  ) async {
    final rows = await _dbService.searchVideoActions(query);
    return rows.map((row) => VideoAction.fromMap(row)).toList();
  }

  @override
  Future<int> countVideoActions(
    VideoActionSearchQuery query,
  ) async {
    return await _dbService.countVideoActions(query);
  }
}


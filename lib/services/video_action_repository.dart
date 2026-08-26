import '../models/video_action.dart';
import 'database_service.dart';

abstract class IVideoActionRepository {
  Future<List<VideoAction>> getVideoActionsForVideo(
    int videoId, {
    String? defaultVideoUrl,
    int? defaultStreamId,
  });

  Future<List<VideoAction>> getVideoActionsForStream(
    int streamId, {
    String? defaultVideoUrl,
  });

  Future<List<VideoAction>> getRecentVideoActions({
    int limit = 20,
    int offset = 0,
    String? actionType,
  });
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
  }) async {
    final rows = await _dbService.getVideoActionsForVideo(videoId);
    return rows
        .map((row) => VideoAction.fromMap(
              row,
              defaultVideoUrl: defaultVideoUrl,
              defaultStreamId: defaultStreamId,
            ))
        .toList();
  }

  @override
  Future<List<VideoAction>> getVideoActionsForStream(
    int streamId, {
    String? defaultVideoUrl,
  }) async {
    final rows = await _dbService.getVideoActionsForStream(streamId);
    return rows
        .map((row) => VideoAction.fromMap(
              row,
              defaultVideoUrl: defaultVideoUrl,
              defaultStreamId: streamId,
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
}

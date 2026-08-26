class VideoAction {
  final int id;
  final int videoId;
  final int? streamId;
  final int? actionTypeId;
  final String actionType;
  final String title;
  final double startTime;
  final double endTime;
  final double duration;
  final String? thumbnailUrl;
  final String? videoUrl;
  final String? stageName;
  final String? stageNumber;
  final String? eventName;
  final String? eventCountry;
  final double? points;

  const VideoAction({
    required this.id,
    required this.videoId,
    this.streamId,
    this.actionTypeId,
    required this.actionType,
    required this.title,
    required this.startTime,
    required this.endTime,
    required this.duration,
    this.thumbnailUrl,
    this.videoUrl,
    this.stageName,
    this.stageNumber,
    this.eventName,
    this.eventCountry,
    this.points,
  });

  factory VideoAction.fromMap(Map<String, dynamic> map, {String? defaultVideoUrl, int? defaultStreamId}) {
    final rawId = _parseInt(map['id']) ?? _parseInt(map['action_instance_id']) ?? 0;
    final rawVideoId = _parseInt(map['video_id']) ?? _parseInt(map['source_video_id']) ?? 0;
    final rawStreamId = _parseInt(map['stream_id']) ?? defaultStreamId;
    final rawActionTypeId = _parseInt(map['action_id']) ?? _parseInt(map['action_type_id']);
    
    final rawActionName = map['action_name']?.toString() ?? 
        map['action_type']?.toString() ?? 
        'action';
    final normalizedType = _normalizeActionType(rawActionName);
    final actionTitle = map['title']?.toString() ?? _formatActionTitle(normalizedType);

    final start = _parseTimestampToSeconds(map['start_action'] ?? map['start_time'] ?? map['clip_start_time']);
    final end = _parseTimestampToSeconds(map['end_action'] ?? map['end_time']);
    
    final explicitDuration = _parseDouble(map['duration']) ?? _parseDouble(map['clip_duration']);
    final computedDuration = (end > start) 
        ? (end - start) 
        : (explicitDuration ?? 0.0);

    final thumb = map['thumbnail_url']?.toString() ?? 
        map['video_thumbnail']?.toString() ?? 
        map['thumbnail']?.toString();

    final vUrl = map['video_url']?.toString() ?? 
        map['on_demand_url']?.toString() ?? 
        defaultVideoUrl;

    return VideoAction(
      id: rawId,
      videoId: rawVideoId,
      streamId: rawStreamId,
      actionTypeId: rawActionTypeId,
      actionType: normalizedType,
      title: actionTitle,
      startTime: start,
      endTime: end > start ? end : (start + (explicitDuration ?? 0.0)),
      duration: computedDuration,
      thumbnailUrl: (thumb != null && thumb.isNotEmpty && thumb != 'none') ? thumb : null,
      videoUrl: (vUrl != null && vUrl.isNotEmpty) ? vUrl : null,
      stageName: map['stage_name']?.toString(),
      stageNumber: map['stage_number']?.toString(),
      eventName: map['event_name']?.toString(),
      eventCountry: map['event_country']?.toString() ?? map['country']?.toString(),
      points: _parseDouble(map['points']),
    );
  }

  static String _normalizeActionType(String rawName) {
    var name = rawName.toLowerCase().trim();
    if (name.endsWith('_segments')) {
      name = name.substring(0, name.length - '_segments'.length);
    }
    return name;
  }

  static String _formatActionTitle(String actionType) {
    switch (actionType) {
      case 'jump':
        return 'Jump';
      case 'drift':
        return 'Drift';
      case 'start_line':
        return 'Start Line';
      case 'crash':
        return 'Crash';
      case 'spin':
        return 'Spin';
      case 'near_miss':
        return 'Near Miss';
      case 'mechanical_failure':
        return 'Mechanical Failure';
      case 'offroad':
        return 'Offroad';
      case 'stuck':
        return 'Stuck';
      default:
        if (actionType.isEmpty) return 'Action';
        return actionType
            .split('_')
            .map((w) => w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1)}' : '')
            .join(' ');
    }
  }

  static double _parseTimestampToSeconds(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    final str = value.toString().trim();
    if (str.isEmpty) return 0.0;

    final directNum = double.tryParse(str);
    if (directNum != null) return directNum;

    final parts = str.split(':');
    if (parts.length == 3) {
      final hours = double.tryParse(parts[0]) ?? 0.0;
      final minutes = double.tryParse(parts[1]) ?? 0.0;
      final seconds = double.tryParse(parts[2]) ?? 0.0;
      return (hours * 3600) + (minutes * 60) + seconds;
    } else if (parts.length == 2) {
      final minutes = double.tryParse(parts[0]) ?? 0.0;
      final seconds = double.tryParse(parts[1]) ?? 0.0;
      return (minutes * 60) + seconds;
    }
    return 0.0;
  }

  static int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    return int.tryParse(value.toString());
  }

  static double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    return double.tryParse(value.toString());
  }

  String get formattedDuration {
    if (duration <= 0) return '0.0s';
    if (duration < 60) {
      return '${duration.toStringAsFixed(1)}s';
    }
    final minutes = (duration / 60).floor();
    final remainingSecs = (duration % 60).toStringAsFixed(1);
    return '${minutes}m ${remainingSecs}s';
  }

  String _formatTime(double totalSeconds) {
    final totalSecsInt = totalSeconds.floor();
    final minutes = (totalSecsInt / 60).floor().toString().padLeft(2, '0');
    final seconds = (totalSecsInt % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  String get formattedTimeRange {
    return '${_formatTime(startTime)} → ${_formatTime(endTime)}';
  }

  String get locationOrStageDescription {
    final parts = <String>[];
    if (eventName != null && eventName!.isNotEmpty) {
      parts.add(eventName!);
    }
    if (stageName != null && stageName!.isNotEmpty) {
      final stgNum = stageNumber != null && stageNumber!.isNotEmpty ? 'SS$stageNumber: ' : '';
      parts.add('$stgNum$stageName');
    }
    if (parts.isEmpty && eventCountry != null && eventCountry!.isNotEmpty) {
      parts.add(eventCountry!.toUpperCase());
    }
    return parts.isNotEmpty ? parts.join(' • ') : 'Full Stream Segment';
  }

  VideoAction copyWith({
    int? id,
    int? videoId,
    int? streamId,
    int? actionTypeId,
    String? actionType,
    String? title,
    double? startTime,
    double? endTime,
    double? duration,
    String? thumbnailUrl,
    String? videoUrl,
    String? stageName,
    String? stageNumber,
    String? eventName,
    String? eventCountry,
    double? points,
  }) {
    return VideoAction(
      id: id ?? this.id,
      videoId: videoId ?? this.videoId,
      streamId: streamId ?? this.streamId,
      actionTypeId: actionTypeId ?? this.actionTypeId,
      actionType: actionType ?? this.actionType,
      title: title ?? this.title,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      duration: duration ?? this.duration,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      videoUrl: videoUrl ?? this.videoUrl,
      stageName: stageName ?? this.stageName,
      stageNumber: stageNumber ?? this.stageNumber,
      eventName: eventName ?? this.eventName,
      eventCountry: eventCountry ?? this.eventCountry,
      points: points ?? this.points,
    );
  }
}

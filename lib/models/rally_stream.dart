class RallyStream {
  final int id;
  final int? videoId;
  final double? clipDuration;
  final String? videoType;
  final String? onDemandUrl;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final double? clipStartTime;
  final String? clipStatus;
  final int downloadCounter;
  final int shareCounter;

  const RallyStream({
    required this.id,
    this.videoId,
    this.clipDuration,
    this.videoType,
    this.onDemandUrl,
    this.createdAt,
    this.updatedAt,
    this.clipStartTime,
    this.clipStatus,
    this.downloadCounter = 0,
    this.shareCounter = 0,
  });

  factory RallyStream.fromMap(Map<String, dynamic> map) {
    return RallyStream(
      id: _parseInt(map['id']) ?? 0,
      videoId: _parseInt(map['video_id']),
      clipDuration: _parseDouble(map['clip_duration']),
      videoType: map['video_type']?.toString(),
      onDemandUrl: map['on_demand_url']?.toString(),
      createdAt: _parseDateTime(map['created_at']),
      updatedAt: _parseDateTime(map['updated_at']),
      clipStartTime: _parseDouble(map['clip_start_time']),
      clipStatus: map['clip_status']?.toString(),
      downloadCounter: _parseInt(map['download_counter']) ?? 0,
      shareCounter: _parseInt(map['share_counter']) ?? 0,
    );
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

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    return DateTime.tryParse(value.toString());
  }

  String get formattedDuration {
    if (clipDuration == null) return '0.0s';
    if (clipDuration! < 60) {
      return '${clipDuration!.toStringAsFixed(1)}s';
    }
    final minutes = (clipDuration! / 60).floor();
    final remainingSecs = (clipDuration! % 60).toStringAsFixed(1);
    return '${minutes}m ${remainingSecs}s';
  }

  String get formattedClipRange {
    final start = clipStartTime ?? 0.0;
    if (clipDuration != null && clipDuration! > 0) {
      final end = start + clipDuration!;
      return '${_formatTimeSeconds(start)} → ${_formatTimeSeconds(end)}';
    }
    return '${_formatTimeSeconds(start)} → End';
  }

  static String _formatTimeSeconds(double totalSeconds) {
    final totalSecsInt = totalSeconds.floor();
    final hours = (totalSecsInt / 3600).floor();
    final minutes = ((totalSecsInt % 3600) / 60).floor().toString().padLeft(2, '0');
    final seconds = (totalSecsInt % 60).toString().padLeft(2, '0');
    if (hours > 0) {
      return '$hours:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }

  String get formattedDate {
    if (createdAt == null) return 'Unknown date';
    final y = createdAt!.year.toString().padLeft(4, '0');
    final m = createdAt!.month.toString().padLeft(2, '0');
    final d = createdAt!.day.toString().padLeft(2, '0');
    final h = createdAt!.hour.toString().padLeft(2, '0');
    final min = createdAt!.minute.toString().padLeft(2, '0');
    final s = createdAt!.second.toString().padLeft(2, '0');
    return '$y-$m-$d $h:$min:$s';
  }
}

import 'search_intent.dart';

/// Represents a Rally Event returned by SEARCH_RALLIES
class RallySearchResult {
  final String eventId;
  final String eventName;
  final String? status;
  final String? country;
  final String? city;
  final DateTime? startDate;
  final DateTime? endDate;
  final int stagesCount;
  final String? thumbnailUrl;
  final int? year;

  const RallySearchResult({
    required this.eventId,
    required this.eventName,
    this.status,
    this.country,
    this.city,
    this.startDate,
    this.endDate,
    this.stagesCount = 0,
    this.thumbnailUrl,
    this.year,
  });

  factory RallySearchResult.fromMap(Map<String, dynamic> map) {
    final start = _parseDateTime(map['start_date']);
    final end = _parseDateTime(map['end_date']);
    final stgCount = _parseInt(map['stages_count']) ?? _parseInt(map['calculated_stages_count']) ?? 0;
    final thumb = map['thumbnail']?.toString() ?? map['logo']?.toString();

    final name = map['event_name']?.toString() ?? 'Unnamed Rally';
    final nameYearMatch = RegExp(r'\b(20\d{2})\b').firstMatch(name);
    final nameYear = nameYearMatch != null ? int.tryParse(nameYearMatch.group(1)!) : null;

    final yr = start?.year ?? (map['year'] != null ? _parseInt(map['year']) : null) ?? nameYear;

    return RallySearchResult(
      eventId: map['event_id']?.toString() ?? '',
      eventName: name,
      status: map['status']?.toString(),
      country: map['country']?.toString(),
      city: (map['city'] != null && map['city'].toString().toLowerCase() != 'none') ? map['city'].toString() : null,
      startDate: start,
      endDate: end,
      stagesCount: stgCount,
      thumbnailUrl: (thumb != null && thumb.isNotEmpty && thumb != 'none') ? thumb : null,
      year: yr,
    );
  }


  String get formattedDateRange {
    if (startDate == null) return '';
    final s = startDate!;
    final months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    final sMonth = months[s.month - 1];

    if (endDate != null && endDate!.year == s.year) {
      final e = endDate!;
      if (e.month == s.month) {
        return '${s.day}–${e.day} $sMonth ${s.year}';
      }
      final eMonth = months[e.month - 1];
      return '${s.day} $sMonth – ${e.day} $eMonth ${s.year}';
    }
    return '${s.day} $sMonth ${s.year}';
  }

  String get formattedLocation {
    final parts = <String>[];
    if (city != null && city!.isNotEmpty) parts.add(city!);
    if (country != null && country!.isNotEmpty) parts.add(country!);
    return parts.isNotEmpty ? parts.join(', ') : 'Location not specified';
  }
}

/// Represents a driver or co-driver's participation record in a rally
class RallyParticipationResult {
  final String rallyId;
  final String eventName;
  final String? country;
  final String? city;
  final String? driverId;
  final String driverName;
  final String? role;
  final String? crew;
  final String? carNumber;
  final String? car;
  final String? make;
  final int? posOverall;
  final String? totalTime;
  final DateTime? startDate;
  final int? year;

  const RallyParticipationResult({
    required this.rallyId,
    required this.eventName,
    this.country,
    this.city,
    this.driverId,
    required this.driverName,
    this.role,
    this.crew,
    this.carNumber,
    this.car,
    this.make,
    this.posOverall,
    this.totalTime,
    this.startDate,
    this.year,
  });

  factory RallyParticipationResult.fromMap(Map<String, dynamic> map) {
    final start = _parseDateTime(map['start_date']);
    return RallyParticipationResult(
      rallyId: map['rally_id']?.toString() ?? map['event_id']?.toString() ?? '',
      eventName: map['event_name']?.toString() ?? 'Rally Event',
      country: map['country']?.toString() ?? map['driver_country']?.toString(),
      city: map['city']?.toString(),
      driverId: map['driver_id']?.toString() ?? map['user_driver_id']?.toString() ?? map['person_id']?.toString(),
      driverName: map['driver_name']?.toString() ?? map['full_name']?.toString() ?? map['crew']?.toString() ?? 'Competitor',
      role: map['role']?.toString(),
      crew: map['crew']?.toString(),
      carNumber: map['car_number']?.toString(),
      car: map['car']?.toString() ?? map['make']?.toString(),
      make: map['make']?.toString(),
      posOverall: _parseInt(map['pos_overall']),
      totalTime: map['total_time']?.toString(),
      startDate: start,
      year: start?.year ?? (map['year'] != null ? _parseInt(map['year']) : null),
    );
  }

  String get finishPositionDisplay {
    if (posOverall == null || posOverall! <= 0) {
      if (role != null && role!.isNotEmpty) {
        return 'Participated ($role)';
      }
      return 'Participated';
    }
    if (posOverall == 1) return '🏆 1st Place (Winner)';
    if (posOverall == 2) return '🥈 2nd Place';
    if (posOverall == 3) return '🥉 3rd Place';
    return 'Finished ${posOverall}th';
  }
}

/// Represents a specific classification or finisher record in a rally
class RallyResult {
  final int id;
  final String rallyId;
  final String eventName;
  final String? stageId;
  final String? stageName;
  final String? stageNumber;
  final String? driverId;
  final String driverName;
  final String? crew;
  final String? carNumber;
  final String? make;
  final String? classType;
  final int posOverall;
  final int? posStage;
  final String? totalTime;
  final String? stageTime;
  final String? diffLeader;
  final String? diffPrev;

  const RallyResult({
    required this.id,
    required this.rallyId,
    required this.eventName,
    this.stageId,
    this.stageName,
    this.stageNumber,
    this.driverId,
    required this.driverName,
    this.crew,
    this.carNumber,
    this.make,
    this.classType,
    required this.posOverall,
    this.posStage,
    this.totalTime,
    this.stageTime,
    this.diffLeader,
    this.diffPrev,
  });

  factory RallyResult.fromMap(Map<String, dynamic> map) {
    return RallyResult(
      id: _parseInt(map['id']) ?? 0,
      rallyId: map['rally_id']?.toString() ?? map['event_id']?.toString() ?? '',
      eventName: map['event_name']?.toString() ?? 'Rally Event',
      stageId: map['stage_id']?.toString(),
      stageName: map['stage_name']?.toString(),
      stageNumber: map['stage_number']?.toString(),
      driverId: map['driver_id']?.toString() ?? map['user_driver_id']?.toString(),
      driverName: map['driver_name']?.toString() ?? map['full_name']?.toString() ?? map['crew']?.toString() ?? 'Driver',
      crew: map['crew']?.toString(),
      carNumber: map['car_number']?.toString(),
      make: map['make']?.toString() ?? map['car']?.toString(),
      classType: map['class_type']?.toString() ?? map['class']?.toString(),
      posOverall: _parseInt(map['pos_overall']) ?? 1,
      posStage: _parseInt(map['pos_stage']),
      totalTime: map['total_time']?.toString(),
      stageTime: map['stage_time']?.toString(),
      diffLeader: map['diff_leader']?.toString(),
      diffPrev: map['diff_prev']?.toString(),
    );
  }

  String get positionBadge {
    if (posOverall == 1) return '🏆 1st';
    if (posOverall == 2) return '🥈 2nd';
    if (posOverall == 3) return '🥉 3rd';
    return '#$posOverall';
  }
}

/// Represents a source/stream video matching a driver or rally search
class VideoSearchResult {
  final int videoId;
  final int? streamId;
  final String? videoUrl;
  final String? thumbnailUrl;
  final String? eventName;
  final String? stageName;
  final String? stageNumber;
  final String? driverId;
  final String? driverName;
  final String? crew;
  final double? videoLengthSeconds;
  final DateTime? uploadTime;

  const VideoSearchResult({
    required this.videoId,
    this.streamId,
    this.videoUrl,
    this.thumbnailUrl,
    this.eventName,
    this.stageName,
    this.stageNumber,
    this.driverId,
    this.driverName,
    this.crew,
    this.videoLengthSeconds,
    this.uploadTime,
  });

  factory VideoSearchResult.fromMap(Map<String, dynamic> map) {
    final thumb = map['thumbnail']?.toString() ?? map['thumbnail_url']?.toString();
    final vUrl = map['on_demand_url']?.toString() ?? map['video_url']?.toString();

    return VideoSearchResult(
      videoId: _parseInt(map['video_id']) ?? _parseInt(map['id']) ?? 0,
      streamId: _parseInt(map['stream_id']),
      videoUrl: (vUrl != null && vUrl.isNotEmpty) ? vUrl : null,
      thumbnailUrl: (thumb != null && thumb.isNotEmpty && thumb != 'none') ? thumb : null,
      eventName: map['event_name']?.toString(),
      stageName: map['stage_name']?.toString(),
      stageNumber: map['stage_number']?.toString(),
      driverId: map['driver_id']?.toString() ?? map['uploader_driver_id']?.toString(),
      driverName: map['driver_name']?.toString() ?? map['full_name']?.toString(),
      crew: map['crew']?.toString(),
      videoLengthSeconds: _parseDouble(map['video_length_seconds']),
      uploadTime: _parseDateTime(map['created_at']),
    );
  }

  String get formattedLength {
    if (videoLengthSeconds == null || videoLengthSeconds! <= 0) return 'Video';
    final len = videoLengthSeconds!;
    final minutes = (len / 60).floor();
    final seconds = (len % 60).floor();
    return '${minutes}m ${seconds}s';
  }
}

/// Represents an uploader ranked by number of uploads
class UploaderSearchResult {
  final String uploaderId;
  final String uploaderName;
  final int uploadCount;
  final String? rallyContext;
  final String? profilePicture;

  const UploaderSearchResult({
    required this.uploaderId,
    required this.uploaderName,
    required this.uploadCount,
    this.rallyContext,
    this.profilePicture,
  });

  factory UploaderSearchResult.fromMap(Map<String, dynamic> map) {
    final pic = map['profile_picture']?.toString();
    final rawUploaderName = map['uploader_name']?.toString()?.trim();
    final rawUserName = map['user_name']?.toString()?.trim();
    final rawFullName = map['full_name']?.toString()?.trim();
    final rawEmail = map['email']?.toString()?.trim();

    final String name;
    if (rawUploaderName != null && rawUploaderName.isNotEmpty) {
      name = rawUploaderName;
    } else if (rawUserName != null && rawUserName.isNotEmpty) {
      name = rawUserName;
    } else if (rawFullName != null && rawFullName.isNotEmpty) {
      name = rawFullName;
    } else if (rawEmail != null && rawEmail.isNotEmpty) {
      name = rawEmail;
    } else {
      name = 'Rally Contributor';
    }

    return UploaderSearchResult(
      uploaderId: map['uploader_user_id']?.toString() ?? map['uploader_id']?.toString() ?? '',
      uploaderName: name,
      uploadCount: _parseInt(map['upload_count']) ?? _parseInt(map['count']) ?? 0,
      rallyContext: map['event_name']?.toString() ?? map['rally_name']?.toString(),
      profilePicture: (pic != null && pic.isNotEmpty && pic != 'none') ? pic : null,
    );
  }
}

/// Represents a driver ranked by total career rally wins
class DriverWinResult {
  final String? driverId;
  final String driverName;
  final int winCount;
  final String? country;
  final String? profilePicture;
  final String? latestRallyWon;

  const DriverWinResult({
    this.driverId,
    required this.driverName,
    required this.winCount,
    this.country,
    this.profilePicture,
    this.latestRallyWon,
  });

  factory DriverWinResult.fromMap(Map<String, dynamic> map) {
    final pic = map['profile_picture']?.toString();
    return DriverWinResult(
      driverId: map['driver_id']?.toString() ?? map['user_driver_id']?.toString(),
      driverName: map['driver_name']?.toString() ?? map['full_name']?.toString() ?? map['crew']?.toString() ?? 'Driver',
      winCount: _parseInt(map['win_count']) ?? _parseInt(map['wins']) ?? 0,
      country: map['country']?.toString() ?? map['driver_country']?.toString(),
      profilePicture: (pic != null && pic.isNotEmpty && pic != 'none') ? pic : null,
      latestRallyWon: map['latest_rally_won']?.toString() ?? map['event_name']?.toString(),
    );
  }
}

/// Typed generic container for search results
class SearchResponse<T> {
  final SearchIntent intent;
  final List<T> results;
  final int totalCount;
  final bool hasMore;
  final int limit;
  final int offset;

  const SearchResponse({
    required this.intent,
    required this.results,
    required this.totalCount,
    required this.hasMore,
    required this.limit,
    required this.offset,
  });

  int get currentPage => (offset / (limit <= 0 ? 20 : limit)).floor() + 1;
  int get totalPages => (totalCount / (limit <= 0 ? 20 : limit)).ceil();
}

// Helpers
int? _parseInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  return int.tryParse(value.toString());
}

double? _parseDouble(dynamic value) {
  if (value == null) return null;
  if (value is double) return value;
  if (value is int) return value.toDouble();
  return double.tryParse(value.toString());
}

DateTime? _parseDateTime(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  final str = value.toString().trim();
  if (str.isEmpty || str == 'null') return null;
  return DateTime.tryParse(str) ?? DateTime.tryParse(str.replaceAll(' ', 'T'));
}


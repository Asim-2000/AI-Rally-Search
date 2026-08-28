import 'dart:convert';
import 'dart:io';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:ai_rally_search/models/search_query.dart';
import 'package:ai_rally_search/models/search_results.dart';
import 'package:ai_rally_search/models/video_action.dart';
import 'package:ai_rally_search/services/database_service.dart';
import 'package:ai_rally_search/services/search_repository.dart';

Future<void> main(List<String> args) async {
  if (args.length != 2) {
    stderr.writeln('usage: dart run bin/run_structured_parity.dart FIXTURES OUTPUT');
    exitCode = 64; return;
  }
  await dotenv.load(fileName: '.env');
  final document=jsonDecode(await File(args[0]).readAsString()) as Map<String,dynamic>;
  if (document['schemaVersion'] != '1.0') throw StateError('Unsupported fixture schema');
  final sink=File(args[1]).openWrite();
  final db=DatabaseService(); final repo=SearchRepository(dbService: db);
  try {
    for (final raw in document['cases'] as List) {
      final fixture=Map<String,dynamic>.from(raw as Map);
      final query=SearchQuery.fromJson(Map<String,dynamic>.from(fixture['searchQuery'] as Map));
      final response=await repo.search(query);
      final ids=response.results.map<String>(_canonicalId).toList();
      sink.writeln(jsonEncode({
        'schemaVersion':'1.0','runtime':'dart','caseId':fixture['caseId'],
        'searchQuery':fixture['searchQuery'],'intent':response.intent.toIntentString(),
        'orderedCanonicalIds':ids,'total':response.totalCount,'limit':response.limit,
        'offset':response.offset,'hasMore':response.hasMore,
        'currentPage':(response.offset ~/ response.limit)+1,
      }));
    }
  } finally { await sink.flush(); await sink.close(); await db.close(); }
}

String _canonicalId(dynamic item) {
  if (item is RallySearchResult) return item.eventId;
  if (item is RallyParticipationResult) return item.rallyId;
  if (item is RallyResult) return item.id.toString();
  if (item is VideoAction) return item.id.toString();
  if (item is VideoSearchResult) return item.videoId.toString();
  if (item is UploaderSearchResult) return item.uploaderId;
  if (item is DriverWinResult) return item.driverId ?? item.driverName;
  throw StateError('No canonical identity for ${item.runtimeType}');
}

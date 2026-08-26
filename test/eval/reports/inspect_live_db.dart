import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:ai_rally_search/services/database_service.dart';
import 'package:ai_rally_search/services/llm/entity_resolution/entity_lookup_repository.dart';
import 'package:ai_rally_search/services/llm/entity_resolution/database_entity_resolver.dart';
import 'package:ai_rally_search/models/search_query.dart';
import 'package:ai_rally_search/models/search_intent.dart';

void main() {
  test('Debug raliserras', () async {
    await dotenv.load(fileName: '.env');
    final dbService = DatabaseService();
    final repo = DatabaseEntityLookupRepository(dbService: dbService);
    final resolver = DatabaseEntityResolver(repository: repo);

    final res = await resolver.resolve(const SearchQuery(
      intent: SearchIntent.searchRallies,
      rallyName: 'raliserras',
      year: 2025,
    ));

    print('raliserras output:');
    print('  requiresClarification: ${res.requiresClarification}');
    print('  strategy: ${res.resolutions['rally']?.strategy}');
    print('  candidates:');
    for (final c in res.resolutions['rally']?.candidateOptions ?? []) {
      print('    ${c.canonicalName} (${c.id}) -> Score: ${c.score}, metadata: ${c.metadata}');
    }
  });
}

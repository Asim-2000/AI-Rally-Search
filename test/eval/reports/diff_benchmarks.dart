import 'dart:convert';
import 'dart:io';

void main() {
  final file5B1 = File('test/eval/reports/live_voice_synthetic_1787784159551.json');
  final file5B2 = File('test/eval/reports/live_voice_synthetic_1787785273378.json');

  final json5B1 = jsonDecode(file5B1.readAsStringSync());
  final json5B2 = jsonDecode(file5B2.readAsStringSync());

  final samples5B1 = json5B1['samples'] as List;
  final samples5B2 = json5B2['samples'] as List;

  print('Total 5B.1 samples: ${samples5B1.length}');
  print('Total 5B.2 samples: ${samples5B2.length}');

  int regressedCount = 0;
  for (int i = 0; i < samples5B1.length; i++) {
    final s1 = samples5B1[i];
    final s2 = samples5B2[i];

    final pass1 = s1['search_semantic_success'] == true;
    final pass2 = s2['search_semantic_success'] == true;

    if (pass1 && !pass2) {
      regressedCount++;
      print('======================================================================');
      print('REGRESSION #${regressedCount}: [${s1['id']}] ${s1['language']} (${s1['locale']})');
      print('Audio: ${s1['audio_file']}');
      print('Expected Transcript: "${s1['expected_transcript']}"');
      print('STT Raw: "${s2['actual_transcript']}"');
      print('5B.1 Normalized: "${s1['normalized_transcript']}" (Mappings: ${s1['recovery_mappings']})');
      print('5B.2 Normalized: "${s2['normalized_transcript']}" (Mappings: ${s2['recovery_mappings']})');
      print('Expected SearchQuery: ${s1['expected_query']}');
      print('5B.1 Resolved Query: ${s1['resolved_query']}');
      print('5B.2 Resolved Query: ${s2['resolved_query']}');
      print('5B.2 Parsed Query (from LLM): ${s2['parsed_query']}');
      print('5B.2 Failure Attribution: ${s2['failure_attribution']}');
      print('5B.2 DB Success: ${s2['db_execution_succeeded']}, Rows: ${s2['returned_row_count']}');
    }
  }
}

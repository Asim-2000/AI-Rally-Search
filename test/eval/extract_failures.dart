import 'dart:convert';
import 'dart:io';

void main() {
  final jsonStr = File('test/eval/reports/openai_gpt-5.6-luna_1787779326486.json').readAsStringSync();
  final data = jsonDecode(jsonStr) as Map<String, dynamic>;
  final records = (data['records'] as List).cast<Map<String, dynamic>>();

  final failed = records.where((r) => !(r['exact_match'] == true && (r['failures'] as List).isEmpty)).toList();
  print('TOTAL FAILED CASES: ${failed.length} / ${records.length}\n');

  for (final f in failed) {
    print('================================================================');
    print('ID: [${f['id']}] | Category: ${f['category']}');
    print('Query: "${f['query']}"');
    print('Exact Match: ${f['exact_match']} | Intent Match: ${f['intent_match']}');
    print('Failures:');
    for (final err in f['failures'] as List) {
      print('  - [${err['type']}] ${err['message']}');
    }
    print('Slot Matches: ${f['slot_matches']}');
  }
}

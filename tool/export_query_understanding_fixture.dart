import 'dart:convert';
import 'dart:io';

import '../test/eval/query_benchmark_cases.dart';

void main(List<String> args) {
  final cases = QueryBenchmarkCases.allCases.map((c) {
    final expected = <String, dynamic>{'intent': c.expectedIntent?.toIntentString()};
    const aliases = {
      'country': 'countries', 'city': 'cities', 'year': 'years',
      'rallyName': 'rallyNames', 'targetRallyName': 'rallyNames',
      'stageName': 'stageNames', 'stageNumber': 'stageNumbers',
      'driverName': 'driverNames', 'actionType': 'actionTypes',
      'uploader': 'uploaders',
    };
    c.expectedFilters.forEach((key, value) {
      final target = aliases[key] ?? key;
      if (aliases.containsKey(key) && value is! List) {
        expected[target] = [value];
      } else {
        expected[target] = value;
      }
    });
    return {
      'caseId': c.id,
      'input': c.query,
      'language': c.languageCode ?? 'en',
      'expected': expected,
      'category': c.category,
      'tags': [c.difficulty.name],
      if (c.description != null) 'description': c.description,
      if (c.context?.currentYear != null) 'currentYear': c.context!.currentYear,
      if (c.expectedClarification) 'expectedClarification': true,
    };
  }).toList();
  final output = const JsonEncoder.withIndent('  ').convert({
    'fixtureVersion': 'dart_golden_176_v1',
    'source': 'test/eval/query_benchmark_cases.dart',
    'singleTurn': true,
    'count': cases.length,
    'cases': cases,
  });
  if (args.isEmpty) {
    stdout.write(output);
  } else {
    final file = File(args.first);
    file.parent.createSync(recursive: true);
    file.writeAsStringSync('$output\n');
    stdout.writeln('Exported ${cases.length} cases to ${file.path}');
  }
}

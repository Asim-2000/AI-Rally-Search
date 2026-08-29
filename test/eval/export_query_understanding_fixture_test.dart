import 'package:flutter_test/flutter_test.dart';

import '../../tool/export_query_understanding_fixture.dart' as exporter;

void main() {
  test('export frozen query-understanding fixture', () {
    exporter.main(['backend/benchmarks/query_understanding/fixtures/golden_176_v1.json']);
  });
}

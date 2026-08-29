import 'package:flutter_test/flutter_test.dart';
import '../../bin/run_structured_parity.dart' as runner;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('execute shared deterministic parity fixtures', () async {
    const fixtures=String.fromEnvironment('PARITY_FIXTURES');
    const output=String.fromEnvironment('PARITY_OUTPUT');
    expect(fixtures,isNotEmpty); expect(output,isNotEmpty);
    await runner.main([fixtures,output]);
  }, timeout: const Timeout(Duration(minutes: 5)));
}

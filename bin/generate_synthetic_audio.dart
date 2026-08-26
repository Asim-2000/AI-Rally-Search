import 'dart:convert';
import 'dart:io';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import '../test/eval/manifest/benchmark_manifest.dart';

void main(List<String> args) async {
  stdout.writeln('===========================================================');
  stdout.writeln('🎙️ Generating 38 Synthetic Audio Files (19 Languages)');
  stdout.writeln('===========================================================');

  try {
    dotenv.testLoad(file: File('.env').readAsStringSync());
  } catch (_) {}

  final apiKey = dotenv.env['OPENAI_API_KEY'];
  if (apiKey == null || apiKey.isEmpty) {
    stderr.writeln('ERROR: OPENAI_API_KEY is not configured in .env');
    exit(1);
  }

  final dir = Directory('test/eval/audio/synthetic');
  if (!dir.existsSync()) {
    dir.createSync(recursive: true);
  }

  final entries = SyntheticSmokeBenchmarkManifest.entries;
  stdout.writeln('Total manifest entries: ${entries.length}\n');

  final client = http.Client();
  int generatedCount = 0;
  int skippedCount = 0;

  for (final entry in entries) {
    final targetFile = File(entry.audioFile);
    if (targetFile.existsSync() && targetFile.lengthSync() > 100 && !args.contains('--force')) {
      stdout.writeln('⏩ [${entry.id}] ${entry.language.displayName} (${entry.locale}) - Exists (${targetFile.lengthSync()} bytes)');
      skippedCount++;
      continue;
    }

    stdout.write('⏳ [${entry.id}] Generating ${entry.language.displayName} (${entry.locale}): "${entry.expectedTranscript}"... ');
    final stopwatch = Stopwatch()..start();

    try {
      final uri = Uri.parse('https://api.openai.com/v1/audio/speech');
      final response = await client.post(
        uri,
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': 'tts-1',
          'voice': 'alloy',
          'input': entry.expectedTranscript,
          'response_format': 'mp3',
        }),
      );

      stopwatch.stop();

      if (response.statusCode >= 200 && response.statusCode < 300) {
        targetFile.writeAsBytesSync(response.bodyBytes);
        stdout.writeln('✅ (${response.bodyBytes.length} bytes, ${stopwatch.elapsedMilliseconds}ms)');
        generatedCount++;
      } else {
        stdout.writeln('❌ HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      stopwatch.stop();
      stdout.writeln('❌ Error: $e');
    }

    // Rate-limiting courtesy
    await Future.delayed(const Duration(milliseconds: 100));
  }

  client.close();

  stdout.writeln('\n===========================================================');
  stdout.writeln('Summary: $generatedCount generated, $skippedCount existing, total ${entries.length}');
  stdout.writeln('===========================================================');
}

import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'manifest/benchmark_manifest.dart';

void main() {
  test('Generate 38 synthetic audio samples via OpenAI TTS for 19 languages', () async {
    final envLines = File('.env').readAsLinesSync();
    String? apiKey;
    for (final line in envLines) {
      if (line.startsWith('OPENAI_API_KEY=')) {
        apiKey = line.substring('OPENAI_API_KEY='.length).trim();
      }
    }

    expect(apiKey, isNotNull);
    expect(apiKey!.isNotEmpty, isTrue);

    final dir = Directory('test/eval/audio/synthetic');
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }

    final entries = SyntheticSmokeBenchmarkManifest.entries;
    expect(entries.length, equals(38));

    final client = http.Client();
    int generatedCount = 0;
    int existingCount = 0;

    for (final entry in entries) {
      final targetFile = File(entry.audioFile);
      if (targetFile.existsSync() && targetFile.lengthSync() > 500) {
        existingCount++;
        continue;
      }

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

      expect(response.statusCode, inInclusiveRange(200, 299),
          reason: 'TTS failed for ${entry.id} (${entry.language.displayName}): ${response.body}');

      targetFile.writeAsBytesSync(response.bodyBytes);
      expect(targetFile.existsSync(), isTrue);
      expect(targetFile.lengthSync(), greaterThan(500));
      generatedCount++;

      // Rate limit buffer
      await Future.delayed(const Duration(milliseconds: 80));
    }

    client.close();
    // Verify all 38 files exist
    for (final entry in entries) {
      final f = File(entry.audioFile);
      expect(f.existsSync(), isTrue, reason: 'Missing audio file ${entry.audioFile}');
      expect(f.lengthSync(), greaterThan(500), reason: 'Empty audio file ${entry.audioFile}');
    }
  }, timeout: const Timeout(Duration(minutes: 5)));
}

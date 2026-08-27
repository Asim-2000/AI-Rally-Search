import 'dart:math';
import 'dart:typed_data';

import 'package:ai_rally_search/services/speech/audio_preprocessor.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const noOp = NoOpAudioPreprocessor();
  const speech = SpeechAudioPreprocessor();

  test('NoOpAudioPreprocessor preserves bytes', () async {
    final input = _fixtureWave();
    final result = await noOp.process(
      inputBytes: input,
      filename: 'fixture.wav',
      strategy: AudioPreprocessingStrategy.raw,
    );
    expect(result.bytes, orderedEquals(input));
    expect(result.changed, isFalse);
  });

  test('VAD trims silence while retaining speech', () async {
    final input = _fixtureWave();
    final result = await speech.process(
      inputBytes: input,
      filename: 'fixture.wav',
      strategy: AudioPreprocessingStrategy.vadOnly,
    );
    expect(result.changed, isTrue);
    expect(result.bytes.length, lessThan(input.length));
    expect(result.diagnostics['trimmedLeadingMs'], isNotNull);
    expect(result.diagnostics['trimmedTrailingMs'], isNotNull);
  });

  test('normalization raises quiet speech without clipping', () async {
    final input = _fixtureWave(amplitude: 1000);
    final result = await speech.process(
      inputBytes: input,
      filename: 'fixture.wav',
      strategy: AudioPreprocessingStrategy.normalized,
    );
    final inputPeak = _peak(input);
    final outputPeak = _peak(result.bytes);
    expect(outputPeak, greaterThan(inputPeak));
    expect(outputPeak, lessThan(32768));
    expect(result.diagnostics['normalizationGain'], greaterThan(1));
  });

  test('all experimental strategies return valid PCM WAVE data', () async {
    final input = _fixtureWave();
    for (final strategy in AudioPreprocessingStrategy.values) {
      final result = await speech.process(
        inputBytes: input,
        filename: 'fixture.wav',
        strategy: strategy,
      );
      expect(String.fromCharCodes(result.bytes.take(4)), 'RIFF');
      expect(String.fromCharCodes(result.bytes.skip(8).take(4)), 'WAVE');
      expect(result.filename, endsWith('.wav'));
    }
  });
}

List<int> _fixtureWave({int amplitude = 2500}) {
  const sampleRate = 16000;
  final samples = <int>[
    ...List<int>.filled(sampleRate ~/ 2, 10),
    ...List<int>.generate(
      sampleRate,
      (index) => (sin(index * 2 * pi * 220 / sampleRate) * amplitude).round(),
    ),
    ...List<int>.filled(sampleRate ~/ 2, -10),
  ];
  final bytes = Uint8List(44 + samples.length * 2);
  final data = ByteData.sublistView(bytes);
  bytes.setRange(0, 4, 'RIFF'.codeUnits);
  data.setUint32(4, 36 + samples.length * 2, Endian.little);
  bytes.setRange(8, 12, 'WAVE'.codeUnits);
  bytes.setRange(12, 16, 'fmt '.codeUnits);
  data.setUint32(16, 16, Endian.little);
  data.setUint16(20, 1, Endian.little);
  data.setUint16(22, 1, Endian.little);
  data.setUint32(24, sampleRate, Endian.little);
  data.setUint32(28, sampleRate * 2, Endian.little);
  data.setUint16(32, 2, Endian.little);
  data.setUint16(34, 16, Endian.little);
  bytes.setRange(36, 40, 'data'.codeUnits);
  data.setUint32(40, samples.length * 2, Endian.little);
  for (var index = 0; index < samples.length; index++) {
    data.setInt16(44 + index * 2, samples[index], Endian.little);
  }
  return bytes;
}

int _peak(List<int> bytes) {
  final data = ByteData.sublistView(Uint8List.fromList(bytes));
  var peak = 0;
  for (var index = 44; index + 1 < bytes.length; index += 2) {
    peak = max(peak, data.getInt16(index, Endian.little).abs());
  }
  return peak;
}

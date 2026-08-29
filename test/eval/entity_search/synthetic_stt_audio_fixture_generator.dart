import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'synthetic_stt_biasing_corpus.dart';

class SyntheticAudioGenerationStats {
  int ttsCalls = 0;
  int reusedFiles = 0;
  int generatedFiles = 0;
  int totalDurationMs = 0;

  Map<String, Object> toJson() => {
    'ttsCalls': ttsCalls,
    'reusedFiles': reusedFiles,
    'generatedFiles': generatedFiles,
    'totalDurationMs': totalDurationMs,
    'ttsProvider': 'macOS say (local system TTS)',
    'estimatedProviderCostUsd': 0.0,
  };
}

class SyntheticSttAudioFixtureGenerator {
  final Directory outputDirectory;

  SyntheticSttAudioFixtureGenerator(this.outputDirectory);

  Future<SyntheticAudioGenerationStats> generate(
    SyntheticSttCorpus corpus,
  ) async {
    outputDirectory.createSync(recursive: true);
    final stats = SyntheticAudioGenerationStats();
    for (var offset = 0; offset < corpus.utterances.length; offset += 8) {
      final batch = corpus.utterances.skip(offset).take(8);
      final partials = await Future.wait(batch.map(_generateUtterance));
      for (final partial in partials) {
        stats.ttsCalls += partial.ttsCalls;
        stats.reusedFiles += partial.reusedFiles;
        stats.generatedFiles += partial.generatedFiles;
        stats.totalDurationMs += partial.totalDurationMs;
      }
    }
    return stats;
  }

  Future<SyntheticAudioGenerationStats> _generateUtterance(
    SyntheticSttUtterance utterance,
  ) async {
    final stats = SyntheticAudioGenerationStats();
    final clean = File('${outputDirectory.path}/${utterance.id}_clean.wav');
    final noisy = File('${outputDirectory.path}/${utterance.id}_noisy.wav');
    if (!clean.existsSync() || clean.lengthSync() < 1000) {
      await _synthesize(
        utterance.text,
        clean,
        voice: utterance.templateIndex.isEven ? 'Samantha' : 'Daniel',
        rate: utterance.templateIndex.isEven ? 180 : 205,
      );
      stats.ttsCalls++;
      stats.generatedFiles++;
    } else {
      stats.reusedFiles++;
    }
    if (!noisy.existsSync() || noisy.lengthSync() < 1000) {
      final alternate = File('${outputDirectory.path}/${utterance.id}_alt.wav');
      await _synthesize(
        utterance.text,
        alternate,
        voice: utterance.templateIndex.isEven ? 'Daniel' : 'Samantha',
        rate: utterance.templateIndex.isEven ? 210 : 165,
      );
      stats.ttsCalls++;
      final wave = _readPcm16Wave(alternate.readAsBytesSync());
      noisy.writeAsBytesSync(
        _perturb(wave, seed: syntheticSttBiasingSeed ^ utterance.id.hashCode),
      );
      alternate.deleteSync();
      stats.generatedFiles++;
    } else {
      stats.reusedFiles++;
    }
    stats.totalDurationMs += _durationMs(clean);
    stats.totalDurationMs += _durationMs(noisy);
    return stats;
  }

  Future<void> _synthesize(
    String text,
    File output, {
    required String voice,
    required int rate,
  }) async {
    final aiff = File('${output.path}.aiff');
    final say = await Process.run('say', [
      '-v',
      voice,
      '-r',
      '$rate',
      '-o',
      aiff.path,
      text,
    ]);
    if (say.exitCode != 0) {
      throw StateError('System TTS failed: ${say.stderr}');
    }
    final convert = await Process.run('afconvert', [
      '-f',
      'WAVE',
      '-d',
      'LEI16@16000',
      '-c',
      '1',
      aiff.path,
      output.path,
    ]);
    if (convert.exitCode != 0) {
      throw StateError('Audio conversion failed: ${convert.stderr}');
    }
    if (aiff.existsSync()) aiff.deleteSync();
  }

  static int _durationMs(File file) {
    final wave = _readPcm16Wave(file.readAsBytesSync());
    return (wave.samples.length * 1000 / wave.sampleRate).round();
  }

  static _PcmWave _readPcm16Wave(List<int> bytes) {
    final data = ByteData.sublistView(Uint8List.fromList(bytes));
    if (bytes.length < 44 || String.fromCharCodes(bytes.take(4)) != 'RIFF') {
      throw const FormatException('Expected RIFF WAV');
    }
    var offset = 12;
    var sampleRate = 16000;
    var channels = 1;
    int? dataOffset;
    int? dataLength;
    while (offset + 8 <= bytes.length) {
      final id = String.fromCharCodes(bytes.sublist(offset, offset + 4));
      final length = data.getUint32(offset + 4, Endian.little);
      if (id == 'fmt ' && offset + 8 + length <= bytes.length) {
        channels = data.getUint16(offset + 10, Endian.little);
        sampleRate = data.getUint32(offset + 12, Endian.little);
      }
      if (id == 'data') {
        dataOffset = offset + 8;
        dataLength = min(length, bytes.length - dataOffset);
        break;
      }
      offset += 8 + length + (length.isOdd ? 1 : 0);
    }
    if (dataOffset == null || dataLength == null || channels != 1) {
      throw const FormatException('Expected mono PCM WAV data');
    }
    final samples = <int>[];
    for (var i = dataOffset; i + 1 < dataOffset + dataLength; i += 2) {
      samples.add(data.getInt16(i, Endian.little));
    }
    return _PcmWave(sampleRate, samples);
  }

  static List<int> _perturb(_PcmWave wave, {required int seed}) {
    final random = Random(seed);
    final leading = wave.sampleRate ~/ 7;
    final trailing = wave.sampleRate ~/ 5;
    final samples = List<int>.filled(leading, 0, growable: true);
    for (final source in wave.samples) {
      final noise = random.nextInt(801) - 400;
      final scaled = source * 0.72 + noise;
      final compressed = scaled.abs() < 10000
          ? scaled
          : scaled.sign * (10000 + (scaled.abs() - 10000) * 0.45);
      samples.add(compressed.round().clamp(-32768, 32767));
    }
    samples.addAll(List.filled(trailing, 0));
    return _writePcm16Wave(wave.sampleRate, samples);
  }

  static List<int> _writePcm16Wave(int sampleRate, List<int> samples) {
    final bytes = Uint8List(44 + samples.length * 2);
    final data = ByteData.sublistView(bytes);
    bytes.setRange(0, 4, 'RIFF'.codeUnits);
    data.setUint32(4, bytes.length - 8, Endian.little);
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
    for (var i = 0; i < samples.length; i++) {
      data.setInt16(44 + i * 2, samples[i], Endian.little);
    }
    return bytes;
  }
}

class _PcmWave {
  final int sampleRate;
  final List<int> samples;
  const _PcmWave(this.sampleRate, this.samples);
}

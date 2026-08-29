import 'dart:math';
import 'dart:typed_data';

enum AudioPreprocessingStrategy {
  raw,
  vadOnly,
  normalized,
  noiseSuppressed,
  vadNormalizedNoiseSuppressed,
}

class AudioPreprocessingResult {
  final AudioPreprocessingStrategy strategy;
  final List<int> bytes;
  final String filename;
  final Duration latency;
  final bool changed;
  final Map<String, Object?> diagnostics;

  const AudioPreprocessingResult({
    required this.strategy,
    required this.bytes,
    required this.filename,
    required this.latency,
    required this.changed,
    this.diagnostics = const {},
  });
}

abstract interface class IAudioPreprocessor {
  Future<AudioPreprocessingResult> process({
    required List<int> inputBytes,
    required String filename,
    required AudioPreprocessingStrategy strategy,
  });
}

class NoOpAudioPreprocessor implements IAudioPreprocessor {
  const NoOpAudioPreprocessor();

  @override
  Future<AudioPreprocessingResult> process({
    required List<int> inputBytes,
    required String filename,
    required AudioPreprocessingStrategy strategy,
  }) async => AudioPreprocessingResult(
    strategy: strategy,
    bytes: List<int>.unmodifiable(inputBytes),
    filename: filename,
    latency: Duration.zero,
    changed: false,
    diagnostics: const {'implementation': 'no_op'},
  );
}

/// Experimental, local-only processor for 16-bit PCM WAVE speech fixtures.
///
/// It is deliberately not wired into production voice routing. The algorithms
/// are conservative and replaceable: energy-based silence trimming, bounded
/// RMS normalization, and a soft frame noise gate.
class SpeechAudioPreprocessor implements IAudioPreprocessor {
  const SpeechAudioPreprocessor();

  @override
  Future<AudioPreprocessingResult> process({
    required List<int> inputBytes,
    required String filename,
    required AudioPreprocessingStrategy strategy,
  }) async {
    final watch = Stopwatch()..start();
    if (strategy == AudioPreprocessingStrategy.raw) {
      watch.stop();
      return AudioPreprocessingResult(
        strategy: strategy,
        bytes: List<int>.unmodifiable(inputBytes),
        filename: filename,
        latency: watch.elapsed,
        changed: false,
        diagnostics: const {'implementation': 'speech_dsp_raw_passthrough'},
      );
    }

    final input = _Pcm16Wave.decode(inputBytes);
    var working = input;
    final diagnostics = <String, Object?>{
      'implementation': 'local_conservative_pcm16_dsp',
      'inputFrames': input.frames,
      'sampleRateHz': input.sampleRate,
      'channels': input.channels,
      'operations': <String>[],
    };
    final operations = diagnostics['operations']! as List<String>;

    if (strategy == AudioPreprocessingStrategy.noiseSuppressed ||
        strategy == AudioPreprocessingStrategy.vadNormalizedNoiseSuppressed) {
      final result = _softNoiseGate(working);
      working = result.wave;
      operations.add('soft_noise_gate');
      diagnostics.addAll(result.diagnostics);
    }
    if (strategy == AudioPreprocessingStrategy.normalized ||
        strategy == AudioPreprocessingStrategy.vadNormalizedNoiseSuppressed) {
      final result = _normalize(working);
      working = result.wave;
      operations.add('bounded_rms_normalization');
      diagnostics.addAll(result.diagnostics);
    }
    if (strategy == AudioPreprocessingStrategy.vadOnly ||
        strategy == AudioPreprocessingStrategy.vadNormalizedNoiseSuppressed) {
      final result = _trimSilence(working);
      working = result.wave;
      operations.add('energy_vad_silence_trim');
      diagnostics.addAll(result.diagnostics);
    }

    final output = working.encode();
    watch.stop();
    diagnostics['outputFrames'] = working.frames;
    diagnostics['durationBeforeMs'] = input.frames / input.sampleRate * 1000;
    diagnostics['durationAfterMs'] = working.frames / working.sampleRate * 1000;
    return AudioPreprocessingResult(
      strategy: strategy,
      bytes: output,
      filename: _derivedFilename(filename, strategy),
      latency: watch.elapsed,
      changed: !_sameBytes(inputBytes, output),
      diagnostics: diagnostics,
    );
  }

  static ({_Pcm16Wave wave, Map<String, Object?> diagnostics}) _trimSilence(
    _Pcm16Wave input,
  ) {
    final frameLength = max(1, (input.sampleRate * 0.02).round());
    final frameRms = _frameRms(input, frameLength);
    if (frameRms.isEmpty) {
      return (wave: input, diagnostics: const {'vadActiveFrames': 0});
    }
    final sorted = [...frameRms]..sort();
    final noiseFloor = sorted[(sorted.length * 0.2).floor()];
    final absoluteFloor = 32768 * pow(10, -45 / 20);
    final threshold = max(absoluteFloor, noiseFloor * 3.0).toDouble();
    final first = frameRms.indexWhere((value) => value >= threshold);
    final last = frameRms.lastIndexWhere((value) => value >= threshold);
    if (first < 0 || last < first) {
      return (
        wave: input,
        diagnostics: {
          'vadActiveFrames': 0,
          'vadThresholdRms': threshold,
          'vadFallback': 'no_active_speech_detected_kept_original',
        },
      );
    }
    final paddingFrames = (0.15 / 0.02).ceil();
    final startFrame = max(0, first - paddingFrames) * frameLength;
    final endFrame = min(
      input.frames,
      (last + paddingFrames + 1) * frameLength,
    );
    final startSample = startFrame * input.channels;
    final endSample = endFrame * input.channels;
    return (
      wave: input.copyWith(
        samples: input.samples.sublist(startSample, endSample),
      ),
      diagnostics: {
        'vadActiveFrames': last - first + 1,
        'vadThresholdRms': threshold,
        'vadNoiseFloorRms': noiseFloor,
        'trimmedLeadingMs': startFrame / input.sampleRate * 1000,
        'trimmedTrailingMs':
            (input.frames - endFrame) / input.sampleRate * 1000,
        'vadPaddingMsPerSide': paddingFrames * 20,
      },
    );
  }

  static ({_Pcm16Wave wave, Map<String, Object?> diagnostics}) _normalize(
    _Pcm16Wave input,
  ) {
    final active = input.samples.where((sample) => sample.abs() >= 64).toList();
    final source = active.isEmpty ? input.samples : active;
    final rms = source.isEmpty
        ? 0.0
        : sqrt(
            source.fold<double>(0, (sum, sample) => sum + sample * sample) /
                source.length,
          );
    final peak = input.samples.fold<int>(
      0,
      (value, sample) => max(value, sample.abs()),
    );
    final targetRms = 32768 * pow(10, -23 / 20);
    final targetPeak = 32768 * pow(10, -3 / 20);
    final rmsGain = rms <= 0 ? 1.0 : targetRms / rms;
    final peakGain = peak <= 0 ? 1.0 : targetPeak / peak;
    final gain = min(3.0, min(rmsGain, peakGain)).clamp(0.75, 3.0).toDouble();
    final output = input.samples
        .map((sample) => (sample * gain).round().clamp(-32768, 32767))
        .toList(growable: false);
    return (
      wave: input.copyWith(samples: output),
      diagnostics: {
        'normalizationInputRms': rms,
        'normalizationInputPeak': peak,
        'normalizationGain': gain,
        'normalizationTargetRmsDbfs': -23,
        'normalizationPeakCeilingDbfs': -3,
        'normalizationGainCapDb': 20 * log(3) / ln10,
      },
    );
  }

  static ({_Pcm16Wave wave, Map<String, Object?> diagnostics}) _softNoiseGate(
    _Pcm16Wave input,
  ) {
    final frameLength = max(1, (input.sampleRate * 0.01).round());
    final rmsValues = _frameRms(input, frameLength);
    if (rmsValues.isEmpty) {
      return (wave: input, diagnostics: const {'noiseGateFramesChanged': 0});
    }
    final sorted = [...rmsValues]..sort();
    final estimatedNoiseRms = sorted[(sorted.length * 0.2).floor()];
    final minimumGate = 32768 * pow(10, -55 / 20);
    final threshold = max(minimumGate, estimatedNoiseRms * 2.5).toDouble();
    final output = List<int>.from(input.samples);
    var changedFrames = 0;
    for (var frame = 0; frame < rmsValues.length; frame++) {
      if (rmsValues[frame] >= threshold) continue;
      changedFrames++;
      final start = frame * frameLength * input.channels;
      final end = min(
        output.length,
        (frame + 1) * frameLength * input.channels,
      );
      for (var index = start; index < end; index++) {
        output[index] = (output[index] * 0.25).round();
      }
    }
    return (
      wave: input.copyWith(samples: output),
      diagnostics: {
        'estimatedNoiseRms': estimatedNoiseRms,
        'noiseGateThresholdRms': threshold,
        'noiseGateAttenuationDb': -12.041199826559248,
        'noiseGateFramesChanged': changedFrames,
        'noiseGateTotalFrames': rmsValues.length,
      },
    );
  }

  static List<double> _frameRms(_Pcm16Wave input, int frameLength) {
    final values = <double>[];
    for (
      var frameStart = 0;
      frameStart < input.frames;
      frameStart += frameLength
    ) {
      final frameEnd = min(input.frames, frameStart + frameLength);
      var squareSum = 0.0;
      var count = 0;
      for (var frame = frameStart; frame < frameEnd; frame++) {
        for (var channel = 0; channel < input.channels; channel++) {
          final sample = input.samples[frame * input.channels + channel];
          squareSum += sample * sample;
          count++;
        }
      }
      values.add(count == 0 ? 0 : sqrt(squareSum / count));
    }
    return values;
  }

  static String _derivedFilename(
    String filename,
    AudioPreprocessingStrategy strategy,
  ) {
    final dot = filename.lastIndexOf('.');
    final stem = dot < 0 ? filename : filename.substring(0, dot);
    return '${stem}_${strategy.name}.wav';
  }

  static bool _sameBytes(List<int> left, List<int> right) {
    if (left.length != right.length) return false;
    for (var index = 0; index < left.length; index++) {
      if (left[index] != right[index]) return false;
    }
    return true;
  }
}

class _Pcm16Wave {
  final int sampleRate;
  final int channels;
  final List<int> samples;

  const _Pcm16Wave({
    required this.sampleRate,
    required this.channels,
    required this.samples,
  });

  int get frames => samples.length ~/ channels;

  _Pcm16Wave copyWith({List<int>? samples}) => _Pcm16Wave(
    sampleRate: sampleRate,
    channels: channels,
    samples: samples ?? this.samples,
  );

  factory _Pcm16Wave.decode(List<int> source) {
    final bytes = Uint8List.fromList(source);
    final data = ByteData.sublistView(bytes);
    if (bytes.length < 44 ||
        _ascii(bytes, 0, 4) != 'RIFF' ||
        _ascii(bytes, 8, 4) != 'WAVE') {
      throw const FormatException('Expected a RIFF/WAVE file.');
    }
    int? sampleRate;
    int? channels;
    int? bitsPerSample;
    int? audioFormat;
    int? audioOffset;
    int? audioLength;
    var offset = 12;
    while (offset + 8 <= bytes.length) {
      final id = _ascii(bytes, offset, 4);
      final length = data.getUint32(offset + 4, Endian.little);
      final start = offset + 8;
      if (start + length > bytes.length) {
        throw const FormatException('Truncated WAVE chunk.');
      }
      if (id == 'fmt ' && length >= 16) {
        audioFormat = data.getUint16(start, Endian.little);
        channels = data.getUint16(start + 2, Endian.little);
        sampleRate = data.getUint32(start + 4, Endian.little);
        bitsPerSample = data.getUint16(start + 14, Endian.little);
      } else if (id == 'data') {
        audioOffset = start;
        audioLength = length;
      }
      offset = start + length + (length.isOdd ? 1 : 0);
    }
    if (audioFormat != 1 ||
        bitsPerSample != 16 ||
        channels == null ||
        channels < 1 ||
        sampleRate == null ||
        audioOffset == null ||
        audioLength == null) {
      throw const FormatException('Expected 16-bit PCM WAVE audio.');
    }
    final samples = <int>[];
    for (
      var index = audioOffset;
      index + 1 < audioOffset + audioLength;
      index += 2
    ) {
      samples.add(data.getInt16(index, Endian.little));
    }
    return _Pcm16Wave(
      sampleRate: sampleRate,
      channels: channels,
      samples: samples,
    );
  }

  List<int> encode() {
    final dataLength = samples.length * 2;
    final output = Uint8List(44 + dataLength);
    final data = ByteData.sublistView(output);
    _writeAscii(output, 0, 'RIFF');
    data.setUint32(4, 36 + dataLength, Endian.little);
    _writeAscii(output, 8, 'WAVE');
    _writeAscii(output, 12, 'fmt ');
    data.setUint32(16, 16, Endian.little);
    data.setUint16(20, 1, Endian.little);
    data.setUint16(22, channels, Endian.little);
    data.setUint32(24, sampleRate, Endian.little);
    data.setUint32(28, sampleRate * channels * 2, Endian.little);
    data.setUint16(32, channels * 2, Endian.little);
    data.setUint16(34, 16, Endian.little);
    _writeAscii(output, 36, 'data');
    data.setUint32(40, dataLength, Endian.little);
    for (var index = 0; index < samples.length; index++) {
      data.setInt16(44 + index * 2, samples[index], Endian.little);
    }
    return output;
  }

  static String _ascii(Uint8List bytes, int offset, int length) =>
      String.fromCharCodes(bytes.sublist(offset, offset + length));

  static void _writeAscii(Uint8List bytes, int offset, String value) {
    bytes.setRange(offset, offset + value.length, value.codeUnits);
  }
}

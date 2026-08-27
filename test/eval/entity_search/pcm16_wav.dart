import 'dart:math';
import 'dart:typed_data';

class Pcm16Wav {
  final int sampleRate;
  final int channels;
  final List<int> samples;

  const Pcm16Wav({
    required this.sampleRate,
    required this.channels,
    required this.samples,
  });

  factory Pcm16Wav.decode(List<int> source) {
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
      final chunkId = _ascii(bytes, offset, 4);
      final chunkLength = data.getUint32(offset + 4, Endian.little);
      final chunkStart = offset + 8;
      if (chunkStart + chunkLength > bytes.length) {
        throw const FormatException('Truncated WAVE chunk.');
      }
      if (chunkId == 'fmt ' && chunkLength >= 16) {
        audioFormat = data.getUint16(chunkStart, Endian.little);
        channels = data.getUint16(chunkStart + 2, Endian.little);
        sampleRate = data.getUint32(chunkStart + 4, Endian.little);
        bitsPerSample = data.getUint16(chunkStart + 14, Endian.little);
      } else if (chunkId == 'data') {
        audioOffset = chunkStart;
        audioLength = chunkLength;
      }
      offset = chunkStart + chunkLength + (chunkLength.isOdd ? 1 : 0);
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
    return Pcm16Wav(
      sampleRate: sampleRate,
      channels: channels,
      samples: samples,
    );
  }

  int get frames => samples.length ~/ channels;
  double get durationSeconds => frames / sampleRate;

  Map<String, Object?> diagnostics({required int fileSizeBytes}) {
    final peak = samples.fold<int>(0, (value, item) => max(value, item.abs()));
    final squareSum = samples.fold<double>(
      0,
      (value, item) => value + item * item,
    );
    final rms = samples.isEmpty ? 0.0 : sqrt(squareSum / samples.length);
    final edgeFrames = min(frames, (sampleRate * 0.25).round());
    final edgeSamples = <int>[
      ...samples.take(edgeFrames * channels),
      ...samples.skip(max(0, samples.length - edgeFrames * channels)),
    ];
    final edgeSquareSum = edgeSamples.fold<double>(
      0,
      (value, item) => value + item * item,
    );
    final edgeRms = edgeSamples.isEmpty
        ? 0.0
        : sqrt(edgeSquareSum / edgeSamples.length);
    const silenceThreshold = 32768 * 0.005623413251903491;
    var firstActiveFrame = 0;
    while (firstActiveFrame < frames &&
        _framePeak(firstActiveFrame) < silenceThreshold) {
      firstActiveFrame++;
    }
    var lastActiveFrame = frames - 1;
    while (lastActiveFrame >= firstActiveFrame &&
        _framePeak(lastActiveFrame) < silenceThreshold) {
      lastActiveFrame--;
    }
    final clipped = samples.where((sample) => sample.abs() >= 32760).length;
    return {
      'format': 'WAVE PCM signed 16-bit little-endian',
      'durationSeconds': durationSeconds,
      'sampleRateHz': sampleRate,
      'channels': channels,
      'fileSizeBytes': fileSizeBytes,
      'peakDbfs': _dbfs(peak.toDouble()),
      'rmsDbfs': _dbfs(rms),
      'edgeNoiseFloorDbfsApprox': _dbfs(edgeRms),
      'leadingSilenceMsApprox': firstActiveFrame / sampleRate * 1000,
      'trailingSilenceMsApprox':
          max(0, frames - lastActiveFrame - 1) / sampleRate * 1000,
      'clippedSampleCount': clipped,
      'clippedSampleRatio': samples.isEmpty ? 0.0 : clipped / samples.length,
      'diagnosticCaveat': 'Waveform statistics are diagnostic only and do not establish perceptual quality.',
    };
  }

  double _framePeak(int frame) {
    var peak = 0;
    final start = frame * channels;
    for (var channel = 0; channel < channels; channel++) {
      peak = max(peak, samples[start + channel].abs());
    }
    return peak.toDouble();
  }

  static double? _dbfs(double amplitude) =>
      amplitude <= 0 ? null : 20 * log(amplitude / 32768) / ln10;

  static String _ascii(Uint8List bytes, int offset, int length) =>
      String.fromCharCodes(bytes.sublist(offset, offset + length));
}

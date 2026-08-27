import 'dart:io';
import 'dart:typed_data';

/// Encapsulates retained in-memory or on-disk spoken audio data
/// with a deterministic lifecycle management contract.
class SpokenAudioContext {
  /// In-memory audio byte buffer (e.g. AAC, WAV, PCM).
  final Uint8List bytes;

  /// Audio container/encoding format (e.g. 'm4a', 'wav', 'aac').
  final String format;

  /// Sample rate in Hz (e.g. 44100, 16000).
  final int sampleRate;

  /// Number of audio channels (e.g. 1 for mono, 2 for stereo).
  final int channels;

  /// Total duration of recorded audio in milliseconds.
  final int durationMs;

  /// Optional temporary on-disk file path where audio was buffered.
  final String? localFilePath;

  bool _isDisposed = false;

  SpokenAudioContext({
    required this.bytes,
    this.format = 'm4a',
    this.sampleRate = 44100,
    this.channels = 1,
    required this.durationMs,
    this.localFilePath,
  });

  /// True if [dispose] has been called on this audio context.
  bool get isDisposed => _isDisposed;

  /// Size of retained audio bytes in memory.
  int get byteLength => bytes.lengthInBytes;

  /// Deterministically cleans up any temporary on-disk files and marks context disposed.
  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;

    if (localFilePath != null && localFilePath!.isNotEmpty) {
      try {
        final file = File(localFilePath!);
        if (file.existsSync()) {
          file.deleteSync();
        }
      } catch (_) {
        // Silently ignore disk cleanup failure on already-deleted temp files
      }
    }
  }
}

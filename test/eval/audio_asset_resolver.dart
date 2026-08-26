import 'dart:io';

/// Exception thrown when an audio asset ID cannot be resolved to physical bytes.
class AudioFileNotFoundException implements Exception {
  final String audioAssetId;
  final String searchLocation;
  final String message;

  const AudioFileNotFoundException({
    required this.audioAssetId,
    required this.searchLocation,
    this.message = 'Audio asset not found',
  });

  @override
  String toString() => 'AudioFileNotFoundException: $message (asset: "$audioAssetId", searched in: "$searchLocation")';
}

/// Abstract audio asset resolver.
///
/// Decouples the benchmark evaluator from physical file locations or cloud storage providers.
abstract class AudioAssetResolver {
  /// Resolves an asset ID to an accessible local [File].
  ///
  /// Throws [AudioFileNotFoundException] if the asset is missing or inaccessible.
  Future<File> resolveAudioFile(String audioAssetId, {String? formatHint});

  /// Checks if the asset exists and is accessible.
  Future<bool> hasAsset(String audioAssetId);

  /// Supported audio format extensions.
  static const List<String> supportedExtensions = ['wav', 'm4a', 'mp3'];
}

/// Resolves audio assets from a local unversioned evaluation directory.
///
/// Searches both flat (`<baseDir>/<assetId>.<ext>`) and partitioned language folders
/// (`<baseDir>/<lang>/<assetId>.<ext>`).
class LocalDirectoryAssetResolver implements AudioAssetResolver {
  final Directory baseDirectory;

  const LocalDirectoryAssetResolver(this.baseDirectory);

  @override
  Future<File> resolveAudioFile(String audioAssetId, {String? formatHint}) async {
    if (!baseDirectory.existsSync()) {
      throw AudioFileNotFoundException(
        audioAssetId: audioAssetId,
        searchLocation: baseDirectory.path,
        message: 'Base audio directory does not exist',
      );
    }

    final extensionsToTry = formatHint != null
        ? [formatHint, ...AudioAssetResolver.supportedExtensions.where((e) => e != formatHint)]
        : AudioAssetResolver.supportedExtensions;

    // 1. Direct match in root of baseDirectory
    for (final ext in extensionsToTry) {
      final file = File('${baseDirectory.path}/$audioAssetId.$ext');
      if (file.existsSync()) {
        return file;
      }
    }

    // 2. Search recursively or inside subdirectories (e.g. baseDir/ga/assetId.wav)
    try {
      final entities = baseDirectory.listSync(recursive: true, followLinks: false);
      for (final entity in entities) {
        if (entity is File) {
          final fileName = entity.uri.pathSegments.last;
          for (final ext in extensionsToTry) {
            if (fileName == '$audioAssetId.$ext') {
              return entity;
            }
          }
        }
      }
    } catch (_) {
      // Ignored, proceed to throw
    }

    throw AudioFileNotFoundException(
      audioAssetId: audioAssetId,
      searchLocation: baseDirectory.path,
    );
  }

  @override
  Future<bool> hasAsset(String audioAssetId) async {
    if (!baseDirectory.existsSync()) return false;

    // Direct check
    for (final ext in AudioAssetResolver.supportedExtensions) {
      final file = File('${baseDirectory.path}/$audioAssetId.$ext');
      if (file.existsSync()) return true;
    }

    // Search inside subdirectories
    try {
      final entities = baseDirectory.listSync(recursive: true, followLinks: false);
      for (final entity in entities) {
        if (entity is File) {
          final fileName = entity.uri.pathSegments.last;
          for (final ext in AudioAssetResolver.supportedExtensions) {
            if (fileName == '$audioAssetId.$ext') return true;
          }
        }
      }
    } catch (_) {
      return false;
    }

    return false;
  }
}

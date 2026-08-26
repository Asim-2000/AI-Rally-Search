import 'package:ai_rally_search/models/search_intent.dart';
import 'package:ai_rally_search/models/search_query.dart';
import 'package:ai_rally_search/models/supported_language.dart';
import 'benchmark_manifest.dart';

/// Semantic query archetypes representing realistic voice search tasks.
enum QueryArchetype {
  /// Archetype A: Rally discovery (e.g., "Ask for rallies in Ireland in 2025.")
  archetypeA_rallyDiscovery,

  /// Archetype B: Driver participation / wins (e.g., "Ask which rallies Josh Moffett won.")
  archetypeB_driverParticipation,

  /// Archetype C: Compound driver + rally + year (e.g., "Ask for Josh Moffett at Moonraker in 2025.")
  archetypeC_compoundQuery,

  /// Archetype D: Video action query (e.g., "Ask for jump highlights featuring Josh Moffett from Moonraker.")
  archetypeD_videoAction,

  /// Archetype E: Stage / difficult / code-switched query (e.g., "Ask for water splashes at Tarenig stage.")
  archetypeE_stageCodeSwitch;

  String get code {
    switch (this) {
      case QueryArchetype.archetypeA_rallyDiscovery:
        return 'A';
      case QueryArchetype.archetypeB_driverParticipation:
        return 'B';
      case QueryArchetype.archetypeC_compoundQuery:
        return 'C';
      case QueryArchetype.archetypeD_videoAction:
        return 'D';
      case QueryArchetype.archetypeE_stageCodeSwitch:
        return 'E';
    }
  }

  String get title {
    switch (this) {
      case QueryArchetype.archetypeA_rallyDiscovery:
        return 'Rally Discovery';
      case QueryArchetype.archetypeB_driverParticipation:
        return 'Driver Participation / Wins';
      case QueryArchetype.archetypeC_compoundQuery:
        return 'Compound (Driver + Rally + Year)';
      case QueryArchetype.archetypeD_videoAction:
        return 'Video Action Query';
      case QueryArchetype.archetypeE_stageCodeSwitch:
        return 'Stage / Code-Switched Query';
    }
  }
}

/// Acoustic recording environment classifications.
enum AcousticEnvironment {
  quiet,
  moderateNoise,
  noisy;

  String get label {
    switch (this) {
      case AcousticEnvironment.quiet:
        return 'Quiet';
      case AcousticEnvironment.moderateNoise:
        return 'Moderate Noise';
      case AcousticEnvironment.noisy:
        return 'High Noise';
    }
  }
}

/// Device hardware recording class.
enum DeviceClass {
  mobileInternalMic,
  desktopInternalMic,
  headsetMic,
  externalMic;

  String get label {
    switch (this) {
      case DeviceClass.mobileInternalMic:
        return 'Mobile Internal Mic';
      case DeviceClass.desktopInternalMic:
        return 'Desktop Internal Mic';
      case DeviceClass.headsetMic:
        return 'Headset / Earbuds Mic';
      case DeviceClass.externalMic:
        return 'External / Dedicated Mic';
    }
  }
}

/// Verification tier for the spoken ground-truth transcript.
enum TranscriptVerificationTier {
  unverified,
  speakerVerified,
  nativeReviewerVerified,
  dualVerified;

  String get label {
    switch (this) {
      case TranscriptVerificationTier.unverified:
        return 'UNVERIFIED';
      case TranscriptVerificationTier.speakerVerified:
        return 'SPEAKER_VERIFIED';
      case TranscriptVerificationTier.nativeReviewerVerified:
        return 'NATIVE_REVIEWER_VERIFIED';
      case TranscriptVerificationTier.dualVerified:
        return 'DUAL_VERIFIED';
    }
  }
}

/// Structural manifest entry for human voice benchmark validation.
///
/// Designed with strict data minimization and pseudonymization:
/// Contains ZERO personal identifiable information (no names, emails, locations, demographics).
class HumanBenchmarkManifestEntry extends BenchmarkManifestEntry {
  final String sampleId;
  final String audioAssetId;
  final String speakerId;
  final QueryArchetype archetype;
  final AcousticEnvironment environment;
  final DeviceClass deviceClass;
  final List<String> functionalTags;

  final String naturalPromptGiven;
  final String humanVerifiedTranscript;
  final TranscriptVerificationTier verificationTier;

  final String collectionDate;
  final String consentVersion;
  final String retentionClass;

  const HumanBenchmarkManifestEntry({
    required this.sampleId,
    required this.audioAssetId,
    required super.language,
    required super.locale,
    required this.speakerId,
    required this.archetype,
    required this.environment,
    required this.deviceClass,
    required this.naturalPromptGiven,
    required this.humanVerifiedTranscript,
    required this.verificationTier,
    required super.expectedIntent,
    required super.expectedFilters,
    super.expectedEntities = const [],
    super.expectedDrivers = const [],
    super.expectedRallies = const [],
    super.expectedStages = const [],
    super.expectedActions = const [],
    this.functionalTags = const [],
    required this.collectionDate,
    required this.consentVersion,
    this.retentionClass = 'pilot_wave1_active',
  }) : super(
          id: sampleId,
          benchmarkType: BenchmarkType.human,
          audioFile: audioAssetId,
          expectedTranscript: humanVerifiedTranscript,
        );

  bool get isAudioTranscribedAndVerified =>
      humanVerifiedTranscript.trim().isNotEmpty &&
      verificationTier != TranscriptVerificationTier.unverified;

  @override
  SearchQuery get expectedQuery {
    return SearchQuery(
      intent: expectedIntent,
      driverName: expectedFilters['driverName'] as String?,
      rallyName: expectedFilters['rallyName'] as String?,
      country: expectedFilters['country'] as String?,
      city: expectedFilters['city'] as String?,
      actionType: expectedFilters['actionType'] as String?,
      year: expectedFilters['year'] as int?,
      stageName: expectedFilters['stageName'] as String?,
    );
  }

  Map<String, dynamic> toManifestJson() => {
        'sample_id': sampleId,
        'audio_asset_id': audioAssetId,
        'benchmark_type': benchmarkType.name,
        'language': language.languageCode,
        'locale': locale,
        'speaker_id': speakerId,
        'archetype': archetype.name,
        'archetype_code': archetype.code,
        'environment': environment.name,
        'device_class': deviceClass.name,
        'functional_tags': functionalTags,
        'natural_prompt_given': naturalPromptGiven,
        'human_verified_transcript': humanVerifiedTranscript,
        'verification_tier': verificationTier.name,
        'expected_intent': expectedIntent.name,
        'expected_filters': expectedFilters,
        'expected_entities': expectedEntities,
        'expected_drivers': expectedDrivers,
        'expected_rallies': expectedRallies,
        'expected_stages': expectedStages,
        'expected_actions': expectedActions,
        'collection_date': collectionDate,
        'consent_version': consentVersion,
        'retention_class': retentionClass,
      };

  factory HumanBenchmarkManifestEntry.fromJson(Map<String, dynamic> json) {
    final langCode = json['language'] as String;
    final lang = SupportedLanguages.all.firstWhere(
      (l) => l.languageCode == langCode,
      orElse: () => SupportedLanguages.english,
    );

    final archetypeStr = json['archetype'] as String? ?? 'archetypeA_rallyDiscovery';
    final archetype = QueryArchetype.values.firstWhere(
      (a) => a.name == archetypeStr,
      orElse: () => QueryArchetype.archetypeA_rallyDiscovery,
    );

    final envStr = json['environment'] as String? ?? 'quiet';
    final env = AcousticEnvironment.values.firstWhere(
      (e) => e.name == envStr,
      orElse: () => AcousticEnvironment.quiet,
    );

    final deviceStr = json['device_class'] as String? ?? 'mobileInternalMic';
    final device = DeviceClass.values.firstWhere(
      (d) => d.name == deviceStr,
      orElse: () => DeviceClass.mobileInternalMic,
    );

    final tierStr = json['verification_tier'] as String? ?? 'unverified';
    final tier = TranscriptVerificationTier.values.firstWhere(
      (t) => t.name == tierStr,
      orElse: () => TranscriptVerificationTier.unverified,
    );

    final intentStr = json['expected_intent'] as String? ?? 'searchRallies';
    final intent = SearchIntent.values.firstWhere(
      (i) => i.name == intentStr,
      orElse: () => SearchIntent.searchRallies,
    );

    return HumanBenchmarkManifestEntry(
      sampleId: json['sample_id'] as String,
      audioAssetId: json['audio_asset_id'] as String,
      language: lang,
      locale: json['locale'] as String? ?? lang.languageCode,
      speakerId: json['speaker_id'] as String? ?? 'unassigned',
      archetype: archetype,
      environment: env,
      deviceClass: device,
      functionalTags: List<String>.from(json['functional_tags'] ?? []),
      naturalPromptGiven: json['natural_prompt_given'] as String? ?? '',
      humanVerifiedTranscript: json['human_verified_transcript'] as String? ?? '',
      verificationTier: tier,
      expectedIntent: intent,
      expectedFilters: Map<String, dynamic>.from(json['expected_filters'] ?? {}),
      expectedEntities: List<String>.from(json['expected_entities'] ?? []),
      expectedDrivers: List<String>.from(json['expected_drivers'] ?? []),
      expectedRallies: List<String>.from(json['expected_rallies'] ?? []),
      expectedStages: List<String>.from(json['expected_stages'] ?? []),
      expectedActions: List<String>.from(json['expected_actions'] ?? []),
      collectionDate: json['collection_date'] as String? ?? '',
      consentVersion: json['consent_version'] as String? ?? 'v1.0',
      retentionClass: json['retention_class'] as String? ?? 'pilot_wave1_active',
    );
  }
}

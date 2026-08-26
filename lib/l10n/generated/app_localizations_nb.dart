// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Norwegian Bokmål (`nb`).
class AppLocalizationsNb extends AppLocalizations {
  AppLocalizationsNb([String locale = 'nb']) : super(locale);

  @override
  String get appTitle => 'AI Rallysøk';

  @override
  String get searchHint =>
      'Søk etter rally, førere, hopp, krasj, resultater med naturlig språk...';

  @override
  String get searchButton => 'Søk';

  @override
  String get searching => 'Søker...';

  @override
  String get listening => 'Lytter...';

  @override
  String resultsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count resultater funnet',
      one: '1 resultat funnet',
      zero: 'Ingen resultater funnet',
    );
    return '$_temp0';
  }

  @override
  String get interpretedSummaryPrefix => 'Tolket';

  @override
  String get clarificationTitle => 'Hvilken mener du?';

  @override
  String get intentSearchRallies => 'Søk etter rally';

  @override
  String get intentSearchDriverRallies => 'Førers rallyer';

  @override
  String get intentSearchDriverWins => 'Førers seire';

  @override
  String get intentGetRallyResults => 'Rallyvinner';

  @override
  String get intentGetRallyTopFinishers => 'Ledertabell';

  @override
  String get intentSearchVideoActions => 'Høydepunkter';

  @override
  String get intentSearchDriverVideos => 'Førervideoer';

  @override
  String get intentGetTopUploaders => 'Beste bidragsytere';

  @override
  String get intentGetTopDriversByWins => 'Flest seire';

  @override
  String get actionAll => 'Alle handlinger';

  @override
  String get actionJump => 'Hopp';

  @override
  String get actionDrift => 'Sladd';

  @override
  String get actionCrash => 'Krasj';

  @override
  String get actionSpin => 'Snurring';

  @override
  String get actionDonut => 'Donut';

  @override
  String get actionHairpin => 'Hårnålssving';

  @override
  String get actionWaterSplash => 'Vannhinder';

  @override
  String get actionStartLine => 'Startlinje';

  @override
  String get actionNearMiss => 'Nestenulykke';

  @override
  String get actionMechanicalFailure => 'Mekanisk svikt';

  @override
  String get actionOffroad => 'Av banen';

  @override
  String get actionStuck => 'Fastkjørt';

  @override
  String get filterDriver => 'Fører';

  @override
  String get filterRally => 'Rally';

  @override
  String get filterCountry => 'Land';

  @override
  String get filterCity => 'By';

  @override
  String get filterStage => 'Fartsprøve';

  @override
  String get filterYear => 'År';

  @override
  String get filterAction => 'Handling';

  @override
  String get labelAllCountries => 'Alle land';

  @override
  String get labelNoResults => 'Ingen resultater som samsvarer med søket';

  @override
  String get labelTelemetry => 'AI-telemetri';

  @override
  String get languageSelector => 'Språk';
}

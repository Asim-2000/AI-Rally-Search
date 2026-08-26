// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'AI Rally Search';

  @override
  String get searchHint =>
      'Search rallies, drivers, jumps, crashes, results in natural language...';

  @override
  String get searchButton => 'Search';

  @override
  String get searching => 'Searching...';

  @override
  String get listening => 'Listening...';

  @override
  String resultsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count results found',
      one: '1 result found',
      zero: 'No results found',
    );
    return '$_temp0';
  }

  @override
  String get interpretedSummaryPrefix => 'Interpreted';

  @override
  String get clarificationTitle => 'Which one do you mean?';

  @override
  String get intentSearchRallies => 'Search Rallies';

  @override
  String get intentSearchDriverRallies => 'Driver Rallies';

  @override
  String get intentSearchDriverWins => 'Driver Wins';

  @override
  String get intentGetRallyResults => 'Rally Winner';

  @override
  String get intentGetRallyTopFinishers => 'Top Finishers';

  @override
  String get intentSearchVideoActions => 'Action Highlights';

  @override
  String get intentSearchDriverVideos => 'Driver Videos';

  @override
  String get intentGetTopUploaders => 'Top Uploaders';

  @override
  String get intentGetTopDriversByWins => 'Most Wins';

  @override
  String get actionAll => 'All Actions';

  @override
  String get actionJump => 'Jump';

  @override
  String get actionDrift => 'Drift';

  @override
  String get actionCrash => 'Crash';

  @override
  String get actionSpin => 'Spin';

  @override
  String get actionDonut => 'Donut';

  @override
  String get actionHairpin => 'Hairpin';

  @override
  String get actionWaterSplash => 'Water Splash';

  @override
  String get actionStartLine => 'Start Line';

  @override
  String get actionNearMiss => 'Near Miss';

  @override
  String get actionMechanicalFailure => 'Mechanical Failure';

  @override
  String get actionOffroad => 'Offroad';

  @override
  String get actionStuck => 'Stuck';

  @override
  String get filterDriver => 'Driver';

  @override
  String get filterRally => 'Rally';

  @override
  String get filterCountry => 'Country';

  @override
  String get filterCity => 'City';

  @override
  String get filterStage => 'Stage';

  @override
  String get filterYear => 'Year';

  @override
  String get filterAction => 'Action';

  @override
  String get labelAllCountries => 'All Countries';

  @override
  String get labelNoResults => 'No results matching your query';

  @override
  String get labelTelemetry => 'AI Telemetry';

  @override
  String get languageSelector => 'Language';
}

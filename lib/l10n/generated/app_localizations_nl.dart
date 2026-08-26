// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Dutch Flemish (`nl`).
class AppLocalizationsNl extends AppLocalizations {
  AppLocalizationsNl([String locale = 'nl']) : super(locale);

  @override
  String get appTitle => 'AI Rally Zoeken';

  @override
  String get searchHint =>
      'Zoek rally\'s, coureurs, sprongen, crashes, uitslagen in natuurlijke taal...';

  @override
  String get searchButton => 'Zoeken';

  @override
  String get searching => 'Bezig met zoeken...';

  @override
  String get listening => 'Luisteren...';

  @override
  String resultsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count resultaten gevonden',
      one: '1 resultaat gevonden',
      zero: 'Geen resultaten gevonden',
    );
    return '$_temp0';
  }

  @override
  String get interpretedSummaryPrefix => 'Geïnterpreteerd';

  @override
  String get clarificationTitle => 'Welke bedoelt u?';

  @override
  String get intentSearchRallies => 'Rally\'s zoeken';

  @override
  String get intentSearchDriverRallies => 'Coureur rally\'s';

  @override
  String get intentSearchDriverWins => 'Coureur overwinningen';

  @override
  String get intentGetRallyResults => 'Rally winnaar';

  @override
  String get intentGetRallyTopFinishers => 'Ranglijst';

  @override
  String get intentSearchVideoActions => 'Actie hoogtepunten';

  @override
  String get intentSearchDriverVideos => 'Coureur video\'s';

  @override
  String get intentGetTopUploaders => 'Top uploaders';

  @override
  String get intentGetTopDriversByWins => 'Meeste overwinningen';

  @override
  String get actionAll => 'Alle acties';

  @override
  String get actionJump => 'Sprong';

  @override
  String get actionDrift => 'Drift';

  @override
  String get actionCrash => 'Crash';

  @override
  String get actionSpin => 'Spin';

  @override
  String get actionDonut => 'Donut';

  @override
  String get actionHairpin => 'Haarspeldbocht';

  @override
  String get actionWaterSplash => 'Waterbak';

  @override
  String get actionStartLine => 'Startlijn';

  @override
  String get actionNearMiss => 'Bijna-ongeluk';

  @override
  String get actionMechanicalFailure => 'Mechanisch defect';

  @override
  String get actionOffroad => 'Naast de baan';

  @override
  String get actionStuck => 'Vastgelopen';

  @override
  String get filterDriver => 'Coureur';

  @override
  String get filterRally => 'Rally';

  @override
  String get filterCountry => 'Land';

  @override
  String get filterCity => 'Stad';

  @override
  String get filterStage => 'Klassementsproef';

  @override
  String get filterYear => 'Jaar';

  @override
  String get filterAction => 'Actie';

  @override
  String get labelAllCountries => 'Alle landen';

  @override
  String get labelNoResults => 'Geen resultaten gevonden voor uw zoekopdracht';

  @override
  String get labelTelemetry => 'AI-telemetrie';

  @override
  String get languageSelector => 'Taal';
}

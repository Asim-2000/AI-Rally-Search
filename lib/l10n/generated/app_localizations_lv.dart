// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Latvian (`lv`).
class AppLocalizationsLv extends AppLocalizations {
  AppLocalizationsLv([String locale = 'lv']) : super(locale);

  @override
  String get appTitle => 'AI Rallija Meklētājs';

  @override
  String get searchHint =>
      'Meklēt rallijus, pilotus, lēcienus, avārijas, rezultātus dabiskā valodā...';

  @override
  String get searchButton => 'Meklēt';

  @override
  String get searching => 'Meklē...';

  @override
  String get listening => 'Klausās...';

  @override
  String resultsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Atrasti $count rezultāti',
      one: 'Atrasts 1 rezultāts',
      zero: 'Nav atrasts neviens rezultāts',
    );
    return '$_temp0';
  }

  @override
  String get interpretedSummaryPrefix => 'Interpretēts';

  @override
  String get clarificationTitle => 'Kuru jūs domājāt?';

  @override
  String get intentSearchRallies => 'Meklēt rallijus';

  @override
  String get intentSearchDriverRallies => 'Pilota ralliji';

  @override
  String get intentSearchDriverWins => 'Pilota uzvaras';

  @override
  String get intentGetRallyResults => 'Rallija uzvarētājs';

  @override
  String get intentGetRallyTopFinishers => 'Rezultātu tabula';

  @override
  String get intentSearchVideoActions => 'Spilgtākie momenti';

  @override
  String get intentSearchDriverVideos => 'Pilota video';

  @override
  String get intentGetTopUploaders => 'Labākie augšupielādētāji';

  @override
  String get intentGetTopDriversByWins => 'Visvairāk uzvaru';

  @override
  String get actionAll => 'Visas darbības';

  @override
  String get actionJump => 'Lēciens';

  @override
  String get actionDrift => 'Drifts';

  @override
  String get actionCrash => 'Avārija';

  @override
  String get actionSpin => 'Sagriešanās';

  @override
  String get actionDonut => 'Griešanās uz vietas';

  @override
  String get actionHairpin => 'Matadata';

  @override
  String get actionWaterSplash => 'Ūdens šķērslis';

  @override
  String get actionStartLine => 'Starta līnija';

  @override
  String get actionNearMiss => 'Bīstams moments';

  @override
  String get actionMechanicalFailure => 'Mehānisks bojājums';

  @override
  String get actionOffroad => 'Nobraukšana no ceļa';

  @override
  String get actionStuck => 'Iestidzis';

  @override
  String get filterDriver => 'Pilots';

  @override
  String get filterRally => 'Rallijs';

  @override
  String get filterCountry => 'Valsts';

  @override
  String get filterCity => 'Pilsēta';

  @override
  String get filterStage => 'Ātrumposms';

  @override
  String get filterYear => 'Gads';

  @override
  String get filterAction => 'Darbība';

  @override
  String get labelAllCountries => 'Visas valstis';

  @override
  String get labelNoResults => 'Nav atrasti rezultāti';

  @override
  String get labelTelemetry => 'AI telemetrija';

  @override
  String get languageSelector => 'Valoda';
}

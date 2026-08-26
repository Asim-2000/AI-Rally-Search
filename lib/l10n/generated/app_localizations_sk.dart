// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Slovak (`sk`).
class AppLocalizationsSk extends AppLocalizations {
  AppLocalizationsSk([String locale = 'sk']) : super(locale);

  @override
  String get appTitle => 'AI Vyhľadávač Rally';

  @override
  String get searchHint =>
      'Hľadajte rally, jazdcov, skoky, havárie, výsledky v prirodzenom jazyku...';

  @override
  String get searchButton => 'Hľadať';

  @override
  String get searching => 'Vyhľadávanie...';

  @override
  String get listening => 'Počúvam...';

  @override
  String resultsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Našlo sa $count výsledkov',
      few: 'Našli sa $count výsledky',
      one: 'Našiel sa 1 výsledok',
      zero: 'Nenašli sa žiadne výsledky',
    );
    return '$_temp0';
  }

  @override
  String get interpretedSummaryPrefix => 'Interpretované';

  @override
  String get clarificationTitle => 'Ktorú máte na mysli?';

  @override
  String get intentSearchRallies => 'Hľadať rally';

  @override
  String get intentSearchDriverRallies => 'Rally jazdca';

  @override
  String get intentSearchDriverWins => 'Víťazstvá jazdca';

  @override
  String get intentGetRallyResults => 'Víťaz rally';

  @override
  String get intentGetRallyTopFinishers => 'Rebríček';

  @override
  String get intentSearchVideoActions => 'Akčné momenty';

  @override
  String get intentSearchDriverVideos => 'Videá jazdca';

  @override
  String get intentGetTopUploaders => 'Najlepší prispievatelia';

  @override
  String get intentGetTopDriversByWins => 'Najviac víťazstiev';

  @override
  String get actionAll => 'Všetky akcie';

  @override
  String get actionJump => 'Skok';

  @override
  String get actionDrift => 'Šmyk';

  @override
  String get actionCrash => 'Havária';

  @override
  String get actionSpin => 'Hodiny';

  @override
  String get actionDonut => 'Kolečko';

  @override
  String get actionHairpin => 'Vracák';

  @override
  String get actionWaterSplash => 'Brod';

  @override
  String get actionStartLine => 'Štartová čiara';

  @override
  String get actionNearMiss => 'Tesný únik';

  @override
  String get actionMechanicalFailure => 'Mechanická porucha';

  @override
  String get actionOffroad => 'Mimo trate';

  @override
  String get actionStuck => 'Zapadnutý';

  @override
  String get filterDriver => 'Jazdec';

  @override
  String get filterRally => 'Rally';

  @override
  String get filterCountry => 'Krajina';

  @override
  String get filterCity => 'Mesto';

  @override
  String get filterStage => 'Rýchlostná skúška';

  @override
  String get filterYear => 'Rok';

  @override
  String get filterAction => 'Akcia';

  @override
  String get labelAllCountries => 'Všetky krajiny';

  @override
  String get labelNoResults => 'Žiadne výsledky nezodpovedajú vašej požiadavke';

  @override
  String get labelTelemetry => 'AI Telemetria';

  @override
  String get languageSelector => 'Jazyk';
}

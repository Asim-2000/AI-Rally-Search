// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Czech (`cs`).
class AppLocalizationsCs extends AppLocalizations {
  AppLocalizationsCs([String locale = 'cs']) : super(locale);

  @override
  String get appTitle => 'AI Vyhledávač Rally';

  @override
  String get searchHint =>
      'Hledejte rally, jezdce, skoky, havárie, výsledky v přirozeném jazyce...';

  @override
  String get searchButton => 'Hledat';

  @override
  String get searching => 'Vyhledávání...';

  @override
  String get listening => 'Poslouchám...';

  @override
  String resultsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Nalezeno $count výsledků',
      few: 'Nalezeny $count výsledky',
      one: 'Nalezen 1 výsledek',
      zero: 'Nenalezeny žádné výsledky',
    );
    return '$_temp0';
  }

  @override
  String get interpretedSummaryPrefix => 'Interpretováno';

  @override
  String get clarificationTitle => 'Kterou máte na mysli?';

  @override
  String get intentSearchRallies => 'Hledat rally';

  @override
  String get intentSearchDriverRallies => 'Rally jezdce';

  @override
  String get intentSearchDriverWins => 'Vítězství jezdce';

  @override
  String get intentGetRallyResults => 'Vítěz rally';

  @override
  String get intentGetRallyTopFinishers => 'Žebříček';

  @override
  String get intentSearchVideoActions => 'Akční momenty';

  @override
  String get intentSearchDriverVideos => 'Videa jezdce';

  @override
  String get intentGetTopUploaders => 'Nejlepší přispěvatelé';

  @override
  String get intentGetTopDriversByWins => 'Nejvíce vítězství';

  @override
  String get actionAll => 'Všechny akce';

  @override
  String get actionJump => 'Skok';

  @override
  String get actionDrift => 'Smyk';

  @override
  String get actionCrash => 'Havárie';

  @override
  String get actionSpin => 'Hodiny';

  @override
  String get actionDonut => 'Kolečka';

  @override
  String get actionHairpin => 'Vracák';

  @override
  String get actionWaterSplash => 'Brod';

  @override
  String get actionStartLine => 'Startovní čára';

  @override
  String get actionNearMiss => 'Těsný únik';

  @override
  String get actionMechanicalFailure => 'Mechanická závada';

  @override
  String get actionOffroad => 'Mimo trať';

  @override
  String get actionStuck => 'Zapadlý';

  @override
  String get filterDriver => 'Jezdec';

  @override
  String get filterRally => 'Rally';

  @override
  String get filterCountry => 'Země';

  @override
  String get filterCity => 'Město';

  @override
  String get filterStage => 'Rychlostní zkouška';

  @override
  String get filterYear => 'Rok';

  @override
  String get filterAction => 'Akce';

  @override
  String get labelAllCountries => 'Všechny země';

  @override
  String get labelNoResults => 'Žádné výsledky neodpovídají vašemu dotazu';

  @override
  String get labelTelemetry => 'AI Telemetrie';

  @override
  String get languageSelector => 'Jazyk';
}

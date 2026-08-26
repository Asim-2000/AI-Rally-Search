// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Italian (`it`).
class AppLocalizationsIt extends AppLocalizations {
  AppLocalizationsIt([String locale = 'it']) : super(locale);

  @override
  String get appTitle => 'Ricerca Rally IA';

  @override
  String get searchHint =>
      'Cerca rally, piloti, salti, incidenti, risultati in linguaggio naturale...';

  @override
  String get searchButton => 'Cerca';

  @override
  String get searching => 'Ricerca in corso...';

  @override
  String get listening => 'Ascolto...';

  @override
  String resultsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count risultati trovati',
      one: '1 risultato trovato',
      zero: 'Nessun risultato trovato',
    );
    return '$_temp0';
  }

  @override
  String get interpretedSummaryPrefix => 'Interpretato';

  @override
  String get clarificationTitle => 'A quale ti riferisci?';

  @override
  String get intentSearchRallies => 'Cerca rally';

  @override
  String get intentSearchDriverRallies => 'Rally del pilota';

  @override
  String get intentSearchDriverWins => 'Vittorie del pilota';

  @override
  String get intentGetRallyResults => 'Vincitore del rally';

  @override
  String get intentGetRallyTopFinishers => 'Classifica';

  @override
  String get intentSearchVideoActions => 'Momenti salienti';

  @override
  String get intentSearchDriverVideos => 'Video del pilota';

  @override
  String get intentGetTopUploaders => 'Migliori contributori';

  @override
  String get intentGetTopDriversByWins => 'Maggior numero di vittorie';

  @override
  String get actionAll => 'Tutte le azioni';

  @override
  String get actionJump => 'Salto';

  @override
  String get actionDrift => 'Derapata';

  @override
  String get actionCrash => 'Incidente';

  @override
  String get actionSpin => 'Testacoda';

  @override
  String get actionDonut => 'Donut';

  @override
  String get actionHairpin => 'Tornante';

  @override
  String get actionWaterSplash => 'Guado';

  @override
  String get actionStartLine => 'Linea di partenza';

  @override
  String get actionNearMiss => 'Quasi incidente';

  @override
  String get actionMechanicalFailure => 'Guasto meccanico';

  @override
  String get actionOffroad => 'Fuoripista';

  @override
  String get actionStuck => 'Bloccato';

  @override
  String get filterDriver => 'Pilota';

  @override
  String get filterRally => 'Rally';

  @override
  String get filterCountry => 'Paese';

  @override
  String get filterCity => 'Città';

  @override
  String get filterStage => 'Prova speciale';

  @override
  String get filterYear => 'Anno';

  @override
  String get filterAction => 'Azione';

  @override
  String get labelAllCountries => 'Tutti i paesi';

  @override
  String get labelNoResults => 'Nessun risultato corrispondente alla ricerca';

  @override
  String get labelTelemetry => 'Telemetria IA';

  @override
  String get languageSelector => 'Lingua';
}

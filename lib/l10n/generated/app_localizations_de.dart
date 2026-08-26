// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class AppLocalizationsDe extends AppLocalizations {
  AppLocalizationsDe([String locale = 'de']) : super(locale);

  @override
  String get appTitle => 'KI-Rallye-Suche';

  @override
  String get searchHint =>
      'Rallyes, Fahrer, Sprünge, Unfälle, Ergebnisse in natürlicher Sprache suchen...';

  @override
  String get searchButton => 'Suchen';

  @override
  String get searching => 'Suche läuft...';

  @override
  String get listening => 'Zuhören...';

  @override
  String resultsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Ergebnisse gefunden',
      one: '1 Ergebnis gefunden',
      zero: 'Keine Ergebnisse gefunden',
    );
    return '$_temp0';
  }

  @override
  String get interpretedSummaryPrefix => 'Interpretiert';

  @override
  String get clarificationTitle => 'Welches meinen Sie?';

  @override
  String get intentSearchRallies => 'Rallyes suchen';

  @override
  String get intentSearchDriverRallies => 'Fahrer-Rallyes';

  @override
  String get intentSearchDriverWins => 'Fahrersiege';

  @override
  String get intentGetRallyResults => 'Rallye-Sieger';

  @override
  String get intentGetRallyTopFinishers => 'Bestenliste';

  @override
  String get intentSearchVideoActions => 'Action-Highlights';

  @override
  String get intentSearchDriverVideos => 'Fahrer-Videos';

  @override
  String get intentGetTopUploaders => 'Top-Uploader';

  @override
  String get intentGetTopDriversByWins => 'Meiste Siege';

  @override
  String get actionAll => 'Alle Aktionen';

  @override
  String get actionJump => 'Sprung';

  @override
  String get actionDrift => 'Drift';

  @override
  String get actionCrash => 'Unfall';

  @override
  String get actionSpin => 'Dreher';

  @override
  String get actionDonut => 'Donut';

  @override
  String get actionHairpin => 'Spitzkehre';

  @override
  String get actionWaterSplash => 'Wasserdurchfahrt';

  @override
  String get actionStartLine => 'Startlinie';

  @override
  String get actionNearMiss => 'Knapp verfehlt';

  @override
  String get actionMechanicalFailure => 'Mechanischer Defekt';

  @override
  String get actionOffroad => 'Abseits der Strecke';

  @override
  String get actionStuck => 'Festgefahren';

  @override
  String get filterDriver => 'Fahrer';

  @override
  String get filterRally => 'Rallye';

  @override
  String get filterCountry => 'Land';

  @override
  String get filterCity => 'Stadt';

  @override
  String get filterStage => 'Wertungsprüfung';

  @override
  String get filterYear => 'Jahr';

  @override
  String get filterAction => 'Aktion';

  @override
  String get labelAllCountries => 'Alle Länder';

  @override
  String get labelNoResults => 'Keine Ergebnisse für Ihre Suchanfrage';

  @override
  String get labelTelemetry => 'KI-Telemetrie';

  @override
  String get languageSelector => 'Sprache';
}

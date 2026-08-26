// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Polish (`pl`).
class AppLocalizationsPl extends AppLocalizations {
  AppLocalizationsPl([String locale = 'pl']) : super(locale);

  @override
  String get appTitle => 'Wyszukiwarka Rajdowa AI';

  @override
  String get searchHint =>
      'Szukaj rajdów, kierowców, skoków, wypadków, wyników w języku naturalnym...';

  @override
  String get searchButton => 'Szukaj';

  @override
  String get searching => 'Wyszukiwanie...';

  @override
  String get listening => 'Słucham...';

  @override
  String resultsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Znaleziono $count wyników',
      many: 'Znaleziono $count wyników',
      few: 'Znaleziono $count wyniki',
      one: 'Znaleziono 1 wynik',
      zero: 'Nie znaleziono wyników',
    );
    return '$_temp0';
  }

  @override
  String get interpretedSummaryPrefix => 'Zinterpretowano';

  @override
  String get clarificationTitle => 'O który element chodzi?';

  @override
  String get intentSearchRallies => 'Szukaj rajdów';

  @override
  String get intentSearchDriverRallies => 'Rajdy kierowcy';

  @override
  String get intentSearchDriverWins => 'Zwycięstwa kierowcy';

  @override
  String get intentGetRallyResults => 'Zwycięzca rajdu';

  @override
  String get intentGetRallyTopFinishers => 'Tabela wyników';

  @override
  String get intentSearchVideoActions => 'Najlepsze akcje';

  @override
  String get intentSearchDriverVideos => 'Filmy z kierowcą';

  @override
  String get intentGetTopUploaders => 'Najlepsi autorzy';

  @override
  String get intentGetTopDriversByWins => 'Najwięcej zwycięstw';

  @override
  String get actionAll => 'Wszystkie akcje';

  @override
  String get actionJump => 'Skok';

  @override
  String get actionDrift => 'Poślizg kontrolowany';

  @override
  String get actionCrash => 'Wypadek';

  @override
  String get actionSpin => 'Obrót';

  @override
  String get actionDonut => 'Bączek';

  @override
  String get actionHairpin => 'Nawrót';

  @override
  String get actionWaterSplash => 'Przejazd przez wodę';

  @override
  String get actionStartLine => 'Linia startu';

  @override
  String get actionNearMiss => 'O włos od wypadku';

  @override
  String get actionMechanicalFailure => 'Awaria mechaniczna';

  @override
  String get actionOffroad => 'Wypadnięcie z trasy';

  @override
  String get actionStuck => 'Zakopany';

  @override
  String get filterDriver => 'Kierowca';

  @override
  String get filterRally => 'Rajd';

  @override
  String get filterCountry => 'Kraj';

  @override
  String get filterCity => 'Miasto';

  @override
  String get filterStage => 'Odcinek specjalny';

  @override
  String get filterYear => 'Rok';

  @override
  String get filterAction => 'Akcja';

  @override
  String get labelAllCountries => 'Wszystkie kraje';

  @override
  String get labelNoResults => 'Brak wyników dla podanego zapytania';

  @override
  String get labelTelemetry => 'Telemetria AI';

  @override
  String get languageSelector => 'Język';
}

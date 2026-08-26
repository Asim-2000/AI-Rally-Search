// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Croatian (`hr`).
class AppLocalizationsHr extends AppLocalizations {
  AppLocalizationsHr([String locale = 'hr']) : super(locale);

  @override
  String get appTitle => 'AI Pretraživanje Relija';

  @override
  String get searchHint =>
      'Pretražujte relije, vozače, skokove, nesreće, rezultate prirodnim jezikom...';

  @override
  String get searchButton => 'Traži';

  @override
  String get searching => 'Pretraživanje...';

  @override
  String get listening => 'Slušam...';

  @override
  String resultsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Pronađeno $count rezultata',
      few: 'Pronađena $count rezultata',
      one: 'Pronađen 1 rezultat',
      zero: 'Nema pronađenih rezultata',
    );
    return '$_temp0';
  }

  @override
  String get interpretedSummaryPrefix => 'Interpretirano';

  @override
  String get clarificationTitle => 'Na što točno mislite?';

  @override
  String get intentSearchRallies => 'Pretraži relije';

  @override
  String get intentSearchDriverRallies => 'Reliji vozača';

  @override
  String get intentSearchDriverWins => 'Pobjede vozača';

  @override
  String get intentGetRallyResults => 'Pobjednik relija';

  @override
  String get intentGetRallyTopFinishers => 'Poredak';

  @override
  String get intentSearchVideoActions => 'Najzanimljiviji trenuci';

  @override
  String get intentSearchDriverVideos => 'Videozapisi vozača';

  @override
  String get intentGetTopUploaders => 'Najbolji autori';

  @override
  String get intentGetTopDriversByWins => 'Najviše pobjeda';

  @override
  String get actionAll => 'Sve radnje';

  @override
  String get actionJump => 'Skok';

  @override
  String get actionDrift => 'Zanošenje';

  @override
  String get actionCrash => 'Sudar';

  @override
  String get actionSpin => 'Okretanje';

  @override
  String get actionDonut => 'Kružnica';

  @override
  String get actionHairpin => 'Oštri zavoj';

  @override
  String get actionWaterSplash => 'Prolazak kroz vodu';

  @override
  String get actionStartLine => 'Startna linija';

  @override
  String get actionNearMiss => 'Za dlaku';

  @override
  String get actionMechanicalFailure => 'Kvar';

  @override
  String get actionOffroad => 'Izlijetanje sa staze';

  @override
  String get actionStuck => 'Zaglavljen';

  @override
  String get filterDriver => 'Vozač';

  @override
  String get filterRally => 'Reli';

  @override
  String get filterCountry => 'Država';

  @override
  String get filterCity => 'Grad';

  @override
  String get filterStage => 'Brzinski ispit';

  @override
  String get filterYear => 'Godina';

  @override
  String get filterAction => 'Radnja';

  @override
  String get labelAllCountries => 'Sve države';

  @override
  String get labelNoResults => 'Nema rezultata za vaš upit';

  @override
  String get labelTelemetry => 'AI Telemetrija';

  @override
  String get languageSelector => 'Jezik';
}

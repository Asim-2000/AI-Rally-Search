// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Swahili (`sw`).
class AppLocalizationsSw extends AppLocalizations {
  AppLocalizationsSw([String locale = 'sw']) : super(locale);

  @override
  String get appTitle => 'Utafutaji wa Rally ya AI';

  @override
  String get searchHint =>
      'Tafuta mashindano ya rally, madereva, kuruka, ajali, matokeo kwa lugha asilia...';

  @override
  String get searchButton => 'Tafuta';

  @override
  String get searching => 'Inatafuta...';

  @override
  String get listening => 'Inasikiliza...';

  @override
  String resultsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Matokeo $count yamepatikana',
      one: 'Matokeo 1 yamepatikana',
      zero: 'Hakuna matokeo yaliyopatikana',
    );
    return '$_temp0';
  }

  @override
  String get interpretedSummaryPrefix => 'Imetafsiriwa';

  @override
  String get clarificationTitle => 'Unamaanisha ipi?';

  @override
  String get intentSearchRallies => 'Tafuta Mashindano ya Rally';

  @override
  String get intentSearchDriverRallies => 'Rally za Dereva';

  @override
  String get intentSearchDriverWins => 'Ushindi wa Dereva';

  @override
  String get intentGetRallyResults => 'Mshindi wa Rally';

  @override
  String get intentGetRallyTopFinishers => 'Bango la Viongozi';

  @override
  String get intentSearchVideoActions => 'Matukio ya Kusisimua';

  @override
  String get intentSearchDriverVideos => 'Video za Dereva';

  @override
  String get intentGetTopUploaders => 'Wapakiaji Bora';

  @override
  String get intentGetTopDriversByWins => 'Ushindi Mwingi Zaidi';

  @override
  String get actionAll => 'Vitendo Vyote';

  @override
  String get actionJump => 'Kuruka';

  @override
  String get actionDrift => 'Kuteleza';

  @override
  String get actionCrash => 'Ajali';

  @override
  String get actionSpin => 'Kuzunguka';

  @override
  String get actionDonut => 'Donut';

  @override
  String get actionHairpin => 'Kona Kali';

  @override
  String get actionWaterSplash => 'Maji';

  @override
  String get actionStartLine => 'Mstari wa Kuanzia';

  @override
  String get actionNearMiss => 'Kupona Kidogo';

  @override
  String get actionMechanicalFailure => 'Hitilafu ya Kiufundi';

  @override
  String get actionOffroad => 'Nje ya Njia';

  @override
  String get actionStuck => 'Kukwama';

  @override
  String get filterDriver => 'Dereva';

  @override
  String get filterRally => 'Rally';

  @override
  String get filterCountry => 'Nchi';

  @override
  String get filterCity => 'Mji';

  @override
  String get filterStage => 'Sehemu';

  @override
  String get filterYear => 'Mwaka';

  @override
  String get filterAction => 'Kitendo';

  @override
  String get labelAllCountries => 'Nchi Zote';

  @override
  String get labelNoResults => 'Hakuna matokeo yanayolingana na utafutaji wako';

  @override
  String get labelTelemetry => 'Takwimu za AI';

  @override
  String get languageSelector => 'Lugha';
}

// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Lithuanian (`lt`).
class AppLocalizationsLt extends AppLocalizations {
  AppLocalizationsLt([String locale = 'lt']) : super(locale);

  @override
  String get appTitle => 'AI Ralio Paieška';

  @override
  String get searchHint =>
      'Ieškokite ralių, vairuotojų, šuolių, avarijų, rezultatų natūralia kalba...';

  @override
  String get searchButton => 'Ieškoti';

  @override
  String get searching => 'Ieškoma...';

  @override
  String get listening => 'Klausoma...';

  @override
  String resultsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Rasta $count rezultatų',
      few: 'Rasti $count rezultatai',
      one: 'Rastas 1 rezultatas',
      zero: 'Rezultatų nerasta',
    );
    return '$_temp0';
  }

  @override
  String get interpretedSummaryPrefix => 'Interpretuota';

  @override
  String get clarificationTitle => 'Kurį turite omenyje?';

  @override
  String get intentSearchRallies => 'Ieškoti ralių';

  @override
  String get intentSearchDriverRallies => 'Vairuotojo raliai';

  @override
  String get intentSearchDriverWins => 'Vairuotojo pergalės';

  @override
  String get intentGetRallyResults => 'Ralio nugalėtojas';

  @override
  String get intentGetRallyTopFinishers => 'Lyderių lentelė';

  @override
  String get intentSearchVideoActions => 'Veiksmo akimirkos';

  @override
  String get intentSearchDriverVideos => 'Vairuotojo vaizdo įrašai';

  @override
  String get intentGetTopUploaders => 'Populiariausi autoriai';

  @override
  String get intentGetTopDriversByWins => 'Daugiausia pergalių';

  @override
  String get actionAll => 'Visi veiksmai';

  @override
  String get actionJump => 'Šuolis';

  @override
  String get actionDrift => 'Šoninis slydimas';

  @override
  String get actionCrash => 'Avarija';

  @override
  String get actionSpin => 'Apsisukimas';

  @override
  String get actionDonut => 'Sukimasis vietoje';

  @override
  String get actionHairpin => 'Apsukos posūkis';

  @override
  String get actionWaterSplash => 'Vandens kliūtis';

  @override
  String get actionStartLine => 'Starto linija';

  @override
  String get actionNearMiss => 'Vos išvengta avarija';

  @override
  String get actionMechanicalFailure => 'Mechaninis gedimas';

  @override
  String get actionOffroad => 'Nuvažiavimas nuo kelio';

  @override
  String get actionStuck => 'Užstrigęs';

  @override
  String get filterDriver => 'Vairuotojas';

  @override
  String get filterRally => 'Ralis';

  @override
  String get filterCountry => 'Šalis';

  @override
  String get filterCity => 'Miestas';

  @override
  String get filterStage => 'Greičio ruožas';

  @override
  String get filterYear => 'Metai';

  @override
  String get filterAction => 'Veiksmas';

  @override
  String get labelAllCountries => 'Visos šalys';

  @override
  String get labelNoResults => 'Rezultatų pagal jūsų užklausą nerasta';

  @override
  String get labelTelemetry => 'AI Telemetrija';

  @override
  String get languageSelector => 'Kalba';
}

// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Welsh (`cy`).
class AppLocalizationsCy extends AppLocalizations {
  AppLocalizationsCy([String locale = 'cy']) : super(locale);

  @override
  String get appTitle => 'Chwilio Rali AI';

  @override
  String get searchHint =>
      'Chwilio ralïau, gyrwyr, neidiau, damweiniau, canlyniadau mewn iaith naturiol...';

  @override
  String get searchButton => 'Chwilio';

  @override
  String get searching => 'Yn chwilio...';

  @override
  String get listening => 'Yn gwrando...';

  @override
  String resultsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count canlyniad wedi\'u darganfod',
      many: '$count chanlyniad wedi\'u darganfod',
      few: '$count chanlyniad wedi\'u darganfod',
      two: '2 ganlyniad wedi\'u darganfod',
      one: '1 canlyniad wedi\'i ddarganfod',
      zero: 'Dim canlyniadau wedi\'u darganfod',
    );
    return '$_temp0';
  }

  @override
  String get interpretedSummaryPrefix => 'Dehonglwyd';

  @override
  String get clarificationTitle => 'Pa un ydych chi\'n ei olygu?';

  @override
  String get intentSearchRallies => 'Chwilio Ralïau';

  @override
  String get intentSearchDriverRallies => 'Ralïau Gyrrwr';

  @override
  String get intentSearchDriverWins => 'Buddugoliaethau Gyrrwr';

  @override
  String get intentGetRallyResults => 'Enillydd Rali';

  @override
  String get intentGetRallyTopFinishers => 'Bwrdd Arweinwyr';

  @override
  String get intentSearchVideoActions => 'Uchafbwyntiau Gweithredu';

  @override
  String get intentSearchDriverVideos => 'Fideos Gyrrwr';

  @override
  String get intentGetTopUploaders => 'Prif Uwchlwythwyr';

  @override
  String get intentGetTopDriversByWins => 'Mwyaf o Fuddugoliaethau';

  @override
  String get actionAll => 'Pob Gweithred';

  @override
  String get actionJump => 'Naid';

  @override
  String get actionDrift => 'Drifft';

  @override
  String get actionCrash => 'Damwain';

  @override
  String get actionSpin => 'Troelli';

  @override
  String get actionDonut => 'Donut';

  @override
  String get actionHairpin => 'Troad Pin Gwallt';

  @override
  String get actionWaterSplash => 'Tasgiad Dŵr';

  @override
  String get actionStartLine => 'Llinell Gychwyn';

  @override
  String get actionNearMiss => 'Bron â tharo';

  @override
  String get actionMechanicalFailure => 'Methiant Mecanyddol';

  @override
  String get actionOffroad => 'Oddi ar y trac';

  @override
  String get actionStuck => 'Yn sownd';

  @override
  String get filterDriver => 'Gyrrwr';

  @override
  String get filterRally => 'Rali';

  @override
  String get filterCountry => 'Gwlad';

  @override
  String get filterCity => 'Dinas';

  @override
  String get filterStage => 'Cymal';

  @override
  String get filterYear => 'Blwyddyn';

  @override
  String get filterAction => 'Gweithred';

  @override
  String get labelAllCountries => 'Pob Gwlad';

  @override
  String get labelNoResults => 'Dim canlyniadau\'n cyfateb i\'ch chwiliad';

  @override
  String get labelTelemetry => 'Telemetreg AI';

  @override
  String get languageSelector => 'Iaith';
}

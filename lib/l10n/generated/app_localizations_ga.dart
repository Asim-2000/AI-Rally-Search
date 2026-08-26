// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Irish (`ga`).
class AppLocalizationsGa extends AppLocalizations {
  AppLocalizationsGa([String locale = 'ga']) : super(locale);

  @override
  String get appTitle => 'Cuardach Railí AI';

  @override
  String get searchHint =>
      'Cuardaigh railíthe, tiománaithe, léimeanna, tuairteanna, torthaí i ngnáth-theanga...';

  @override
  String get searchButton => 'Cuardaigh';

  @override
  String get searching => 'Ag cuardach...';

  @override
  String get listening => 'Ag éisteacht...';

  @override
  String resultsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Fuarthas $count toradh',
      many: 'Fuarthas $count dtoradh',
      few: 'Fuarthas $count thoradh',
      two: 'Fuarthas 2 thoradh',
      one: 'Fuarthas 1 toradh',
      zero: 'Ní bhfuarthas aon torthaí',
    );
    return '$_temp0';
  }

  @override
  String get interpretedSummaryPrefix => 'Léirmhínithe';

  @override
  String get clarificationTitle => 'Cé acu atá i gceist agat?';

  @override
  String get intentSearchRallies => 'Cuardaigh Railíthe';

  @override
  String get intentSearchDriverRallies => 'Railíthe Tiománaí';

  @override
  String get intentSearchDriverWins => 'Buaiteanna Tiománaí';

  @override
  String get intentGetRallyResults => 'Buaiteoir Railí';

  @override
  String get intentGetRallyTopFinishers => 'Clár na gCeannairí';

  @override
  String get intentSearchVideoActions => 'Buaicphointí Gníomhaíochta';

  @override
  String get intentSearchDriverVideos => 'Físeáin Tiománaí';

  @override
  String get intentGetTopUploaders => 'Príomh-Uasluchtóirí';

  @override
  String get intentGetTopDriversByWins => 'Buaiteanna is Mó';

  @override
  String get actionAll => 'Gach Gníomh';

  @override
  String get actionJump => 'Léim';

  @override
  String get actionDrift => 'Sruthlú';

  @override
  String get actionCrash => 'Tuairt';

  @override
  String get actionSpin => 'Casadh';

  @override
  String get actionDonut => 'Ciorcal';

  @override
  String get actionHairpin => 'Casadh Géar';

  @override
  String get actionWaterSplash => 'Splancadh Uisce';

  @override
  String get actionStartLine => 'Líne Tosaigh';

  @override
  String get actionNearMiss => 'Beagnach Tuairteáil';

  @override
  String get actionMechanicalFailure => 'Fabht Meicniúil';

  @override
  String get actionOffroad => 'Lasmuigh den Rian';

  @override
  String get actionStuck => 'Fostaithe';

  @override
  String get filterDriver => 'Tiománaí';

  @override
  String get filterRally => 'Railí';

  @override
  String get filterCountry => 'Tír';

  @override
  String get filterCity => 'Cathair';

  @override
  String get filterStage => 'Céim';

  @override
  String get filterYear => 'Bliain';

  @override
  String get filterAction => 'Gníomh';

  @override
  String get labelAllCountries => 'Gach Tír';

  @override
  String get labelNoResults => 'Níl aon torthaí a mheaitseálann do chuardach';

  @override
  String get labelTelemetry => 'Teiliméadracht AI';

  @override
  String get languageSelector => 'Teanga';
}

// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Portuguese (`pt`).
class AppLocalizationsPt extends AppLocalizations {
  AppLocalizationsPt([String locale = 'pt']) : super(locale);

  @override
  String get appTitle => 'Pesquisa de Ralis IA';

  @override
  String get searchHint =>
      'Pesquisar ralis, pilotos, saltos, acidentes, resultados em linguagem natural...';

  @override
  String get searchButton => 'Pesquisar';

  @override
  String get searching => 'A pesquisar...';

  @override
  String get listening => 'A ouvir...';

  @override
  String resultsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count resultados encontrados',
      one: '1 resultado encontrado',
      zero: 'Nenhum resultado encontrado',
    );
    return '$_temp0';
  }

  @override
  String get interpretedSummaryPrefix => 'Interpretado';

  @override
  String get clarificationTitle => 'A qual se refere?';

  @override
  String get intentSearchRallies => 'Pesquisar ralis';

  @override
  String get intentSearchDriverRallies => 'Ralis do piloto';

  @override
  String get intentSearchDriverWins => 'Vitórias do piloto';

  @override
  String get intentGetRallyResults => 'Vencedor do rali';

  @override
  String get intentGetRallyTopFinishers => 'Classificação';

  @override
  String get intentSearchVideoActions => 'Destaques de ação';

  @override
  String get intentSearchDriverVideos => 'Vídeos do piloto';

  @override
  String get intentGetTopUploaders => 'Principais contribuidores';

  @override
  String get intentGetTopDriversByWins => 'Mais vitórias';

  @override
  String get actionAll => 'Todas as ações';

  @override
  String get actionJump => 'Salto';

  @override
  String get actionDrift => 'Derrapagem';

  @override
  String get actionCrash => 'Acidente';

  @override
  String get actionSpin => 'Pião';

  @override
  String get actionDonut => 'Donut';

  @override
  String get actionHairpin => 'Gancho';

  @override
  String get actionWaterSplash => 'Passagem de água';

  @override
  String get actionStartLine => 'Linha de partida';

  @override
  String get actionNearMiss => 'Quase acidente';

  @override
  String get actionMechanicalFailure => 'Avaria mecânica';

  @override
  String get actionOffroad => 'Saída de pista';

  @override
  String get actionStuck => 'Preso';

  @override
  String get filterDriver => 'Piloto';

  @override
  String get filterRally => 'Rali';

  @override
  String get filterCountry => 'País';

  @override
  String get filterCity => 'Cidade';

  @override
  String get filterStage => 'Troço';

  @override
  String get filterYear => 'Ano';

  @override
  String get filterAction => 'Ação';

  @override
  String get labelAllCountries => 'Todos os países';

  @override
  String get labelNoResults =>
      'Nenhum resultado encontrado para a sua pesquisa';

  @override
  String get labelTelemetry => 'Telemetria IA';

  @override
  String get languageSelector => 'Idioma';
}

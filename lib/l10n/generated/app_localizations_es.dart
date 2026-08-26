// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get appTitle => 'Búsqueda Rally IA';

  @override
  String get searchHint =>
      'Buscar rallies, pilotos, saltos, choques, resultados en lenguaje natural...';

  @override
  String get searchButton => 'Buscar';

  @override
  String get searching => 'Buscando...';

  @override
  String get listening => 'Escuchando...';

  @override
  String resultsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count resultados encontrados',
      one: '1 resultado encontrado',
      zero: 'No se encontraron resultados',
    );
    return '$_temp0';
  }

  @override
  String get interpretedSummaryPrefix => 'Interpretado';

  @override
  String get clarificationTitle => '¿A cuál te refieres?';

  @override
  String get intentSearchRallies => 'Buscar rallies';

  @override
  String get intentSearchDriverRallies => 'Rallies del piloto';

  @override
  String get intentSearchDriverWins => 'Victorias del piloto';

  @override
  String get intentGetRallyResults => 'Ganador del rally';

  @override
  String get intentGetRallyTopFinishers => 'Clasificación';

  @override
  String get intentSearchVideoActions => 'Momentos destacados';

  @override
  String get intentSearchDriverVideos => 'Vídeos del piloto';

  @override
  String get intentGetTopUploaders => 'Mejores colaboradores';

  @override
  String get intentGetTopDriversByWins => 'Más victorias';

  @override
  String get actionAll => 'Todas las acciones';

  @override
  String get actionJump => 'Salto';

  @override
  String get actionDrift => 'Derrape';

  @override
  String get actionCrash => 'Choque';

  @override
  String get actionSpin => 'Trompo';

  @override
  String get actionDonut => 'Donut';

  @override
  String get actionHairpin => 'Horquilla';

  @override
  String get actionWaterSplash => 'Paso de agua';

  @override
  String get actionStartLine => 'Línea de salida';

  @override
  String get actionNearMiss => 'Casi accidente';

  @override
  String get actionMechanicalFailure => 'Fallo mecánico';

  @override
  String get actionOffroad => 'Salida de pista';

  @override
  String get actionStuck => 'Atascado';

  @override
  String get filterDriver => 'Piloto';

  @override
  String get filterRally => 'Rally';

  @override
  String get filterCountry => 'País';

  @override
  String get filterCity => 'Ciudad';

  @override
  String get filterStage => 'Tramo';

  @override
  String get filterYear => 'Año';

  @override
  String get filterAction => 'Acción';

  @override
  String get labelAllCountries => 'Todos los países';

  @override
  String get labelNoResults => 'No se encontraron resultados para tu consulta';

  @override
  String get labelTelemetry => 'Telemetría IA';

  @override
  String get languageSelector => 'Idioma';
}

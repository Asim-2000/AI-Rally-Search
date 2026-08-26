// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get appTitle => 'Recherche Rallye IA';

  @override
  String get searchHint =>
      'Rechercher des rallyes, pilotes, sauts, crashs, résultats en langage naturel...';

  @override
  String get searchButton => 'Rechercher';

  @override
  String get searching => 'Recherche en cours...';

  @override
  String get listening => 'Écoute...';

  @override
  String resultsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count résultats trouvés',
      one: '1 résultat trouvé',
      zero: 'Aucun résultat trouvé',
    );
    return '$_temp0';
  }

  @override
  String get interpretedSummaryPrefix => 'Interprété';

  @override
  String get clarificationTitle => 'Lequel voulez-vous dire ?';

  @override
  String get intentSearchRallies => 'Rechercher des rallyes';

  @override
  String get intentSearchDriverRallies => 'Rallyes du pilote';

  @override
  String get intentSearchDriverWins => 'Victoires du pilote';

  @override
  String get intentGetRallyResults => 'Vainqueur du rallye';

  @override
  String get intentGetRallyTopFinishers => 'Classement';

  @override
  String get intentSearchVideoActions => 'Moments forts';

  @override
  String get intentSearchDriverVideos => 'Vidéos du pilote';

  @override
  String get intentGetTopUploaders => 'Meilleurs contributeurs';

  @override
  String get intentGetTopDriversByWins => 'Plus de victoires';

  @override
  String get actionAll => 'Toutes les actions';

  @override
  String get actionJump => 'Saut';

  @override
  String get actionDrift => 'Dérapage';

  @override
  String get actionCrash => 'Crash';

  @override
  String get actionSpin => 'Tête-à-queue';

  @override
  String get actionDonut => 'Donut';

  @override
  String get actionHairpin => 'Épingle';

  @override
  String get actionWaterSplash => 'Gué d\'eau';

  @override
  String get actionStartLine => 'Ligne de départ';

  @override
  String get actionNearMiss => 'Frôlement';

  @override
  String get actionMechanicalFailure => 'Panne mécanique';

  @override
  String get actionOffroad => 'Sortie de route';

  @override
  String get actionStuck => 'Bloqué';

  @override
  String get filterDriver => 'Pilote';

  @override
  String get filterRally => 'Rallye';

  @override
  String get filterCountry => 'Pays';

  @override
  String get filterCity => 'Ville';

  @override
  String get filterStage => 'Spéciale';

  @override
  String get filterYear => 'Année';

  @override
  String get filterAction => 'Action';

  @override
  String get labelAllCountries => 'Tous les pays';

  @override
  String get labelNoResults => 'Aucun résultat correspondant à votre recherche';

  @override
  String get labelTelemetry => 'Télémétrie IA';

  @override
  String get languageSelector => 'Langue';
}

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_cs.dart';
import 'app_localizations_cy.dart';
import 'app_localizations_de.dart';
import 'app_localizations_en.dart';
import 'app_localizations_es.dart';
import 'app_localizations_fr.dart';
import 'app_localizations_ga.dart';
import 'app_localizations_hr.dart';
import 'app_localizations_it.dart';
import 'app_localizations_lt.dart';
import 'app_localizations_lv.dart';
import 'app_localizations_nb.dart';
import 'app_localizations_nl.dart';
import 'app_localizations_pl.dart';
import 'app_localizations_pt.dart';
import 'app_localizations_sk.dart';
import 'app_localizations_sw.dart';
import 'app_localizations_ur.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('cs'),
    Locale('cy'),
    Locale('de'),
    Locale('en'),
    Locale('es'),
    Locale('fr'),
    Locale('ga'),
    Locale('hr'),
    Locale('it'),
    Locale('lt'),
    Locale('lv'),
    Locale('nb'),
    Locale('nl'),
    Locale('pl'),
    Locale('pt'),
    Locale('sk'),
    Locale('sw'),
    Locale('ur'),
  ];

  /// The title of the application
  ///
  /// In en, this message translates to:
  /// **'AI Rally Search'**
  String get appTitle;

  /// Placeholder hint in natural language search bar
  ///
  /// In en, this message translates to:
  /// **'Search rallies, drivers, jumps, crashes, results in natural language...'**
  String get searchHint;

  /// Label on the search button
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get searchButton;

  /// Label displayed while search is executing
  ///
  /// In en, this message translates to:
  /// **'Searching...'**
  String get searching;

  /// Label displayed during speech listening
  ///
  /// In en, this message translates to:
  /// **'Listening...'**
  String get listening;

  /// Number of results found
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No results found} =1{1 result found} other{{count} results found}}'**
  String resultsCount(int count);

  /// Prefix for the natural language interpreted summary chip
  ///
  /// In en, this message translates to:
  /// **'Interpreted'**
  String get interpretedSummaryPrefix;

  /// Title shown when entity clarification is needed
  ///
  /// In en, this message translates to:
  /// **'Which one do you mean?'**
  String get clarificationTitle;

  /// Label for search rallies intent
  ///
  /// In en, this message translates to:
  /// **'Search Rallies'**
  String get intentSearchRallies;

  /// Label for driver rallies intent
  ///
  /// In en, this message translates to:
  /// **'Driver Rallies'**
  String get intentSearchDriverRallies;

  /// Label for driver wins intent
  ///
  /// In en, this message translates to:
  /// **'Driver Wins'**
  String get intentSearchDriverWins;

  /// Label for rally winner intent
  ///
  /// In en, this message translates to:
  /// **'Rally Winner'**
  String get intentGetRallyResults;

  /// Label for top finishers intent
  ///
  /// In en, this message translates to:
  /// **'Top Finishers'**
  String get intentGetRallyTopFinishers;

  /// Label for video action highlights intent
  ///
  /// In en, this message translates to:
  /// **'Action Highlights'**
  String get intentSearchVideoActions;

  /// Label for driver videos intent
  ///
  /// In en, this message translates to:
  /// **'Driver Videos'**
  String get intentSearchDriverVideos;

  /// Label for top uploaders intent
  ///
  /// In en, this message translates to:
  /// **'Top Uploaders'**
  String get intentGetTopUploaders;

  /// Label for most career wins leaderboard intent
  ///
  /// In en, this message translates to:
  /// **'Most Wins'**
  String get intentGetTopDriversByWins;

  /// Label for all actions filter
  ///
  /// In en, this message translates to:
  /// **'All Actions'**
  String get actionAll;

  /// Jump action label
  ///
  /// In en, this message translates to:
  /// **'Jump'**
  String get actionJump;

  /// Drift action label
  ///
  /// In en, this message translates to:
  /// **'Drift'**
  String get actionDrift;

  /// Crash action label
  ///
  /// In en, this message translates to:
  /// **'Crash'**
  String get actionCrash;

  /// Spin action label
  ///
  /// In en, this message translates to:
  /// **'Spin'**
  String get actionSpin;

  /// Donut action label
  ///
  /// In en, this message translates to:
  /// **'Donut'**
  String get actionDonut;

  /// Hairpin action label
  ///
  /// In en, this message translates to:
  /// **'Hairpin'**
  String get actionHairpin;

  /// Water splash action label
  ///
  /// In en, this message translates to:
  /// **'Water Splash'**
  String get actionWaterSplash;

  /// Start line action label
  ///
  /// In en, this message translates to:
  /// **'Start Line'**
  String get actionStartLine;

  /// Near miss action label
  ///
  /// In en, this message translates to:
  /// **'Near Miss'**
  String get actionNearMiss;

  /// Mechanical failure action label
  ///
  /// In en, this message translates to:
  /// **'Mechanical Failure'**
  String get actionMechanicalFailure;

  /// Offroad action label
  ///
  /// In en, this message translates to:
  /// **'Offroad'**
  String get actionOffroad;

  /// Stuck action label
  ///
  /// In en, this message translates to:
  /// **'Stuck'**
  String get actionStuck;

  /// Driver filter label
  ///
  /// In en, this message translates to:
  /// **'Driver'**
  String get filterDriver;

  /// Rally filter label
  ///
  /// In en, this message translates to:
  /// **'Rally'**
  String get filterRally;

  /// Country filter label
  ///
  /// In en, this message translates to:
  /// **'Country'**
  String get filterCountry;

  /// City filter label
  ///
  /// In en, this message translates to:
  /// **'City'**
  String get filterCity;

  /// Stage filter label
  ///
  /// In en, this message translates to:
  /// **'Stage'**
  String get filterStage;

  /// Year filter label
  ///
  /// In en, this message translates to:
  /// **'Year'**
  String get filterYear;

  /// Action filter label
  ///
  /// In en, this message translates to:
  /// **'Action'**
  String get filterAction;

  /// Label for all countries dropdown
  ///
  /// In en, this message translates to:
  /// **'All Countries'**
  String get labelAllCountries;

  /// Label when no results match
  ///
  /// In en, this message translates to:
  /// **'No results matching your query'**
  String get labelNoResults;

  /// Label for telemetry button
  ///
  /// In en, this message translates to:
  /// **'AI Telemetry'**
  String get labelTelemetry;

  /// Label for language switcher
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get languageSelector;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>[
    'ar',
    'cs',
    'cy',
    'de',
    'en',
    'es',
    'fr',
    'ga',
    'hr',
    'it',
    'lt',
    'lv',
    'nb',
    'nl',
    'pl',
    'pt',
    'sk',
    'sw',
    'ur',
  ].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'cs':
      return AppLocalizationsCs();
    case 'cy':
      return AppLocalizationsCy();
    case 'de':
      return AppLocalizationsDe();
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
    case 'fr':
      return AppLocalizationsFr();
    case 'ga':
      return AppLocalizationsGa();
    case 'hr':
      return AppLocalizationsHr();
    case 'it':
      return AppLocalizationsIt();
    case 'lt':
      return AppLocalizationsLt();
    case 'lv':
      return AppLocalizationsLv();
    case 'nb':
      return AppLocalizationsNb();
    case 'nl':
      return AppLocalizationsNl();
    case 'pl':
      return AppLocalizationsPl();
    case 'pt':
      return AppLocalizationsPt();
    case 'sk':
      return AppLocalizationsSk();
    case 'sw':
      return AppLocalizationsSw();
    case 'ur':
      return AppLocalizationsUr();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}

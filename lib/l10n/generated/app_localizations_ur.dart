// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Urdu (`ur`).
class AppLocalizationsUr extends AppLocalizations {
  AppLocalizationsUr([String locale = 'ur']) : super(locale);

  @override
  String get appTitle => 'اے آئی ریلی سرچ';

  @override
  String get searchHint =>
      'ریلیز، ڈرائیورز، جمپس، حادثات، نتائج قدرتی زبان میں تلاش کریں...';

  @override
  String get searchButton => 'تلاش کریں';

  @override
  String get searching => 'تلاش جاری ہے...';

  @override
  String get listening => 'سن رہا ہے...';

  @override
  String resultsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count نتائج ملے',
      one: '1 نتیجہ ملا',
      zero: 'کوئی نتیجہ نہیں ملا',
    );
    return '$_temp0';
  }

  @override
  String get interpretedSummaryPrefix => 'سمجھا گیا مفہوم';

  @override
  String get clarificationTitle => 'آپ کا کیا مطلب ہے؟';

  @override
  String get intentSearchRallies => 'ریلیز تلاش کریں';

  @override
  String get intentSearchDriverRallies => 'ڈرائیور کی ریلیز';

  @override
  String get intentSearchDriverWins => 'ڈرائیور کی فتوحات';

  @override
  String get intentGetRallyResults => 'ریلی فاتح';

  @override
  String get intentGetRallyTopFinishers => 'لیڈر بورڈ';

  @override
  String get intentSearchVideoActions => 'ایکشن ہائی لائٹس';

  @override
  String get intentSearchDriverVideos => 'ڈرائیور ویڈیوز';

  @override
  String get intentGetTopUploaders => 'ٹاپ اپ لوڈرز';

  @override
  String get intentGetTopDriversByWins => 'سب سے زیادہ فتوحات';

  @override
  String get actionAll => 'تمام ایکشنز';

  @override
  String get actionJump => 'جمپ';

  @override
  String get actionDrift => 'ڈرفٹ';

  @override
  String get actionCrash => 'حادثہ';

  @override
  String get actionSpin => 'اسپن';

  @override
  String get actionDonut => 'ڈونٹ';

  @override
  String get actionHairpin => 'ہیئر پن موڑ';

  @override
  String get actionWaterSplash => 'پانی کا چھینٹا';

  @override
  String get actionStartLine => 'اسٹارٹ لائن';

  @override
  String get actionNearMiss => 'بال بال بچنا';

  @override
  String get actionMechanicalFailure => 'مکینیکل خرابی';

  @override
  String get actionOffroad => 'ٹریک سے باہر';

  @override
  String get actionStuck => 'پھنس گیا';

  @override
  String get filterDriver => 'ڈرائیور';

  @override
  String get filterRally => 'ریلی';

  @override
  String get filterCountry => 'ملک';

  @override
  String get filterCity => 'شہر';

  @override
  String get filterStage => 'اسٹیج';

  @override
  String get filterYear => 'سال';

  @override
  String get filterAction => 'ایکشن';

  @override
  String get labelAllCountries => 'تمام ممالک';

  @override
  String get labelNoResults => 'آپ کی تلاش کے مطابق کوئی نتیجہ نہیں ملا';

  @override
  String get labelTelemetry => 'اے آئی ٹیلی میٹری';

  @override
  String get languageSelector => 'زبان';
}

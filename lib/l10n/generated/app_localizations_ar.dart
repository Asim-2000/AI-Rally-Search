// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get appTitle => 'بحث رالي بالذكاء الاصطناعي';

  @override
  String get searchHint =>
      'ابحث عن الراليات، السائقين، القفزات، الحوادث، النتائج بلغة طبيعية...';

  @override
  String get searchButton => 'بحث';

  @override
  String get searching => 'جارٍ البحث...';

  @override
  String get listening => 'جارٍ الاستماع...';

  @override
  String resultsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'تم العثور على $count نتيجة',
      many: 'تم العثور على $count نتيجة',
      few: 'تم العثور على $count نتائج',
      two: 'تم العثور على نتيجتين',
      one: 'تم العثور على نتيجة واحدة',
      zero: 'لم يتم العثور على نتائج',
    );
    return '$_temp0';
  }

  @override
  String get interpretedSummaryPrefix => 'المفهوم';

  @override
  String get clarificationTitle => 'ما الذي تقصده؟';

  @override
  String get intentSearchRallies => 'البحث عن راليات';

  @override
  String get intentSearchDriverRallies => 'راليات السائق';

  @override
  String get intentSearchDriverWins => 'انتصارات السائق';

  @override
  String get intentGetRallyResults => 'الفائز بالرالي';

  @override
  String get intentGetRallyTopFinishers => 'لوحة الصدارة';

  @override
  String get intentSearchVideoActions => 'أبرز اللحظات الحماسية';

  @override
  String get intentSearchDriverVideos => 'فيديوهات السائق';

  @override
  String get intentGetTopUploaders => 'أفضل الناشرين';

  @override
  String get intentGetTopDriversByWins => 'الأكثر فوزاً';

  @override
  String get actionAll => 'جميع الحركات';

  @override
  String get actionJump => 'قفزة';

  @override
  String get actionDrift => 'دريفت / انجراف';

  @override
  String get actionCrash => 'حادث';

  @override
  String get actionSpin => 'دوران';

  @override
  String get actionDonut => 'دونات';

  @override
  String get actionHairpin => 'منعطف حاد';

  @override
  String get actionWaterSplash => 'عبور المياه';

  @override
  String get actionStartLine => 'خط البداية';

  @override
  String get actionNearMiss => 'نجاة وشيكة';

  @override
  String get actionMechanicalFailure => 'عطل ميكانيكي';

  @override
  String get actionOffroad => 'خروج عن المسار';

  @override
  String get actionStuck => 'عالق';

  @override
  String get filterDriver => 'السائق';

  @override
  String get filterRally => 'الرالي';

  @override
  String get filterCountry => 'البلد';

  @override
  String get filterCity => 'المدينة';

  @override
  String get filterStage => 'المرحلة';

  @override
  String get filterYear => 'السنة';

  @override
  String get filterAction => 'الحركة';

  @override
  String get labelAllCountries => 'جميع البلدان';

  @override
  String get labelNoResults => 'لا توجد نتائج تطابق بحثك';

  @override
  String get labelTelemetry => 'قياسات الذكاء الاصطناعي';

  @override
  String get languageSelector => 'اللغة';
}

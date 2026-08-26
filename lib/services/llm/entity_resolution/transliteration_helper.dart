/// Helper for algorithmic transliteration from Arabic/Urdu scripts to Latin phonetics.
///
/// Converts standard Arabic and Urdu orthography into phonetic Latin approximations
/// for database entity candidate retrieval and matching without hardcoded entity dictionaries.
class TransliterationHelper {
  const TransliterationHelper._();

  /// Regex matching Arabic / Urdu Unicode blocks.
  static final RegExp _arabicUrduRegex = RegExp(
    r'[\u0600-\u06FF\u0750-\u077F\u08A0-\u08FF\uFB50-\uFDFF\uFE70-\uFEFF]',
  );

  /// Arabic Tashkeel / Harakat and Diacritics Regex.
  static final RegExp _tashkeelRegex = RegExp(
    r'[\u064B-\u065F\u0670\u06D6-\u06ED\u0610-\u061A]',
  );

  /// Tatweel (Kashida) character.
  static const String _tatweel = '\u0640';

  /// Arabic-Indic digits map.
  static const Map<String, String> _arabicDigitsMap = {
    '٠': '0',
    '١': '1',
    '٢': '2',
    '٣': '3',
    '٤': '4',
    '٥': '5',
    '٦': '6',
    '٧': '7',
    '٨': '8',
    '٩': '9',
  };

  /// Determines whether [text] contains Arabic or Urdu characters.
  static bool isArabicOrUrdu(String text) {
    return _arabicUrduRegex.hasMatch(text);
  }

  /// Normalizes Arabic and Urdu script by stripping diacritics, tatweel,
  /// standardizing digits, and unifying character variants.
  static String normalizeScript(String input) {
    if (input.isEmpty) return input;

    String text = input.replaceAll(_tashkeelRegex, '');
    text = text.replaceAll(_tatweel, '');

    // Standardize Arabic-Indic digits to ASCII
    _arabicDigitsMap.forEach((ar, en) {
      text = text.replaceAll(ar, en);
    });

    // Standardize Alef variants
    text = text.replaceAll(RegExp(r'[إأآٱ]'), 'ا');

    // Standardize Taa Marbuta
    text = text.replaceAll('ة', 'ه');

    // Standardize Ya / Alef Maksura
    text = text.replaceAll('ى', 'ي');
    text = text.replaceAll('ئ', 'ي');
    text = text.replaceAll('ؤ', 'و');

    // Standardize Persian/Urdu variants to unified phonemes
    text = text.replaceAll('ٹ', 'ت');
    text = text.replaceAll('ڈ', 'د');
    text = text.replaceAll('ڑ', 'ر');
    text = text.replaceAll('ں', 'ن');
    text = text.replaceAll('ے', 'ي');
    text = text.replaceAll('ہ', 'ه');
    text = text.replaceAll('گ', 'ك');
    text = text.replaceAll('پ', 'ب');
    text = text.replaceAll('چ', 'ج');

    return text.trim();
  }

  /// Transliterates Arabic/Urdu text to Latin phonetic approximations.
  ///
  /// Returns a list of plausible phonetic Latin string candidates.
  static List<String> transliterateToLatin(String input) {
    if (!isArabicOrUrdu(input)) {
      return [input.trim().toLowerCase()];
    }

    final normalized = normalizeScript(input);
    final words = normalized.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();

    if (words.isEmpty) return [];

    final wordCandidates = <List<String>>[];
    for (final word in words) {
      wordCandidates.add(_transliterateWord(word).take(25).toList());
    }

    // Build combination of word transliterations
    return _cartesianProduct(wordCandidates).map((w) => w.join(' ')).toList();
  }

  /// Transliterates a single normalized Arabic/Urdu word into Latin phonetic candidates.
  static List<String> _transliterateWord(String word) {
    String w = word;

    // Handle common rally vocabulary words in Arabic/Urdu
    if (w == 'رالي' || w == 'ريلي' || w == 'ريليا' || w == 'راليات') {
      return ['rally', 'rallies'];
    }

    // Handle definite article 'al-' / 'el-' at word start
    bool hasAl = false;
    if (w.startsWith('ال') && w.length > 2) {
      hasAl = true;
      w = w.substring(2);
    }

    final charOptions = <List<String>>[];
    for (int i = 0; i < w.length; i++) {
      charOptions.add(_getCharOptions(w[i], i == 0, i == w.length - 1));
    }

    final variants = _generateVariants(charOptions, maxVariants: 50);

    final results = <String>{};
    for (final v in variants) {
      final clean = v.trim();
      if (clean.isNotEmpty) {
        results.add(clean);
        if (hasAl) results.add('al-$clean');
      }
    }

    return results.toList();
  }

  static List<String> _getCharOptions(String char, bool isFirst, bool isLast) {
    switch (char) {
      case 'ا':
        return isFirst ? ['a', 'e', 'o'] : ['a', ''];
      case 'ب':
        return ['b'];
      case 'ت':
        return ['t', 'tt'];
      case 'ث':
        return ['th', 's'];
      case 'ج':
        return ['j', 'g'];
      case 'ح':
        return ['h'];
      case 'خ':
        return ['kh', 'k'];
      case 'د':
        return ['d'];
      case 'ذ':
        return ['dh', 'z'];
      case 'ر':
        return ['rr', 'r'];
      case 'ز':
        return ['z'];
      case 'س':
        return ['s', 'ss'];
      case 'ش':
        return ['sh'];
      case 'ص':
        return ['s'];
      case 'ض':
        return ['d'];
      case 'ط':
        return ['t', 'tt'];
      case 'ظ':
        return ['z'];
      case 'ع':
        return ['a', ''];
      case 'غ':
        return ['g', 'gh'];
      case 'ف':
        return ['f', 'ff', 'v'];
      case 'ق':
        return ['k', 'q', 'c'];
      case 'ك':
        return ['k', 'c'];
      case 'ل':
        return ['l', 'll', 'lum', 'lam'];
      case 'م':
        return isLast ? ['m', 'um'] : ['m'];
      case 'ن':
        return ['n'];
      case 'ه':
        return ['h'];
      case 'و':
        return isFirst ? ['w', 'v'] : ['o', 'v', 'w', 'u', 'oo'];
      case 'ي':
        return isFirst
            ? ['y', 'i']
            : (isLast ? ['y', 'ee', 'i', 'e'] : ['e', 'ee', 'ai', 'i', 'ay']);
      default:
        return [char];
    }
  }

  static List<String> _generateVariants(List<List<String>> charOptions, {int maxVariants = 50}) {
    List<String> current = [''];

    for (final options in charOptions) {
      final next = <String>[];
      for (final prefix in current) {
        for (final opt in options) {
          next.add('$prefix$opt');
        }
      }
      current = next.take(maxVariants).toList();
    }

    return current;
  }

  static List<List<String>> _cartesianProduct(List<List<String>> lists) {
    List<List<String>> result = [[]];
    for (final list in lists) {
      final temp = <List<String>>[];
      for (final r in result) {
        for (final item in list) {
          temp.add([...r, item]);
        }
      }
      result = temp.take(60).toList();
    }
    return result;
  }
}

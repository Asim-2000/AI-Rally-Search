import 'package:flutter_test/flutter_test.dart';
import 'package:ai_rally_search/services/llm/entity_resolution/phonetic_matching_helper.dart';

void main() {
  group('Conservative Descriptor Stripping & Negative Regressions', () {
    test('Motorsport descriptors stripped conservatively', () {
      expect(PhoneticMatchingHelper.stripDescriptors('West Cork Rally'), equals('west cork'));
      expect(PhoneticMatchingHelper.stripDescriptors('Monaghan Stages'), equals('monaghan'));
      expect(PhoneticMatchingHelper.stripDescriptors('Moonraker Forestry Rally'), equals('moonraker'));
      expect(PhoneticMatchingHelper.stripDescriptors('Polski Rajd Legend'), equals('polski legend'));
      expect(PhoneticMatchingHelper.stripDescriptors('Rallijsprints Cesavine'), equals('cesavine'));
    });

    test('Material language/function terms are PRESERVED and NOT stripped', () {
      // Must preserve international, hotel, test, regional, series, de, des, van, der, del, di, the, of, uren
      const preservedPhrases = [
        'Rally of the Lakes',
        '6 Uren van Kortrijk',
        'Clonakilty Park Hotel West Cork',
        'Rallye Régional des Ardennes',
        'Century 21 Portugal Rally Series Castelo Branco',
        'Donegal test rally',
        'Rally Internazionale Golfo dell Asinara',
        'OBM Land der 1000 Hügel',
      ];

      for (final p in preservedPhrases) {
        final stripped = PhoneticMatchingHelper.stripDescriptors(p);
        expect(stripped.toLowerCase().contains('hotel') || !p.toLowerCase().contains('hotel'), isTrue);
        expect(stripped.toLowerCase().contains('regional') || !p.toLowerCase().contains('regional'), isTrue);
        expect(stripped.toLowerCase().contains('series') || !p.toLowerCase().contains('series'), isTrue);
        expect(stripped.toLowerCase().contains('test') || !p.toLowerCase().contains('test'), isTrue);
        expect(stripped.toLowerCase().contains('uren') || !p.toLowerCase().contains('uren'), isTrue);
        expect(stripped.toLowerCase().contains('van') || !p.toLowerCase().contains('van'), isTrue);
        expect(stripped.toLowerCase().contains('des') || !p.toLowerCase().contains('des'), isTrue);
        expect(stripped.toLowerCase().contains('der') || !p.toLowerCase().contains('der'), isTrue);
      }
    });

    test('Negative regression: Distinct real rallies do NOT collapse to same stem', () {
      // Different regional rallies
      final r1 = PhoneticMatchingHelper.stripDescriptors('Rallye Régional des Ardennes');
      final r2 = PhoneticMatchingHelper.stripDescriptors('Rallye Régional de la Suisse Normande');
      expect(PhoneticMatchingHelper.collapseSpaces(r1), isNot(equals(PhoneticMatchingHelper.collapseSpaces(r2))));

      // Different hotel sponsored rallies
      final h1 = PhoneticMatchingHelper.stripDescriptors('Clonakilty Park Hotel West Cork Rally');
      final h2 = PhoneticMatchingHelper.stripDescriptors('Seven Oaks Hotel Carlow Stages Rally');
      expect(PhoneticMatchingHelper.collapseSpaces(h1), isNot(equals(PhoneticMatchingHelper.collapseSpaces(h2))));

      // Different rally series
      final s1 = PhoneticMatchingHelper.stripDescriptors('Century 21 Portugal Rally Series - Castelo Branco');
      final s2 = PhoneticMatchingHelper.stripDescriptors('AMF Mobilidade Rally Series - Ponte de Lima');
      expect(PhoneticMatchingHelper.collapseSpaces(s1), isNot(equals(PhoneticMatchingHelper.collapseSpaces(s2))));

      // Different hour endurance events
      final u1 = PhoneticMatchingHelper.stripDescriptors('6 Uren van Kortrijk');
      final u2 = PhoneticMatchingHelper.stripDescriptors('24 Uren van Ieper');
      expect(PhoneticMatchingHelper.collapseSpaces(u1), isNot(equals(PhoneticMatchingHelper.collapseSpaces(u2))));

      // Distinct Irish rallies sharing "International"
      final i1 = PhoneticMatchingHelper.stripDescriptors('Wilton Donegal International Rally');
      final i2 = PhoneticMatchingHelper.stripDescriptors('Assess Ireland International Rally of the Lakes');
      expect(PhoneticMatchingHelper.collapseSpaces(i1), isNot(equals(PhoneticMatchingHelper.collapseSpaces(i2))));
    });
  });
}

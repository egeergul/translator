import 'package:flutter_test/flutter_test.dart';
import 'package:translator/utils/json_utils.dart';

void main() {
  group('JsonUtils', () {
    test('decodes object JSON into a map', () {
      final result = JsonUtils.decodeObject('{"enabled":true}');

      expect(result, <String, dynamic>{'enabled': true});
    });

    test('returns an empty map for corrupt object JSON', () {
      final result = JsonUtils.decodeObject('{bad json');

      expect(result, isEmpty);
    });

    test('decodes a list of object JSON values', () {
      final result = JsonUtils.decodeObjectList(
        '[{"bcpCode":"en"},{"bcpCode":"tr"}]',
      );

      expect(result, <Map<String, dynamic>>[
        <String, dynamic>{'bcpCode': 'en'},
        <String, dynamic>{'bcpCode': 'tr'},
      ]);
    });

    test('filters non-object values from object lists', () {
      final result = JsonUtils.decodeObjectList('[{"bcpCode":"en"}, 7, "x"]');

      expect(result, <Map<String, dynamic>>[
        <String, dynamic>{'bcpCode': 'en'},
      ]);
    });
  });
}

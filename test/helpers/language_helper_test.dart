import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_translation/google_mlkit_translation.dart';
import 'package:translator/helpers/language_helper.dart';

void main() {
  group('LanguageHelper', () {
    test('sorts downloaded languages before available languages', () {
      final options = LanguageHelper.buildOptions(
        languages: const [
          TranslateLanguage.turkish,
          TranslateLanguage.english,
          TranslateLanguage.german,
        ],
        downloadedCodes: <String>{TranslateLanguage.german.bcpCode},
      );

      expect(options.first.bcpCode, TranslateLanguage.german.bcpCode);
      expect(options.first.isDownloaded, isTrue);
      expect(options.map((option) => option.name), <String>[
        'German',
        'English',
        'Turkish',
      ]);
    });

    test('finds options by BCP-47 code', () {
      final options = LanguageHelper.buildOptions(
        languages: const [TranslateLanguage.english, TranslateLanguage.turkish],
        downloadedCodes: <String>{},
      );

      final result = LanguageHelper.findByCode(
        options,
        TranslateLanguage.turkish.bcpCode,
      );

      expect(result?.language, TranslateLanguage.turkish);
    });
  });
}

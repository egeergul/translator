import 'package:collection/collection.dart';
import 'package:google_mlkit_translation/google_mlkit_translation.dart';

class LanguageOption {
  const LanguageOption({required this.language, required this.name, required this.bcpCode, required this.isDownloaded});

  final TranslateLanguage language;
  final String name;
  final String bcpCode;
  final bool isDownloaded;

  LanguageOption copyWith({bool? isDownloaded}) {
    return LanguageOption(language: language, name: name, bcpCode: bcpCode, isDownloaded: isDownloaded ?? this.isDownloaded);
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) || other is LanguageOption && other.bcpCode == bcpCode;
  }

  @override
  int get hashCode => bcpCode.hashCode;
}

class LanguageHelper {
  const LanguageHelper._();

  static List<LanguageOption> buildOptions({required Iterable<TranslateLanguage> languages, required Set<String> downloadedCodes}) {
    final options = languages.map((language) {
      return LanguageOption(
        language: language,
        name: displayName(language),
        bcpCode: language.bcpCode,
        isDownloaded: downloadedCodes.contains(language.bcpCode),
      );
    }).toList();

    options.sort((left, right) {
      if (left.isDownloaded != right.isDownloaded) {
        return left.isDownloaded ? -1 : 1;
      }
      return left.name.compareTo(right.name);
    });

    return options;
  }

  static String displayName(TranslateLanguage language) {
    final name = language.name;
    return '${name[0].toUpperCase()}${name.substring(1)}';
  }

  static LanguageOption? findByCode(List<LanguageOption> options, String bcpCode) {
    return options.firstWhereOrNull((option) => option.bcpCode == bcpCode);
  }

  static LanguageOption? equivalentOption(List<LanguageOption> options, LanguageOption? current) {
    if (current == null) {
      return null;
    }
    return findByCode(options, current.bcpCode);
  }
}

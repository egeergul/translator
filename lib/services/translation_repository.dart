import 'package:google_mlkit_translation/google_mlkit_translation.dart';

import '../utils/app_exception.dart';
import 'mlkit_translation_service.dart';
import 'model_repository.dart';

class TranslationRepository {
  const TranslationRepository({
    required MlkitTranslationService mlkitTranslationService,
    required ModelRepository modelRepository,
  }) : _mlkitTranslationService = mlkitTranslationService,
       _modelRepository = modelRepository;

  final MlkitTranslationService _mlkitTranslationService;
  final ModelRepository _modelRepository;

  Future<String> translate({
    required String text,
    required TranslateLanguage sourceLanguage,
    required TranslateLanguage targetLanguage,
  }) async {
    if (text.trim().isEmpty) {
      return '';
    }

    if (sourceLanguage == targetLanguage) {
      return text;
    }

    final sourceReady = await _modelRepository.isReadyForOfflineUse(
      sourceLanguage,
    );
    final targetReady = await _modelRepository.isReadyForOfflineUse(
      targetLanguage,
    );

    if (!sourceReady || !targetReady) {
      throw const AppException(
        'Download both selected language models before translating offline.',
      );
    }

    return _mlkitTranslationService.translateText(
      text: text,
      sourceLanguage: sourceLanguage,
      targetLanguage: targetLanguage,
    );
  }
}

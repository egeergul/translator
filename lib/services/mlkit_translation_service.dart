import 'package:google_mlkit_translation/google_mlkit_translation.dart';

import '../utils/app_exception.dart';
import '../utils/platform_guard.dart';

class MlkitTranslationService {
  MlkitTranslationService() : _modelManager = OnDeviceTranslatorModelManager();

  final OnDeviceTranslatorModelManager _modelManager;

  List<TranslateLanguage> get supportedLanguages => TranslateLanguage.values;

  Future<bool> isModelDownloaded(TranslateLanguage language) async {
    _ensureSupportedPlatform();
    return _modelManager.isModelDownloaded(language.bcpCode);
  }

  Future<bool> downloadModel(
    TranslateLanguage language, {
    bool isWifiRequired = false,
  }) async {
    _ensureSupportedPlatform();
    return _modelManager.downloadModel(
      language.bcpCode,
      isWifiRequired: isWifiRequired,
    );
  }

  Future<bool> deleteModel(TranslateLanguage language) async {
    _ensureSupportedPlatform();
    return _modelManager.deleteModel(language.bcpCode);
  }

  Future<String> translateText({
    required String text,
    required TranslateLanguage sourceLanguage,
    required TranslateLanguage targetLanguage,
  }) async {
    _ensureSupportedPlatform();

    final translator = OnDeviceTranslator(
      sourceLanguage: sourceLanguage,
      targetLanguage: targetLanguage,
    );

    try {
      return await translator.translateText(text);
    } finally {
      await translator.close();
    }
  }

  void _ensureSupportedPlatform() {
    if (!PlatformGuard.isSupported) {
      throw const AppException(PlatformGuard.unsupportedMessage);
    }
  }
}

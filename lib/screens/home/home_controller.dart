import 'package:collection/collection.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import '../../constants/app_constants.dart';
import '../../constants/app_routes.dart';
import '../../helpers/language_helper.dart';
import '../../services/model_repository.dart';
import '../../services/translation_repository.dart';
import '../../utils/app_exception.dart';
import '../../utils/platform_guard.dart';

class HomeController extends GetxController {
  HomeController({
    required ModelRepository modelRepository,
    required TranslationRepository translationRepository,
  }) : _modelRepository = modelRepository,
       _translationRepository = translationRepository;

  final ModelRepository _modelRepository;
  final TranslationRepository _translationRepository;

  final languages = <LanguageOption>[].obs;
  final selectedSource = Rxn<LanguageOption>();
  final selectedTarget = Rxn<LanguageOption>();
  final sourceText = ''.obs;
  final translatedText = ''.obs;
  final statusMessage = RxnString();
  final isLoadingLanguages = true.obs;
  final isTranslating = false.obs;
  final selectedTabIndex = 0.obs;

  bool _initialRedirectHandled = false;
  int _translationRequestId = 0;

  @override
  void onInit() {
    super.onInit();
    refreshLanguages();
  }

  @override
  void onReady() {
    super.onReady();
    _redirectToInitialModelSetupIfNeeded();
  }

  Future<void> refreshLanguages() async {
    isLoadingLanguages.value = true;
    try {
      final nextLanguages = await _modelRepository.getLanguageOptions();
      languages.assignAll(nextLanguages);

      selectedSource.value =
          LanguageHelper.equivalentOption(
            nextLanguages,
            selectedSource.value,
          ) ??
          LanguageHelper.findByCode(
            nextLanguages,
            AppConstants.defaultSourceLanguageCode,
          ) ??
          nextLanguages.firstOrNull;

      selectedTarget.value =
          LanguageHelper.equivalentOption(
            nextLanguages,
            selectedTarget.value,
          ) ??
          LanguageHelper.findByCode(
            nextLanguages,
            AppConstants.defaultTargetLanguageCode,
          ) ??
          _firstDifferentLanguage(nextLanguages, selectedSource.value);

      await translateCurrentText();
    } on AppException catch (error) {
      statusMessage.value = error.message;
    } catch (_) {
      statusMessage.value = 'Languages could not be loaded.';
    } finally {
      isLoadingLanguages.value = false;
    }
  }

  void onSourceTextChanged(String value) {
    sourceText.value = value;
    translateCurrentText();
  }

  void onSourceTextSubmitted(String value) {
    sourceText.value = value;
    FocusManager.instance.primaryFocus?.unfocus();
    translateCurrentText();
  }

  void onSourceLanguageChanged(LanguageOption? language) {
    selectedSource.value = language;
    translateCurrentText();
  }

  void onTargetLanguageChanged(LanguageOption? language) {
    selectedTarget.value = language;
    translateCurrentText();
  }

  void onTabSelected(int index) {
    selectedTabIndex.value = index;
  }

  Future<void> translateCurrentText() async {
    final requestId = ++_translationRequestId;
    final text = sourceText.value;
    final source = selectedSource.value;
    final target = selectedTarget.value;

    statusMessage.value = null;

    if (text.trim().isEmpty) {
      translatedText.value = '';
      isTranslating.value = false;
      return;
    }

    if (!PlatformGuard.isSupported) {
      translatedText.value = '';
      statusMessage.value = PlatformGuard.unsupportedMessage;
      isTranslating.value = false;
      return;
    }

    if (source == null || target == null) {
      translatedText.value = '';
      statusMessage.value = 'Select source and target languages.';
      isTranslating.value = false;
      return;
    }

    if (source.language == target.language) {
      translatedText.value = text;
      isTranslating.value = false;
      return;
    }

    isTranslating.value = true;
    try {
      final translation = await _translationRepository.translate(
        text: text,
        sourceLanguage: source.language,
        targetLanguage: target.language,
      );

      if (requestId == _translationRequestId) {
        translatedText.value = translation;
      }
    } on AppException catch (error) {
      if (requestId == _translationRequestId) {
        translatedText.value = '';
        statusMessage.value = error.message;
      }
    } catch (_) {
      if (requestId == _translationRequestId) {
        translatedText.value = '';
        statusMessage.value = 'Translation failed. Try again.';
      }
    } finally {
      if (requestId == _translationRequestId) {
        isTranslating.value = false;
      }
    }
  }

  Future<void> openModelManagement() async {
    await Get.toNamed<void>(AppRoutes.models);
    if (!isClosed) {
      await refreshLanguages();
    }
  }

  Future<void> _redirectToInitialModelSetupIfNeeded() async {
    if (_initialRedirectHandled) {
      return;
    }

    _initialRedirectHandled = true;
    final hasCompletedSetup = await _modelRepository
        .hasCompletedInitialModelDownload();

    if (!hasCompletedSetup && !isClosed) {
      await Future<void>.delayed(Duration.zero);
      await Get.toNamed<void>(AppRoutes.models);
      if (!isClosed) {
        await refreshLanguages();
      }
    }
  }

  LanguageOption? _firstDifferentLanguage(
    List<LanguageOption> options,
    LanguageOption? source,
  ) {
    return options.firstWhereOrNull(
      (option) => source == null || option.bcpCode != source.bcpCode,
    );
  }
}

import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import '../../helpers/language_helper.dart';
import '../../screens/home/home_controller.dart';
import '../../services/model_repository.dart';
import '../../utils/app_exception.dart';
import '../../utils/platform_guard.dart';
import '../../widgets/blocking_progress_dialog.dart';

class ManageLanguageModelsController extends GetxController {
  ManageLanguageModelsController({required ModelRepository modelRepository})
    : _modelRepository = modelRepository;

  final ModelRepository _modelRepository;

  final languages = <LanguageOption>[].obs;
  final searchTextController = TextEditingController();
  final searchQuery = ''.obs;
  final isLoading = true.obs;
  final activeLanguageCode = RxnString();
  final errorMessage = RxnString();

  @override
  void onInit() {
    super.onInit();
    refreshLanguages();
  }

  int get downloadedCount =>
      languages.where((language) => language.isDownloaded).length;

  List<LanguageOption> get filteredLanguages {
    final query = searchQuery.value.trim().toLowerCase();
    if (query.isEmpty) {
      return languages;
    }

    return languages
        .where((language) {
          return language.name.toLowerCase().contains(query) ||
              language.bcpCode.toLowerCase().contains(query);
        })
        .toList(growable: false);
  }

  void onSearchChanged(String value) {
    searchQuery.value = value;
  }

  void clearSearch() {
    searchTextController.clear();
    searchQuery.value = '';
  }

  @override
  void onClose() {
    searchTextController.dispose();
    super.onClose();
  }

  Future<void> refreshLanguages() async {
    isLoading.value = true;
    errorMessage.value = null;

    try {
      languages.assignAll(await _modelRepository.getLanguageOptions());
    } on AppException catch (error) {
      errorMessage.value = error.message;
    } catch (_) {
      errorMessage.value = 'Language models could not be loaded.';
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> download(LanguageOption language) async {
    if (!PlatformGuard.isSupported || activeLanguageCode.value != null) {
      return;
    }

    activeLanguageCode.value = language.bcpCode;
    Get.dialog<void>(
      BlockingProgressDialog(
        title: 'Downloading ${language.name}',
        message: 'Keep the app open until the model is ready.',
      ),
      barrierDismissible: false,
    );

    try {
      await _modelRepository.downloadModel(language.language);
      await refreshLanguages();
      await _refreshHome();
      _closeDialogIfOpen();
      Get.snackbar('Model downloaded', '${language.name} is ready offline.');
    } on AppException catch (error) {
      _closeDialogIfOpen();
      Get.snackbar('Download failed', error.message);
    } catch (_) {
      _closeDialogIfOpen();
      Get.snackbar('Download failed', 'The model could not be downloaded.');
    } finally {
      activeLanguageCode.value = null;
    }
  }

  Future<void> delete(LanguageOption language) async {
    if (!PlatformGuard.isSupported || activeLanguageCode.value != null) {
      return;
    }

    activeLanguageCode.value = language.bcpCode;
    try {
      await _modelRepository.deleteModel(language.language);
      await refreshLanguages();
      await _refreshHome();
      Get.snackbar('Model deleted', '${language.name} was removed.');
    } on AppException catch (error) {
      Get.snackbar('Delete failed', error.message);
    } catch (_) {
      Get.snackbar('Delete failed', 'The model could not be deleted.');
    } finally {
      activeLanguageCode.value = null;
    }
  }

  Future<void> _refreshHome() async {
    if (Get.isRegistered<HomeController>()) {
      await Get.find<HomeController>().refreshLanguages();
    }
  }

  void _closeDialogIfOpen() {
    if (Get.isDialogOpen == true) {
      Get.back<void>();
    }
  }
}

import 'package:get/get.dart';

import '../constants/app_routes.dart';
import '../screens/home/home_controller.dart';
import '../screens/home/home_screen.dart';
import '../screens/manage_language_models/manage_language_models_controller.dart';
import '../screens/manage_language_models/manage_language_models_screen.dart';
import '../screens/splash/splash_screen.dart';
import '../screens/splash/splash_controller.dart';
import '../services/hive_json_storage_service.dart';
import '../services/mlkit_translation_service.dart';
import '../services/model_repository.dart';
import '../services/translation_repository.dart';

class AppBinding extends Bindings {
  AppBinding({required this.storageService});

  final HiveJsonStorageService storageService;

  @override
  void dependencies() {
    Get.put<HiveJsonStorageService>(storageService, permanent: true);
    Get.put<MlkitTranslationService>(
      MlkitTranslationService(),
      permanent: true,
    );

    Get.put<ModelRepository>(
      ModelRepository(
        storageService: Get.find<HiveJsonStorageService>(),
        mlkitTranslationService: Get.find<MlkitTranslationService>(),
      ),
      permanent: true,
    );

    Get.put<TranslationRepository>(
      TranslationRepository(
        mlkitTranslationService: Get.find<MlkitTranslationService>(),
        modelRepository: Get.find<ModelRepository>(),
      ),
      permanent: true,
    );
  }
}

final appPages = <GetPage<dynamic>>[
  GetPage<dynamic>(
    name: AppRoutes.splash,
    page: () => const SplashScreen(),
    binding: BindingsBuilder(() {
      Get.put<SplashController>(SplashController());
    }),
  ),
  GetPage<dynamic>(
    name: AppRoutes.home,
    page: () => const HomeScreen(),
    binding: BindingsBuilder(() {
      Get.put<HomeController>(
        HomeController(
          modelRepository: Get.find<ModelRepository>(),
          translationRepository: Get.find<TranslationRepository>(),
        ),
      );
    }),
  ),
  GetPage<dynamic>(
    name: AppRoutes.models,
    page: () => const ManageLanguageModelsScreen(),
    binding: BindingsBuilder(() {
      Get.put<ManageLanguageModelsController>(
        ManageLanguageModelsController(
          modelRepository: Get.find<ModelRepository>(),
        ),
      );
    }),
  ),
];

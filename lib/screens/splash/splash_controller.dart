import 'package:get/get.dart';

import '../../constants/app_constants.dart';
import '../../constants/app_routes.dart';

class SplashController extends GetxController {
  @override
  void onReady() {
    super.onReady();
    _openHome();
  }

  Future<void> _openHome() async {
    await Future<void>.delayed(AppConstants.splashDuration);
    if (!isClosed) {
      await Get.offNamed<void>(AppRoutes.home);
    }
  }
}

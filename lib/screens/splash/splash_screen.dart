import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../constants/app_constants.dart';
import 'splash_controller.dart';

class SplashScreen extends GetView<SplashController> {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Center(
        child: Text(AppConstants.appName, style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700)),
      ),
    );
  }
}

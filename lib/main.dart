import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'constants/app_constants.dart';
import 'constants/app_routes.dart';
import 'helpers/app_binding.dart';
import 'services/hive_json_storage_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final storageService = await HiveJsonStorageService.open();

  runApp(TranslatorApp(storageService: storageService));
}

class TranslatorApp extends StatelessWidget {
  const TranslatorApp({required this.storageService, super.key});

  final HiveJsonStorageService storageService;

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      debugShowCheckedModeBanner: false,
      title: AppConstants.appName,
      initialBinding: AppBinding(storageService: storageService),
      initialRoute: AppRoutes.splash,
      getPages: appPages,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2563EB)),
        scaffoldBackgroundColor: const Color(0xFFF8FAFC),
        useMaterial3: true,
      ),
    );
  }
}

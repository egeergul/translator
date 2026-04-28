import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../constants/app_constants.dart';
import 'home_controller.dart';
import 'realtime_speech.dart';
import 'speech.dart';
import 'text.dart';

class HomeScreen extends GetView<HomeController> {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const pages = [TextTranslationPage(), SpeechPage(), RealtimeSpeechPage()];

    return Obx(() {
      return Scaffold(
        appBar: AppBar(
          title: const Text(AppConstants.appName),
          actions: [
            IconButton(
              tooltip: 'Manage language models',
              onPressed: controller.openModelManagement,
              icon: const Icon(Icons.settings),
            ),
          ],
        ),
        body: IndexedStack(
          index: controller.selectedTabIndex.value,
          children: pages,
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: controller.selectedTabIndex.value,
          onDestinationSelected: controller.onTabSelected,
          destinations: const [
            NavigationDestination(icon: Icon(Icons.translate), label: 'Text'),
            NavigationDestination(icon: Icon(Icons.mic), label: 'Speech'),
            NavigationDestination(icon: Icon(Icons.hearing), label: 'Realtime'),
          ],
        ),
      );
    });
  }
}

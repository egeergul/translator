import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../constants/app_constants.dart';
import '../../utils/platform_guard.dart';
import '../../widgets/language_selector.dart';
import '../../widgets/translation_input.dart';
import '../../widgets/translation_output.dart';
import 'home_controller.dart';

class HomeScreen extends GetView<HomeController> {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(AppConstants.appName),
        actions: [IconButton(tooltip: 'Manage language models', onPressed: controller.openModelManagement, icon: const Icon(Icons.settings))],
      ),
      body: SafeArea(
        child: Obx(() {
          if (!PlatformGuard.isSupported) {
            return const _UnsupportedPlatformMessage();
          }

          if (controller.isLoadingLanguages.value) {
            return const Center(child: CircularProgressIndicator());
          }

          return LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                padding: AppConstants.pagePadding,
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TranslationInput(onChanged: controller.onSourceTextChanged, onSubmitted: controller.onSourceTextSubmitted),
                      const SizedBox(height: 16),
                      TranslationOutput(
                        text: controller.translatedText.value,
                        isLoading: controller.isTranslating.value,
                        statusMessage: controller.statusMessage.value,
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: LanguageSelector(
                              label: 'From',
                              languages: controller.languages,
                              value: controller.selectedSource.value,
                              onChanged: controller.onSourceLanguageChanged,
                            ),
                          ),
                          const Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Icon(Icons.arrow_forward)),
                          Expanded(
                            child: LanguageSelector(
                              label: 'To',
                              languages: controller.languages,
                              value: controller.selectedTarget.value,
                              onChanged: controller.onTargetLanguageChanged,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        }),
      ),
    );
  }
}

class _UnsupportedPlatformMessage extends StatelessWidget {
  const _UnsupportedPlatformMessage();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: AppConstants.pagePadding,
      child: Center(child: Text(PlatformGuard.unsupportedMessage, textAlign: TextAlign.center)),
    );
  }
}

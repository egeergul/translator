import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../constants/app_constants.dart';
import '../../utils/platform_guard.dart';
import '../../widgets/language_selector.dart';
import 'realtime_speech_controller.dart';

class RealtimeSpeechPage extends GetView<RealtimeSpeechController> {
  const RealtimeSpeechPage({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Obx(() {
        if (!PlatformGuard.isSupported) {
          return const _UnsupportedPlatformMessage();
        }

        if (controller.isLoadingLanguages.value) {
          return const Center(child: CircularProgressIndicator());
        }

        return const _RealtimeSpeechContent();
      }),
    );
  }
}

class _RealtimeSpeechContent extends GetView<RealtimeSpeechController> {
  const _RealtimeSpeechContent();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: AppConstants.pagePadding,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _RealtimeLanguageSelectors(),
                SizedBox(height: 24),
                _ReactiveRealtimeRecorderPanel(),
                SizedBox(height: 16),
                _RealtimeTranscriptionPanel(),
                SizedBox(height: 16),
                _RealtimeTranslationPanel(),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _RealtimeLanguageSelectors extends GetView<RealtimeSpeechController> {
  const _RealtimeLanguageSelectors();

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      true.obs.value;
      return LayoutBuilder(
        builder: (context, constraints) {
          final sourceSelector = LanguageSelector(
            label: 'Speech',
            languages: controller.supportedSourceLanguages,
            value: controller.selectedSource.value,
            onChanged: controller.onSourceLanguageChanged,
          );
          final targetSelector = LanguageSelector(
            label: 'To',
            languages: controller.languages,
            value: controller.selectedTarget.value,
            onChanged: controller.onTargetLanguageChanged,
          );

          if (constraints.maxWidth < 520) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                sourceSelector,
                const SizedBox(height: 12),
                const Center(child: Icon(Icons.arrow_downward)),
                const SizedBox(height: 12),
                targetSelector,
              ],
            );
          }

          return Row(
            children: [
              Expanded(child: sourceSelector),
              const Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Icon(Icons.arrow_forward)),
              Expanded(child: targetSelector),
            ],
          );
        },
      );
    });
  }
}

class _ReactiveRealtimeRecorderPanel extends GetView<RealtimeSpeechController> {
  const _ReactiveRealtimeRecorderPanel();

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      return _RealtimeRecorderPanel(
        isPreparing: controller.isPreparing.value,
        isListening: controller.isListening.value,
        statusMessage: controller.statusMessage.value,
        duration: controller.listeningDuration.value,
        onToggleListening: controller.toggleListening,
        onClear: controller.isBusy ? null : controller.clear,
      );
    });
  }
}

class _RealtimeTranscriptionPanel extends GetView<RealtimeSpeechController> {
  const _RealtimeTranscriptionPanel();

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      return _RealtimeResultPanel(
        title: 'Live transcription',
        text: controller.transcribedText.value,
        placeholder: 'Transcribed speech will appear here.',
        isLoading: controller.isListening.value,
      );
    });
  }
}

class _RealtimeTranslationPanel extends GetView<RealtimeSpeechController> {
  const _RealtimeTranslationPanel();

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      return _RealtimeResultPanel(
        title: 'Live translation',
        text: controller.translatedText.value,
        placeholder: controller.translationStatusMessage.value ?? 'Translated speech will appear here.',
        isLoading: controller.isTranslating.value,
      );
    });
  }
}

class _RealtimeRecorderPanel extends StatelessWidget {
  const _RealtimeRecorderPanel({
    required this.isPreparing,
    required this.isListening,
    required this.statusMessage,
    required this.duration,
    required this.onToggleListening,
    required this.onClear,
  });

  final bool isPreparing;
  final bool isListening;
  final String? statusMessage;
  final Duration duration;
  final VoidCallback onToggleListening;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final status = statusMessage;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isListening ? theme.colorScheme.errorContainer : theme.colorScheme.primaryContainer,
                ),
                child: Icon(
                  isListening ? Icons.graphic_eq : Icons.hearing,
                  color: isListening ? theme.colorScheme.onErrorContainer : theme.colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(isListening ? 'Listening' : 'Realtime speech', style: theme.textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text(_formatDuration(duration), style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                  ],
                ),
              ),
              IconButton(tooltip: 'Clear realtime speech', onPressed: onClear, icon: const Icon(Icons.clear)),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: isPreparing ? null : onToggleListening,
                icon: isPreparing
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : Icon(isListening ? Icons.stop : Icons.mic),
                label: Text(isListening ? 'Stop' : 'Listen'),
              ),
            ],
          ),
          if (status != null) ...[
            const SizedBox(height: 12),
            Text(status, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          ],
        ],
      ),
    );
  }

  static String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}

class _RealtimeResultPanel extends StatelessWidget {
  const _RealtimeResultPanel({required this.title, required this.text, required this.placeholder, required this.isLoading});

  final String title;
  final String text;
  final String placeholder;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasText = text.isNotEmpty;

    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 140),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(title, style: theme.textTheme.titleMedium)),
              if (isLoading) const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            hasText ? text : placeholder,
            style: theme.textTheme.bodyLarge?.copyWith(color: hasText ? theme.colorScheme.onSurface : theme.colorScheme.onSurfaceVariant),
          ),
        ],
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

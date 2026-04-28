import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../constants/app_constants.dart';
import '../../utils/platform_guard.dart';
import '../../widgets/language_selector.dart';
import 'speech_controller.dart';

class SpeechPage extends GetView<SpeechController> {
  const SpeechPage({super.key});

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

        return const _SpeechContent();
      }),
    );
  }
}

class _SpeechContent extends GetView<SpeechController> {
  const _SpeechContent();

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
                _SpeechLanguageSelectors(),
                SizedBox(height: 24),
                _ReactiveSpeechRecorderPanel(),
                SizedBox(height: 16),
                _TranscriptionResultPanel(),
                SizedBox(height: 16),
                _TranslationResultPanel(),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SpeechLanguageSelectors extends GetView<SpeechController> {
  const _SpeechLanguageSelectors();

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      return Row(
        children: [
          Expanded(
            child: LanguageSelector(
              label: 'Speech',
              languages: controller.languages,
              value: controller.selectedSource.value,
              onChanged: controller.onSourceLanguageChanged,
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 12),
            child: Icon(Icons.arrow_forward),
          ),
          Expanded(
            child: LanguageSelector(
              label: 'To',
              languages: controller.languages,
              value: controller.selectedTarget.value,
              onChanged: controller.onTargetLanguageChanged,
            ),
          ),
        ],
      );
    });
  }
}

class _ReactiveSpeechRecorderPanel extends GetView<SpeechController> {
  const _ReactiveSpeechRecorderPanel();

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      return _SpeechRecorderPanel(
        isRecording: controller.isRecording.value,
        isTranscribing: controller.isTranscribing.value,
        statusMessage: controller.statusMessage.value,
        duration: controller.recordingDuration.value,
        onToggleRecording: controller.toggleRecording,
        onClear: controller.isBusy ? null : controller.clear,
      );
    });
  }
}

class _TranscriptionResultPanel extends GetView<SpeechController> {
  const _TranscriptionResultPanel();

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      return _SpeechResultPanel(
        title: 'Transcription',
        text: controller.transcribedText.value,
        placeholder: 'Transcribed speech will appear here.',
        isLoading: controller.isTranscribing.value,
      );
    });
  }
}

class _TranslationResultPanel extends GetView<SpeechController> {
  const _TranslationResultPanel();

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      return _SpeechResultPanel(
        title: 'Translation',
        text: controller.translatedText.value,
        placeholder: 'Translated speech will appear here.',
        isLoading: controller.isTranslating.value,
      );
    });
  }
}

class _SpeechRecorderPanel extends StatelessWidget {
  const _SpeechRecorderPanel({
    required this.isRecording,
    required this.isTranscribing,
    required this.statusMessage,
    required this.duration,
    required this.onToggleRecording,
    required this.onClear,
  });

  final bool isRecording;
  final bool isTranscribing;
  final String? statusMessage;
  final Duration duration;
  final VoidCallback onToggleRecording;
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
                  color: isRecording
                      ? theme.colorScheme.errorContainer
                      : theme.colorScheme.primaryContainer,
                ),
                child: Icon(
                  isRecording ? Icons.mic : Icons.mic_none,
                  color: isRecording
                      ? theme.colorScheme.onErrorContainer
                      : theme.colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isRecording ? 'Recording' : 'Speech capture',
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatDuration(duration),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Clear speech',
                onPressed: onClear,
                icon: const Icon(Icons.clear),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: isTranscribing ? null : onToggleRecording,
                icon: Icon(isRecording ? Icons.stop : Icons.mic),
                label: Text(isRecording ? 'Stop' : 'Record'),
              ),
            ],
          ),
          if (status != null) ...[
            const SizedBox(height: 12),
            Text(
              status,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
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

class _SpeechResultPanel extends StatelessWidget {
  const _SpeechResultPanel({
    required this.title,
    required this.text,
    required this.placeholder,
    required this.isLoading,
  });

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
              Text(title, style: theme.textTheme.titleMedium),
              const Spacer(),
              if (isLoading)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            hasText ? text : placeholder,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: hasText
                  ? theme.colorScheme.onSurface
                  : theme.colorScheme.onSurfaceVariant,
            ),
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
      child: Center(
        child: Text(
          PlatformGuard.unsupportedMessage,
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

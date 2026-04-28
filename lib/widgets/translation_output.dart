import 'package:flutter/material.dart';

class TranslationOutput extends StatelessWidget {
  const TranslationOutput({
    required this.text,
    required this.isLoading,
    required this.statusMessage,
    super.key,
  });

  final String text;
  final bool isLoading;
  final String? statusMessage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final displayText = text.isNotEmpty
        ? text
        : statusMessage ?? 'Translation will appear here.';

    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 150),
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
              Text('Translation', style: theme.textTheme.titleMedium),
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
            displayText,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: text.isNotEmpty
                  ? theme.colorScheme.onSurface
                  : theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

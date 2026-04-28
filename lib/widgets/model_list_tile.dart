import 'package:flutter/material.dart';

import '../helpers/language_helper.dart';

class ModelListTile extends StatelessWidget {
  const ModelListTile({
    required this.language,
    required this.isBusy,
    required this.onDownload,
    required this.onDelete,
    super.key,
  });

  final LanguageOption language;
  final bool isBusy;
  final VoidCallback onDownload;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final action = language.isDownloaded
        ? IconButton.filledTonal(
            tooltip: 'Delete model',
            onPressed: isBusy ? null : onDelete,
            icon: const Icon(Icons.delete_outline),
          )
        : FilledButton.icon(
            onPressed: isBusy ? null : onDownload,
            icon: isBusy
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.download),
            label: const Text('Download'),
          );

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: ListTile(
        title: Text(language.name),
        subtitle: Text(language.bcpCode),
        leading: CircleAvatar(
          backgroundColor: language.isDownloaded
              ? theme.colorScheme.primaryContainer
              : theme.colorScheme.surfaceContainerHighest,
          foregroundColor: language.isDownloaded
              ? theme.colorScheme.onPrimaryContainer
              : theme.colorScheme.onSurfaceVariant,
          child: Icon(
            language.isDownloaded ? Icons.offline_pin : Icons.cloud_download,
          ),
        ),
        trailing: action,
      ),
    );
  }
}

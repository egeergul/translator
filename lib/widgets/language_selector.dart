import 'package:flutter/material.dart';

import '../helpers/language_helper.dart';

class LanguageSelector extends StatelessWidget {
  const LanguageSelector({
    required this.label,
    required this.languages,
    required this.value,
    required this.onChanged,
    super.key,
  });

  final String label;
  final List<LanguageOption> languages;
  final LanguageOption? value;
  final ValueChanged<LanguageOption?> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<LanguageOption>(
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      items: languages
          .map((language) {
            return DropdownMenuItem<LanguageOption>(
              value: language,
              child: Row(
                children: [
                  Expanded(
                    child: Text(language.name, overflow: TextOverflow.ellipsis),
                  ),
                  if (language.isDownloaded) ...[
                    const SizedBox(width: 8),
                    const Icon(Icons.offline_pin, size: 18),
                  ],
                ],
              ),
            );
          })
          .toList(growable: false),
      onChanged: onChanged,
    );
  }
}

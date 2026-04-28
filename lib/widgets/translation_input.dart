import 'package:flutter/material.dart';

class TranslationInput extends StatelessWidget {
  const TranslationInput({
    required this.onChanged,
    required this.onSubmitted,
    super.key,
  });

  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;

  @override
  Widget build(BuildContext context) {
    return TextField(
      minLines: 5,
      maxLines: 8,
      keyboardType: TextInputType.text,
      textInputAction: TextInputAction.done,
      decoration: const InputDecoration(
        labelText: 'Text to translate',
        alignLabelWithHint: true,
        border: OutlineInputBorder(),
      ),
      onChanged: onChanged,
      onSubmitted: onSubmitted,
    );
  }
}

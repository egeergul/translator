import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../constants/app_constants.dart';
import '../../utils/platform_guard.dart';
import '../../widgets/model_list_tile.dart';
import 'manage_language_models_controller.dart';

class ManageLanguageModelsScreen
    extends GetView<ManageLanguageModelsController> {
  const ManageLanguageModelsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Language Models')),
      body: SafeArea(
        child: Obx(() {
          if (!PlatformGuard.isSupported) {
            return const _UnsupportedPlatformMessage();
          }

          if (controller.isLoading.value) {
            return const Center(child: CircularProgressIndicator());
          }

          final error = controller.errorMessage.value;
          if (error != null) {
            return _ErrorState(
              message: error,
              onRetry: controller.refreshLanguages,
            );
          }

          final filteredLanguages = controller.filteredLanguages;

          return RefreshIndicator(
            onRefresh: controller.refreshLanguages,
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: AppConstants.pagePadding,
                    child: _Header(downloadedCount: controller.downloadedCount),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                    child: _LanguageSearchField(
                      controller: controller.searchTextController,
                      hasQuery: controller.searchQuery.value.trim().isNotEmpty,
                      onChanged: controller.onSearchChanged,
                      onClear: controller.clearSearch,
                    ),
                  ),
                ),
                if (filteredLanguages.isEmpty)
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: _EmptySearchState(),
                  )
                else
                  SliverList.builder(
                    itemCount: filteredLanguages.length,
                    itemBuilder: (context, index) {
                      final language = filteredLanguages[index];
                      final activeCode = controller.activeLanguageCode.value;
                      return ModelListTile(
                        language: language,
                        isBusy: activeCode == language.bcpCode,
                        onDownload: () => controller.download(language),
                        onDelete: () => controller.delete(language),
                      );
                    },
                  ),
                const SliverToBoxAdapter(child: SizedBox(height: 24)),
              ],
            ),
          );
        }),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.downloadedCount});

  final int downloadedCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$downloadedCount downloaded',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Download source and target language models once, then translate fully offline.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _LanguageSearchField extends StatelessWidget {
  const _LanguageSearchField({
    required this.controller,
    required this.hasQuery,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final bool hasQuery;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: 'Search languages',
        prefixIcon: const Icon(Icons.search),
        suffixIcon: hasQuery
            ? IconButton(
                tooltip: 'Clear search',
                onPressed: onClear,
                icon: const Icon(Icons.close),
              )
            : null,
        border: const OutlineInputBorder(),
      ),
      onChanged: onChanged,
    );
  }
}

class _EmptySearchState extends StatelessWidget {
  const _EmptySearchState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: AppConstants.pagePadding,
        child: Text(
          'No language models match your search.',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: AppConstants.pagePadding,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
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

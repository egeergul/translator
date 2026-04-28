import 'package:google_mlkit_translation/google_mlkit_translation.dart';

import '../constants/storage_keys.dart';
import '../helpers/language_helper.dart';
import '../utils/app_exception.dart';
import '../utils/json_utils.dart';
import '../utils/platform_guard.dart';
import 'hive_json_storage_service.dart';
import 'mlkit_translation_service.dart';

class DownloadedModelRecord {
  const DownloadedModelRecord({required this.bcpCode, required this.name, required this.downloadedAtIso8601});

  final String bcpCode;
  final String name;
  final String downloadedAtIso8601;

  factory DownloadedModelRecord.fromJson(Map<String, dynamic> json) {
    return DownloadedModelRecord(
      bcpCode: json['bcpCode'] as String? ?? '',
      name: json['name'] as String? ?? '',
      downloadedAtIso8601: json['downloadedAtIso8601'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{'bcpCode': bcpCode, 'name': name, 'downloadedAtIso8601': downloadedAtIso8601};
  }
}

class ModelRepository {
  const ModelRepository({required HiveJsonStorageService storageService, required MlkitTranslationService mlkitTranslationService})
    : _storageService = storageService,
      _mlkitTranslationService = mlkitTranslationService;

  final HiveJsonStorageService _storageService;
  final MlkitTranslationService _mlkitTranslationService;

  Future<List<LanguageOption>> getLanguageOptions() async {
    final downloadedCodes = await getDownloadedCodes();
    return LanguageHelper.buildOptions(languages: _mlkitTranslationService.supportedLanguages, downloadedCodes: downloadedCodes);
  }

  Future<List<DownloadedModelRecord>> getDownloadedRecords() async {
    final encoded = _storageService.readString(StorageKeys.downloadedModels);
    return JsonUtils.decodeObjectList(
      encoded,
    ).map(DownloadedModelRecord.fromJson).where((record) => record.bcpCode.isNotEmpty).toList(growable: false);
  }

  Future<Set<String>> getDownloadedCodes() async {
    final records = await getDownloadedRecords();
    return records.map((record) => record.bcpCode).toSet();
  }

  Future<bool> hasCompletedInitialModelDownload() async {
    final state = JsonUtils.decodeObject(_storageService.readString(StorageKeys.appState));
    final hasCompleted = state[StorageKeys.hasCompletedInitialModelDownload] as bool? ?? false;

    if (hasCompleted) {
      return true;
    }

    return (await getDownloadedRecords()).isNotEmpty;
  }

  Future<bool> isPersistedAsDownloaded(TranslateLanguage language) async {
    final downloadedCodes = await getDownloadedCodes();
    return downloadedCodes.contains(language.bcpCode);
  }

  Future<bool> isReadyForOfflineUse(TranslateLanguage language) async {
    final isPersisted = await isPersistedAsDownloaded(language);
    if (!isPersisted || !PlatformGuard.isSupported) {
      return false;
    }

    return _mlkitTranslationService.isModelDownloaded(language);
  }

  Future<void> downloadModel(TranslateLanguage language) async {
    final isAlreadyDownloaded = await _mlkitTranslationService.isModelDownloaded(language);

    if (!isAlreadyDownloaded) {
      final wasDownloaded = await _mlkitTranslationService.downloadModel(language);

      if (!wasDownloaded) {
        throw const AppException('The model download did not complete.');
      }
    }

    final verified = await _mlkitTranslationService.isModelDownloaded(language);
    if (!verified) {
      throw const AppException('The downloaded model could not be verified.');
    }

    final records = await getDownloadedRecords();
    final nextRecords = <DownloadedModelRecord>[
      for (final record in records)
        if (record.bcpCode != language.bcpCode) record,
      DownloadedModelRecord(
        bcpCode: language.bcpCode,
        name: LanguageHelper.displayName(language),
        downloadedAtIso8601: DateTime.now().toUtc().toIso8601String(),
      ),
    ]..sort((left, right) => left.name.compareTo(right.name));

    await _writeDownloadedRecords(nextRecords);
    await _markInitialDownloadComplete();
  }

  Future<void> deleteModel(TranslateLanguage language) async {
    final wasDeleted = await _mlkitTranslationService.deleteModel(language);
    if (!wasDeleted) {
      throw const AppException('The model could not be deleted.');
    }

    final stillDownloaded = await _mlkitTranslationService.isModelDownloaded(language);
    if (stillDownloaded) {
      throw const AppException('The model is still present on this device and was not removed.');
    }

    final records = await getDownloadedRecords();
    final nextRecords = records.where((record) => record.bcpCode != language.bcpCode).toList(growable: false);
    await _writeDownloadedRecords(nextRecords);
  }

  Future<void> _writeDownloadedRecords(List<DownloadedModelRecord> records) async {
    await _storageService.writeString(StorageKeys.downloadedModels, JsonUtils.encode(records.map((record) => record.toJson()).toList()));
  }

  Future<void> _markInitialDownloadComplete() async {
    final state = JsonUtils.decodeObject(_storageService.readString(StorageKeys.appState));
    state[StorageKeys.hasCompletedInitialModelDownload] = true;
    await _storageService.writeString(StorageKeys.appState, JsonUtils.encode(state));
  }
}

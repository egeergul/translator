import 'dart:async';
import 'dart:developer';
import 'dart:io';
import 'dart:typed_data';

import 'package:collection/collection.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;

import '../../helpers/language_helper.dart';
import '../../services/translation_repository.dart';
import '../../utils/app_exception.dart';
import '../../utils/platform_guard.dart';
import 'home_controller.dart';

class RealtimeSpeechController extends GetxController {
  RealtimeSpeechController({required HomeController homeController, required TranslationRepository translationRepository})
    : _homeController = homeController,
      _translationRepository = translationRepository;

  static const _sampleRate = 16000;
  static const _modelDirectoryName = 'sherpa-onnx-streaming-zipformer-small-bilingual-zh-en-2023-02-16';
  static const _assetModelDirectory = 'assets/models/$_modelDirectoryName';
  static const _modelAssetMissingMessage = 'Zipformer small model assets are missing.';

  final HomeController _homeController;
  final TranslationRepository _translationRepository;
  final AudioRecorder _recorder = AudioRecorder();

  final supportedSourceLanguages = <LanguageOption>[].obs;
  final selectedSource = Rxn<LanguageOption>();
  final transcribedText = ''.obs;
  final translatedText = ''.obs;
  final statusMessage = RxnString();
  final translationStatusMessage = RxnString();
  final isPreparing = false.obs;
  final isListening = false.obs;
  final isTranslating = false.obs;
  final listeningDuration = Duration.zero.obs;

  Timer? _durationTimer;
  Timer? _translationDebounce;
  StreamSubscription<Uint8List>? _audioSubscription;
  sherpa.OnlineRecognizer? _recognizer;
  sherpa.OnlineStream? _stream;
  Worker? _languagesWorker;
  bool _bindingsInitialized = false;
  String _finalTranscript = '';
  String _lastDisplayedTranscript = '';
  int _translationRequestId = 0;

  RxList<LanguageOption> get languages => _homeController.languages;
  Rxn<LanguageOption> get selectedTarget => _homeController.selectedTarget;
  RxBool get isLoadingLanguages => _homeController.isLoadingLanguages;

  bool get isBusy => isPreparing.value || isListening.value;

  @override
  void onInit() {
    super.onInit();
    _syncSupportedSourceLanguages();
    _languagesWorker = ever<List<LanguageOption>>(_homeController.languages, (_) => _syncSupportedSourceLanguages());
  }

  Future<void> toggleListening() async {
    if (isListening.value) {
      await stopListening();
      return;
    }

    await startListening();
  }

  Future<void> startListening() async {
    if (isBusy) {
      return;
    }

    statusMessage.value = null;
    translationStatusMessage.value = null;

    if (!PlatformGuard.isSupported) {
      statusMessage.value = PlatformGuard.unsupportedMessage;
      return;
    }

    if (selectedSource.value == null) {
      statusMessage.value = 'Select a speech language.';
      return;
    }

    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) {
      statusMessage.value = 'Microphone permission is required.';
      return;
    }

    final supportsPcm = await _recorder.isEncoderSupported(AudioEncoder.pcm16bits);
    if (!supportsPcm) {
      statusMessage.value = 'Realtime PCM recording is not supported.';
      return;
    }

    isPreparing.value = true;
    statusMessage.value = 'Preparing Zipformer model...';

    try {
      final recognizer = await _getRecognizer();
      _resetStream(recognizer);
      _clearTranscriptState();
      listeningDuration.value = Duration.zero;

      final audioStream = await _recorder.startStream(const RecordConfig(encoder: AudioEncoder.pcm16bits, sampleRate: _sampleRate, numChannels: 1));

      _audioSubscription = audioStream.listen(_onAudioData, onError: (_) => _handleAudioStreamError());

      isListening.value = true;
      statusMessage.value = 'Listening...';
      _startDurationTimer();
    } on AppException catch (error) {
      statusMessage.value = error.message;
      await _stopRecorderAfterFailedStart();
    } catch (e) {
      statusMessage.value = 'Realtime speech could not be started.';
      debugPrint('Error starting realtime speech: $e');
      await _stopRecorderAfterFailedStart();
    } finally {
      isPreparing.value = false;
    }
  }

  Future<void> stopListening() async {
    if (!isListening.value) {
      return;
    }

    _stopDurationTimer();
    statusMessage.value = 'Stopping...';

    try {
      await _recorder.stop();
    } catch (_) {
      statusMessage.value = 'Realtime recording could not be stopped.';
    }

    await _audioSubscription?.cancel();
    _audioSubscription = null;

    _finalizeOpenStream();
    _freeStream();

    isListening.value = false;
    statusMessage.value = transcribedText.value.trim().isEmpty ? 'No speech was detected.' : null;
    _scheduleTranslation(Duration.zero);
  }

  void clear() {
    if (isBusy) {
      return;
    }

    _translationDebounce?.cancel();
    _clearTranscriptState();
    listeningDuration.value = Duration.zero;
    statusMessage.value = null;
    translationStatusMessage.value = null;
    isTranslating.value = false;
  }

  void onSourceLanguageChanged(LanguageOption? language) {
    selectedSource.value = language;
    _scheduleTranslation(Duration.zero);
  }

  void onTargetLanguageChanged(LanguageOption? language) {
    _homeController.onTargetLanguageChanged(language);
    _scheduleTranslation(Duration.zero);
  }

  Future<void> translateCurrentTranscription() async {
    final requestId = ++_translationRequestId;
    final text = transcribedText.value;
    final source = selectedSource.value;
    final target = selectedTarget.value;

    if (text.trim().isEmpty) {
      translatedText.value = '';
      translationStatusMessage.value = null;
      isTranslating.value = false;
      return;
    }

    if (!PlatformGuard.isSupported) {
      translatedText.value = '';
      translationStatusMessage.value = PlatformGuard.unsupportedMessage;
      isTranslating.value = false;
      return;
    }

    if (source == null || target == null) {
      translatedText.value = '';
      translationStatusMessage.value = 'Select source and target languages.';
      isTranslating.value = false;
      return;
    }

    if (source.language == target.language) {
      translatedText.value = text;
      translationStatusMessage.value = null;
      isTranslating.value = false;
      return;
    }

    isTranslating.value = true;
    try {
      final translation = await _translationRepository.translate(text: text, sourceLanguage: source.language, targetLanguage: target.language);

      if (requestId == _translationRequestId) {
        translatedText.value = translation;
        translationStatusMessage.value = null;
      }
    } on AppException catch (error) {
      if (requestId == _translationRequestId) {
        translatedText.value = '';
        translationStatusMessage.value = error.message;
      }
    } catch (_) {
      if (requestId == _translationRequestId) {
        translatedText.value = '';
        translationStatusMessage.value = 'Realtime translation failed.';
      }
    } finally {
      if (requestId == _translationRequestId) {
        isTranslating.value = false;
      }
    }
  }

  void _onAudioData(Uint8List bytes) {
    final recognizer = _recognizer;
    final stream = _stream;

    if (!isListening.value || recognizer == null || stream == null) {
      return;
    }

    final samples = _pcm16BytesToFloat32(bytes);
    if (samples.isEmpty) {
      return;
    }

    stream.acceptWaveform(samples: samples, sampleRate: _sampleRate);

    while (recognizer.isReady(stream)) {
      recognizer.decode(stream);
    }

    final partial = recognizer.getResult(stream).text.trim();
    _publishTranscript(partial);

    if (recognizer.isEndpoint(stream)) {
      if (partial.isNotEmpty) {
        _finalTranscript = _joinTranscript(_finalTranscript, partial);
      }
      recognizer.reset(stream);
      _publishTranscript('');
    }
  }

  Future<sherpa.OnlineRecognizer> _getRecognizer() async {
    final cached = _recognizer;
    if (cached != null) {
      return cached;
    }

    if (!_bindingsInitialized) {
      sherpa.initBindings();
      _bindingsInitialized = true;
    }

    final encoder = await _copyModelAsset('encoder-epoch-99-avg-1.int8.onnx');
    final decoder = await _copyModelAsset('decoder-epoch-99-avg-1.onnx');
    final joiner = await _copyModelAsset('joiner-epoch-99-avg-1.int8.onnx');
    final tokens = await _copyModelAsset('tokens.txt');

    final modelConfig = sherpa.OnlineModelConfig(
      transducer: sherpa.OnlineTransducerModelConfig(encoder: encoder, decoder: decoder, joiner: joiner),
      tokens: tokens,
      numThreads: 1,
      debug: false,
    );

    final recognizer = sherpa.OnlineRecognizer(sherpa.OnlineRecognizerConfig(model: modelConfig));
    _recognizer = recognizer;
    return recognizer;
  }

  Future<String> _copyModelAsset(String fileName) async {
    final source = '$_assetModelDirectory/$fileName';
    final supportDirectory = await getApplicationSupportDirectory();
    final modelDirectory = Directory('${supportDirectory.path}/sherpa_onnx/$_modelDirectoryName');
    await modelDirectory.create(recursive: true);

    final target = File('${modelDirectory.path}/$fileName');

    final ByteData data;
    try {
      data = await rootBundle.load(source);
    } catch (_) {
      throw const AppException(_modelAssetMissingMessage);
    }

    if (target.existsSync() && target.lengthSync() == data.lengthInBytes) {
      return target.path;
    }

    final bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    await target.writeAsBytes(bytes, flush: true);
    return target.path;
  }

  void _resetStream(sherpa.OnlineRecognizer recognizer) {
    _freeStream();
    _stream = recognizer.createStream();
  }

  void _freeStream() {
    _stream?.free();
    _stream = null;
  }

  void _finalizeOpenStream() {
    final recognizer = _recognizer;
    final stream = _stream;
    if (recognizer == null || stream == null) {
      return;
    }

    stream.inputFinished();
    while (recognizer.isReady(stream)) {
      recognizer.decode(stream);
    }

    final finalPartial = recognizer.getResult(stream).text.trim();
    if (finalPartial.isNotEmpty) {
      _finalTranscript = _joinTranscript(_finalTranscript, finalPartial);
      _publishTranscript('');
    }
  }

  void _publishTranscript(String partial) {
    final nextTranscript = _joinTranscript(_finalTranscript, partial);
    if (nextTranscript == _lastDisplayedTranscript) {
      return;
    }

    _lastDisplayedTranscript = nextTranscript;
    transcribedText.value = nextTranscript;
    _scheduleTranslation();
  }

  void _scheduleTranslation([Duration delay = const Duration(milliseconds: 350)]) {
    _translationDebounce?.cancel();
    _translationDebounce = Timer(delay, () {
      unawaited(translateCurrentTranscription());
    });
  }

  void _syncSupportedSourceLanguages() {
    final supported = _homeController.languages.where((option) => _isSupportedSourceCode(option.bcpCode)).toList(growable: false);

    supportedSourceLanguages.assignAll(supported);

    selectedSource.value =
        LanguageHelper.equivalentOption(supported, selectedSource.value) ??
        LanguageHelper.findByCode(supported, 'en') ??
        supported.firstWhereOrNull((option) => option.bcpCode.startsWith('zh')) ??
        supported.firstOrNull;
  }

  bool _isSupportedSourceCode(String bcpCode) {
    final normalizedCode = bcpCode.toLowerCase();
    return normalizedCode == 'en' || normalizedCode.startsWith('zh');
  }

  String _joinTranscript(String left, String right) {
    if (left.isEmpty) {
      return right;
    }

    if (right.isEmpty) {
      return left;
    }

    if (_needsWordSeparator(left, right)) {
      return '$left $right';
    }

    return '$left$right';
  }

  bool _needsWordSeparator(String left, String right) {
    final leftUnit = left.codeUnitAt(left.length - 1);
    final rightUnit = right.codeUnitAt(0);
    return _isAsciiLetterOrDigit(leftUnit) && _isAsciiLetterOrDigit(rightUnit);
  }

  bool _isAsciiLetterOrDigit(int codeUnit) {
    return (codeUnit >= 48 && codeUnit <= 57) || (codeUnit >= 65 && codeUnit <= 90) || (codeUnit >= 97 && codeUnit <= 122);
  }

  Float32List _pcm16BytesToFloat32(Uint8List bytes) {
    final samples = Float32List(bytes.length ~/ 2);
    final byteData = ByteData.sublistView(bytes);

    for (var i = 0; i < samples.length; i += 1) {
      samples[i] = byteData.getInt16(i * 2, Endian.little) / 32768.0;
    }

    return samples;
  }

  void _clearTranscriptState() {
    _finalTranscript = '';
    _lastDisplayedTranscript = '';
    transcribedText.value = '';
    translatedText.value = '';
  }

  void _startDurationTimer() {
    _stopDurationTimer();
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      listeningDuration.value += const Duration(seconds: 1);
    });
  }

  void _stopDurationTimer() {
    _durationTimer?.cancel();
    _durationTimer = null;
  }

  void _handleAudioStreamError() {
    if (!isListening.value) {
      return;
    }

    statusMessage.value = 'Microphone stream stopped unexpectedly.';
    unawaited(stopListening());
  }

  Future<void> _stopRecorderAfterFailedStart() async {
    try {
      if (await _recorder.isRecording()) {
        await _recorder.cancel();
      }
    } catch (_) {
      // Best-effort cleanup after a failed stream start.
    }
    await _audioSubscription?.cancel();
    _audioSubscription = null;
    _freeStream();
    _stopDurationTimer();
    isListening.value = false;
  }

  @override
  void onClose() {
    _languagesWorker?.dispose();
    _stopDurationTimer();
    _translationDebounce?.cancel();
    unawaited(_disposeAudio());
    _freeStream();
    _recognizer?.free();
    _recognizer = null;
    super.onClose();
  }

  Future<void> _disposeAudio() async {
    await _audioSubscription?.cancel();
    _audioSubscription = null;

    if (await _recorder.isRecording()) {
      await _recorder.cancel();
    }

    await _recorder.dispose();
  }
}

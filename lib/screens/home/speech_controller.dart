import 'dart:async';
import 'dart:io';

import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:whisper_flutter_new/whisper_flutter_new.dart';

import '../../helpers/language_helper.dart';
import '../../services/translation_repository.dart';
import '../../utils/app_exception.dart';
import '../../utils/platform_guard.dart';
import 'home_controller.dart';

class SpeechController extends GetxController {
  SpeechController({required HomeController homeController, required TranslationRepository translationRepository})
    : _homeController = homeController,
      _translationRepository = translationRepository;

  static const _model = WhisperModel.base;
  static const _downloadHost = 'https://huggingface.co/ggerganov/whisper.cpp/resolve/main';

  final HomeController _homeController;
  final TranslationRepository _translationRepository;
  final AudioRecorder _recorder = AudioRecorder();

  final transcribedText = ''.obs;
  final translatedText = ''.obs;
  final statusMessage = RxnString();
  final isRecording = false.obs;
  final isTranscribing = false.obs;
  final isTranslating = false.obs;
  final recordingDuration = Duration.zero.obs;

  Timer? _recordingTimer;
  Whisper? _whisper;
  int _translationRequestId = 0;
  int _transcriptionRequestId = 0;

  RxList<LanguageOption> get languages => _homeController.languages;
  Rxn<LanguageOption> get selectedSource => _homeController.selectedSource;
  Rxn<LanguageOption> get selectedTarget => _homeController.selectedTarget;
  RxBool get isLoadingLanguages => _homeController.isLoadingLanguages;

  bool get isBusy => isRecording.value || isTranscribing.value || isTranslating.value;

  Future<void> toggleRecording() async {
    if (isRecording.value) {
      await stopRecording();
      return;
    }

    await startRecording();
  }

  Future<void> startRecording() async {
    if (isTranscribing.value || isTranslating.value) {
      return;
    }

    statusMessage.value = null;

    if (!PlatformGuard.isSupported) {
      statusMessage.value = PlatformGuard.unsupportedMessage;
      return;
    }

    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) {
      statusMessage.value = 'Microphone permission is required.';
      return;
    }

    final supportsWav = await _recorder.isEncoderSupported(AudioEncoder.wav);
    if (!supportsWav) {
      statusMessage.value = 'WAV recording is not supported on this device.';
      return;
    }

    final tempDirectory = await getTemporaryDirectory();
    final audioPath = '${tempDirectory.path}/speech_${DateTime.now().millisecondsSinceEpoch}.wav';

    transcribedText.value = '';
    translatedText.value = '';
    recordingDuration.value = Duration.zero;

    try {
      await _recorder.start(const RecordConfig(encoder: AudioEncoder.wav, sampleRate: 16000, numChannels: 1), path: audioPath);

      isRecording.value = true;
      statusMessage.value = 'Recording...';
      _startRecordingTimer();
    } catch (_) {
      statusMessage.value = 'Recording could not be started.';
    }
  }

  Future<void> stopRecording() async {
    if (!isRecording.value) {
      return;
    }

    _stopRecordingTimer();

    try {
      final audioPath = await _recorder.stop();
      isRecording.value = false;

      if (audioPath == null || audioPath.isEmpty) {
        statusMessage.value = 'Recording could not be saved.';
        return;
      }

      await _transcribeAudio(audioPath);
    } catch (_) {
      isRecording.value = false;
      statusMessage.value = 'Recording could not be stopped.';
    }
  }

  void clear() {
    if (isBusy) {
      return;
    }

    transcribedText.value = '';
    translatedText.value = '';
    statusMessage.value = null;
    recordingDuration.value = Duration.zero;
  }

  void onSourceLanguageChanged(LanguageOption? language) {
    _homeController.onSourceLanguageChanged(language);
    translateCurrentTranscription();
  }

  void onTargetLanguageChanged(LanguageOption? language) {
    _homeController.onTargetLanguageChanged(language);
    translateCurrentTranscription();
  }

  Future<void> translateCurrentTranscription() async {
    final requestId = ++_translationRequestId;
    final text = transcribedText.value;
    final source = selectedSource.value;
    final target = selectedTarget.value;

    if (text.trim().isEmpty) {
      translatedText.value = '';
      isTranslating.value = false;
      return;
    }

    if (!PlatformGuard.isSupported) {
      translatedText.value = '';
      statusMessage.value = PlatformGuard.unsupportedMessage;
      isTranslating.value = false;
      return;
    }

    if (source == null || target == null) {
      translatedText.value = '';
      statusMessage.value = 'Select source and target languages.';
      isTranslating.value = false;
      return;
    }

    if (source.language == target.language) {
      translatedText.value = text;
      isTranslating.value = false;
      return;
    }

    isTranslating.value = true;
    try {
      final translation = await _translationRepository.translate(text: text, sourceLanguage: source.language, targetLanguage: target.language);

      if (requestId == _translationRequestId) {
        translatedText.value = translation;
        statusMessage.value = null;
      }
    } on AppException catch (error) {
      if (requestId == _translationRequestId) {
        translatedText.value = '';
        statusMessage.value = error.message;
      }
    } catch (_) {
      if (requestId == _translationRequestId) {
        translatedText.value = '';
        statusMessage.value = 'Speech translation failed. Try again.';
      }
    } finally {
      if (requestId == _translationRequestId) {
        isTranslating.value = false;
      }
    }
  }

  Future<void> _transcribeAudio(String audioPath) async {
    final requestId = ++_transcriptionRequestId;
    final sourceLanguageCode = selectedSource.value?.bcpCode ?? 'auto';

    isTranscribing.value = true;
    statusMessage.value = 'Transcribing speech locally...';

    try {
      final whisper = await _getWhisper();
      final response = await whisper.transcribe(
        transcribeRequest: TranscribeRequest(audio: audioPath, language: sourceLanguageCode, isNoTimestamps: true, splitOnWord: false),
      );

      if (requestId != _transcriptionRequestId) {
        return;
      }

      final transcription = response.text.trim();
      if (transcription.isEmpty) {
        transcribedText.value = '';
        translatedText.value = '';
        statusMessage.value = 'No speech was detected.';
        return;
      }

      transcribedText.value = transcription;
      statusMessage.value = null;
      await translateCurrentTranscription();
    } catch (_) {
      if (requestId == _transcriptionRequestId) {
        transcribedText.value = '';
        translatedText.value = '';
        statusMessage.value = 'Speech could not be transcribed.';
      }
    } finally {
      if (requestId == _transcriptionRequestId) {
        isTranscribing.value = false;
      }
    }
  }

  Future<Whisper> _getWhisper() async {
    final cached = _whisper;
    if (cached != null) {
      return cached;
    }

    final supportDirectory = await getApplicationSupportDirectory();
    final modelDirectory = Directory('${supportDirectory.path}/whisper_models');
    await modelDirectory.create(recursive: true);

    if (!File(_model.getPath(modelDirectory.path)).existsSync()) {
      statusMessage.value = 'Preparing speech model...';
    }

    final whisper = Whisper(model: _model, modelDir: modelDirectory.path, downloadHost: _downloadHost);
    _whisper = whisper;
    return whisper;
  }

  void _startRecordingTimer() {
    _stopRecordingTimer();
    _recordingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      recordingDuration.value += const Duration(seconds: 1);
    });
  }

  void _stopRecordingTimer() {
    _recordingTimer?.cancel();
    _recordingTimer = null;
  }

  @override
  void onClose() {
    _stopRecordingTimer();
    unawaited(_disposeRecorder());
    super.onClose();
  }

  Future<void> _disposeRecorder() async {
    if (await _recorder.isRecording()) {
      await _recorder.cancel();
    }
    await _recorder.dispose();
  }
}

import 'dart:io';

import 'package:flutter/foundation.dart';

class PlatformGuard {
  const PlatformGuard._();

  static bool get isSupported {
    if (kIsWeb) {
      return false;
    }

    return Platform.isAndroid || Platform.isIOS;
  }

  static const unsupportedMessage =
      'Offline translation and transcription are available on Android and iOS devices only.';
}

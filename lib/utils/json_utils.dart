import 'dart:convert';

class JsonUtils {
  const JsonUtils._();

  static Map<String, dynamic> decodeObject(String? source) {
    if (source == null || source.trim().isEmpty) {
      return <String, dynamic>{};
    }

    try {
      final decoded = jsonDecode(source);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
    } on FormatException {
      return <String, dynamic>{};
    } on TypeError {
      return <String, dynamic>{};
    }

    return <String, dynamic>{};
  }

  static List<Map<String, dynamic>> decodeObjectList(String? source) {
    if (source == null || source.trim().isEmpty) {
      return <Map<String, dynamic>>[];
    }

    try {
      final decoded = jsonDecode(source);
      if (decoded is! List) {
        return <Map<String, dynamic>>[];
      }

      return decoded
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList(growable: false);
    } on FormatException {
      return <Map<String, dynamic>>[];
    } on TypeError {
      return <Map<String, dynamic>>[];
    }
  }

  static String encode(Object? value) => jsonEncode(value);
}

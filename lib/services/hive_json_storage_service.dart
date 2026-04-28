import 'package:hive_flutter/hive_flutter.dart';

import '../constants/app_constants.dart';

class HiveJsonStorageService {
  const HiveJsonStorageService._(this._box);

  final Box<String> _box;

  static Future<HiveJsonStorageService> open() async {
    await Hive.initFlutter();
    final box = await Hive.openBox<String>(AppConstants.hiveBoxName);
    return HiveJsonStorageService._(box);
  }

  String? readString(String key) => _box.get(key);

  Future<void> writeString(String key, String value) async {
    await _box.put(key, value);
  }

  Future<void> delete(String key) async {
    await _box.delete(key);
  }
}

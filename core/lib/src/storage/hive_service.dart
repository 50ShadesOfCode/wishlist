import 'package:hive_ce/hive.dart';

/// Thin wrapper around Hive CE used to cache Supabase payloads.
class HiveCacheService {
  HiveCacheService(this._boxName);
  final String _boxName;

  Box<dynamic>? _box;

  Future<Box<dynamic>> _open() async {
    if (_box != null && _box!.isOpen) return _box!;
    _box = await Hive.openBox(_boxName);
    return _box!;
  }

  Future<void> put(String key, Map<String, dynamic> value) async {
    final box = await _open();
    await box.put(key, value);
  }

  Future<Map<String, dynamic>?> get(String key) async {
    final box = await _open();
    final raw = box.get(key);
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return null;
  }

  Future<void> putAll(Map<String, Map<String, dynamic>> entries) async {
    final box = await _open();
    await box.putAll(entries);
  }

  Future<List<Map<String, dynamic>>> getAll() async {
    final box = await _open();
    return box.values
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  Future<void> delete(String key) async {
    final box = await _open();
    await box.delete(key);
  }

  Future<List<dynamic>> keys() async {
    final box = await _open();
    return box.keys.toList();
  }

  /// Opens and clears a box by name (used at sign-out to wipe per-user
  /// caches without holding a service instance).
  static Future<void> clearBox(String boxName) async {
    final box = await Hive.openBox(boxName);
    await box.clear();
  }
}

/// Local DB abstraction backed by isar_plus in production.
/// Kept interface-only here so features depend on abstraction, not Isar directly.
abstract class LocalDbService {
  Future<void> init();
  Future<void> put<T>(String collection, String key, Map<String, dynamic> json);
  Future<Map<String, dynamic>?> get(String collection, String key);
  Future<List<Map<String, dynamic>>> getAll(String collection);
  Future<void> delete(String collection, String key);
  Future<void> clear(String collection);
}

class InMemoryLocalDbService implements LocalDbService {
  final Map<String, Map<String, Map<String, dynamic>>> _store = {};

  @override
  Future<void> init() async {}

  @override
  Future<void> put<T>(
    String collection,
    String key,
    Map<String, dynamic> json,
  ) async {
    _store.putIfAbsent(collection, () => {})[key] = json;
  }

  @override
  Future<Map<String, dynamic>?> get(String collection, String key) async =>
      _store[collection]?[key];

  @override
  Future<List<Map<String, dynamic>>> getAll(String collection) async =>
      _store[collection]?.values.toList() ?? [];

  @override
  Future<void> delete(String collection, String key) async {
    _store[collection]?.remove(key);
  }

  @override
  Future<void> clear(String collection) async {
    _store[collection]?.clear();
  }
}

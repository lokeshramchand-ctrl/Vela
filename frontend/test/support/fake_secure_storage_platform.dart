import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';

/// In-memory [FlutterSecureStoragePlatform] for tests. `flutter_secure_storage`
/// talks to a real OS keychain/keystore via a platform channel, which
/// `flutter test` has nothing behind - installing this as
/// [FlutterSecureStoragePlatform.instance] lets [TokenStorage] (which
/// constructs a real `FlutterSecureStorage()` under the hood) run unmodified
/// against a plain map instead.
class FakeSecureStoragePlatform extends FlutterSecureStoragePlatform {
  final Map<String, String> _store = {};

  @override
  Future<void> write({required String key, required String value, required Map<String, String> options}) async {
    _store[key] = value;
  }

  @override
  Future<String?> read({required String key, required Map<String, String> options}) async => _store[key];

  @override
  Future<bool> containsKey({required String key, required Map<String, String> options}) async =>
      _store.containsKey(key);

  @override
  Future<void> delete({required String key, required Map<String, String> options}) async {
    _store.remove(key);
  }

  @override
  Future<Map<String, String>> readAll({required Map<String, String> options}) async => Map.of(_store);

  @override
  Future<void> deleteAll({required Map<String, String> options}) async {
    _store.clear();
  }
}

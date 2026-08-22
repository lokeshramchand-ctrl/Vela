import '../../../core/network/api_client.dart';
import '../../../core/storage/token_storage.dart';
import '../domain/user.dart';

class AuthRepository {
  AuthRepository({required this._apiClient, required this._tokenStorage});

  final ApiClient _apiClient;
  final TokenStorage _tokenStorage;

  Future<User> register({required String email, required String password}) async {
    final response = await _apiClient.post<Map<String, dynamic>>(
      '/auth/register',
      data: {'email': email, 'password': password},
    );
    return User.fromJson(response.data!);
  }

  Future<User> login({required String email, required String password}) async {
    final response = await _apiClient.post<Map<String, dynamic>>(
      '/auth/login',
      data: {'email': email, 'password': password},
    );
    final data = response.data!;
    await _tokenStorage.saveTokens(
      accessToken: data['access_token'] as String,
      refreshToken: data['refresh_token'] as String,
    );
    return fetchCurrentUser();
  }

  Future<void> logout() async {
    final refreshToken = await _tokenStorage.readRefreshToken();
    if (refreshToken != null) {
      try {
        await _apiClient.post('/auth/logout', data: {'refresh_token': refreshToken});
      } catch (_) {
        // Best-effort: logout is idempotent server-side and the client
        // session is cleared locally regardless of network state.
      }
    }
    await _tokenStorage.clear();
  }

  Future<bool> hasSession() => _tokenStorage.hasSession();

  Future<User> fetchCurrentUser() async {
    final response = await _apiClient.get<Map<String, dynamic>>('/users/me');
    return User.fromJson(response.data!);
  }

  Future<User> updateProfile({String? fullName}) async {
    final response = await _apiClient.patch<Map<String, dynamic>>(
      '/users/me',
      data: {'full_name': fullName},
    );
    return User.fromJson(response.data!);
  }
}

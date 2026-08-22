import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:velar/core/network/api_client.dart';
import 'package:velar/core/network/api_exception.dart';
import 'package:velar/core/storage/token_storage.dart';
import 'package:velar/features/auth/data/auth_repository.dart';

import '../../support/fake_http_client_adapter.dart';
import '../../support/fake_secure_storage_platform.dart';

void main() {
  late FakeHttpClientAdapter adapter;
  late TokenStorage tokenStorage;
  late AuthRepository repository;

  setUp(() {
    FlutterSecureStoragePlatform.instance = FakeSecureStoragePlatform();
    adapter = FakeHttpClientAdapter();
    tokenStorage = TokenStorage();
    final apiClient = ApiClient(tokenStorage: tokenStorage, onSessionExpired: () async {});
    apiClient.dio.httpClientAdapter = adapter;
    repository = AuthRepository(apiClient: apiClient, tokenStorage: tokenStorage);
  });

  const userJson = {
    'id': 'user_123',
    'email': 'test@velar.dev',
    'is_active': true,
    'created_at': '2026-08-13T00:00:00Z',
  };

  FakeResponse tokenResponse({required String suffix}) => FakeResponse(
        statusCode: 200,
        body: {
          'access_token': 'access-$suffix',
          'refresh_token': 'refresh-$suffix',
          'token_type': 'bearer',
          'expires_in': 900,
        },
      );

  group('login', () {
    test('saves tokens and returns the user on success', () async {
      adapter.queue('POST', '/auth/login', tokenResponse(suffix: '1'));
      adapter.queue('GET', '/users/me', const FakeResponse(statusCode: 200, body: userJson));

      final user = await repository.login(email: 'test@velar.dev', password: 'TestPass123!');

      expect(user.id, 'user_123');
      expect(user.email, 'test@velar.dev');
      expect(await tokenStorage.readAccessToken(), 'access-1');
      expect(await tokenStorage.readRefreshToken(), 'refresh-1');
    });

    test('persists tokens even when the follow-up /users/me 404s', () async {
      // Mirrors what velar.deploy.lokeshrc.me actually does today:
      // /auth/login succeeds and issues real tokens, but /users/me isn't
      // mounted there (see AppConfig.apiBaseUrl for the full writeup).
      adapter.queue('POST', '/auth/login', tokenResponse(suffix: '2'));
      adapter.queue(
        'GET',
        '/users/me',
        const FakeResponse(
          statusCode: 404,
          body: {
            'error': {'detail': 'Not Found', 'request_id': 'req-1'},
          },
        ),
      );

      await expectLater(
        repository.login(email: 'test@velar.dev', password: 'TestPass123!'),
        throwsA(isA<ApiHttpException>().having((e) => e.statusCode, 'statusCode', 404)),
      );

      // login() only fails on the fetchCurrentUser() step *after* saving the
      // tokens from the successful /auth/login call - they're still on disk.
      expect(await tokenStorage.hasSession(), isTrue);
    });
  });

  group('register', () {
    test('creates the account, then a separate login signs it in', () async {
      // Matches AuthController.registerAndLogin: register() and login() are
      // two independent repository calls, not one atomic operation.
      adapter.queue('POST', '/auth/register', const FakeResponse(statusCode: 201, body: userJson));
      adapter.queue('POST', '/auth/login', tokenResponse(suffix: '3'));
      adapter.queue('GET', '/users/me', const FakeResponse(statusCode: 200, body: userJson));

      final registered = await repository.register(email: 'test@velar.dev', password: 'TestPass123!');
      final loggedIn = await repository.login(email: 'test@velar.dev', password: 'TestPass123!');

      expect(registered.email, 'test@velar.dev');
      expect(loggedIn.email, 'test@velar.dev');
      expect(await tokenStorage.hasSession(), isTrue);
    });
  });

  group('logout', () {
    test('clears the local session on a successful server call', () async {
      await tokenStorage.saveTokens(accessToken: 'a', refreshToken: 'r');
      adapter.queue('POST', '/auth/logout', const FakeResponse(statusCode: 204));

      await repository.logout();

      expect(await tokenStorage.hasSession(), isFalse);
    });

    test('still clears the local session when the server call fails', () async {
      // Logout is best-effort: the docstring on AuthRepository.logout says
      // the client session is cleared locally "regardless of network state".
      await tokenStorage.saveTokens(accessToken: 'a', refreshToken: 'r');
      adapter.queue(
        'POST',
        '/auth/logout',
        const FakeResponse(
          statusCode: 500,
          body: {
            'error': {'detail': 'Internal Server Error', 'request_id': 'req-2'},
          },
        ),
      );

      await repository.logout();

      expect(await tokenStorage.hasSession(), isFalse);
    });

    test('does not call the server when there is no session to end', () async {
      await repository.logout();
      expect(adapter.requests, isEmpty);
    });
  });
}

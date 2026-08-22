import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/core_providers.dart';
import '../data/auth_repository.dart';
import 'auth_state.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    apiClient: ref.watch(apiClientProvider),
    tokenStorage: ref.watch(tokenStorageProvider),
  );
});

final authControllerProvider = AsyncNotifierProvider<AuthController, AuthState>(AuthController.new);

class AuthController extends AsyncNotifier<AuthState> {
  @override
  Future<AuthState> build() async {
    // A forced logout from the API layer (refresh-token reuse/expiry) bumps
    // this counter; react by dropping straight to unauthenticated rather
    // than re-hitting a backend that will just 401 again.
    ref.listen(sessionExpiredTickProvider, (previous, next) {
      if (previous != null && next != previous) {
        state = const AsyncData(AuthState.unauthenticated());
      }
    });

    final repo = ref.watch(authRepositoryProvider);
    if (!await repo.hasSession()) {
      return const AuthState.unauthenticated();
    }
    try {
      final user = await repo.fetchCurrentUser();
      return AuthState.authenticated(user);
    } catch (_) {
      return const AuthState.unauthenticated();
    }
  }

  Future<void> login({required String email, required String password}) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final user = await ref.read(authRepositoryProvider).login(email: email, password: password);
      return AuthState.authenticated(user);
    });
  }

  Future<void> registerAndLogin({required String email, required String password}) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final repo = ref.read(authRepositoryProvider);
      await repo.register(email: email, password: password);
      final user = await repo.login(email: email, password: password);
      return AuthState.authenticated(user);
    });
  }

  Future<void> logout() async {
    await ref.read(authRepositoryProvider).logout();
    state = const AsyncData(AuthState.unauthenticated());
  }

  Future<void> refreshUser() async {
    final current = state.valueOrNull;
    if (current is! AuthAuthenticated) return;
    try {
      final user = await ref.read(authRepositoryProvider).fetchCurrentUser();
      state = AsyncData(AuthState.authenticated(user));
    } catch (_) {
      // Keep the current cached user on a transient refresh failure.
    }
  }
}

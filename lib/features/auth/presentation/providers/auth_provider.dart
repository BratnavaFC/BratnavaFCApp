import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/api/dio_client.dart';
import '../../../../core/api/interceptors/auth_interceptor.dart';
import '../../../../core/auth/jwt_helper.dart';
import '../../data/datasources/auth_remote_datasource.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/usecases/login_usecase.dart';
import '../../domain/usecases/register_usecase.dart';
import 'account_store.dart';

// ── AuthInterceptor (singleton por conta ativa) ───────────────────────────────

final authInterceptorProvider = Provider<AuthInterceptor>((ref) {
  final notifier = ref.read(accountStoreProvider.notifier);
  return AuthInterceptor(
    getAccessToken:  () => ref.read(accountStoreProvider).activeAccount?.accessToken,
    getRefreshToken: () => ref.read(accountStoreProvider).activeAccount?.refreshToken,
    onTokensRefreshed: (access, refresh) async {
      await notifier.updateTokens(access, refresh);
    },
    onUnauthorized: () async {
      await notifier.logout();
    },
  );
});

// ── Dio configurado com AuthInterceptor ───────────────────────────────────────

final dioProvider = Provider<Dio>((ref) {
  return buildDio(authInterceptor: ref.watch(authInterceptorProvider));
});

// ── Repositório & Use Cases ───────────────────────────────────────────────────

final _authDataSourceProvider = Provider<AuthRemoteDataSource>(
  (ref) => AuthRemoteDataSource(ref.watch(dioProvider)),
);

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepositoryImpl(ref.watch(_authDataSourceProvider)),
);

final loginUseCaseProvider = Provider<LoginUseCase>(
  (ref) => LoginUseCase(ref.watch(authRepositoryProvider)),
);

final registerUseCaseProvider = Provider<RegisterUseCase>(
  (ref) => RegisterUseCase(ref.watch(authRepositoryProvider)),
);

// ── AsyncNotifier para operações de login/registro ───────────────────────────

class AuthNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> login(
    String email,
    String password, {
    bool keepLoggedIn = true,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final useCase = ref.read(loginUseCaseProvider);
      final account = await useCase(email: email, password: password);

      final dataSource = ref.read(_authDataSourceProvider);

      // Busca em paralelo: roles de grupo + grupos do jogador.
      final roles    = await dataSource.fetchGroupRoles(account.userId);
      final groupIds = await dataSource.fetchMyGroupIds();

      // Auto-seleciona o grupo se o usuário pertencer a apenas um.
      final activeGroupId = groupIds.length == 1 ? groupIds.first : null;

      final enriched = account.copyWith(
        groupAdminIds:      roles['adminIds'],
        groupFinanceiroIds: roles['financeiroIds'],
        activeGroupId:      activeGroupId,
        keepLoggedIn:       keepLoggedIn,
      );

      await ref.read(accountStoreProvider.notifier).upsertAccount(enriched);
    });
  }

  Future<void> register({
    required String userName,
    required String firstName,
    required String lastName,
    required String email,
    required String password,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final useCase = ref.read(registerUseCaseProvider);
      await useCase(
        userName:  userName,
        firstName: firstName,
        lastName:  lastName,
        email:     email,
        password:  password,
      );
    });
  }

  Future<void> logout() async {
    await ref.read(accountStoreProvider.notifier).logout();
    ref.invalidateSelf();
  }

  /// Tenta renovar o token proativamente antes de expirar.
  /// Delega ao AuthInterceptor para reutilizar a lógica de envelope e mutex.
  Future<void> proactiveRefresh() async {
    final account = ref.read(accountStoreProvider).activeAccount;
    if (account == null) return;
    if (!JwtHelper.isExpiring(account.accessToken, bufferSeconds: 300)) return;

    debugPrint('🔄 proactiveRefresh: token expirando, renovando...');
    final newToken =
        await ref.read(authInterceptorProvider).tryRefresh();
    if (newToken != null) {
      debugPrint('✅ proactiveRefresh: token renovado');
    } else {
      debugPrint('⚠ proactiveRefresh: renovação falhou (interceptor tratará 401)');
    }
  }
}

final authNotifierProvider =
    AsyncNotifierProvider<AuthNotifier, void>(AuthNotifier.new);

// ── Serviço de refresh proativo ───────────────────────────────────────────────

/// Agenda renovação do token 5 minutos antes de expirar.
/// Deve ser assistido por um widget de longa duração (ShellPage).
final tokenRefreshServiceProvider = Provider<void>((ref) {
  final token = ref.watch(
    accountStoreProvider.select((s) => s.activeAccount?.accessToken),
  );
  if (token == null) return;

  final expiresAt = JwtHelper.expiresAt(token);
  if (expiresAt == null) return;

  final refreshAt = expiresAt.subtract(const Duration(minutes: 5));
  final delay     = refreshAt.difference(DateTime.now());

  Timer? timer;

  if (delay.isNegative || delay.inSeconds < 30) {
    // Token já próximo do limite — agenda refresh imediato
    Future.microtask(
      () => ref.read(authNotifierProvider.notifier).proactiveRefresh(),
    );
  } else {
    timer = Timer(delay, () {
      ref.read(authNotifierProvider.notifier).proactiveRefresh();
    });
  }

  ref.onDispose(() => timer?.cancel());
});

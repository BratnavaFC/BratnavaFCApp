import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/api/dio_client.dart';
import '../../../../core/api/interceptors/auth_interceptor.dart';
import '../../data/datasources/auth_remote_datasource.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/usecases/login_usecase.dart';
import '../../domain/usecases/register_usecase.dart';
import 'account_store.dart';

// ── Dio configurado com AuthInterceptor ───────────────────────────────────────

final dioProvider = Provider<Dio>((ref) {
  final notifier = ref.read(accountStoreProvider.notifier);

  final interceptor = AuthInterceptor(
    getAccessToken:  () => ref.read(accountStoreProvider).activeAccount?.accessToken,
    getRefreshToken: () => ref.read(accountStoreProvider).activeAccount?.refreshToken,
    onTokensRefreshed: (access, refresh) async {
      await notifier.updateTokens(access, refresh);
    },
    onUnauthorized: () async {
      await notifier.logout();
    },
  );

  return buildDio(authInterceptor: interceptor);
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

  Future<void> login(String email, String password) async {
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
}

final authNotifierProvider =
    AsyncNotifierProvider<AuthNotifier, void>(AuthNotifier.new);

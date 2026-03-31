import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/push/push_providers.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/presentation/providers/account_store.dart';

class App extends ConsumerStatefulWidget {
  const App({super.key});

  @override
  ConsumerState<App> createState() => _AppState();
}

class _AppState extends ConsumerState<App> {
  bool _pushInitialized = false;

  @override
  void initState() {
    super.initState();
    // Inicializa push se o usuário já estiver logado ao abrir o app
    WidgetsBinding.instance.addPostFrameCallback((_) => _tryInitPush());
  }

  void _tryInitPush() {
    final isLoggedIn = ref.read(accountStoreProvider).isLoggedIn;
    if (isLoggedIn && !_pushInitialized) {
      _pushInitialized = true;
      ref.read(pushServiceProvider).initialize();
    }
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);

    // Escuta mudanças de login para inicializar push assim que o usuário fizer login
    ref.listen<AccountState>(accountStoreProvider, (previous, next) {
      final wasLoggedIn = previous?.isLoggedIn ?? false;
      if (!wasLoggedIn && next.isLoggedIn && !_pushInitialized) {
        _pushInitialized = true;
        ref.read(pushServiceProvider).initialize();
      }
    });

    return MaterialApp.router(
      title:                    'BratnavaFC',
      theme:                    AppTheme.light,
      darkTheme:                AppTheme.dark,
      themeMode:                ThemeMode.system,
      routerConfig:             router,
      debugShowCheckedModeBanner: false,
    );
  }
}

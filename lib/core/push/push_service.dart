import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:logger/logger.dart';
import 'local_notifications.dart';
import 'push_token_api.dart';

/// Handler de background — DEVE ser função top-level (fora de qualquer classe).
/// Chamado quando o app está terminado ou em background.
@pragma('vm:entry-point')
Future<void> firebaseBackgroundMessageHandler(RemoteMessage message) async {
  final log  = Logger();
  final data = message.data;
  log.d('[Push BG] type=${data["type"]} | data: $data');

  // match_invite é data-only: exibe notificação local com botões SIM/NÃO
  if (data['type'] == 'match_invite') {
    await LocalNotifications.initialize();
    await LocalNotifications.showMatchInvite(
      title:   data['title'] ?? 'Convite para partida',
      body:    data['body']  ?? 'Você foi convidado. Confirme sua presença!',
      groupId: data['groupId'] ?? '',
      matchId: data['matchId'] ?? '',
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

/// Gerencia o ciclo de vida completo das push notifications via FCM.
///
/// Uso (após login):
///   final push = PushService(tokenApi: PushTokenApi(dio), router: goRouter, navigatorKey: key);
///   await push.initialize();
class PushService {
  PushService({
    required PushTokenApi tokenApi,
    required GoRouter router,
  })  : _tokenApi = tokenApi,
        _router = router
  {
    // Injeta callback de navegação para toque no corpo da notificação local
    LocalNotifications.onMatchInviteTapped = (groupId, matchId) {
      _router.push('/app/matches');
    };
  }

  final PushTokenApi _tokenApi;
  final GoRouter _router;
  final _log = Logger();
  late final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  bool _initialized = false;

  // ── Inicialização ────────────────────────────────────────────────────────

  /// Chame uma vez após login bem-sucedido. Idempotente — seguro chamar múltiplas vezes.
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    await _requestPermission();
    await _registerToken();
    _handleLocalNotificationLaunch();
    _listenTokenRefresh();
    _setupForegroundListener();
    _setupOpenedAppListener();
    await _handleInitialMessage();
  }

  // ── Permissões ───────────────────────────────────────────────────────────

  Future<void> _requestPermission() async {
    final settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
    _log.d('[Push] Permissão: ${settings.authorizationStatus}');
  }

  // ── Token ────────────────────────────────────────────────────────────────

  Future<void> _registerToken() async {
    try {
      _log.i('[Push] Obtendo token FCM...');
      final token = await _fcm.getToken();
      if (token == null) {
        _log.w('[Push] Token FCM nulo — dispositivo pode não suportar push.');
        return;
      }
      _log.i('[Push] Token FCM obtido: ${token.substring(0, 20)}...');
      await _sendTokenToBackend(token);
    } catch (e, st) {
      _log.e('[Push] Erro ao obter/registrar token', error: e, stackTrace: st);
    }
  }

  void _listenTokenRefresh() {
    _fcm.onTokenRefresh.listen((newToken) async {
      _log.d('[Push] Token renovado automaticamente.');
      await _sendTokenToBackend(newToken);
    });
  }

  Future<void> _sendTokenToBackend(String token) async {
    final platform = Platform.isIOS ? 'ios' : 'android';
    _log.i('[Push] Enviando token ao backend (platform=$platform)...');
    final ok = await _tokenApi.registerToken(token: token, platform: platform);
    if (ok) {
      _log.i('[Push] Token registrado no backend com sucesso.');
    } else {
      _log.e('[Push] Falha ao registrar token no backend — verifique autenticação e URL da API.');
    }
  }

  /// App foi aberto pelo toque no corpo de uma notificação local (match_invite).
  Future<void> _handleLocalNotificationLaunch() async {
    final details = await LocalNotifications.plugin.getNotificationAppLaunchDetails();
    if (details == null || !details.didNotificationLaunchApp) return;
    final payload = details.notificationResponse?.payload;
    if (payload == null || !payload.contains('::')) return;
    // É um match_invite — navega para partidas após o frame ser construído
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _router.push('/app/matches');
    });
  }

  // ── Listeners ────────────────────────────────────────────────────────────

  /// Notificações recebidas com app em FOREGROUND.
  void _setupForegroundListener() {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      _log.i('[Push FG] ${message.notification?.title} | data: ${message.data}');
      _showForegroundNotification(message);
    });
  }

  /// Usuário tocou na notificação com app em BACKGROUND (não terminado).
  void _setupOpenedAppListener() {
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      _log.d('[Push OPEN] ${message.notification?.title} | data: ${message.data}');
      _navigate(message.data);
    });
  }

  /// App estava TERMINADO — notificação que o abriu.
  Future<void> _handleInitialMessage() async {
    final initial = await _fcm.getInitialMessage();
    if (initial != null) {
      _log.d('[Push INIT] ${initial.notification?.title} | data: ${initial.data}');
      // Aguarda o frame ser construído antes de navegar
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _navigate(initial.data);
      });
    }
  }

  // ── Navegação via payload ────────────────────────────────────────────────

  /// Interpreta o campo `type` do payload e redireciona para a tela correta.
  ///
  /// Payloads esperados:
  ///   { "type": "match_invite",    "groupId": "...", "matchId": "..." }
  ///   { "type": "match_started",   "groupId": "...", "matchId": "..." }
  ///   { "type": "match_ended",     "groupId": "...", "matchId": "..." }
  ///   { "type": "group_invite" }
  ///   { "type": "payment_pending", "groupId": "..." }
  void _navigate(Map<String, dynamic> data) {
    final type    = data['type']    as String?;
    final groupId = data['groupId'] as String?;
    final matchId = data['matchId'] as String?;

    switch (type) {
      // ── Partidas ────────────────────────────────────────────────────────────
      case 'match_invite':
      case 'match_started':
        _router.push('/app/matches');
        break;

      case 'teams_assigned':
        _router.push('/app/matches');
        break;

      case 'match_ended':
        // Encerrada → tela de partidas para votar no MVP
        _router.push('/app/matches');
        break;

      case 'match_finalized':
        // Finalizada → histórico com resultado e MVP
        if (groupId != null && matchId != null) {
          _router.push('/app/history/$groupId/$matchId');
        } else {
          _router.push('/app/history');
        }
        break;

      // ── Convites / grupo ─────────────────────────────────────────────────────
      case 'group_invite':
      case 'player_left':
      case 'promoted_admin':
      case 'promoted_financeiro':
        _router.push('/app/groups');
        break;

      // ── Financeiro ───────────────────────────────────────────────────────────
      case 'payment_pending':
      case 'payment_confirmed':
        _router.push('/app/payments');
        break;

      // ── Votações ─────────────────────────────────────────────────────────────
      case 'poll_created':
      case 'poll_closed':
        _router.push('/app/polls');
        break;

      // ── Calendário ───────────────────────────────────────────────────────────
      case 'event_created':
      case 'event_deleted':
        _router.push('/app/calendar');
        break;

      default:
        _log.d('[Push] Tipo de notificação desconhecido: $type');
    }
  }

  // ── Notificação em foreground ────────────────────────────────────────────

  void _showForegroundNotification(RemoteMessage message) {
    final data  = message.data;
    final type  = data['type'] as String?;

    // match_invite é data-only (sem notification field) — exibe com botões SIM/NÃO
    if (type == 'match_invite') {
      LocalNotifications.showMatchInvite(
        title:   data['title'] ?? 'Convite para partida',
        body:    data['body']  ?? 'Você foi convidado. Confirme sua presença!',
        groupId: data['groupId'] ?? '',
        matchId: data['matchId'] ?? '',
      );
      return;
    }

    final title = message.notification?.title ?? data['title'] as String? ?? '';
    final body  = message.notification?.body  ?? data['body']  as String? ?? '';
    if (title.isEmpty && body.isEmpty) return;

    LocalNotifications.show(title: title, body: body);
  }
}

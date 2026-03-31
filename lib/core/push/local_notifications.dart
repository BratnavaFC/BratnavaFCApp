import 'dart:convert';
import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api/api_constants.dart';
import '../constants/app_constants.dart';

// ─── IDs das ações ────────────────────────────────────────────────────────────

const _kActionAccept = 'match_accept';
const _kActionReject = 'match_reject';
const _kCategoryMatchInvite = 'MATCH_INVITE';

// ─── Canais Android ───────────────────────────────────────────────────────────

const _channelId        = 'bratnavafc_high';
const _channelName      = 'BratnavaFC';
const _channelDesc      = 'Notificações do BratnavaFC';

const _inviteChannelId   = 'bratnavafc_match_invite';
const _inviteChannelName = 'Convites de Partida';
const _inviteChannelDesc = 'Convites para participar de partidas';

// ─── Handler de background (top-level obrigatório) ───────────────────────────

/// Chamado quando o usuário toca em SIM ou NÃO com o app em background/terminado.
@pragma('vm:entry-point')
Future<void> onNotificationActionBackground(NotificationResponse response) async {
  if (response.actionId != _kActionAccept && response.actionId != _kActionReject) return;

  final parts = response.payload?.split('::');
  if (parts == null || parts.length < 2) return;
  final groupId = parts[0];
  final matchId = parts[1];

  // Lê o accessToken do SharedPreferences (sem Riverpod, sem Dio)
  final prefs    = await SharedPreferences.getInstance();
  final raw      = prefs.getString(AppConstants.accountsStorageKey);
  final activeId = prefs.getString(AppConstants.activeAccountKey);
  if (raw == null) return;

  String? accessToken;
  try {
    final accounts = jsonDecode(raw) as List;
    final account  = accounts.firstWhere(
      (a) => a['userId'] == activeId,
      orElse: () => accounts.first,
    ) as Map<String, dynamic>;
    accessToken = account['accessToken'] as String?;
  } catch (_) {
    return;
  }
  if (accessToken == null) return;

  final isAccept = response.actionId == _kActionAccept;
  final path     = isAccept
      ? ApiConstants.matchMyInviteAccept(groupId, matchId)
      : ApiConstants.matchMyInviteReject(groupId, matchId);

  try {
    final client  = HttpClient();
    final uri     = Uri.parse('${AppConstants.apiUrl}$path');
    final request = await client.openUrl('PATCH', uri);
    request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $accessToken');
    request.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
    request.contentLength = 0;
    final resp = await request.close();
    client.close();
    // ignore: avoid_print
    print('[Push Action] ${isAccept ? "Aceito" : "Recusado"} — HTTP ${resp.statusCode}');
  } catch (e) {
    // ignore: avoid_print
    print('[Push Action] Erro ao chamar API: $e');
  }
}

// ─── Classe principal ─────────────────────────────────────────────────────────

/// Gerencia notificações locais usadas para exibir mensagens FCM
/// quando o app está em foreground (Android não exibe o banner do sistema).
class LocalNotifications {
  LocalNotifications._();

  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;
  static int  _nextId = 0;

  /// Callback chamado no isolate principal quando o usuário toca no
  /// corpo da notificação (sem apertar SIM/NÃO). Injetado pelo PushService.
  static void Function(String groupId, String matchId)? onMatchInviteTapped;

  static FlutterLocalNotificationsPlugin get plugin => _plugin;

  /// Handler para foreground/background (isolate principal).
  /// Faz a chamada à API E navega se o usuário tocou no corpo da notificação.
  static void _onForegroundResponse(NotificationResponse response) {
    final isAction = response.actionId == _kActionAccept ||
        response.actionId == _kActionReject;

    if (isAction) {
      // Mesmo fluxo do handler de background: chama API sem abrir o app
      onNotificationActionBackground(response);
    } else {
      // Toque no corpo da notificação → navega para a tela de partidas
      final parts = response.payload?.split('::');
      if (parts != null && parts.length >= 2) {
        onMatchInviteTapped?.call(parts[0], parts[1]);
      }
    }
  }

  /// Inicializa o plugin. Chamar uma vez no `main()` antes de `runApp`.
  static Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    const android = AndroidInitializationSettings('@drawable/ic_notification');

    // Categoria iOS para convites de partida com botões SIM / NÃO
    final ios = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
      notificationCategories: [
        DarwinNotificationCategory(
          _kCategoryMatchInvite,
          actions: [
            DarwinNotificationAction.plain(_kActionAccept, 'SIM ✅'),
            DarwinNotificationAction.plain(
              _kActionReject,
              'NÃO ❌',
              options: <DarwinNotificationActionOption>{
                DarwinNotificationActionOption.destructive,
              },
            ),
          ],
        ),
      ],
    );

    await _plugin.initialize(
      InitializationSettings(android: android, iOS: ios),
      onDidReceiveNotificationResponse:           _onForegroundResponse,
      onDidReceiveBackgroundNotificationResponse: onNotificationActionBackground,
    );

    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

    // Canal padrão (alta prioridade)
    await androidPlugin?.createNotificationChannel(const AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: _channelDesc,
      importance: Importance.high,
      playSound: true,
    ));

    // Canal dedicado para convites com botões de ação
    await androidPlugin?.createNotificationChannel(const AndroidNotificationChannel(
      _inviteChannelId,
      _inviteChannelName,
      description: _inviteChannelDesc,
      importance: Importance.high,
      playSound: true,
    ));
  }

  // ── Notificação simples (foreground) ────────────────────────────────────────

  static Future<void> show({
    required String title,
    required String body,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDesc,
      importance: Importance.high,
      priority:   Priority.high,
      playSound:  true,
      icon:       '@drawable/ic_notification',
    );
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    await _plugin.show(
      _nextId++,
      title,
      body,
      const NotificationDetails(android: androidDetails, iOS: iosDetails),
    );
  }

  // ── Notificação de convite de partida com botões SIM / NÃO ─────────────────

  static Future<void> showMatchInvite({
    required String title,
    required String body,
    required String groupId,
    required String matchId,
  }) async {
    final payload = '$groupId::$matchId';

    final androidDetails = AndroidNotificationDetails(
      _inviteChannelId,
      _inviteChannelName,
      channelDescription: _inviteChannelDesc,
      importance: Importance.high,
      priority:   Priority.high,
      playSound:  true,
      icon:       '@drawable/ic_notification',
      actions: const [
        AndroidNotificationAction(
          _kActionAccept,
          'SIM ✅',
          showsUserInterface: false,
          cancelNotification: true,
        ),
        AndroidNotificationAction(
          _kActionReject,
          'NÃO ❌',
          showsUserInterface: false,
          cancelNotification: true,
        ),
      ],
    );
    const iosDetails = DarwinNotificationDetails(
      presentAlert:         true,
      presentBadge:         true,
      presentSound:         true,
      categoryIdentifier:   _kCategoryMatchInvite,
    );

    await _plugin.show(
      _nextId++,
      title,
      body,
      NotificationDetails(android: androidDetails, iOS: iosDetails),
      payload: payload,
    );
  }
}

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'app.dart';
import 'core/providers/core_providers.dart';
import 'core/push/local_notifications.dart';
import 'core/push/push_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase e SharedPreferences são obrigatórios antes do runApp.
  // Os demais são inicializados em paralelo para reduzir o tempo de boot.
  final results = await Future.wait([
    Firebase.initializeApp(),
    SharedPreferences.getInstance(),
    initializeDateFormatting('pt_BR', null),
    LocalNotifications.initialize(),
  ]);

  // Handler de background — deve ser registrado após Firebase.initializeApp().
  FirebaseMessaging.onBackgroundMessage(firebaseBackgroundMessageHandler);

  final prefs = results[1] as SharedPreferences;

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: const App(),
    ),
  );
}

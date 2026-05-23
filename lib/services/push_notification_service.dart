import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;

import '../firebase_options.dart';
import '../config/api_config.dart';
import 'auth_service.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
}

class PushNotificationService {
  PushNotificationService._();

  static final PushNotificationService instance = PushNotificationService._();

  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  final AuthService _authService = AuthService();

  // IMPORTANTE: se usa la misma baseUrl de ApiConfig para mantener coherencia.

  Future<void> init() async {
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    await _requestPermission();
    await _initLocalNotifications();
    await _listenForegroundMessages();
    await registrarTokenEnBackend();
    _listenTokenRefresh();
  }

  Future<void> _requestPermission() async {
    await _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  Future<void> _initLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');

    const settings = InitializationSettings(
      android: androidSettings,
    );

    await _localNotifications.initialize(
      settings: settings,
    );

    const channel = AndroidNotificationChannel(
      'recordatorios_channel',
      'Recordatorios',
      description: 'Notificaciones de recordatorios pendientes',
      importance: Importance.high,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  Future<void> registrarTokenEnBackend() async {
    try {
      final fcmToken = await _firebaseMessaging.getToken();

      if (fcmToken == null || fcmToken.isEmpty) {
        return;
      }

      final authToken = await _authService.getToken();

      if (authToken == null || authToken.isEmpty) {
        return;
      }

      await http.post(
        Uri.parse('${ApiConfig.baseUrl}/notificaciones/registrar-token'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $authToken',
        },
        body: jsonEncode({
          'token': fcmToken,
          'platform': 'android',
        }),
      );
    } catch (e) {
      // No detenemos la app si falla el registro del token.
      // Luego se puede volver a intentar después del login.
    }
  }

  void _listenTokenRefresh() {
    _firebaseMessaging.onTokenRefresh.listen((nuevoToken) async {
      try {
        final authToken = await _authService.getToken();

        if (authToken == null || authToken.isEmpty) {
          return;
        }

        await http.post(
          Uri.parse('${ApiConfig.baseUrl}/notificaciones/registrar-token'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $authToken',
          },
          body: jsonEncode({
            'token': nuevoToken,
            'platform': 'android',
          }),
        );
      } catch (_) {}
    });
  }

  Future<void> _listenForegroundMessages() async {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      final notification = message.notification;

      if (notification == null) {
        return;
      }

      const androidDetails = AndroidNotificationDetails(
        'recordatorios_channel',
        'Recordatorios',
        channelDescription: 'Notificaciones de recordatorios pendientes',
        importance: Importance.high,
        priority: Priority.high,
        icon: 'ic_stat_gestor',
      );

      const details = NotificationDetails(
        android: androidDetails,
      );

      await _localNotifications.show(
        id: notification.hashCode,
        title: notification.title ?? 'Gestor de Proyectos',
        body: notification.body ?? 'Tenés un recordatorio pendiente.',
        notificationDetails: details,
      );
    });
  }
}

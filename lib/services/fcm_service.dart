import 'dart:io';
import 'package:app/models/alert.dart';
import 'package:app/services/auth_service.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Handles FCM messages when app is terminated or in background.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('[FCM] Background message: ${message.messageId}');
}

class FcmService {
  FcmService._();
  static final FcmService instance = FcmService._();

  final _messaging = FirebaseMessaging.instance;

  // Local notifications plugin — used only for foreground banners
  final _localNotif = FlutterLocalNotificationsPlugin();

  // Callback: provider passes this in so alerts reach the UI
  void Function(AppAlert alert)? onAlert;

  // Called once from AppProvider
  Future<void> init({required void Function(AppAlert) onAlert}) async {
    this.onAlert = onAlert;

    await _requestPermission();
    await _setupLocalNotifications();
    await _registerToken();

    // Token rotates sometimes — re-register when it does
    _messaging.onTokenRefresh.listen((newToken) async {
      debugPrint('[FCM] Token refreshed');
      await ApiService.registerFcmToken(newToken);
    });

    // Foreground messages
    FirebaseMessaging.onMessage.listen((msg) {
      debugPrint('[FCM] Foreground: ${msg.notification?.title}');
      _showLocalBanner(msg);
      final alert = _toAlert(msg);
      if (alert != null) onAlert(alert);
    });

    // Notification tapped while app was in background
    FirebaseMessaging.onMessageOpenedApp.listen((msg) {
      debugPrint('[FCM] Opened from background: ${msg.notification?.title}');
      final alert = _toAlert(msg);
      if (alert != null) onAlert(alert);
    });

    // App opened from a terminated-state notification
    final initial = await _messaging.getInitialMessage();
    if (initial != null) {
      debugPrint(
        '[FCM] Launched from terminated: ${initial.notification?.title}',
      );
      final alert = _toAlert(initial);
      if (alert != null) onAlert(alert);
    }
  }

  // Token registration

  Future<void> _registerToken() async {
    try {
      if (Platform.isIOS) {
        await _messaging.getAPNSToken();
      }
      final token = await _messaging.getToken();
      if (token != null) {
        debugPrint('[FCM] Token: ${token.substring(0, 20)}...');
        await ApiService.registerFcmToken(token);
      }
    } catch (e) {
      debugPrint('[FCM] Token error: $e');
    }
  }

  // Permission

  Future<void> _requestPermission() async {
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    debugPrint('[FCM] Permission: ${settings.authorizationStatus}');
  }

  // Local notification

  Future<void> _setupLocalNotifications() async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _localNotif.initialize(
      const InitializationSettings(android: android, iOS: ios),
    );

    // Create Android notification channel
    const channel = AndroidNotificationChannel(
      'high_importance_channel',
      'KitchenBDY Alerts',
      description: 'Inventory alerts and reminders',
      importance: Importance.high,
      playSound: true,
    );
    await _localNotif
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(channel);
  }

  Future<void> _showLocalBanner(RemoteMessage msg) async {
    final notif = msg.notification;
    if (notif == null) return;

    await _localNotif.show(
      msg.hashCode,
      notif.title,
      notif.body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'high_importance_channel',
          'KitchenBDY Alerts',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
    );
  }

  // Message → AppAlert conversion

  AppAlert? _toAlert(RemoteMessage msg) {
    final title = msg.notification?.title ?? msg.data['title'] ?? '';
    final body = msg.notification?.body ?? msg.data['body'] ?? '';
    if (title.isEmpty && body.isEmpty) return null;

    final data = Map<String, String>.from(msg.data);
    final type = _parseType(data['type'] ?? '');

    return AppAlert(
      id: msg.messageId ?? '${DateTime.now().millisecondsSinceEpoch}',
      type: type,
      title: title,
      message: body,
      timestamp: DateTime.now(),
      isRead: false,
      itemName: data['itemName'],
      deviceId: data['sensorId'],
      data: data,
    );
  }

  /// Maps the backend `type` string to a Flutter AlertType
  AlertType _parseType(String type) {
    switch (type) {
      case 'low_stock':
        return AlertType.lowStock;
      case 'out_of_stock':
        return AlertType.outOfStock;
      case 'sensor_offline':
        return AlertType.deviceOffline;
      case 'sensor_online':
        return AlertType.deviceOnline;
      case 'sensor_placement':
        return AlertType.sensorPlacement;
      case 'reminder':
        return AlertType.refillReminder;
      case 'receipt_pending':
        return AlertType.receiptPending;
      case 'receipt_confirmed':
        return AlertType.receiptProcessed;
      case 'meal_reminder':
        return AlertType.mealReminder;
      default:
        return AlertType.info;
    }
  }
}

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'firestore_service.dart';

/// Top-level background message handler (must be top-level, not a class method).
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Firebase is already initialized in main.dart via background isolate.
  // Background notifications are shown by the system automatically on Android.
  // No additional handling required for MVP.
}

class NotificationService {
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'chat_messages',
    'Chat Messages',
    description: 'New message notifications',
    importance: Importance.high,
  );

  final FirestoreService _firestoreService;

  NotificationService(this._firestoreService);

  Future<void> initialize(String uid) async {
    // Set up background handler
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    // Request permission (iOS + Android 13+)
    await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // Initialize local notifications
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings();
    await _localNotifications.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
    );

    // Create Android notification channel
    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_channel);

    // Handle foreground messages
    FirebaseMessaging.onMessage.listen((message) {
      _showLocalNotification(message);
    });

    // Get and store FCM token
    await _refreshToken(uid);

    // Listen for token refresh
    FirebaseMessaging.instance.onTokenRefresh.listen((token) {
      _firestoreService.updateFcmToken(uid, token);
    });
  }

  Future<void> _refreshToken(String uid) async {
    final token = await FirebaseMessaging.instance.getToken();
    if (token != null) {
      await _firestoreService.updateFcmToken(uid, token);
    }
  }

  void _showLocalNotification(RemoteMessage message) {
    final notification = message.notification;
    if (notification == null) return;

    _localNotifications.show(
      notification.hashCode,
      notification.title,
      notification.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(),
      ),
    );
  }
}

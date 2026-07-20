import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Thin wrapper around flutter_local_notifications. Initialised once at startup
/// and exposed via [notificationServiceProvider] so it's swappable/testable.
///
/// Scope: fires *local* notifications while the app is alive (foreground or
/// backgrounded). There is no FCM/push, so **no notification when the app is
/// fully killed** — a documented, intentional limitation.
class NotificationService {
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  /// Called with the chatId payload when a notification is tapped.
  void Function(String chatId)? onOpenChat;

  static const _channelId = 'messages';

  Future<void> init() async {
    if (_initialized) return;

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    // Permissions are requested explicitly later, not at init.
    const ios = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    await _plugin.initialize(
      settings: const InitializationSettings(android: android, iOS: ios),
      onDidReceiveNotificationResponse: (response) {
        final chatId = response.payload;
        if (chatId != null && chatId.isNotEmpty) onOpenChat?.call(chatId);
      },
    );
    _initialized = true;
  }

  /// Ask for notification permission (Android 13+ and iOS both require it).
  Future<void> requestPermissions() async {
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
    await _plugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);
  }

  Future<void> showMessage({
    required String chatId,
    required String title,
    required String body,
  }) async {
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        'Messages',
        channelDescription: 'New message notifications',
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(),
    );
    // One notification per chat (a newer message replaces the older one).
    await _plugin.show(
      id: chatId.hashCode & 0x7fffffff,
      title: title,
      body: body,
      notificationDetails: details,
      payload: chatId,
    );
  }
}

final notificationServiceProvider =
    Provider<NotificationService>((ref) => NotificationService());

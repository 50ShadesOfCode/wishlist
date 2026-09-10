import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// A notification tap, parsed from the payload (`<type>:<id>`).
class NotificationTap {
  const NotificationTap(this.type, this.id);

  /// `item` (wishlist item id) or `chat` (thread id).
  final String type;
  final String id;

  static NotificationTap? parse(String? payload) {
    if (payload == null) return null;
    final idx = payload.indexOf(':');
    if (idx <= 0 || idx == payload.length - 1) return null;
    return NotificationTap(
      payload.substring(0, idx),
      payload.substring(idx + 1),
    );
  }
}

/// Local notifications: permission flow, channels per category, stable ids
/// (no collisions/overwrites), and tap payloads the router deep-links into
/// (`item:<id>` → edit page, `chat:<id>` → thread).
///
/// Remote push (FCM) is intentionally out of scope: no server fan-out exists
/// yet. When it lands, route FCM messages through [showNewItem]/
/// [showNewMessage] so channels, ids and taps keep working.
class NotificationService {
  NotificationService(this._plugin);

  static const wishlistChannel = 'wishlist';
  static const chatsChannel = 'chats';

  final FlutterLocalNotificationsPlugin _plugin;

  /// Called on notification tap (wired to go_router in [WishlistApp]).
  void Function(NotificationTap tap)? onTap;

  Future<void> init() async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings();
    await _plugin.initialize(
      settings: const InitializationSettings(android: android, iOS: ios),
      onDidReceiveNotificationResponse: (response) {
        final tap = NotificationTap.parse(response.payload);
        if (tap != null) onTap?.call(tap);
      },
    );
    await _createChannels();
  }

  Future<void> _createChannels() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await android?.createNotificationChannel(
      const AndroidNotificationChannel(
        wishlistChannel,
        'Wishlist updates',
        description: 'New and updated wishlist items',
        importance: Importance.high,
      ),
    );
    await android?.createNotificationChannel(
      const AndroidNotificationChannel(
        chatsChannel,
        'Secret chats',
        description: 'New secret discussion messages',
        importance: Importance.high,
      ),
    );
  }

  /// Requests system permission (Android 13+, iOS). Best-effort: returns
  /// false when denied or unsupported; callers must not block on it.
  Future<bool> requestPermissions() async {
    try {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      final androidGranted =
          await android?.requestNotificationsPermission() ?? true;
      final ios = _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      final iosGranted = await ios?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          ) ??
          true;
      return androidGranted && iosGranted;
    } catch (_) {
      return false;
    }
  }

  static int _stableId(String key) => key.hashCode & 0x7fffffff;

  Future<void> showNewItem({
    required String itemId,
    required String title,
    required String body,
  }) => _plugin.show(
    id: _stableId('item:$itemId'),
    title: title,
    body: body,
    payload: 'item:$itemId',
    notificationDetails: const NotificationDetails(
      android: AndroidNotificationDetails(
        wishlistChannel,
        'Wishlist updates',
        importance: Importance.high,
      ),
      iOS: DarwinNotificationDetails(),
    ),
  );

  Future<void> showNewMessage({
    required String chatId,
    required String title,
    required String body,
  }) => _plugin.show(
    id: _stableId('chat:$chatId'),
    title: title,
    body: body,
    payload: 'chat:$chatId',
    notificationDetails: const NotificationDetails(
      android: AndroidNotificationDetails(
        chatsChannel,
        'Secret chats',
        importance: Importance.high,
      ),
      iOS: DarwinNotificationDetails(),
    ),
  );
}

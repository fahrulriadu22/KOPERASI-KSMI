// services/simple_inbox_notifier.dart - VERSI SIMPLE
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class SimpleInboxNotifier {
  static final SimpleInboxNotifier _instance = SimpleInboxNotifier._internal();
  factory SimpleInboxNotifier() => _instance;
  SimpleInboxNotifier._internal();

  static final FlutterLocalNotificationsPlugin _notifications = 
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;
  int _lastUnreadCount = 0;

  // ✅ INITIALIZE
  Future<void> initialize() async {
    try {
      if (_isInitialized) return;
      
      const AndroidInitializationSettings androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      
      const InitializationSettings initializationSettings =
          InitializationSettings(android: androidSettings);
      
      await _notifications.initialize(initializationSettings);
      
      // ✅ CREATE CHANNEL
      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        'ksmi_inbox_channel',
        'KSMI Inbox Notifications',
        description: 'Notifications for new inbox messages',
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
      );
      
      await _notifications.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()?.createNotificationChannel(channel);
      
      _isInitialized = true;
      print('✅ SimpleInboxNotifier initialized successfully');
    } catch (e) {
      print('⚠️ SimpleInboxNotifier initialization warning: $e');
      _isInitialized = true;
    }
  }

  // ✅ CHECK AND NOTIFY
  Future<void> checkAndNotifyNewMessages(int currentUnreadCount) async {
    try {
      if (!_isInitialized) await initialize();
      
      print('📧 Checking new messages: last=$_lastUnreadCount, current=$currentUnreadCount');
      
      if (currentUnreadCount > _lastUnreadCount && currentUnreadCount > 0) {
        await _showNewMessageNotification(currentUnreadCount);
      }
      
      _lastUnreadCount = currentUnreadCount;
    } catch (e) {
      print('❌ Error in checkAndNotifyNewMessages: $e');
    }
  }

  // ✅ SHOW NOTIFICATION - VERSI SEDERHANA
  Future<void> _showNewMessageNotification(int unreadCount) async {
    try {
      final body = unreadCount == 1 
          ? 'Anda memiliki 1 pesan belum dibaca'
          : 'Anda memiliki $unreadCount pesan belum dibaca';

      await _notifications.show(
        DateTime.now().millisecondsSinceEpoch.remainder(100000),
        'Pesan Baru - KSMI',
        body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'ksmi_inbox_channel',
            'KSMI Inbox',
            channelDescription: 'Notifikasi untuk pesan inbox KSMI',
            importance: Importance.high,
            priority: Priority.high,
            playSound: true,
            enableVibration: true,
            // ✅ HAPUS color dan ledColor untuk menghindari error
          ),
        ),
      );
      
      print('📲 Notification shown: $unreadCount new messages');
    } catch (e) {
      print('❌ Error showing notification: $e');
    }
  }

  // ✅ TEST METHOD
  Future<void> testNotification() async {
    await _showNewMessageNotification(3);
  }

  // ✅ RESET COUNTER
  void resetCounter() {
    _lastUnreadCount = 0;
  }

  // ✅ GETTERS
  int get lastUnreadCount => _lastUnreadCount;
  bool get isInitialized => _isInitialized;
}
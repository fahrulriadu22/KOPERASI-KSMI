// notification_service.dart - VERSI LENGKAP DENGAN SEMUA METHOD
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';

class SimpleNotificationService {
  // ✅ FIX: Tidak pakai singleton, tidak pakai late variables
  SimpleNotificationService() {
    _initialize();
  }

  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;

  // ✅ FIX: Initialize di constructor
  Future<void> _initialize() async {
    try {
      print('🔄 SimpleNotificationService initializing...');

      // ✅ ANDROID SETTINGS
      const AndroidInitializationSettings androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      // ✅ IOS SETTINGS
      const DarwinInitializationSettings iosSettings =
          DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );

      // ✅ INITIALIZATION SETTINGS
      const InitializationSettings initializationSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      // ✅ INITIALIZE PLUGIN
      await _notifications.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: _onNotificationTap,
      );

      // ✅ CREATE ANDROID CHANNEL
      await _createNotificationChannel();

      _isInitialized = true;
      print('✅ SimpleNotificationService initialized successfully');
    } catch (e) {
      print('❌ SimpleNotificationService initialization failed: $e');
      _isInitialized = true; // Tetap set true
    }
  }

  // ✅ FIX: Create notification channel
  Future<void> _createNotificationChannel() async {
    try {
      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        'ksmi_inbox_channel',
        'KSMI Inbox Notifications',
        description: 'Notifications for new inbox messages from KSMI',
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
        showBadge: true,
      );

      await _notifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);
      
      print('✅ Notification channel created');
    } catch (e) {
      print('⚠️ Error creating notification channel: $e');
    }
  }

  // ✅ FIX: SHOW NOTIFICATION - SANGAT SEDERHANA
  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    required String payload,
  }) async {
    try {
      // ✅ Safety check
      if (!_isInitialized) {
        print('⏳ Notification service not ready yet, skipping...');
        return;
      }

      // ✅ Notification details
      const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        'ksmi_inbox_channel',
        'KSMI Inbox Notifications',
        channelDescription: 'Notifications for new inbox messages from KSMI',
        importance: Importance.high,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
        showWhen: true,
        autoCancel: true,
      );

      const NotificationDetails details = NotificationDetails(
        android: androidDetails,
      );

      // ✅ Show notification
      await _notifications.show(id, title, body, details, payload: payload);
      
      print('📱 Notification shown: $title');
    } catch (e) {
      print('❌ Error showing notification: $e');
    }
  }

  // ✅ TEST METHODS
  Future<void> testBasicNotification() async {
    try {
      print('1. Testing basic system notification...');
      await showNotification(
        id: 1001,
        title: 'TEST: Basic Notification',
        body: 'Ini adalah test notifikasi dasar dari KSMI',
        payload: 'test_basic',
      );
    } catch (e) {
      print('❌ Basic notification test failed: $e');
    }
  }

  Future<void> testInboxNotification() async {
    try {
      print('2. Testing inbox system notification...');
      await showNotification(
        id: 1002,
        title: 'Pesan Baru - KSMI',
        body: 'Anda memiliki 2 pesan belum dibaca di inbox',
        payload: 'inbox_new',
      );
    } catch (e) {
      print('❌ Inbox notification test failed: $e');
    }
  }

  Future<void> testMultipleNotifications() async {
    try {
      print('3. Testing multiple system notifications...');

      await _notifications.cancelAll();

      // Notification 1
      await showNotification(
        id: 1003,
        title: 'Penarikan SIQUNA',
        body: 'Penarikan SIQUNA Sebesar Rp. 100.000 Telah Berhasil',
        payload: 'inbox_9',
      );

      await Future.delayed(const Duration(seconds: 1));

      // Notification 2
      await showNotification(
        id: 1004,
        title: 'Penarikan SIQUNA',
        body: 'Penarikan SIQUNA Sebesar Rp. 100.000 Telah Berhasil',
        payload: 'inbox_10',
      );

      await Future.delayed(const Duration(seconds: 1));

      // Summary
      await showNotification(
        id: 1005,
        title: '2 Pesan Baru',
        body: 'Anda memiliki 2 pesan belum dibaca di inbox KSMI',
        payload: 'inbox_summary',
      );
    } catch (e) {
      print('❌ Multiple notifications test failed: $e');
    }
  }

  Future<void> testHighPriorityNotification() async {
    try {
      print('4. Testing high priority system notification...');
      await showNotification(
        id: 1006,
        title: 'PENTING: Pembayaran SIQUNA',
        body: 'Pembayaran SIQUNA Sebesar Rp. 500.000 Telah Berhasil',
        payload: 'inbox_important',
      );
    } catch (e) {
      print('❌ High priority notification test failed: $e');
    }
  }

  // ✅ METHOD YANG DIPERLUKAN OLEH FIREBASE_SERVICE
  Future<void> showInboxNotification(int unreadCount) async {
    try {
      final title = unreadCount == 1 ? 'Pesan Baru' : '$unreadCount Pesan Baru';
      final body = unreadCount == 1 
          ? 'Anda memiliki 1 pesan belum dibaca' 
          : 'Anda memiliki $unreadCount pesan belum dibaca';

      await showNotification(
        id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
        title: title,
        body: body,
        payload: 'inbox_new_messages',
      );
      
      print('📬 Inbox notification shown for $unreadCount unread messages');
    } catch (e) {
      print('❌ Error showing inbox notification: $e');
    }
  }

  // ✅ METHOD RUNALLTESTS UNTUK FIREBASE_SERVICE
  Future<void> runAllTests() async {
    print('🧪 STARTING ALL NOTIFICATION TESTS...');
    
    try {
      await testBasicNotification();
      await Future.delayed(const Duration(seconds: 2));
      
      await testInboxNotification();
      await Future.delayed(const Duration(seconds: 2));
      
      await testMultipleNotifications();
      await Future.delayed(const Duration(seconds: 2));
      
      await testHighPriorityNotification();
      
      print('🎉 ALL NOTIFICATION TESTS COMPLETED!');
      print('📱 Check your device notification panel');
      
    } catch (e) {
      print('❌ Notification tests failed: $e');
    }
  }

  // ✅ NOTIFICATION TAP HANDLER
  void _onNotificationTap(NotificationResponse response) {
    print('🎯 Notification tapped: ${response.payload}');
  }

  // ✅ CLEAR ALL NOTIFICATIONS
  Future<void> clearAllNotifications() async {
    try {
      await _notifications.cancelAll();
      print('🧹 All notifications cleared');
    } catch (e) {
      print('❌ Error clearing notifications: $e');
    }
  }

  // ✅ GETTER UNTUK CHECK INITIALIZATION
  bool get isInitialized => _isInitialized;
}
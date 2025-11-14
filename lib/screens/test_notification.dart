import 'package:flutter/material.dart';
import '../services/firebase_service.dart';
import '../services/simple_inbox_notifier.dart';

class TestNotificationScreen extends StatefulWidget {
  @override
  _TestNotificationScreenState createState() => _TestNotificationScreenState();
}

class _TestNotificationScreenState extends State<TestNotificationScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  final SimpleInboxNotifier _inboxNotifier = SimpleInboxNotifier();
  bool _isTesting = false;

  @override
  void initState() {
    super.initState();
    _initializeNotifier();
  }

  Future<void> _initializeNotifier() async {
    await _inboxNotifier.initialize();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Test Notifikasi Android'),
        backgroundColor: Colors.blue,
      ),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Test Android System Notifications',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 20),
            
            // Test Button 1: Basic Notification
            ElevatedButton(
              onPressed: _isTesting ? null : _testBasicNotification,
              child: Text('Test Notifikasi Dasar'),
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.symmetric(vertical: 15),
              ),
            ),
            SizedBox(height: 10),
            
            // Test Button 2: Multiple Notifications
            ElevatedButton(
              onPressed: _isTesting ? null : _testMultipleNotifications,
              child: Text('Test Check New Messages'),
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.symmetric(vertical: 15),
              ),
            ),
            SizedBox(height: 10),
            
            // Test Button 3: Inbox Simulation
            ElevatedButton(
              onPressed: _isTesting ? null : _testInboxSimulation,
              child: Text('Simulasi Inbox Real'),
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.symmetric(vertical: 15),
              ),
            ),
            SizedBox(height: 10),
            
            // Test Button 4: Run All Tests
            ElevatedButton(
              onPressed: _isTesting ? null : _runAllTests,
              child: Text('Run All Tests'),
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.symmetric(vertical: 15),
                backgroundColor: Colors.green,
              ),
            ),
            SizedBox(height: 10),
            
            // Test Button 5: Clear All
            ElevatedButton(
              onPressed: _isTesting ? null : _clearNotifications,
              child: Text('Clear Semua Notifikasi'),
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.symmetric(vertical: 15),
                backgroundColor: Colors.red,
              ),
            ),
            SizedBox(height: 20),
            
            if (_isTesting)
              Column(
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 10),
                  Text('Testing in progress...'),
                ],
              ),
            
            Spacer(),
            
            // Debug Info
            Card(
              color: Colors.grey[100],
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Debug Info:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 8),
                    Text('Service Initialized: ${_inboxNotifier.isInitialized}'),
                    Text('Platform: Android'),
                    SizedBox(height: 8),
                    Text(
                      'Instruksi:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text('1. Pastikan app tidak di-force close'),
                    Text('2. Buka panel notifikasi Android'),
                    Text('3. Cek apakah notifikasi muncul'),
                    Text('4. Test satu per satu untuk debug'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _testBasicNotification() async {
    setState(() => _isTesting = true);
    try {
      await _inboxNotifier.testNotification();
      _showSuccess('Notifikasi dasar berhasil dikirim!');
    } catch (e) {
      _showError('Error: $e');
    }
    setState(() => _isTesting = false);
  }

  Future<void> _testMultipleNotifications() async {
    setState(() => _isTesting = true);
    try {
      // Simulasi beberapa unread count
      await _inboxNotifier.checkAndNotifyNewMessages(1);
      await Future.delayed(Duration(seconds: 1));
      await _inboxNotifier.checkAndNotifyNewMessages(3);
      await Future.delayed(Duration(seconds: 1));
      await _inboxNotifier.checkAndNotifyNewMessages(5);
      
      _showSuccess('Multiple notifikasi berhasil dikirim!');
    } catch (e) {
      _showError('Error: $e');
    }
    setState(() => _isTesting = false);
  }

  Future<void> _testInboxSimulation() async {
    setState(() => _isTesting = true);
    try {
      // Simulasi inbox dengan berbagai jumlah pesan
      await _inboxNotifier.checkAndNotifyNewMessages(2);
      _showSuccess('Simulasi inbox berhasil!');
    } catch (e) {
      _showError('Error: $e');
    }
    setState(() => _isTesting = false);
  }

  Future<void> _runAllTests() async {
    setState(() => _isTesting = true);
    try {
      await _testBasicNotification();
      await Future.delayed(Duration(seconds: 2));
      await _testMultipleNotifications();
      await Future.delayed(Duration(seconds: 2));
      await _testInboxSimulation();
      
      _showSuccess('Semua test berhasil dijalankan!');
    } catch (e) {
      _showError('Error: $e');
    }
    setState(() => _isTesting = false);
  }

  Future<void> _clearNotifications() async {
    setState(() => _isTesting = true);
    try {
      // Reset counter
      _inboxNotifier.resetCounter();
      _showSuccess('Counter notifikasi direset!');
    } catch (e) {
      _showError('Error: $e');
    }
    setState(() => _isTesting = false);
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 3),
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: Duration(seconds: 5),
      ),
    );
  }
}
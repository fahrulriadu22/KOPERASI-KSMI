// lib/services/global_session_checker.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'device_service.dart';
import 'session_manager.dart';
import '../screens/login_screen.dart';
import 'api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class GlobalSessionChecker {
  static final GlobalSessionChecker _instance = GlobalSessionChecker._internal();
  factory GlobalSessionChecker() => _instance;
  GlobalSessionChecker._internal();

  Timer? _sessionTimer;
  bool _isChecking = false;
  BuildContext? _currentContext;
  int _consecutiveErrors = 0; // ✅ TRACK ERROR BERUNTUN
  DateTime? _lastSuccessfulCheck; // ✅ TRACK LAST SUCCESS

  // ✅ START SESSION CHECKER DENGAN INTERVAL LEBIH PANJANG
  void startSessionChecker(BuildContext context) {
    _currentContext = context;
    _stopSessionChecker(); // Stop existing timer first
    
    print('🔄 Starting global session checker (interval: 5 minutes)...');
    
    _sessionTimer = Timer.periodic(const Duration(minutes: 5), (timer) async { // ✅ 5 MENIT!
      if (_isChecking) return;
      
      _isChecking = true;
      try {
        await _performSessionCheck();
      } catch (e) {
        print('❌ Global session check error: $e');
        _consecutiveErrors++;
        
        // ✅ JANGAN LOGOUT KALAU ERROR NETWORK BERUNTUN
        if (_consecutiveErrors >= 3) {
          print('⚠️ Multiple consecutive errors, pausing checks for 10 minutes');
          _stopSessionChecker();
          // Auto restart setelah 10 menit
          Timer(const Duration(minutes: 10), () {
            if (_currentContext != null) {
              startSessionChecker(_currentContext!);
            }
          });
        }
      } finally {
        _isChecking = false;
      }
    });
  }

  // ✅ STOP SESSION CHECKER
  void _stopSessionChecker() {
    _sessionTimer?.cancel();
    _sessionTimer = null;
    print('🛑 Global session checker stopped');
  }

  void stopSessionChecker() {
    _stopSessionChecker();
    _currentContext = null;
    _consecutiveErrors = 0; // ✅ RESET ERROR COUNTER
  }

  Future<void> _performSessionCheck() async {
    try {
      print('🔍 Performing ULTIMATE session check...');
      
      // ✅ 1. CEK TOKEN DULU
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      
      if (token == null || token.isEmpty) {
        print('🚨 No token found');
        _handleSessionExpired();
        return;
      }

      // ✅ 2. GUNAKAN API SALDO UNTUK CHECK (KARENA DI LOG SALDO RETURN 401)
      final apiService = ApiService();
      final saldoResult = await apiService.getAllSaldo();
      
      // ✅ 3. JIKA SALDO RETURN 401 ATAU TOKEN_EXPIRED - LANGSUNG LOGOUT!
      if (saldoResult['token_expired'] == true || 
          saldoResult['status_code'] == 401 ||
          (saldoResult['success'] == false && 
           saldoResult['message']?.toString().toLowerCase().contains('authorized') == true)) {
        
        print('🚨 SALDO API RETURN 401 - FORCE LOGOUT');
        _handleSessionExpired();
        return;
      }
      
      // ✅ 4. JIKA DATA SALDO KOSONG - CURIGAI MULTI DEVICE
      final saldoData = saldoResult['data'] ?? {};
      if (saldoData.isEmpty) {
        print('⚠️ Empty saldo data - possible multi-device');
        // Biarkan user tetap login, tapi log warning
      }
      
      // ✅ 5. RESET ERROR COUNTER KALAU SUCCESS
      _consecutiveErrors = 0;
      _lastSuccessfulCheck = DateTime.now();
      
      print('✅ Session check passed');
      
    } catch (e) {
      print('❌ Session check error: $e');
      _consecutiveErrors++;
      
      // ✅ HANYA LOGOUT UNTUK 401
      if (e.toString().contains('401') || e.toString().contains('unauthorized')) {
        _handleSessionExpired();
      }
    }
  }

  // ✅ ✅✅ PERBAIKAN: CHECK MULTI DEVICE LOGIN YANG LEBIH TOLERAN
  Future<void> _checkMultiDeviceLogin() async {
    try {
      final userData = await SessionManager.getUserData();
      final userId = userData?['user_id']?.toString() ?? userData?['id']?.toString() ?? '';
      
      if (userId.isEmpty) {
        print('⚠️ No user ID found for multi-device check');
        return;
      }

      final isOtherDeviceLogin = await DeviceService.detectOtherDeviceLogin(userId);
      
      if (isOtherDeviceLogin) {
        print('🚨 Multi-device login detected - showing confirmation');
        _showMultiDeviceConfirmationDialog();
      }
    } catch (e) {
      print('❌ Multi-device check error: $e');
      // JANGAN LOGOUT KALAU ERROR CHECK MULTI DEVICE
    }
  }

  // ✅ PERBAIKAN: HANDLE SESSION EXPIRED - LANGSUNG LOGOUT TANPA DIALOG
  void _handleSessionExpired() {
    print('🔐 Session expired - forcing immediate logout');
    stopSessionChecker();
    _performImmediateLogout();
  }

    // ✅ TAMBAHIN: IMMEDIATE LOGOUT TANPA DIALOG
  void _performImmediateLogout() async {
    try {
      print('🔐 Performing IMMEDIATE logout...');
      
      // ✅ CLEAR SEMUA DATA
      await SessionManager.clearSession();
      await DeviceService.clearSession();
      
      // ✅ FORCE NAVIGATE KE LOGIN
      if (_currentContext != null && _currentContext!.mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          Navigator.of(_currentContext!).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => LoginScreen()),
            (route) => false,
          );
        });
      }
      
      print('✅ Immediate logout completed');
    } catch (e) {
      print('❌ Immediate logout error: $e');
      // Fallback navigation
      if (_currentContext != null && _currentContext!.mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          Navigator.of(_currentContext!).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => LoginScreen()),
            (route) => false,
          );
        });
      }
    }
  }

  // ✅ TAMBAHIN: FORCE LOGOUT METHOD UNTUK DIPANGGIL DARI LUAR
  void forceLogout() {
    print('🔐 Force logout triggered');
    _handleSessionExpired();
  }

  // ✅ ✅✅ PERBAIKAN: DIALOG KONFIRMASI UNTUK MULTI DEVICE
  void _showMultiDeviceConfirmationDialog() {
    if (_currentContext == null) {
      print('❌ No context available for dialog');
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      showDialog(
        context: _currentContext!,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.orange),
              SizedBox(width: 8),
              Text('Login dari Device Lain'),
            ],
          ),
          content: const Text(
            'Terdeteksi login dari device lain. Apakah ini Anda?\n\n'
            'Jika ini bukan Anda, pilih "Logout" untuk keamanan akun.'
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                print('✅ User confirmed this is their device');
                // Update session untuk device saat ini
                DeviceService.updateLastLoginTime();
              },
              child: const Text('Ini Saya'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _handleSessionExpired();
              },
              child: const Text('Logout', style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      );
    });
  }

  // ✅ SHOW GLOBAL SESSION EXPIRED DIALOG
  void _showGlobalSessionExpiredDialog() {
    if (_currentContext == null) {
      print('❌ No context available for dialog');
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      showDialog(
        context: _currentContext!,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('Sesi Berakhir'),
          content: const Text(
            'Sesi login Anda telah berakhir. '
            'Silakan login kembali untuk melanjutkan.'
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _performGlobalLogout();
              },
              child: const Text('OK'),
            ),
          ],
        ),
      );
    });
  }

  // ✅ PERFORM GLOBAL LOGOUT
  void _performGlobalLogout() async {
    try {
      print('🔐 Performing global logout...');
      
      await SessionManager.clearSession();
      await DeviceService.clearSession();
      
      if (_currentContext != null && _currentContext!.mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          Navigator.of(_currentContext!).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => LoginScreen()),
            (route) => false,
          );
        });
      }
      
      print('✅ Global logout completed');
    } catch (e) {
      print('❌ Global logout error: $e');
      if (_currentContext != null && _currentContext!.mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          Navigator.of(_currentContext!).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => LoginScreen()),
            (route) => false,
          );
        });
      }
    }
  }

  // ✅ GETTERS
  bool get isRunning => _sessionTimer != null;
  BuildContext? get currentContext => _currentContext;
  int get consecutiveErrors => _consecutiveErrors;
  DateTime? get lastSuccessfulCheck => _lastSuccessfulCheck;
}

// Global instance
final globalSessionChecker = GlobalSessionChecker();
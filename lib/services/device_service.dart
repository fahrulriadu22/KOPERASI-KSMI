// lib/services/device_service.dart
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io' show Platform;
import 'package:device_info_plus/device_info_plus.dart';

class DeviceService {
  static const String _keyDeviceId = 'current_device_id';
  static const String _keyLastLogin = 'last_login_timestamp';
  static const String _keyLoginSession = 'login_session_id';
  static const String _keyUserId = 'current_user_id';

  // ✅ GENERATE UNIQUE DEVICE ID
  static Future<String> getDeviceId() async {
    try {
      final deviceInfo = DeviceInfoPlugin();
      
      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        return 'android_${androidInfo.id}';
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        return 'ios_${iosInfo.identifierForVendor}';
      } else {
        // Fallback untuk web/desktop
        final prefs = await SharedPreferences.getInstance();
        String? storedId = prefs.getString(_keyDeviceId);
        if (storedId == null) {
          storedId = 'web_${DateTime.now().millisecondsSinceEpoch}';
          await prefs.setString(_keyDeviceId, storedId);
        }
        return storedId;
      }
    } catch (e) {
      // Ultimate fallback
      return 'device_${DateTime.now().millisecondsSinceEpoch}';
    }
  }

  // ✅ SIMPAN SESSION INFO SAAT LOGIN
  static Future<void> saveLoginSession(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final deviceId = await getDeviceId();
      final sessionId = '${userId}_${DateTime.now().millisecondsSinceEpoch}';
      
      await prefs.setString(_keyDeviceId, deviceId);
      await prefs.setString(_keyLoginSession, sessionId);
      await prefs.setString(_keyUserId, userId);
      await prefs.setString(_keyLastLogin, DateTime.now().toIso8601String());
      
      print('🔐 Login session saved - Device: $deviceId, Session: $sessionId, User: $userId');
    } catch (e) {
      print('❌ Error saving login session: $e');
    }
  }

  // ✅ CEK SESSION VALIDITY
  static Future<bool> isSessionValid() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final storedDeviceId = prefs.getString(_keyDeviceId);
      final currentDeviceId = await getDeviceId();
      final sessionId = prefs.getString(_keyLoginSession);
      final userId = prefs.getString(_keyUserId);
      
      print('''
🔍 Session Check:
  - Stored Device: $storedDeviceId
  - Current Device: $currentDeviceId  
  - Session ID: ${sessionId != null ? 'Exists' : 'Null'}
  - User ID: $userId
''');

      // ✅ JIKA BELUM PERNAH LOGIN, ANGGAP VALID
      if (storedDeviceId == null && sessionId == null && userId == null) {
        print('✅ First time login - session valid');
        return true;
      }
      
      // ✅ JIKA DEVICE BERBEDA
      if (storedDeviceId != currentDeviceId) {
        print('⚠️ Device changed, checking if same app instance...');
        final lastLogin = prefs.getString(_keyLastLogin);
        if (lastLogin != null) {
          try {
            final lastLoginTime = DateTime.parse(lastLogin);
            final now = DateTime.now();
            final difference = now.difference(lastLoginTime);
            
            if (difference.inMinutes < 5) {
              print('✅ Device changed but within 5 minutes - session valid');
              await prefs.setString(_keyDeviceId, currentDeviceId);
              return true;
            }
          } catch (e) {
            print('❌ Error parsing last login time: $e');
          }
        }
        
        print('🚨 Device changed significantly - session invalid');
        return false;
      }
      
      // ✅ CEK SESSION ID
      if (sessionId == null) {
        print('⚠️ No session ID found');
        return false;
      }
      
      print('✅ Session valid');
      return true;
    } catch (e) {
      print('❌ Error checking session validity: $e');
      return true;
    }
  }

  // ✅ CEK APAKAH USER SAMA
  static Future<bool> isSameUser(String currentUserId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final storedUserId = prefs.getString(_keyUserId);
      
      if (storedUserId == null) {
        await prefs.setString(_keyUserId, currentUserId);
        return true;
      }
      
      return storedUserId == currentUserId;
    } catch (e) {
      print('❌ Error checking same user: $e');
      return true;
    }
  }

  // ✅ PERBAIKAN: DETECT OTHER DEVICE LOGIN - LEBIH SENSITIF
  static Future<bool> detectOtherDeviceLogin(String currentUserId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final storedUserId = prefs.getString(_keyUserId);
      final lastLogin = prefs.getString(_keyLastLogin);
      
      print('''
🔍 Multi Device Check:
  - Stored User: $storedUserId
  - Current User: $currentUserId  
  - Last Login: $lastLogin
''');

      // ✅ JIKA USER BERBEDA - LANGSUNG LOGOUT!
      if (storedUserId != null && storedUserId != currentUserId) {
        print('🚨 REAL MULTI-DEVICE: Different user detected - FORCE LOGOUT');
        return true;
      }

      // ✅ JIKA USER SAMA TAPI LAST LOGIN LAMA - MUNGKIN MULTI DEVICE
      if (lastLogin != null && storedUserId == currentUserId) {
        try {
          final lastLoginTime = DateTime.parse(lastLogin);
          final now = DateTime.now();
          final difference = now.difference(lastLoginTime);
          
          // Jika lebih dari 10 menit tidak update, curigai multi-device
          if (difference.inMinutes > 10) {
            print('⚠️ Last login > 10 minutes ago - possible multi-device');
            // Update waktu tapi return true untuk trigger check
            await updateLastLoginTime();
            return false; // Jangan logout dulu, biarkan session checker yang handle
          }
        } catch (e) {
          print('❌ Error parsing last login time: $e');
        }
      }

      // ✅ UPDATE WAKTU DAN LANJUT
      await updateLastLoginTime();
      print('✅ Same user & device - session valid');
      return false;
      
    } catch (e) {
      print('❌ Error detecting other device login: $e');
      return false;
    }
  }

  // ✅ CLEAR SESSION SAAT LOGOUT
  static Future<void> clearSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyLoginSession);
      await prefs.remove(_keyLastLogin);
      await prefs.remove(_keyUserId);
      print('🧹 Session cleared completely');
    } catch (e) {
      print('❌ Error clearing session: $e');
    }
  }

    static Future<void> saveAppCloseTime() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('last_app_close', DateTime.now().toIso8601String());
      print('📱 App closing time saved');
    } catch (e) {
      print('❌ Error saving app close time: $e');
    }
  }

    static Future<String> getCurrentDeviceId() async {
    return await getDeviceId();
  }

  // ✅ METHOD BARU: CLEAR DEVICE SESSION
  static Future<void> clearDeviceSession(String userId, String deviceId) async {
    try {
      print('🧹 Clearing device session for user: $userId, device: $deviceId');
      await clearSession();
    } catch (e) {
      print('❌ Error clearing device session: $e');
    }
  }

  // ✅ METHOD BARU: UPDATE DEVICE SESSION
  static Future<void> updateDeviceSession(String userId, String deviceId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyDeviceId, deviceId);
      await prefs.setString(_keyUserId, userId);
      await prefs.setString(_keyLastLogin, DateTime.now().toIso8601String());
      
      print('✅ Device session updated - User: $userId, Device: $deviceId');
    } catch (e) {
      print('❌ Error updating device session: $e');
    }
  }

  // ✅ METHOD BARU: GET CURRENT SESSION INFO (HAPUS STATIC)
  Future<Map<String, dynamic>> getSessionInfo() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return {
        'deviceId': prefs.getString(_keyDeviceId),
        'sessionId': prefs.getString(_keyLoginSession),
        'userId': prefs.getString(_keyUserId),
        'lastLogin': prefs.getString(_keyLastLogin),
      };
    } catch (e) {
      print('❌ Error getting session info: $e');
      return {};
    }
  }

  // ✅ METHOD BARU: UPDATE LAST LOGIN TIME
  static Future<void> updateLastLoginTime() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyLastLogin, DateTime.now().toIso8601String());
      print('🕒 Last login time updated');
    } catch (e) {
      print('❌ Error updating last login time: $e');
    }
  }
}
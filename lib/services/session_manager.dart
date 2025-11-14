import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class SessionManager {
  static const String _keyToken = 'token';
  static const String _keyUserData = 'user';
  static const String _keyIsLoggedIn = 'isLoggedIn';
  static const String _keyUsername = 'username';

  // ✅ SAVE LOGIN SESSION (compatible with ApiService)
  static Future<void> saveLoginSession(String token, Map<String, dynamic> userData) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyToken, token);
    await prefs.setString(_keyUserData, jsonEncode(userData));
    await prefs.setBool(_keyIsLoggedIn, true);
    await prefs.setString(_keyUsername, userData['username'] ?? '');
  }

  // ✅ CLEAR SESSION (logout)
  static Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyToken);
    await prefs.remove(_keyUserData);
    await prefs.remove(_keyIsLoggedIn);
    await prefs.remove(_keyUsername);
  }

  // ✅ CHECK LOGIN STATUS
  static Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyIsLoggedIn) ?? false;
  }

  // ✅ GET TOKEN
  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyToken);
  }

  // ✅ GET USERNAME
  static Future<String?> getUsername() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyUsername);
  }

  // ✅ GET USER DATA
  static Future<Map<String, dynamic>?> getUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userDataString = prefs.getString(_keyUserData);
      if (userDataString != null) {
        return Map<String, dynamic>.from(jsonDecode(userDataString));
      }
      return null;
    } catch (e) {
      print('❌ Error getting user data: $e');
      return null;
    }
  }

  // ✅ UPDATE USER DATA
  static Future<void> updateUserData(Map<String, dynamic> newUserData) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyUserData, jsonEncode(newUserData));
    
    // Update username juga jika ada
    if (newUserData['username'] != null) {
      await prefs.setString(_keyUsername, newUserData['username']);
    }
  }

  // ✅ GET SPECIFIC USER FIELD
  static Future<dynamic> getUserField(String field) async {
    final userData = await getUserData();
    return userData?[field];
  }

  // ✅ CHECK IF USER HAS UPLOADED DOCUMENTS
  static Future<bool> hasUploadedDocuments() async {
    final userData = await getUserData();
    final ktpPath = userData?['ktpPath'];
    final kkPath = userData?['kkPath'];
    
    return ktpPath != null && ktpPath.isNotEmpty && 
           kkPath != null && kkPath.isNotEmpty;
  }
}
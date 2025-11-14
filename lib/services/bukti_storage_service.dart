import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class BuktiStorageService {
  static const String _buktiKey = 'uploaded_bukti_ids';
  static const String _buktiDetailsKey = 'uploaded_bukti_details';

  // ✅ GET ALL UPLOADED BUKTI IDs
  static Future<Set<String>> getUploadedBuktiIds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_buktiKey);
      if (jsonString != null && jsonString.isNotEmpty) {
        final list = jsonDecode(jsonString) as List;
        print('✅ Loaded ${list.length} bukti IDs from storage');
        return Set<String>.from(list);
      }
    } catch (e) {
      print('❌ Error loading bukti IDs: $e');
    }
    return <String>{};
  }

  // ✅ SAVE BUKTI ID
  static Future<void> saveBuktiId(String transactionId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final existingIds = await getUploadedBuktiIds();
      existingIds.add(transactionId);
      
      await prefs.setString(_buktiKey, jsonEncode(existingIds.toList()));
      print('✅ Saved bukti ID: $transactionId');
      print('📊 Total bukti IDs stored: ${existingIds.length}');
    } catch (e) {
      print('❌ Error saving bukti ID: $e');
      rethrow;
    }
  }

  // ✅ REMOVE BUKTI ID (jika perlu)
  static Future<void> removeBuktiId(String transactionId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final existingIds = await getUploadedBuktiIds();
      existingIds.remove(transactionId);
      
      await prefs.setString(_buktiKey, jsonEncode(existingIds.toList()));
      print('✅ Removed bukti ID: $transactionId');
    } catch (e) {
      print('❌ Error removing bukti ID: $e');
      rethrow;
    }
  }

  // ✅ CLEAR ALL BUKTI DATA (untuk debug/reset)
  static Future<void> clearAllBuktiData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_buktiKey);
      await prefs.remove(_buktiDetailsKey);
      print('✅ Cleared all bukti storage data');
    } catch (e) {
      print('❌ Error clearing bukti data: $e');
      rethrow;
    }
  }

  // ✅ CHECK IF BUKTI EXISTS FOR TRANSACTION
  static Future<bool> hasBukti(String transactionId) async {
    try {
      final ids = await getUploadedBuktiIds();
      final hasBukti = ids.contains(transactionId);
      print('🔍 Check bukti for $transactionId: $hasBukti');
      return hasBukti;
    } catch (e) {
      print('❌ Error checking bukti: $e');
      return false;
    }
  }

  // ✅ GET UPLOADED BUKTI COUNT
  static Future<int> getBuktiCount() async {
    try {
      final ids = await getUploadedBuktiIds();
      return ids.length;
    } catch (e) {
      print('❌ Error getting bukti count: $e');
      return 0;
    }
  }

  // ✅ GET ALL UPLOADED BUKTI DETAILS (advanced)
  static Future<Map<String, dynamic>> getBuktiDetails() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_buktiDetailsKey);
      if (jsonString != null && jsonString.isNotEmpty) {
        final details = jsonDecode(jsonString) as Map<String, dynamic>;
        print('✅ Loaded bukti details for ${details.length} transactions');
        return details;
      }
    } catch (e) {
      print('❌ Error loading bukti details: $e');
    }
    return {};
  }

  // ✅ SAVE BUKTI DETAILS (advanced - dengan timestamp dll)
  static Future<void> saveBuktiDetails({
    required String transactionId,
    required String fileName,
    required int fileSize,
    required String uploadTime,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final existingDetails = await getBuktiDetails();
      
      existingDetails[transactionId] = {
        'file_name': fileName,
        'file_size': fileSize,
        'upload_time': uploadTime,
        'transaction_id': transactionId,
      };
      
      await prefs.setString(_buktiDetailsKey, jsonEncode(existingDetails));
      print('✅ Saved bukti details for: $transactionId');
    } catch (e) {
      print('❌ Error saving bukti details: $e');
      rethrow;
    }
  }

  // ✅ DEBUG: PRINT ALL STORED DATA
  static Future<void> debugPrintStoredData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final ids = await getUploadedBuktiIds();
      final details = await getBuktiDetails();
      
      print('🔍 === BUKTI STORAGE DEBUG ===');
      print('📊 Stored IDs: $ids');
      print('📊 Stored Details: $details');
      print('📊 Total IDs: ${ids.length}');
      print('📊 Total Details: ${details.length}');
      print('🔍 === END DEBUG ===');
    } catch (e) {
      print('❌ Debug error: $e');
    }
  }
}
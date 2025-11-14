import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
// ✅ TAMBAH IMPORT INI DI ATAS local_image_service.dart
import '../services/api_service.dart'; // ✅ UNTUK AKSES ApiService

class LocalImageService {
  static final LocalImageService _instance = LocalImageService._internal();
  factory LocalImageService() => _instance;
  LocalImageService._internal();

  // ✅ SIMPAN IMAGE KE LOCAL STORAGE
  Future<File?> saveNetworkImage(String imageUrl, String filename) async {
    try {
      print('💾 Saving network image to local: $filename');
      
      // ✅ DOWNLOAD IMAGE DARI URL
      final response = await http.get(
        Uri.parse(imageUrl),
        headers: {
          'User-Agent': 'KoperasiApp/1.0',
          'Accept': 'image/jpeg, image/png, image/*',
        },
      );

      if (response.statusCode == 200) {
        // ✅ DAPATKAN DIRECTORY UNTUK SIMPAN FILE
        final directory = await getApplicationDocumentsDirectory();
        final filePath = '${directory.path}/profile_images/$filename';
        
        // ✅ BUAT DIRECTORY JIKA BELUM ADA
        final fileDir = Directory('${directory.path}/profile_images');
        if (!await fileDir.exists()) {
          await fileDir.create(recursive: true);
        }

        // ✅ SIMPAN FILE
        final file = File(filePath);
        await file.writeAsBytes(response.bodyBytes);
        
        // ✅ SIMPAN PATH KE SHARED PREFERENCES
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('local_$filename', filePath);
        
        print('✅ Image saved locally: $filePath');
        return file;
      } else {
        print('❌ Failed to download image: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('❌ Error saving image locally: $e');
      return null;
    }
  }

  // ✅ LOAD IMAGE DARI LOCAL STORAGE
  Future<File?> getLocalImage(String filename) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final filePath = prefs.getString('local_$filename');
      
      if (filePath != null) {
        final file = File(filePath);
        if (await file.exists()) {
          print('✅ Loaded image from local storage: $filename');
          return file;
        } else {
          // ✅ HAPUS KEY JIKA FILE TIDAK ADA
          await prefs.remove('local_$filename');
        }
      }
      return null;
    } catch (e) {
      print('❌ Error loading local image: $e');
      return null;
    }
  }

  // ✅ CEK APAKAH IMAGE SUDAH ADA DI LOCAL
  Future<bool> hasLocalImage(String filename) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final filePath = prefs.getString('local_$filename');
      
      if (filePath != null) {
        final file = File(filePath);
        return await file.exists();
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  // ✅ DELETE IMAGE DARI LOCAL STORAGE
  Future<void> deleteLocalImage(String filename) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final filePath = prefs.getString('local_$filename');
      
      if (filePath != null) {
        final file = File(filePath);
        if (await file.exists()) {
          await file.delete();
        }
        await prefs.remove('local_$filename');
        print('✅ Deleted local image: $filename');
      }
    } catch (e) {
      print('❌ Error deleting local image: $e');
    }
  }

  // ✅ CLEAN UP OLD IMAGES
  Future<void> cleanupOldImages() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final imageDir = Directory('${directory.path}/profile_images');
      
      if (await imageDir.exists()) {
        final files = imageDir.listSync();
        final now = DateTime.now();
        
        for (var file in files) {
          if (file is File) {
            final stat = await file.stat();
            final age = now.difference(stat.modified);
            
            // ✅ HAPUS FILE YANG LEBIH DARI 7 HARI
            if (age.inDays > 7) {
              await file.delete();
              print('🧹 Cleaned up old image: ${file.path}');
            }
          }
        }
      }
    } catch (e) {
      print('❌ Error cleaning up images: $e');
    }
  }

  // ✅ TAMBAH METHOD INI DI LocalImageService - SETELAH cleanupOldImages()

// ✅ METHOD BARU: DOWNLOAD GAMBAR VIA API DENGAN AUTHENTICATION
Future<File?> saveProfileImageFromApi(String filename) async {
  try {
    // ✅ IMPORT ApiService - TAMBAH INI DI ATAS FILE
    // import '../services/api_service.dart';
    final apiService = ApiService();
    
    print('💾 Downloading profile image via API: $filename');
    
    // ✅ DOWNLOAD DARI API DENGAN AUTHENTICATION
    final imageBytes = await apiService.downloadProfileImage(filename);
    
    if (imageBytes != null && imageBytes.isNotEmpty) {
      // ✅ SIMPAN KE LOCAL STORAGE
      final directory = await getApplicationDocumentsDirectory();
      final filePath = '${directory.path}/profile_images/$filename';
      
      final fileDir = Directory('${directory.path}/profile_images');
      if (!await fileDir.exists()) {
        await fileDir.create(recursive: true);
      }

      final file = File(filePath);
      await file.writeAsBytes(imageBytes);
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('local_$filename', filePath);
      
      print('✅ Profile image saved via API: $filePath (${imageBytes.length} bytes)');
      return file;
    } else {
      print('❌ No image data received from API');
      return null;
    }
  } catch (e) {
    print('❌ Error saving profile image via API: $e');
    return null;
  }
}
}
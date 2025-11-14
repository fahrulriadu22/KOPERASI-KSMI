import 'dart:io';
import 'package:http_parser/http_parser.dart';

class FileValidator {
  // ✅ VALIDASI FILE UNTUK UPLOAD - DIPERBAIKI & DIBUAT LEBIH TOLERAN
  static Future<Map<String, dynamic>> validateImageFile(String filePath) async {
    try {
      File file = File(filePath);
      
      print('🔍 === FILE VALIDATION START ===');
      print('📁 File path: $filePath');
      
      // Check if file exists
      if (!await file.exists()) {
        print('❌ File tidak ditemukan');
        return {
          'valid': false, 
          'message': 'File tidak ditemukan',
          'error_code': 'FILE_NOT_FOUND'
        };
      }

      // Check file size (max 10MB - lebih longgar)
      int fileSize = await file.length();
      print('📊 File size: $fileSize bytes (${(fileSize / 1024 / 1024).toStringAsFixed(2)}MB)');
      
      if (fileSize == 0) {
        print('❌ File kosong');
        return {
          'valid': false, 
          'message': 'File kosong atau tidak dapat dibaca',
          'error_code': 'EMPTY_FILE'
        };
      }

      // ✅ RELAX: Max 10MB (dari 5MB)
      if (fileSize > 10 * 1024 * 1024) {
        print('❌ File terlalu besar');
        return {
          'valid': false, 
          'message': 'Ukuran file terlalu besar (${(fileSize / 1024 / 1024).toStringAsFixed(2)}MB). Maksimal 10MB.',
          'error_code': 'FILE_TOO_LARGE',
          'file_size': fileSize
        };
      }

      // Check file extension - DIPERBOLEHKAN PNG & JPG
      String extension = filePath.split('.').last.toLowerCase();
      print('📄 File extension: $extension');
      
      // ✅ RELAX: Support PNG juga
      if (extension != 'jpg' && extension != 'jpeg' && extension != 'png') {
        print('❌ Format tidak didukung: $extension');
        return {
          'valid': false, 
          'message': 'Format file .$extension tidak didukung. Gunakan JPG, JPEG, atau PNG.',
          'error_code': 'INVALID_EXTENSION',
          'extension': extension
        };
      }

      // Check MIME type dengan validasi yang lebih toleran
      List<int> bytes = await file.readAsBytes();
      String mimeType = _getMimeType(bytes);
      print('🎯 MIME type detected: $mimeType');
      
      // ✅ RELAX: Terima PNG juga
      if (mimeType != 'image/jpeg' && mimeType != 'image/png') {
        print('❌ MIME type tidak valid: $mimeType');
        return {
          'valid': false, 
          'message': 'File harus berupa gambar JPEG atau PNG yang valid.',
          'error_code': 'INVALID_MIME_TYPE',
          'mime_type': mimeType
        };
      }

      print('✅ FILE VALIDATION SUCCESS');
      return {
        'valid': true, 
        'message': 'File valid',
        'file_size': fileSize,
        'extension': extension,
        'mime_type': mimeType
      };
    } catch (e) {
      print('❌ Validation error: $e');
      return {
        'valid': false, 
        'message': 'Error validasi file: ${e.toString()}',
        'error_code': 'VALIDATION_ERROR'
      };
    }
  }

  // ✅ VALIDASI UNTUK BUKTI TRANSFER - DIPERBAIKI & DIBUAT LEBIH TOLERAN
  static Future<Map<String, dynamic>> validateBuktiTransfer(String filePath) async {
    print('🔄 === BUKTI TRANSFER VALIDATION START ===');
    
    final result = await validateImageFile(filePath);
    if (!result['valid']) {
      print('❌ Basic validation failed');
      return result;
    }

    // Additional validation for transfer proof - DIPERBAIKI
    try {
      File file = File(filePath);
      final fileSize = await file.length();
      
      print('📊 Additional validation - File size: $fileSize bytes');
      
      // ✅ RELAX: Minimum size hanya 1KB (dari 10KB)
      if (fileSize < 1 * 1024) { // 1KB minimum saja
        print('❌ File terlalu kecil: $fileSize bytes');
        return {
          'valid': false,
          'message': 'File terlalu kecil. Pastikan gambar memiliki kualitas yang cukup.',
          'error_code': 'LOW_QUALITY',
          'file_size': fileSize
        };
      }

      // ✅ HAPUS VALIDASI KUALITAS GAMBAR YANG TERLALU KETAT
      // Tidak perlu cek dimensi gambar atau kualitas visual
      
      print('✅ BUKTI TRANSFER VALIDATION SUCCESS');
      return {
        'valid': true,
        'message': 'Bukti transfer valid',
        'file_size': fileSize,
        'extension': result['extension'],
        'mime_type': result['mime_type']
      };
    } catch (e) {
      print('❌ Additional validation error: $e');
      return {
        'valid': false,
        'message': 'Error validasi tambahan: ${e.toString()}',
        'error_code': 'ADDITIONAL_VALIDATION_ERROR'
      };
    }
  }

  // ✅ DETEKSI MIME TYPE DARI BYTES - DIPERBAIKI
  static String _getMimeType(List<int> bytes) {
    if (bytes.length < 2) return 'unknown';
    
    // Check JPEG signature (FF D8 FF)
    if (bytes.length >= 3 && 
        bytes[0] == 0xFF && 
        bytes[1] == 0xD8 && 
        bytes[2] == 0xFF) {
      return 'image/jpeg';
    }
    
    // Check PNG signature
    if (bytes.length >= 8 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47 &&
        bytes[4] == 0x0D &&
        bytes[5] == 0x0A &&
        bytes[6] == 0x1A &&
        bytes[7] == 0x0A) {
      return 'image/png';
    }
    
    // Check for other common image formats
    if (bytes.length >= 4) {
      // GIF
      if (bytes[0] == 0x47 && bytes[1] == 0x49 && bytes[2] == 0x46) {
        return 'image/gif';
      }
      // BMP
      if (bytes[0] == 0x42 && bytes[1] == 0x4D) {
        return 'image/bmp';
      }
      // WEBP
      if (bytes[0] == 0x52 && bytes[1] == 0x49 && bytes[2] == 0x46 && bytes[3] == 0x46) {
        return 'image/webp';
      }
    }
    
    return 'unknown';
  }

  // ✅ GET FILE INFO UNTUK DEBUG - DIPERBAIKI
  static Future<Map<String, dynamic>> getFileInfo(String filePath) async {
    try {
      File file = File(filePath);
      final stat = await file.stat();
      final bytes = await file.readAsBytes();
      final mimeType = _getMimeType(bytes);
      
      final info = {
        'exists': await file.exists(),
        'size': stat.size,
        'size_kb': (stat.size / 1024).toStringAsFixed(2),
        'size_mb': (stat.size / 1024 / 1024).toStringAsFixed(2),
        'modified': stat.modified.toString(),
        'extension': filePath.split('.').last.toLowerCase(),
        'mime_type': mimeType,
        'path': filePath,
        'filename': filePath.split('/').last,
        'is_valid_jpeg': mimeType == 'image/jpeg',
        'is_valid_png': mimeType == 'image/png',
        'is_valid_image': mimeType.startsWith('image/'),
        'needs_conversion': mimeType != 'image/jpeg' && mimeType != 'image/png'
      };
      
      print('📄 === FILE INFO ===');
      print('   - Exists: ${info['exists']}');
      print('   - Size: ${info['size_kb']} KB');
      print('   - Extension: ${info['extension']}');
      print('   - MIME Type: ${info['mime_type']}');
      print('   - Valid JPEG: ${info['is_valid_jpeg']}');
      print('   - Valid PNG: ${info['is_valid_png']}');
      print('📄 === END FILE INFO ===');
      
      return info;
    } catch (e) {
      print('❌ Error getting file info: $e');
      return {
        'error': e.toString(),
        'exists': false
      };
    }
  }

  // ✅ METHOD BARU: Quick validation untuk UI
  static Future<bool> isFileValid(String filePath) async {
    final result = await validateImageFile(filePath);
    return result['valid'] == true;
  }

  // ✅ METHOD BARU: Get allowed extensions
  static List<String> getAllowedExtensions() {
    return ['jpg', 'jpeg', 'png']; // ✅ TAMBAH PNG
  }

  // ✅ METHOD BARU: Get max file size
  static int getMaxFileSize() {
    return 10 * 1024 * 1024; // ✅ 10MB (dari 5MB)
  }

  // ✅ METHOD BARU: Get min file size  
  static int getMinFileSize() {
    return 1 * 1024; // ✅ 1KB minimum (dari 10KB)
  }

  // ✅ METHOD BARU: Simple validation tanpa error message
  static Future<bool> quickValidate(String filePath) async {
    try {
      File file = File(filePath);
      if (!await file.exists()) return false;
      
      final size = await file.length();
      if (size < getMinFileSize() || size > getMaxFileSize()) return false;
      
      final ext = filePath.split('.').last.toLowerCase();
      if (!getAllowedExtensions().contains(ext)) return false;
      
      return true;
    } catch (e) {
      return false;
    }
  }

  // ✅ METHOD BARU: Validate dengan debug info
  static Future<Map<String, dynamic>> validateWithDebug(String filePath) async {
    final fileInfo = await getFileInfo(filePath);
    final validation = await validateBuktiTransfer(filePath);
    
    return {
      'file_info': fileInfo,
      'validation': validation,
      'summary': {
        'is_valid': validation['valid'] == true,
        'file_size': fileInfo['size'],
        'file_type': fileInfo['mime_type'],
        'allowed_extensions': getAllowedExtensions(),
        'max_size_mb': getMaxFileSize() / 1024 / 1024,
        'min_size_kb': getMinFileSize() / 1024,
      }
    };
  }
}
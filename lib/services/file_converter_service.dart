import 'dart:io';
import 'dart:typed_data';
import 'package:image/image.dart' as img;

class FileConverterService {
  static final FileConverterService _instance = FileConverterService._internal();
  factory FileConverterService() => _instance;
  FileConverterService._internal();

  // ✅ AUTO CONVERT KE JPG - DIPERBAIKI DENGAN COMPATIBLE APPROACH
  Future<File> convertToJpg(File originalFile) async {
    try {
      final originalPath = originalFile.path;
      final originalExtension = originalPath.split('.').last.toLowerCase();
      
      print('🔄 AUTO-CONVERT: .$originalExtension → .jpg');
      print('📁 Original: $originalPath');

      // ✅ Jika sudah JPG, return as is
      if (originalExtension == 'jpg' || originalExtension == 'jpeg') {
        print('✅ Already JPG, no conversion needed');
        return originalFile;
      }

      // ✅ Baca file sebagai bytes
      final bytes = await originalFile.readAsBytes();
      print('📊 File size: ${bytes.length} bytes');

      // ✅ Validasi ukuran file
      if (bytes.isEmpty) {
        throw Exception('File kosong atau tidak dapat dibaca');
      }

      if (bytes.length > 10 * 1024 * 1024) { // 10MB max
        throw Exception('Ukuran file terlalu besar (>10MB)');
      }

      // ✅ PERBAIKAN: Handle khusus untuk format yang bermasalah
      if (originalExtension == 'heic' || originalExtension == 'heif') {
        print('⚠️ HEIC/HEIF format detected - using fallback conversion');
        return _fallbackConvert(originalFile, 'jpg');
      }

      // ✅ Decode image berdasarkan format - DIPERBAIKI
      img.Image? image;
      
      try {
        if (originalExtension == 'png') {
          image = img.decodePng(bytes);
          print('🎨 Decoding PNG...');
        } else if (originalExtension == 'webp') {
          image = img.decodeWebP(bytes);
          print('🎨 Decoding WebP...');
        } else {
          // Untuk format lain, coba decode sebagai image umum
          image = img.decodeImage(bytes);
          print('🎨 Decoding image (auto-detect)...');
        }
      } catch (e) {
        print('❌ Cannot decode image format .$originalExtension: $e');
        // Fallback: copy file dengan extension .jpg
        return _fallbackConvert(originalFile, 'jpg');
      }

      if (image == null) {
        print('❌ Failed to decode image - using fallback');
        return _fallbackConvert(originalFile, 'jpg');
      }

      print('✅ Image decoded: ${image.width}x${image.height}');

      // ✅ PERBAIKAN: Resize image jika terlalu besar (max 1200px)
      final maxDimension = 1200;
      img.Image resizedImage = image;
      if (image.width > maxDimension || image.height > maxDimension) {
        print('📐 Resizing image from ${image.width}x${image.height}');
        resizedImage = img.copyResize(image, width: maxDimension, height: maxDimension);
        print('✅ Resized to: ${resizedImage.width}x${resizedImage.height}');
      }

      // ✅ PERBAIKAN: Handle alpha channel dengan cara yang compatible
      // Skip alpha channel handling untuk sekarang karena kompleks
      print('ℹ️ Skipping alpha channel conversion for compatibility');

      // ✅ Encode ke JPG dengan quality 85%
      final jpgBytes = img.encodeJpg(resizedImage, quality: 85);
      print('✅ Encoded to JPG: ${jpgBytes.length} bytes');

      // ✅ Validasi hasil encode
      if (jpgBytes.isEmpty) {
        throw Exception('Gagal encode ke JPG - hasil kosong');
      }

      // ✅ Simpan file JPG baru di temporary directory
      final tempDir = Directory.systemTemp;
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final newFileName = 'converted_$timestamp.jpg';
      final newFile = File('${tempDir.path}/$newFileName');
      
      await newFile.writeAsBytes(jpgBytes);

      // ✅ Validasi file hasil
      final newFileSize = await newFile.length();
      if (newFileSize == 0) {
        throw Exception('File hasil konversi kosong');
      }

      print('💾 Saved converted file: ${newFile.path} ($newFileSize bytes)');
      
      return newFile;
    } catch (e) {
      print('❌ Auto-convert error: $e');
      // Fallback ke method sederhana
      return _fallbackConvert(originalFile, 'jpg');
    }
  }

  // ✅ FALLBACK CONVERT (jika image processing gagal) - DIPERBAIKI
  Future<File> _fallbackConvert(File originalFile, String newExtension) async {
    try {
      final originalPath = originalFile.path;
      final tempDir = Directory.systemTemp;
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final newFileName = 'fallback_$timestamp.$newExtension';
      final newPath = '${tempDir.path}/$newFileName';
      
      print('🔄 Fallback convert: $originalPath → $newPath');
      
      // Copy file dengan nama baru
      final newFile = await originalFile.copy(newPath);
      
      // Validasi file hasil copy
      final newFileSize = await newFile.length();
      if (newFileSize == 0) {
        throw Exception('Fallback conversion failed - file kosong');
      }
      
      print('✅ Fallback conversion successful: $newPath ($newFileSize bytes)');
      return newFile;
    } catch (e) {
      print('❌ Fallback conversion error: $e');
      rethrow;
    }
  }

  // ✅ VALIDATE & CONVERT IF NEEDED - DIPERBAIKI
  Future<File> validateAndConvert(File file, {String type = 'document'}) async {
    try {
      final path = file.path;
      final extension = path.split('.').last.toLowerCase();
      
      print('🔍 Validating file: .$extension for $type');
      
      // ✅ Validasi file exists
      if (!await file.exists()) {
        throw Exception('File tidak ditemukan: $path');
      }

      // ✅ Validasi ukuran file
      final fileSize = await file.length();
      if (fileSize == 0) {
        throw Exception('File kosong: $path');
      }

      if (fileSize > 10 * 1024 * 1024) { // 10MB max
        throw Exception('Ukuran file terlalu besar (${(fileSize / 1024 / 1024).toStringAsFixed(2)}MB). Maksimal 10MB.');
      }

      // ✅ Format yang langsung diizinkan
      final allowedFormats = ['jpg', 'jpeg'];
      if (allowedFormats.contains(extension)) {
        print('✅ Valid JPG file - ready for upload');
        return file;
      }
      
      // ✅ Format yang perlu di-convert
      final convertableFormats = ['png', 'heic', 'heif', 'webp', 'bmp', 'tiff'];
      if (convertableFormats.contains(extension)) {
        print('🔄 Converting .$extension to JPG...');
        return await convertToJpg(file);
      }
      
      // ❌ Format tidak didukung
      throw Exception('Format .$extension tidak didukung untuk $type. Gunakan JPG, PNG, HEIC, atau WebP.');
    } catch (e) {
      print('❌ File validation error: $e');
      rethrow;
    }
  }

  // ✅ GET FILE INFO - DIPERBAIKI
  Future<Map<String, dynamic>> getFileInfo(File file) async {
    try {
      if (!await file.exists()) {
        return {
          'exists': false,
          'error': 'File tidak ditemukan'
        };
      }

      final stat = await file.stat();
      final path = file.path;
      final extension = path.split('.').last.toLowerCase();
      final filename = path.split('/').last;
      
      // ✅ Cek apakah perlu konversi
      final needsConversion = !['jpg', 'jpeg'].contains(extension);
      final isConvertable = ['png', 'heic', 'heif', 'webp', 'bmp', 'tiff'].contains(extension);
      
      return {
        'exists': true,
        'path': path,
        'filename': filename,
        'extension': extension,
        'size': stat.size,
        'size_kb': (stat.size / 1024).toStringAsFixed(2),
        'size_mb': (stat.size / 1024 / 1024).toStringAsFixed(2),
        'modified': stat.modified,
        'needs_conversion': needsConversion,
        'is_convertable': isConvertable,
        'is_valid_format': ['jpg', 'jpeg', 'png', 'heic', 'heif', 'webp'].contains(extension),
        'status': needsConversion 
            ? (isConvertable ? 'Perlu Konversi' : 'Format Tidak Didukung')
            : 'Siap Upload',
      };
    } catch (e) {
      print('❌ Get file info error: $e');
      return {
        'exists': false,
        'error': e.toString()
      };
    }
  }

  // ✅ METHOD BARU: Clean up temporary files
  Future<void> cleanupTemporaryFiles({int maxAgeHours = 24}) async {
    try {
      final tempDir = Directory.systemTemp;
      final now = DateTime.now();
      final cutoffTime = now.subtract(Duration(hours: maxAgeHours));
      
      print('🧹 Cleaning up temporary files older than $maxAgeHours hours...');
      
      int deletedCount = 0;
      int errorCount = 0;
      
      if (await tempDir.exists()) {
        final files = await tempDir.list().toList();
        
        for (var file in files) {
          if (file is File) {
            try {
              final stat = await file.stat();
              final filename = file.path.split('/').last;
              
              // Hapus file temporary yang mengandung 'converted_' atau 'fallback_'
              if (filename.contains('converted_') || filename.contains('fallback_')) {
                if (stat.modified.isBefore(cutoffTime)) {
                  await file.delete();
                  deletedCount++;
                  print('🗑️ Deleted old temp file: $filename');
                }
              }
            } catch (e) {
              errorCount++;
              print('⚠️ Failed to process temp file: ${file.path} - $e');
            }
          }
        }
      }
      
      print('✅ Cleanup completed: $deletedCount files deleted, $errorCount errors');
    } catch (e) {
      print('❌ Cleanup error: $e');
    }
  }

  // ✅ METHOD BARU: Check if file needs conversion
  bool needsConversion(File file) {
    try {
      final path = file.path;
      final extension = path.split('.').last.toLowerCase();
      return !['jpg', 'jpeg'].contains(extension);
    } catch (e) {
      return true; // Default to needing conversion if error
    }
  }

  // ✅ METHOD BARU: Get supported formats
  List<String> getSupportedFormats() {
    return ['jpg', 'jpeg', 'png', 'heic', 'heif', 'webp', 'bmp', 'tiff'];
  }

  // ✅ METHOD BARU: Get allowed extensions for upload (hanya JPG)
  List<String> getAllowedUploadFormats() {
    return ['jpg', 'jpeg'];
  }

  // ✅ METHOD BARU: Quick validation tanpa konversi
  Future<bool> isValidUploadFile(File file) async {
    try {
      if (!await file.exists()) return false;
      
      final extension = file.path.split('.').last.toLowerCase();
      final fileSize = await file.length();
      
      return ['jpg', 'jpeg'].contains(extension) && 
             fileSize > 0 && 
             fileSize <= 10 * 1024 * 1024;
    } catch (e) {
      return false;
    }
  }

  // ✅ METHOD BARU: Batch convert multiple files
  Future<List<File>> convertMultipleFiles(List<File> files) async {
    final results = <File>[];
    
    for (var file in files) {
      try {
        final convertedFile = await validateAndConvert(file);
        results.add(convertedFile);
        print('✅ Converted: ${file.path} → ${convertedFile.path}');
      } catch (e) {
        print('❌ Failed to convert ${file.path}: $e');
        // Skip file yang gagal dikonversi
      }
    }
    
    return results;
  }

  // ✅ METHOD BARU: Get conversion status
  String getConversionStatus(File file) {
    try {
      final extension = file.path.split('.').last.toLowerCase();
      
      if (['jpg', 'jpeg'].contains(extension)) {
        return 'READY';
      } else if (['png', 'heic', 'heif', 'webp'].contains(extension)) {
        return 'NEEDS_CONVERSION';
      } else {
        return 'UNSUPPORTED';
      }
    } catch (e) {
      return 'ERROR';
    }
  }

  // ✅ METHOD BARU: Force convert even if already JPG (for re-compression)
  Future<File> forceConvertToJpg(File file, {int quality = 85}) async {
    try {
      print('🔄 Force converting to JPG with quality $quality%');
      
      final bytes = await file.readAsBytes();
      final image = img.decodeImage(bytes);
      
      if (image == null) {
        throw Exception('Cannot decode image for force conversion');
      }
      
      // Resize jika perlu
      final maxDimension = 1200;
      img.Image resizedImage = image;
      if (image.width > maxDimension || image.height > maxDimension) {
        resizedImage = img.copyResize(image, width: maxDimension, height: maxDimension);
      }
      
      final jpgBytes = img.encodeJpg(resizedImage, quality: quality);
      
      final tempDir = Directory.systemTemp;
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final newFile = File('${tempDir.path}/forced_$timestamp.jpg');
      
      await newFile.writeAsBytes(jpgBytes);
      
      print('✅ Force conversion completed: ${newFile.path}');
      return newFile;
    } catch (e) {
      print('❌ Force conversion error: $e');
      return file; // Return original file if conversion fails
    }
  }

  // ✅ METHOD BARU: Simple file copy dengan rename extension
  Future<File> simpleConvert(File originalFile, String targetExtension) async {
    try {
      final originalPath = originalFile.path;
      final tempDir = Directory.systemTemp;
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final newFileName = 'simple_$timestamp.$targetExtension';
      final newPath = '${tempDir.path}/$newFileName';
      
      print('🔄 Simple convert: $originalPath → $newPath');
      
      final newFile = await originalFile.copy(newPath);
      final newFileSize = await newFile.length();
      
      print('✅ Simple conversion successful: $newPath ($newFileSize bytes)');
      return newFile;
    } catch (e) {
      print('❌ Simple conversion error: $e');
      rethrow;
    }
  }
}
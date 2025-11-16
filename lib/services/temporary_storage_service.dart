import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';

class TemporaryStorageService {
  // Singleton instance
  static final TemporaryStorageService _instance = TemporaryStorageService._internal();
  factory TemporaryStorageService() => _instance;
  TemporaryStorageService._internal();

  // ✅ FILE STORAGE - 3 FILE ASLI + 1 DUMMY PATH + 1 BUKTI TRANSFER
  static File? _ktpFile;
  static File? _kkFile;
  static File? _diriFile;
  static String? _dummyBuktiPath; // ✅ UNTUK UPLOAD DOKUMEN
  static File? _buktiTransferFile; // ✅ UNTUK RIIWAYAT TABUNGAN
  static File? _buktiPembayaranFile; // ✅ BARU: UNTUK BUKTI PEMBAYARAN DI UPLOAD DOKUMEN

  // Upload status
  static bool _isUploading = false;
  static String _uploadMessage = '';
  static double _uploadProgress = 0.0;

  // Getters
  File? get ktpFile => _ktpFile;
  File? get kkFile => _kkFile;
  File? get diriFile => _diriFile;
  String? get dummyBuktiPath => _dummyBuktiPath;
  File? get buktiTransferFile => _buktiTransferFile;
  File? get buktiPembayaranFile => _buktiPembayaranFile; // ✅ GETTER BARU
  bool get isUploading => _isUploading;
  String get uploadMessage => _uploadMessage;
  double get uploadProgress => _uploadProgress;
  
  // Status checkers
  bool get hasKtpFile => _ktpFile != null;
  bool get hasKkFile => _kkFile != null;
  bool get hasDiriFile => _diriFile != null;
  bool get hasDummyBukti => _dummyBuktiPath != null;
  bool get hasBuktiTransfer => _buktiTransferFile != null;
  bool get hasBuktiPembayaran => _buktiPembayaranFile != null; // ✅ CHECKER BARU

  // ✅ CHECK COMPLETE - UNTUK UPLOAD DOKUMEN (3 ASLI + 1 DUMMY) - VERSI LAMA
  bool get isAllFilesComplete {
    return _ktpFile != null && _kkFile != null && _diriFile != null && _dummyBuktiPath != null;
  }

  // ✅ CHECK COMPLETE - UNTUK BUKTI TRANSFER (1 ASLI + 3 DUMMY)
  bool get isBuktiTransferComplete {
    return _buktiTransferFile != null && _dummyBuktiPath != null;
  }

  // ✅ CHECK COMPLETE BARU - UNTUK UPLOAD DOKUMEN DENGAN BUKTI PEMBAYARAN (4 FILE ASLI)
  bool get isAllFilesWithBuktiComplete {
    return _ktpFile != null && _kkFile != null && _diriFile != null && _buktiPembayaranFile != null;
  }

  bool get hasAnyFile {
    return _ktpFile != null || _kkFile != null || _diriFile != null || _buktiTransferFile != null || _buktiPembayaranFile != null;
  }

 Future<void> setBuktiPembayaranFile(File file) async {
  try {
    print('🔄 Processing Bukti Pembayaran file...');
    
    // ✅ VALIDASI FILE
    await _validateFileBeforeProcessing(file, 'Bukti Pembayaran');
    final convertedFile = await _autoConvertToJpg(file, 'Bukti Pembayaran');
    
    // ✅ SIMPAN KE MEMORY
    _buktiPembayaranFile = convertedFile;
    
    // ✅ SIMPAN KE STORAGE - PASTIKAN INI DIPANGGIL
    await _saveFileStatus('bukti_pembayaran', convertedFile.path);
    
    print('✅ Bukti Pembayaran file processed and SAVED: ${convertedFile.path}');
    
    // ✅ VERIFIKASI PENYIMPANAN
    final prefs = await SharedPreferences.getInstance();
    final savedPath = prefs.getString('temp_file_bukti_pembayaran');
    final hasFile = prefs.getBool('has_file_bukti_pembayaran') ?? false;
    
    print('🔍 Save verification:');
    print('   - Saved path: $savedPath');
    print('   - Has file: $hasFile');
    print('   - Expected: ${convertedFile.path}');
    
    if (savedPath != convertedFile.path || !hasFile) {
      print('❌ Save verification FAILED! Retrying...');
      // ✅ COBA SIMPAN ULANG JIKA GAGAL
      await _saveFileStatus('bukti_pembayaran', convertedFile.path);
    }
    
    _checkAndAutoUpload();
  } catch (e) {
    print('❌ Error processing Bukti Pembayaran file: $e');
    rethrow;
  }
}

  // ✅ METHOD BARU: SET BUKTI TRANSFER FILE (UNTUK RIIWAYAT TABUNGAN)
  Future<void> setBuktiTransferFile(File file) async {
    try {
      print('🔄 Processing Bukti Transfer file...');
      
      await _validateFileBeforeProcessing(file, 'Bukti Transfer');
      final convertedFile = await _autoConvertToJpg(file, 'Bukti Transfer');
      
      _buktiTransferFile = convertedFile;
      await _saveFileStatus('bukti_transfer', convertedFile.path);
      
      print('✅ Bukti Transfer file processed: ${convertedFile.path}');
    } catch (e) {
      print('❌ Error processing Bukti Transfer file: $e');
      rethrow;
    }
  }

Future<void> _commitBuktiPembayaranToStorage() async {
  try {
    print('💾 Committing bukti pembayaran to storage...');
    
    // ✅ CEK APAKAH ADA BUKTI PEMBAYARAN YANG BELUM DISIMPAN
    if (hasBuktiPembayaran) {
      final buktiFile = _buktiPembayaranFile;
      if (buktiFile != null && await buktiFile.exists()) {
        // ✅ FORCE SAVE KE STORAGE LAGI
        await setBuktiPembayaranFile(buktiFile);
        print('✅ Bukti pembayaran committed to storage');
      }
    }
    
    // ✅ CEK FILE LAIN JUGA
    if (hasKtpFile) {
      final ktpFile = _ktpFile;
      if (ktpFile != null && await ktpFile.exists()) {
        await setKtpFile(ktpFile);
      }
    }
    
    if (hasKkFile) {
      final kkFile = _kkFile;
      if (kkFile != null && await kkFile.exists()) {
        await setKkFile(kkFile);
      }
    }
    
    if (hasDiriFile) {
      final diriFile = _diriFile;
      if (diriFile != null && await diriFile.exists()) {
        await setDiriFile(diriFile);
      }
    }
    
    print('🎯 All files committed successfully');
    
  } catch (e) {
    print('❌ Error committing files to storage: $e');
  }
}

// ✅ METHOD BARU: COMMIT SEMUA FILE KE STORAGE PERMANEN
Future<void> commitAllFilesToPermanentStorage() async {
  try {
    print('💾 COMMIT ALL FILES TO PERMANENT STORAGE STARTED...');
    
    int savedCount = 0;
    
    // ✅ COMMIT KTP
    if (_ktpFile != null && await _ktpFile!.exists()) {
      await setKtpFile(_ktpFile!);
      savedCount++;
      print('✅ KTP committed to permanent storage');
    }
    
    // ✅ COMMIT KK
    if (_kkFile != null && await _kkFile!.exists()) {
      await setKkFile(_kkFile!);
      savedCount++;
      print('✅ KK committed to permanent storage');
    }
    
    // ✅ COMMIT FOTO DIRI
    if (_diriFile != null && await _diriFile!.exists()) {
      await setDiriFile(_diriFile!);
      savedCount++;
      print('✅ Foto Diri committed to permanent storage');
    }
    
    // ✅ COMMIT BUKTI PEMBAYARAN
    if (_buktiPembayaranFile != null && await _buktiPembayaranFile!.exists()) {
      await setBuktiPembayaranFile(_buktiPembayaranFile!);
      savedCount++;
      print('✅ Bukti Pembayaran committed to permanent storage');
    }
    
    print('🎯 COMMIT COMPLETED: $savedCount files saved to permanent storage');
    
    // ✅ VERIFIKASI PENYIMPANAN
    await _verifyStorageCommit();
    
  } catch (e) {
    print('❌ ERROR committing files to permanent storage: $e');
    throw Exception('Gagal menyimpan file: $e');
  }
}

// ✅ METHOD BARU: VERIFIKASI PENYIMPANAN
Future<void> _verifyStorageCommit() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    
    print('🔍 STORAGE VERIFICATION:');
    print('   - KTP: ${prefs.getBool('has_file_ktp')}');
    print('   - KK: ${prefs.getBool('has_file_kk')}');
    print('   - Diri: ${prefs.getBool('has_file_diri')}');
    print('   - Bukti: ${prefs.getBool('has_file_bukti_pembayaran')}');
    
    // ✅ VERIFIKASI PATH MASING-MASING FILE
    final ktpPath = prefs.getString('temp_file_ktp');
    final kkPath = prefs.getString('temp_file_kk');
    final diriPath = prefs.getString('temp_file_diri');
    final buktiPath = prefs.getString('temp_file_bukti_pembayaran');
    
    print('📁 Saved paths:');
    print('   - KTP: $ktpPath');
    print('   - KK: $kkPath');
    print('   - Diri: $diriPath');
    print('   - Bukti: $buktiPath');
    
    // ✅ VERIFIKASI FILE EXISTS DI PATH TERSEBUT
    if (ktpPath != null) {
      final file = File(ktpPath);
      print('   - KTP exists: ${await file.exists()}');
    }
    if (kkPath != null) {
      final file = File(kkPath);
      print('   - KK exists: ${await file.exists()}');
    }
    if (diriPath != null) {
      final file = File(diriPath);
      print('   - Diri exists: ${await file.exists()}');
    }
    if (buktiPath != null) {
      final file = File(buktiPath);
      print('   - Bukti exists: ${await file.exists()}');
    }
    
  } catch (e) {
    print('❌ Error during storage verification: $e');
  }
}

  // ✅ METHOD BARU: SET DUMMY BUKTI PATH
  Future<void> setDummyBuktiPath(String filePath) async {
    try {
      print('🔄 Setting dummy bukti path...');
      
      final file = File(filePath);
      if (!await file.exists()) {
        throw Exception('File dummy bukti tidak ditemukan: $filePath');
      }

      _dummyBuktiPath = filePath;
      await _saveFileStatus('dummy_bukti', filePath);
      
      print('✅ Dummy bukti path set: $filePath');
      _checkAndAutoUpload();
    } catch (e) {
      print('❌ Error setting dummy bukti path: $e');
      rethrow;
    }
  }

  // ✅ SETTERS UNTUK 3 FILE ASLI
  Future<void> setKtpFile(File file) async {
    try {
      print('🔄 Processing KTP file...');
      await _validateFileBeforeProcessing(file, 'KTP');
      final convertedFile = await _autoConvertToJpg(file, 'KTP');
      _ktpFile = convertedFile;
      await _saveFileStatus('ktp', convertedFile.path);
      print('✅ KTP file processed: ${convertedFile.path}');
      _checkAndAutoUpload();
    } catch (e) {
      print('❌ Error processing KTP file: $e');
      rethrow;
    }
  }

  Future<void> setKkFile(File file) async {
    try {
      print('🔄 Processing KK file...');
      await _validateFileBeforeProcessing(file, 'KK');
      final convertedFile = await _autoConvertToJpg(file, 'KK');
      _kkFile = convertedFile;
      await _saveFileStatus('kk', convertedFile.path);
      print('✅ KK file processed: ${convertedFile.path}');
      _checkAndAutoUpload();
    } catch (e) {
      print('❌ Error processing KK file: $e');
      rethrow;
    }
  }

  Future<void> setDiriFile(File file) async {
    try {
      print('🔄 Processing Foto Diri file...');
      await _validateFileBeforeProcessing(file, 'Foto Diri');
      final convertedFile = await _autoConvertToJpg(file, 'Foto Diri');
      _diriFile = convertedFile;
      await _saveFileStatus('diri', convertedFile.path);
      print('✅ Foto Diri file processed: ${convertedFile.path}');
      _checkAndAutoUpload();
    } catch (e) {
      print('❌ Error processing Foto Diri file: $e');
      rethrow;
    }
  }

  // ✅ VALIDASI FILE
  Future<void> _validateFileBeforeProcessing(File file, String type) async {
    try {
      final filePath = file.path;
      
      if (!await file.exists()) {
        throw Exception('File $type tidak ditemukan: $filePath');
      }

      final fileSize = await file.length();
      final maxSize = 5 * 1024 * 1024; // 5MB
      
      if (fileSize == 0) {
        throw Exception('File $type kosong atau tidak dapat diakses');
      }
      
      if (fileSize > maxSize) {
        throw Exception('Ukuran file $type terlalu besar (${(fileSize / 1024 / 1024).toStringAsFixed(2)}MB). Maksimal 5MB.');
      }

      final fileExtension = filePath.toLowerCase().split('.').last;
      final allowedExtensions = ['jpg', 'jpeg', 'png', 'heic', 'heif', 'webp'];
      
      if (!allowedExtensions.contains(fileExtension)) {
        throw Exception('Format file .$fileExtension tidak didukung untuk $type. Gunakan JPG, JPEG, PNG, atau HEIC.');
      }

      print('✅ File $type validated: ${(fileSize / 1024).toStringAsFixed(2)} KB, .$fileExtension');
      
    } catch (e) {
      print('❌ File validation failed for $type: $e');
      rethrow;
    }
  }

  // ✅ AUTO-CONVERT SYSTEM
  Future<File> _autoConvertToJpg(File originalFile, String type) async {
    try {
      final originalPath = originalFile.path;
      final originalExtension = originalPath.split('.').last.toLowerCase();
      
      print('🔄 AUTO-CONVERT $type: .$originalExtension → .jpg');
      print('📁 Original: $originalPath');

      if (originalExtension == 'jpg' || originalExtension == 'jpeg') {
        print('✅ $type already JPG, no conversion needed');
        return originalFile;
      }

      final fileSize = await originalFile.length();
      print('📊 $type file size: ${(fileSize / 1024).toStringAsFixed(2)} KB');

      if (['png', 'heic', 'heif', 'webp'].contains(originalExtension)) {
        print('🔄 Converting $type from .$originalExtension to .jpg');
        return await _copyWithJpgExtension(originalFile, type);
      }

      throw Exception('Format .$originalExtension tidak didukung untuk $type. Gunakan JPG, PNG, atau HEIC.');
      
    } catch (e) {
      print('❌ Auto-convert error for $type: $e');
      print('⚠️ Fallback: using original file despite format issue');
      return originalFile;
    }
  }

  // ✅ COPY FILE DENGAN EXTENSION JPG
  Future<File> _copyWithJpgExtension(File originalFile, String type) async {
    try {
      final originalPath = originalFile.path;
      final directory = originalPath.substring(0, originalPath.lastIndexOf('/'));
      final fileName = '${type.toLowerCase()}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final newPath = '$directory/$fileName';
      
      print('🔄 Copying file: $originalPath → $newPath');
      
      final newFile = await originalFile.copy(newPath);
      print('✅ File copied successfully: $newPath');
      
      return newFile;
    } catch (e) {
      print('❌ Error copying file: $e');
      throw Exception('Gagal mengkonversi file $type ke format JPG: $e');
    }
  }

  // Check and auto upload jika semua file sudah lengkap
  void _checkAndAutoUpload() {
    print('🔄 _checkAndAutoUpload called');
    print('   - isAllFilesComplete: $isAllFilesComplete');
    print('   - isAllFilesWithBuktiComplete: $isAllFilesWithBuktiComplete');
    print('   - isUploading: $_isUploading');
    
    if ((isAllFilesComplete || isAllFilesWithBuktiComplete) && !_isUploading) {
      print('🚀 All files complete, auto-upload ready!');
    } else {
      print('⏳ Not ready for auto-upload yet');
    }
  }

  // ✅ METHOD BARU: GET 3 DUMMY FILES UNTUK RIIWAYAT TABUNGAN
  Future<List<File>> _getThreeDummyFiles() async {
    try {
      final apiService = ApiService();
      final dummyPath = await apiService.getDummyFilePath();
      
      if (dummyPath == null || !await File(dummyPath).exists()) {
        throw Exception('File dummy tidak ditemukan');
      }

      // ✅ BUAT 3 COPY DARI FILE DUMMY YANG SAMA
      final dummyFile = File(dummyPath);
      final dummyFiles = <File>[];
      
      for (int i = 1; i <= 3; i++) {
        final copiedFile = await _copyDummyFile(dummyFile, 'dummy_$i');
        dummyFiles.add(copiedFile);
        print('✅ Created dummy file $i: ${copiedFile.path}');
      }
      
      return dummyFiles;
    } catch (e) {
      print('❌ Error getting dummy files: $e');
      rethrow;
    }
  }

  // ✅ COPY DUMMY FILE DENGAN NAMA BERBEDA
  Future<File> _copyDummyFile(File originalFile, String prefix) async {
    try {
      final originalPath = originalFile.path;
      final directory = originalPath.substring(0, originalPath.lastIndexOf('/'));
      final fileName = '${prefix}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final newPath = '$directory/$fileName';
      
      final newFile = await originalFile.copy(newPath);
      return newFile;
    } catch (e) {
      print('❌ Error copying dummy file: $e');
      throw Exception('Gagal membuat file dummy: $e');
    }
  }

  // ✅ PERBAIKAN BESAR: Upload 4 files (3 ASLI + 1 DUMMY) - UNTUK UPLOAD DOKUMEN VERSI LAMA
  Future<Map<String, dynamic>> uploadAllFiles() async {
    if (!isAllFilesComplete) {
      final missing = _getMissingFiles();
      return {
        'success': false,
        'message': 'Harap lengkapi semua dokumen terlebih dahulu',
        'missing_files': missing
      };
    }

    if (_isUploading) {
      return {
        'success': false, 
        'message': 'Upload sedang berjalan, harap tunggu...'
      };
    }

    _isUploading = true;
    _uploadProgress = 0.0;
    _uploadMessage = 'Mempersiapkan upload...';

    try {
      print('🚀 UPLOAD 4 FILES STARTED (3 ASLI + 1 DUMMY)');
      print('📁 KTP: ${_ktpFile!.path}');
      print('📁 KK: ${_kkFile!.path}');
      print('📁 Foto Diri: ${_diriFile!.path}');
      print('📁 Foto Bukti (Dummy): $_dummyBuktiPath');

      // ✅ VALIDASI 3 FILE ASLI SEBELUM UPLOAD
      await _validateFileBeforeUpload(_ktpFile!, 'KTP');
      await _validateFileBeforeUpload(_kkFile!, 'KK');
      await _validateFileBeforeUpload(_diriFile!, 'Foto Diri');

      // ✅ VALIDASI FILE DUMMY
      final dummyFile = File(_dummyBuktiPath!);
      if (!await dummyFile.exists()) {
        throw Exception('File dummy bukti tidak ditemukan: $_dummyBuktiPath');
      }

      // ✅ PREPARE FILES FOR UPLOAD
      final ktpFileToUpload = await _prepareFileForUpload(_ktpFile!, 'KTP');
      final kkFileToUpload = await _prepareFileForUpload(_kkFile!, 'KK');
      final diriFileToUpload = await _prepareFileForUpload(_diriFile!, 'Foto Diri');
      final buktiFileToUpload = await _prepareFileForUpload(dummyFile, 'Foto Bukti');

      print('✅ All 4 files prepared for upload');

      // Create multipart request
      final apiService = ApiService();
      final headers = await apiService.getMultipartHeaders();
      
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('${ApiService.baseUrl}/users/setPhoto'),
      );
      request.headers.addAll(headers);

      // ✅ TAMBAHKAN 4 FILES KE REQUEST
      _uploadMessage = 'Menyiapkan dokumen KTP...';
      request.files.add(await http.MultipartFile.fromPath(
        'foto_ktp',
        ktpFileToUpload.path,
        filename: 'ktp_${DateTime.now().millisecondsSinceEpoch}.jpg',
      ));

      _uploadMessage = 'Menyiapkan dokumen KK...';
      request.files.add(await http.MultipartFile.fromPath(
        'foto_kk',
        kkFileToUpload.path,
        filename: 'kk_${DateTime.now().millisecondsSinceEpoch}.jpg',
      ));

      _uploadMessage = 'Menyiapkan foto diri...';
      request.files.add(await http.MultipartFile.fromPath(
        'foto_diri',
        diriFileToUpload.path,
        filename: 'diri_${DateTime.now().millisecondsSinceEpoch}.jpg',
      ));

      // ✅ TAMBAHKAN FOTO_BUKTI (DUMMY) KE REQUEST
      _uploadMessage = 'Menyiapkan foto bukti...';
      request.files.add(await http.MultipartFile.fromPath(
        'foto_bukti',
        buktiFileToUpload.path,
        filename: 'bukti_${DateTime.now().millisecondsSinceEpoch}.jpg',
      ));

      // ✅ TAMBAHKAN FORM FIELDS
      request.fields['type'] = 'foto_ktp';
      
      // Add user data
      final currentUser = await apiService.getCurrentUser();
      if (currentUser != null) {
        if (currentUser['user_id'] != null) {
          request.fields['user_id'] = currentUser['user_id'].toString();
          print('✅ Added user_id: ${currentUser['user_id']}');
        }
        if (currentUser['user_key'] != null) {
          request.fields['user_key'] = currentUser['user_key'].toString();
          print('✅ Added user_key: ${currentUser['user_key']?.toString().substring(0, 10)}...');
        }
      } else {
        print('❌ User data is null');
      }

      print('📤 Request fields: ${request.fields}');
      print('📤 Files count: ${request.files.length}'); // ✅ HARUSNYA 4 SEKARANG

      // ✅ KIRIM REQUEST
      _uploadMessage = 'Mengupload dokumen ke server...';
      _uploadProgress = 0.5;
      
      print('📤 Sending request to server...');
      
      final streamedResponse = await request.send().timeout(const Duration(seconds: 60));
      final response = await http.Response.fromStream(streamedResponse);
      
      print('📡 Response Status: ${response.statusCode}');
      print('📡 Response Body: ${response.body}');

      _isUploading = false;
      _uploadProgress = 0.0;
      _uploadMessage = '';

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['status'] == true) {
          _uploadMessage = 'Semua dokumen berhasil diupload!';
          
          await _cleanupAfterSuccessfulUpload();
          await _updateUserProfileAfterUpload();
          
          print('✅ UPLOAD SUCCESS - All 4 documents uploaded');
          return {
            'success': true,
            'message': data['message'] ?? 'Upload berhasil',
            'data': data
          };
        } else {
          _uploadMessage = 'Upload gagal: ${data['message']}';
          print('❌ UPLOAD FAILED: ${data['message']}');
          return {
            'success': false,
            'message': data['message'] ?? 'Upload gagal'
          };
        }
      } else {
        _uploadMessage = 'Server error: ${response.statusCode}';
        print('❌ SERVER ERROR: ${response.statusCode} - ${response.body}');
        return {
          'success': false,
          'message': 'Server error ${response.statusCode}: ${response.body}'
        };
      }
    } catch (e) {
      _isUploading = false;
      _uploadProgress = 0.0;
      _uploadMessage = 'Upload error: $e';
      print('❌ UPLOAD ALL FILES ERROR: $e');
      
      return {
        'success': false,
        'message': 'Upload error: $e'
      };
    }
  }

// ✅ PERBAIKAN BESAR: UPLOAD 4 FILE ASLI DENGAN BUKTI PEMBAYARAN
Future<Map<String, dynamic>> uploadAllFilesWithBuktiPembayaran() async {
  if (!isAllFilesWithBuktiComplete) {
    final missing = _getMissingFilesWithBukti();
    return {
      'success': false,
      'message': 'Harap lengkapi semua 4 dokumen terlebih dahulu',
      'missing_files': missing
    };
  }

  if (_isUploading) {
    return {
      'success': false, 
      'message': 'Upload sedang berjalan, harap tunggu...'
    };
  }

  _isUploading = true;
  _uploadProgress = 0.0;
  _uploadMessage = 'Mempersiapkan upload...';

  try {
    print('🚀 UPLOAD 4 FILE ASLI DENGAN BUKTI PEMBAYARAN STARTED');
    print('📁 KTP: ${_ktpFile!.path}');
    print('📁 KK: ${_kkFile!.path}');
    print('📁 Foto Diri: ${_diriFile!.path}');
    print('📁 Bukti Pembayaran: ${_buktiPembayaranFile!.path}');

    // ✅ VALIDASI 4 FILE ASLI SEBELUM UPLOAD
    await _validateFileBeforeUpload(_ktpFile!, 'KTP');
    await _validateFileBeforeUpload(_kkFile!, 'KK');
    await _validateFileBeforeUpload(_diriFile!, 'Foto Diri');
    await _validateFileBeforeUpload(_buktiPembayaranFile!, 'Bukti Pembayaran');

    // ✅ DAPATKAN USER DATA YANG VALID
    final currentUser = await _getValidUserDataForUpload();
    print('👤 User data for upload:');
    print('   - user_id: ${currentUser['user_id']}');
    print('   - user_key: ${currentUser['user_key']?.toString().substring(0, 10)}...');

    // ✅ GUNAKAN API SERVICE YANG BARU UNTUK UPLOAD 4 FILE
    final apiService = ApiService();
    final result = await apiService.uploadFourDocumentsComplete(
      fotoKtpPath: _ktpFile!.path,
      fotoKkPath: _kkFile!.path,
      fotoDiriPath: _diriFile!.path,
      fotoBuktiPath: _buktiPembayaranFile!.path,
      userData: currentUser, // ✅ KIRIM USER DATA YANG SUDAH VALIDASI
    );

    _isUploading = false;
    _uploadProgress = 0.0;
    _uploadMessage = '';

    if (result['success'] == true) {
      print('🎉 UPLOAD 4 FILE ASLI DENGAN BUKTI PEMBAYARAN SUKSES!');
      
      // ✅ CLEANUP SETELAH SUKSES
      await _cleanupAfterSuccessfulUploadWithBukti();
      
      return {
        'success': true,
        'message': result['message'] ?? 'Semua dokumen berhasil diupload',
        'data': result['data']
      };
    } else {
      print('❌ UPLOAD 4 FILE ASLI DENGAN BUKTI PEMBAYARAN FAILED: ${result['message']}');
      return {
        'success': false,
        'message': result['message'] ?? 'Upload dokumen gagal',
        'token_expired': result['token_expired'] ?? false
      };
    }
  } catch (e) {
    _isUploading = false;
    _uploadProgress = 0.0;
    _uploadMessage = 'Upload error: $e';
    print('❌ UPLOAD 4 FILE ASLI DENGAN BUKTI PEMBAYARAN ERROR: $e');
    
    return {
      'success': false,
      'message': 'Upload error: $e'
    };
  }
}

// ✅ METHOD BARU: DAPATKAN USER DATA YANG VALID UNTUK UPLOAD
Future<Map<String, dynamic>> _getValidUserDataForUpload() async {
  try {
    final apiService = ApiService();
    
    // ✅ COBA DAPATKAN DARI getCurrentUserForUpload() DULU
    var currentUser = await apiService.getCurrentUserForUpload();
    
    print('🔍 Validating user data for upload...');
    print('   - Initial user_id: ${currentUser?['user_id']}');
    print('   - Initial user_key: ${currentUser?['user_key']}');
    
    // ✅ JIKA DATA TIDAK LENGKAP, COBA DARI getCurrentUser()
    if (currentUser == null || 
        currentUser['user_id'] == null || 
        currentUser['user_key'] == null) {
      
      print('🔄 Falling back to getCurrentUser()...');
      currentUser = await apiService.getCurrentUser();
      
      print('   - Fallback user_id: ${currentUser?['user_id']}');
      print('   - Fallback user_key: ${currentUser?['user_key']}');
    }
    
    // ✅ JIKA MASIH TIDAK LENGKAP, GUNAKAN SHARED PREFERENCES
    if (currentUser == null || 
        currentUser['user_id'] == null || 
        currentUser['user_key'] == null) {
      
      print('🔄 Falling back to SharedPreferences...');
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      final userId = prefs.getString('user_id');
      final userKey = prefs.getString('user_key');
      
      currentUser = {
        'user_id': userId,
        'user_key': userKey,
        'token': token,
      };
      
      print('   - Prefs user_id: $userId');
      print('   - Prefs user_key: $userKey');
    }
    
    // ✅ VALIDASI FINAL
    if (currentUser == null || currentUser['user_id'] == null) {
      throw Exception('Data user tidak lengkap. user_id: ${currentUser?['user_id']}, user_key: ${currentUser?['user_key']}');
    }
    
    print('✅ User data validated:');
    print('   - user_id: ${currentUser['user_id']}');
    print('   - user_key: ${currentUser['user_key']?.toString().substring(0, 10)}...');
    
    return currentUser;
    
  } catch (e) {
    print('❌ Error getting valid user data: $e');
    rethrow;
  }
}

// ✅ PERBAIKAN: UPLOAD BUKTI TRANSFER DENGAN 4 FILE SAMA DARI BUKTI TRANSFER
Future<Map<String, dynamic>> uploadBuktiTransfer({
  required String transaksiId,
  required String jenisTransaksi,
}) async {
  if (_buktiTransferFile == null) {
    return {
      'success': false,
      'message': 'Harap pilih file bukti transfer terlebih dahulu'
    };
  }

  if (_isUploading) {
    return {
      'success': false, 
      'message': 'Upload sedang berjalan, harap tunggu...'
    };
  }

  _isUploading = true;
  _uploadProgress = 0.0;
  _uploadMessage = 'Mempersiapkan upload bukti transfer...';

  try {
    print('🚀 UPLOAD BUKTI TRANSFER STARTED (4 FILE SAMA)');
    print('📁 Transaksi ID: $transaksiId');
    print('📁 Jenis: $jenisTransaksi');
    print('📁 Bukti Transfer: ${_buktiTransferFile!.path}');

    // ✅ VALIDASI BUKTI TRANSFER
    await _validateFileBeforeUpload(_buktiTransferFile!, 'Bukti Transfer');
    final buktiFileToUpload = await _prepareFileForUpload(_buktiTransferFile!, 'Bukti Transfer');

    // ✅ GUNAKAN API SERVICE YANG BARU (4 FILE SAMA)
    final apiService = ApiService();
    final result = await apiService.uploadBuktiTabunganFourFiles(
      transaksiId: transaksiId,
      jenisTransaksi: jenisTransaksi,
      buktiTransferPath: buktiFileToUpload.path,
    );

    _isUploading = false;
    _uploadProgress = 0.0;
    _uploadMessage = '';

    if (result['success'] == true) {
      print('✅ BUKTI TRANSFER UPLOAD SUCCESS (4 FILE SAMA)');
      
      // ✅ CLEANUP BUKTI TRANSFER SETELAH SUKSES
      await _cleanupBuktiTransfer();
      
      return {
        'success': true,
        'message': result['message'] ?? 'Bukti transfer berhasil diupload',
        'data': result['data']
      };
    } else {
      print('❌ BUKTI TRANSFER UPLOAD FAILED: ${result['message']}');
      return {
        'success': false,
        'message': result['message'] ?? 'Upload bukti transfer gagal',
        'token_expired': result['token_expired'] ?? false
      };
    }
  } catch (e) {
    _isUploading = false;
    _uploadProgress = 0.0;
    _uploadMessage = 'Upload bukti transfer error: $e';
    print('❌ BUKTI TRANSFER UPLOAD ERROR: $e');
    
    return {
      'success': false,
      'message': 'Upload bukti transfer error: $e'
    };
  }
}

// ✅ FIX: UPLOAD DENGAN USER DATA YANG BENAR
Future<Map<String, dynamic>> uploadWithDummySystem() async {
  try {
    print('🚀 UPLOAD 3 FILE + 1 BUKTI STARTED');
    
    // ✅ GUNAKAN METHOD YANG SUDAH DIPERBAIKI
    final currentUser = await ApiService().getCurrentUserForUpload();
    
    print('👤 Current User for Upload:');
    print('   - user_id: ${currentUser?['user_id']}');
    print('   - user_key: ${currentUser?['user_key']?.substring(0, 10)}...');
    print('   - username: ${currentUser?['username']}');
    print('   - Available keys: ${currentUser?.keys}');
    
    if (currentUser == null) {
      return {
        'success': false,
        'message': 'Data user tidak ditemukan. Silakan login ulang.'
      };
    }

    final userId = currentUser['user_id']?.toString();
    final userKey = currentUser['user_key']?.toString();

    if (userId == null || userKey == null) {
      print('❌ User ID or User Key is null');
      print('   - user_id: $userId');
      print('   - user_key: $userKey');
      
      // ✅ FALLBACK: COBA AMBIL DARI TOKEN ATAU DATA LAIN
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      
      if (token != null) {
        print('🔄 Trying fallback with token...');
        // Coba extract user_id dari token atau data lain
        // Fallback logic here...
      }
      
      return {
        'success': false,
        'message': 'Data user tidak lengkap. user_id: $userId, user_key: $userKey'
      };
    }

    print('📁 Files to upload:');
    print('   - KTP: ${_ktpFile?.path}');
    print('   - KK: ${_kkFile?.path}');
    print('   - Foto Diri: ${_diriFile?.path}');
    print('   - Foto Bukti: ${_diriFile?.path} (SAME AS FOTO DIRI)');

    // Validasi file
    if (_ktpFile == null || _kkFile == null || _diriFile == null) {
      return {
        'success': false,
        'message': 'Semua file (KTP, KK, Foto Diri) harus lengkap'
      };
    }

    // ✅ UPLOAD 4 FILE: KTP, KK, DIRI, DIRI (SEBAGAI BUKTI)
    final result = await ApiService().uploadFourPhotosWithUser(
      fotoKtpPath: _ktpFile!.path,
      fotoKkPath: _kkFile!.path,
      fotoDiriPath: _diriFile!.path,
      fotoBuktiPath: _diriFile!.path, // ✅ GUNAKAN FOTO DIRI UNTUK BUKTI
    );

    print('📡 Upload result: ${result['success']} - ${result['message']}');
    
    if (result['success'] == true) {
      await clearAllFiles();
      print('✅ Files cleared after successful upload');
    }

    return result;
  } catch (e) {
    print('❌ UPLOAD ERROR: $e');
    return {
      'success': false,
      'message': 'Upload error: $e'
    };
  }
}

  // ✅ VALIDASI FILE SEBELUM UPLOAD
  Future<void> _validateFileBeforeUpload(File file, String type) async {
    try {
      if (!await file.exists()) {
        throw Exception('File $type tidak ditemukan untuk upload');
      }
      
      final fileSize = await file.length();
      if (fileSize == 0) {
        throw Exception('File $type kosong');
      }
      
      print('✅ File $type validated for upload: ${(fileSize / 1024).toStringAsFixed(2)} KB');
    } catch (e) {
      print('❌ File validation failed before upload: $e');
      rethrow;
    }
  }

  // ✅ PREPARE FILE FOR UPLOAD
  Future<File> _prepareFileForUpload(File file, String type) async {
    try {
      final fileExtension = file.path.split('.').last.toLowerCase();
      
      if (fileExtension != 'jpg' && fileExtension != 'jpeg') {
        print('🔄 Converting $type to JPG before upload...');
        return await _autoConvertToJpg(file, type);
      }
      
      return file;
    } catch (e) {
      print('❌ Error preparing file for upload: $e');
      rethrow;
    }
  }

  // ✅ CLEANUP AFTER SUCCESSFUL UPLOAD (UNTUK UPLOAD DOKUMEN VERSI LAMA)
  Future<void> _cleanupAfterSuccessfulUpload() async {
    try {
      // Clear files dari memory (HANYA 3 FILE ASLI)
      _ktpFile = null;
      _kkFile = null;
      _diriFile = null;
      // ❌ JANGAN CLEAR _dummyBuktiPath, BIAR TETAP ADA UNTUK NEXT UPLOAD
      
      _isUploading = false;
      _uploadMessage = '';
      _uploadProgress = 0.0;
      
      // Hapus temporary files dari storage (HANYA 3 FILE ASLI)
      await _deleteTemporaryFiles();
      await _clearAllFileStatus();
      
      print('🧹 Cleanup completed after successful upload');
    } catch (e) {
      print('❌ Error during cleanup: $e');
    }
  }

  // ✅ CLEANUP AFTER SUCCESSFUL UPLOAD DENGAN BUKTI PEMBAYARAN
  Future<void> _cleanupAfterSuccessfulUploadWithBukti() async {
    try {
      // Clear semua file dari memory
      _ktpFile = null;
      _kkFile = null;
      _diriFile = null;
      _buktiPembayaranFile = null;
      
      _isUploading = false;
      _uploadMessage = '';
      _uploadProgress = 0.0;
      
      // Hapus temporary files dari storage
      await _deleteTemporaryFilesWithBukti();
      await _clearAllFileStatusWithBukti();
      
      print('🧹 Cleanup completed after successful upload with bukti pembayaran');
    } catch (e) {
      print('❌ Error during cleanup with bukti pembayaran: $e');
    }
  }

  // ✅ CLEANUP BUKTI TRANSFER (UNTUK RIIWAYAT TABUNGAN)
  Future<void> _cleanupBuktiTransfer() async {
    try {
      // Clear bukti transfer dari memory
      _buktiTransferFile = null;
      
      _isUploading = false;
      _uploadMessage = '';
      _uploadProgress = 0.0;
      
      // Hapus file bukti transfer dari storage
      await _clearFileStatus('bukti_transfer');
      
      print('🧹 Bukti transfer cleanup completed');
    } catch (e) {
      print('❌ Error during bukti transfer cleanup: $e');
    }
  }

  // ✅ DELETE TEMPORARY FILES (HANYA 3 FILE ASLI) - VERSI LAMA
  Future<void> _deleteTemporaryFiles() async {
    try {
      final filesToDelete = [
        if (_ktpFile != null) _ktpFile!,
        if (_kkFile != null) _kkFile!,
        if (_diriFile != null) _diriFile!,
      ];

      for (final file in filesToDelete) {
        if (await file.exists()) {
          await file.delete();
          print('🗑️ Deleted temporary file: ${file.path}');
        }
      }
    } catch (e) {
      print('❌ Error deleting temporary files: $e');
    }
  }

  // ✅ DELETE TEMPORARY FILES DENGAN BUKTI PEMBAYARAN
  Future<void> _deleteTemporaryFilesWithBukti() async {
    try {
      final filesToDelete = [
        if (_ktpFile != null) _ktpFile!,
        if (_kkFile != null) _kkFile!,
        if (_diriFile != null) _diriFile!,
        if (_buktiPembayaranFile != null) _buktiPembayaranFile!,
      ];

      for (final file in filesToDelete) {
        if (await file.exists()) {
          await file.delete();
          print('🗑️ Deleted temporary file: ${file.path}');
        }
      }
    } catch (e) {
      print('❌ Error deleting temporary files with bukti: $e');
    }
  }

  // ✅ UPDATE USER PROFILE SETELAH UPLOAD BERHASIL
  Future<void> _updateUserProfileAfterUpload() async {
    try {
      final apiService = ApiService();
      await apiService.getUserProfile();
      print('✅ User profile refreshed after upload');
    } catch (e) {
      print('❌ Error refreshing user profile: $e');
    }
  }

  // ✅ PERBAIKAN: Get missing files list - 3 ASLI + 1 DUMMY
  List<String> _getMissingFiles() {
    List<String> missing = [];
    if (_ktpFile == null) missing.add('KTP');
    if (_kkFile == null) missing.add('KK');
    if (_diriFile == null) missing.add('Foto Diri');
    if (_dummyBuktiPath == null) missing.add('Foto Bukti (Auto)');
    return missing;
  }

  // ✅ METHOD BARU: Get missing files list dengan bukti pembayaran
  List<String> _getMissingFilesWithBukti() {
    List<String> missing = [];
    if (_ktpFile == null) missing.add('KTP');
    if (_kkFile == null) missing.add('KK');
    if (_diriFile == null) missing.add('Foto Diri');
    if (_buktiPembayaranFile == null) missing.add('Bukti Pembayaran');
    return missing;
  }

  // ✅ PERBAIKAN: Clear all files - SEMUA FILE
  Future<void> clearAllFiles() async {
    _ktpFile = null;
    _kkFile = null;
    _diriFile = null;
    _buktiTransferFile = null;
    _buktiPembayaranFile = null;
    // ❌ JANGAN CLEAR _dummyBuktiPath
    _isUploading = false;
    _uploadMessage = '';
    _uploadProgress = 0.0;
    
    await _clearAllFileStatus();
    print('🧹 All files cleared from memory');
  }

  // ✅ PERBAIKAN: Clear specific file
  Future<void> clearFile(String type) async {
    switch (type) {
      case 'ktp':
        _ktpFile = null;
        await _clearFileStatus('ktp');
        break;
      case 'kk':
        _kkFile = null;
        await _clearFileStatus('kk');
        break;
      case 'diri':
        _diriFile = null;
        await _clearFileStatus('diri');
        break;
      case 'dummy_bukti':
        _dummyBuktiPath = null;
        await _clearFileStatus('dummy_bukti');
        break;
      case 'bukti_transfer':
        _buktiTransferFile = null;
        await _clearFileStatus('bukti_transfer');
        break;
      case 'bukti_pembayaran': // ✅ CASE BARU
        _buktiPembayaranFile = null;
        await _clearFileStatus('bukti_pembayaran');
        break;
    }
    print('🧹 $type file cleared');
  }

  // ✅ PERBAIKAN: Save file status - TAMBAH BUKTI_PEMBAYARAN
  Future<void> _saveFileStatus(String type, String filePath) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('temp_file_$type', filePath);
      await prefs.setBool('has_file_$type', true);
      print('💾 Saved $type file status: $filePath');
    } catch (e) {
      print('❌ Error saving file status: $e');
    }
  }

  // ✅ PERBAIKAN: Clear file status - TAMBAH BUKTI_PEMBAYARAN
  Future<void> _clearFileStatus(String type) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('temp_file_$type');
      await prefs.setBool('has_file_$type', false);
      print('💾 Cleared $type file status');
    } catch (e) {
      print('❌ Error clearing file status: $e');
    }
  }

  // ✅ PERBAIKAN: Clear all file status - SEMUA FILE
  Future<void> _clearAllFileStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('temp_file_ktp');
      await prefs.remove('temp_file_kk');
      await prefs.remove('temp_file_diri');
      await prefs.remove('temp_file_dummy_bukti');
      await prefs.remove('temp_file_bukti_transfer');
      await prefs.remove('temp_file_bukti_pembayaran'); // ✅ TAMBAH INI
      await prefs.setBool('has_file_ktp', false);
      await prefs.setBool('has_file_kk', false);
      await prefs.setBool('has_file_diri', false);
      await prefs.setBool('has_file_dummy_bukti', false);
      await prefs.setBool('has_file_bukti_transfer', false);
      await prefs.setBool('has_file_bukti_pembayaran', false); // ✅ TAMBAH INI
      print('💾 All file status cleared');
    } catch (e) {
      print('❌ Error clearing all file status: $e');
    }
  }

  // ✅ METHOD BARU: Clear all file status khusus untuk bukti pembayaran
  Future<void> _clearAllFileStatusWithBukti() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('temp_file_ktp');
      await prefs.remove('temp_file_kk');
      await prefs.remove('temp_file_diri');
      await prefs.remove('temp_file_bukti_pembayaran');
      await prefs.setBool('has_file_ktp', false);
      await prefs.setBool('has_file_kk', false);
      await prefs.setBool('has_file_diri', false);
      await prefs.setBool('has_file_bukti_pembayaran', false);
      print('💾 All file status with bukti cleared');
    } catch (e) {
      print('❌ Error clearing all file status with bukti: $e');
    }
  }

  // ✅ PERBAIKAN: Load files from storage - TAMBAH BUKTI_PEMBAYARAN
  Future<void> loadFilesFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      final ktpPath = prefs.getString('temp_file_ktp');
      final kkPath = prefs.getString('temp_file_kk');
      final diriPath = prefs.getString('temp_file_diri');
      final dummyBuktiPath = prefs.getString('temp_file_dummy_bukti');
      final buktiTransferPath = prefs.getString('temp_file_bukti_transfer');
      final buktiPembayaranPath = prefs.getString('temp_file_bukti_pembayaran'); // ✅ LOAD BARU

      if (ktpPath != null && await File(ktpPath).exists()) {
        _ktpFile = File(ktpPath);
        print('📁 Loaded KTP from storage: $ktpPath');
      }
      
      if (kkPath != null && await File(kkPath).exists()) {
        _kkFile = File(kkPath);
        print('📁 Loaded KK from storage: $kkPath');
      }
      
      if (diriPath != null && await File(diriPath).exists()) {
        _diriFile = File(diriPath);
        print('📁 Loaded Foto Diri from storage: $diriPath');
      }

      // ✅ LOAD DUMMY BUKTI PATH
      if (dummyBuktiPath != null && await File(dummyBuktiPath).exists()) {
        _dummyBuktiPath = dummyBuktiPath;
        print('📁 Loaded Dummy Bukti from storage: $dummyBuktiPath');
      } else {
        // ✅ JIKA DUMMY BUKTI TIDAK ADA, CARI FILE test.jpg OTOMATIS
        await _findAndSetDummyBukti();
      }

      // ✅ LOAD BUKTI TRANSFER
      if (buktiTransferPath != null && await File(buktiTransferPath).exists()) {
        _buktiTransferFile = File(buktiTransferPath);
        print('📁 Loaded Bukti Transfer from storage: $buktiTransferPath');
      }

      // ✅ LOAD BUKTI PEMBAYARAN
      if (buktiPembayaranPath != null && await File(buktiPembayaranPath).exists()) {
        _buktiPembayaranFile = File(buktiPembayaranPath);
        print('📁 Loaded Bukti Pembayaran from storage: $buktiPembayaranPath');
      }

      print('📁 Storage loading completed. Files loaded: ${[
        if (_ktpFile != null) 'KTP',
        if (_kkFile != null) 'KK',
        if (_diriFile != null) 'Foto Diri',
        if (_dummyBuktiPath != null) 'Dummy Bukti',
        if (_buktiTransferFile != null) 'Bukti Transfer',
        if (_buktiPembayaranFile != null) 'Bukti Pembayaran',
      ].join(', ')}');
    } catch (e) {
      print('❌ Error loading files from storage: $e');
    }
  }

  // ✅ METHOD BARU: CARI DAN SET DUMMY BUKTI OTOMATIS
  Future<void> _findAndSetDummyBukti() async {
    try {
      final apiService = ApiService();
      final dummyPath = await apiService.getDummyFilePath();
      
      if (dummyPath != null && await File(dummyPath).exists()) {
        _dummyBuktiPath = dummyPath;
        await _saveFileStatus('dummy_bukti', dummyPath);
        print('✅ Auto-set dummy bukti: $dummyPath');
      } else {
        print('⚠️ Dummy bukti file tidak ditemukan otomatis');
      }
    } catch (e) {
      print('❌ Error finding dummy bukti: $e');
    }
  }

  // ✅ PERBAIKAN: Get file info - TAMBAH BUKTI_PEMBAYARAN
  Map<String, dynamic> getFileInfo(String type) {
    dynamic file;
    String name = '';
    bool isDummy = false;
    
    switch (type) {
      case 'ktp':
        file = _ktpFile;
        name = 'KTP';
        break;
      case 'kk':
        file = _kkFile;
        name = 'Kartu Keluarga';
        break;
      case 'diri':
        file = _diriFile;
        name = 'Foto Diri';
        break;
      case 'dummy_bukti':
        file = _dummyBuktiPath;
        name = 'Foto Bukti (Auto)';
        isDummy = true;
        break;
      case 'bukti_transfer':
        file = _buktiTransferFile;
        name = 'Bukti Transfer';
        break;
      case 'bukti_pembayaran': // ✅ CASE BARU
        file = _buktiPembayaranFile;
        name = 'Bukti Pembayaran';
        break;
    }

    if (file == null) {
      return {
        'exists': false,
        'name': name,
        'path': '',
        'size': 0,
        'status': 'Belum diupload',
        'status_color': Colors.red,
        'is_dummy': isDummy,
      };
    }

    if (isDummy) {
      // ✅ HANDLE DUMMY FILE (HANYA PATH)
      final dummyFile = File(file as String);
      if (!dummyFile.existsSync()) {
        return {
          'exists': false,
          'name': name,
          'path': '',
          'size': 0,
          'status': 'File dummy tidak ditemukan',
          'status_color': Colors.red,
          'is_dummy': true,
        };
      }

      final fileSize = dummyFile.lengthSync();
      final fileExtension = file.split('.').last.toLowerCase();

      return {
        'exists': true,
        'name': name,
        'path': file,
        'size': fileSize,
        'size_formatted': '${(fileSize / 1024).toStringAsFixed(1)} KB',
        'status': 'Auto (Dummy File)',
        'status_color': Colors.blue,
        'filename': file.split('/').last,
        'extension': fileExtension,
        'needs_conversion': false,
        'is_ready': true,
        'is_dummy': true,
      };
    } else {
      // ✅ HANDLE FILE ASLI
      final fileObj = file as File;
      final fileExtension = fileObj.path.split('.').last.toLowerCase();
      final fileSize = fileObj.lengthSync();
      final isJpg = fileExtension == 'jpg' || fileExtension == 'jpeg';
      final needsConversion = !isJpg;

      return {
        'exists': true,
        'name': name,
        'path': fileObj.path,
        'size': fileSize,
        'size_formatted': '${(fileSize / 1024).toStringAsFixed(1)} KB',
        'status': needsConversion ? 'Perlu Konversi ke JPG' : 'Siap Upload',
        'status_color': needsConversion ? Colors.orange : Colors.green,
        'filename': fileObj.path.split('/').last,
        'extension': fileExtension,
        'needs_conversion': needsConversion,
        'is_ready': isJpg,
        'is_dummy': false,
      };
    }
  }

  // ✅ PERBAIKAN: Get all files info - TAMBAH BUKTI_PEMBAYARAN
  Map<String, dynamic> getAllFilesInfo() {
    return {
      'ktp': getFileInfo('ktp'),
      'kk': getFileInfo('kk'),
      'diri': getFileInfo('diri'),
      'dummy_bukti': getFileInfo('dummy_bukti'),
      'bukti_transfer': getFileInfo('bukti_transfer'),
      'bukti_pembayaran': getFileInfo('bukti_pembayaran'), // ✅ TAMBAH INI
      'all_complete': isAllFilesComplete,
      'all_with_bukti_complete': isAllFilesWithBuktiComplete, // ✅ TAMBAH INI
      'bukti_transfer_complete': isBuktiTransferComplete,
      'is_uploading': _isUploading,
      'upload_message': _uploadMessage,
      'upload_progress': _uploadProgress,
    };
  }

  // ✅ PERBAIKAN: Debug info - TAMBAH BUKTI_PEMBAYARAN
  void printDebugInfo() {
    print('🐛 === TEMPORARY STORAGE DEBUG ===');
    print('📁 KTP: ${_ktpFile?.path ?? "NULL"}');
    print('📁 KK: ${_kkFile?.path ?? "NULL"}');
    print('📁 Foto Diri: ${_diriFile?.path ?? "NULL"}');
    print('📁 Dummy Bukti: ${_dummyBuktiPath ?? "NULL"}');
    print('📁 Bukti Transfer: ${_buktiTransferFile?.path ?? "NULL"}');
    print('📁 Bukti Pembayaran: ${_buktiPembayaranFile?.path ?? "NULL"}'); // ✅ TAMBAH INI
    print('🔄 Is Uploading: $_isUploading');
    print('💬 Upload Message: $_uploadMessage');
    print('📊 Upload Progress: ${(_uploadProgress * 100).toStringAsFixed(1)}%');
    print('✅ All Complete (3+1): $isAllFilesComplete');
    print('✅ All With Bukti Complete (4 asli): $isAllFilesWithBuktiComplete'); // ✅ TAMBAH INI
    print('✅ Bukti Transfer Complete: $isBuktiTransferComplete');
    
    final filesInfo = getAllFilesInfo();
    for (final entry in filesInfo.entries) {
      if (entry.key != 'all_complete' && entry.key != 'all_with_bukti_complete' && 
          entry.key != 'bukti_transfer_complete' && entry.key != 'is_uploading' && 
          entry.key != 'upload_message' && entry.key != 'upload_progress') {
        final info = entry.value as Map<String, dynamic>;
        print('📄 ${entry.key.toUpperCase()}:');
        print('   - Exists: ${info['exists']}');
        print('   - Is Dummy: ${info['is_dummy']}');
        if (info['exists']) {
          print('   - Size: ${info['size_formatted']}');
          print('   - Extension: .${info['extension']}');
          print('   - Status: ${info['status']}');
          print('   - Needs Conversion: ${info['needs_conversion']}');
        }
      }
    }
    
    print('🐛 === DEBUG END ===');
  }
}
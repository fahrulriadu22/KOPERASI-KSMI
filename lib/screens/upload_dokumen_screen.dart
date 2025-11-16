import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/api_service.dart';
import '../services/temporary_storage_service.dart';
import 'aktivasi_berhasil_screen.dart';
import 'dashboard_main.dart';
import 'login_screen.dart';
import 'profile_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:photo_view/photo_view.dart';

class UploadDokumenScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  final VoidCallback? onDocumentsComplete;

  const UploadDokumenScreen({
    super.key, 
    required this.user,
    this.onDocumentsComplete,
  });

  @override
  State<UploadDokumenScreen> createState() => _UploadDokumenScreenState();
}

class _UploadDokumenScreenState extends State<UploadDokumenScreen> {
  final TemporaryStorageService _storageService = TemporaryStorageService();
  final ApiService _apiService = ApiService();
  final ImagePicker _imagePicker = ImagePicker();
  
  bool _isLoading = false;
  bool _isInitializing = true;
  String? _uploadError;
  Map<String, dynamic> _currentUser = {};
  bool _isNavigating = false;
  bool _isWidgetActive = true; 

  @override
  void initState() {
    super.initState();
    _currentUser = Map<String, dynamic>.from(widget.user);
    _initializeData();
  }

  @override
  void dispose() {
    _isWidgetActive = false; // ✅ SET FLAG SEBELUM DISPOSE
    _isNavigating = true;
    super.dispose();
  }

  // ✅ INITIALIZE DATA DENGAN CEK STATUS DOKUMEN DARI SERVER
  Future<void> _initializeData() async {
    try {
      setState(() => _isInitializing = true);
      
      // ✅ CEK STATUS DOKUMEN DARI SERVER
      final profileResult = await _apiService.getUserProfile();
      if (profileResult['success'] == true && profileResult['data'] != null) {
        setState(() {
          _currentUser = profileResult['data'];
        });
        print('✅ User profile loaded from API for document status check');
        
        // ✅ DEBUG: CEK STATUS DOKUMEN DI SERVER
        _debugServerDocumentStatus();
      }
      
      // ✅ INITIALIZE TEMPORARY STORAGE
      await _storageService.loadFilesFromStorage();
      print('✅ TemporaryStorageService initialized');
      _storageService.printDebugInfo();
      
    } catch (e) {
      print('❌ Error initializing data: $e');
      // ✅ FALLBACK: GUNAKAN DATA LOKAL
      await _storageService.loadFilesFromStorage();
    } finally {
      if (mounted && !_isNavigating) {
        setState(() => _isInitializing = false);
      }
    }
  }

  // ✅ FIX: DEBUG SERVER DOCUMENT STATUS
  void _debugServerDocumentStatus() {
    print('🐛 === SERVER DOCUMENT STATUS ===');
    print('📄 KTP Server: ${_currentUser['foto_ktp'] ?? 'NULL'}');
    print('📄 KK Server: ${_currentUser['foto_kk'] ?? 'NULL'}');
    print('📄 Foto Diri Server: ${_currentUser['foto_diri'] ?? 'NULL'}');
    print('💰 Bukti Pembayaran Server: ${_currentUser['foto_bukti'] ?? 'NULL'}');
    
    final ktpUploaded = _isDocumentUploadedToServer('ktp');
    final kkUploaded = _isDocumentUploadedToServer('kk');
    final diriUploaded = _isDocumentUploadedToServer('diri');
    final buktiUploaded = _isDocumentUploadedToServer('bukti');
    
    print('✅ KTP Uploaded to Server: $ktpUploaded');
    print('✅ KK Uploaded to Server: $kkUploaded');
    print('✅ Foto Diri Uploaded to Server: $diriUploaded');
    print('✅ Bukti Pembayaran Uploaded to Server: $buktiUploaded');
    print('🐛 === DEBUG END ===');
  }

  // ✅ PERBAIKAN: VALIDASI SEBELUM UPLOAD DENGAN SAFE CHECK
  bool _validateBeforeUpload() {
    // ✅ CEK FILE LOKAL - SEKARANG 4 DOKUMEN (TAMBAH BUKTI PEMBAYARAN)
    if (!_storageService.isAllFilesWithBuktiComplete) {
      _showSafeSnackBar('Harap lengkapi semua 4 dokumen terlebih dahulu', isError: true);
      return false;
    }

    // ✅ CEK APAKAH SUDAH DI SERVER
    final ktpServer = _isDocumentUploadedToServer('ktp');
    final kkServer = _isDocumentUploadedToServer('kk');
    final diriServer = _isDocumentUploadedToServer('diri');
    final buktiServer = _isDocumentUploadedToServer('bukti');
    
    if (ktpServer && kkServer && diriServer && buktiServer) {
      _showSafeSnackBar('Semua dokumen sudah terupload ke server');
      return false;
    }

    // ✅ CEK FILE SIZE
    final ktpSize = _storageService.ktpFile?.lengthSync() ?? 0;
    final kkSize = _storageService.kkFile?.lengthSync() ?? 0;
    final diriSize = _storageService.diriFile?.lengthSync() ?? 0;
    final buktiSize = _storageService.buktiPembayaranFile?.lengthSync() ?? 0;

    if (ktpSize > 5 * 1024 * 1024 || kkSize > 5 * 1024 * 1024 || 
        diriSize > 5 * 1024 * 1024 || buktiSize > 5 * 1024 * 1024) {
      _showSafeSnackBar('Ukuran file terlalu besar. Maksimal 5MB per file', isError: true);
      return false;
    }

    return true;
  }

  // ✅ FIX: CEK STATUS DOKUMEN YANG LEBIH KETAT DAN AKURAT
  bool _isDocumentUploadedToServer(String type) {
    String? documentUrl;
    
    switch (type) {
      case 'ktp':
        documentUrl = _currentUser['foto_ktp'];
        break;
      case 'kk':
        documentUrl = _currentUser['foto_kk'];
        break;
      case 'diri':
        documentUrl = _currentUser['foto_diri'];
        break;
      case 'bukti':
        documentUrl = _currentUser['foto_bukti'];
        break;
    }
    
    // ✅ FIX: VALIDASI YANG LEBIH KETAT
    if (documentUrl == null || 
        documentUrl.toString().isEmpty || 
        documentUrl == 'null' ||
        documentUrl == 'uploaded' ||
        documentUrl.trim().isEmpty) {
      return false;
    }
    
    final urlString = documentUrl.toString().trim();
    
    // ✅ FIX: HANYA RETURN TRUE JIKA BENAR-BENAR ADA FILENAME DENGAN EXTENSION
    final isUploaded = 
        (urlString.toLowerCase().contains('.jpg') || 
         urlString.toLowerCase().contains('.jpeg') || 
         urlString.toLowerCase().contains('.png')) &&
        urlString.length > 5 && // Pastikan bukan string pendek
        !urlString.toLowerCase().contains('null') &&
        !urlString.toLowerCase().contains('uploaded'); // Pastikan bukan status string
    
    print('🔍 Document $type: "$urlString" → Uploaded: $isUploaded');
    return isUploaded;
  }

  // ✅ PERBAIKAN: UPLOAD DOKUMEN DENGAN SAFE CHECK
  Future<void> _uploadDocument(String type, String documentName) async {
    try {
      final XFile? pickedFile = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1200,
        maxHeight: 800,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        if (mounted) {
          setState(() {
            _uploadError = null;
          });
        }

        final file = File(pickedFile.path);
        print('📤 Uploading $documentName: ${file.path}');
        
        // ✅ VALIDASI FILE - HANYA JPG/JPEG
        if (!await file.exists()) {
          throw Exception('File tidak ditemukan');
        }

        final fileSize = file.lengthSync();
        if (fileSize > 5 * 1024 * 1024) {
          throw Exception('Ukuran file terlalu besar. Maksimal 5MB.');
        }

        final fileExtension = pickedFile.path.toLowerCase().split('.').last;
        if (!['jpg', 'jpeg', 'png'].contains(fileExtension)) {
          throw Exception('Format file tidak didukung. Gunakan JPG, JPEG atau PNG saja.');
        }

        // ✅ SIMPAN FILE KE TEMPORARY STORAGE
        switch (type) {
          case 'ktp':
            await _storageService.setKtpFile(file);
            break;
          case 'kk':
            await _storageService.setKkFile(file);
            break;
          case 'diri':
            await _storageService.setDiriFile(file);
            break;
          case 'bukti':
            await _storageService.setBuktiPembayaranFile(file);
            break;
        }

        if (mounted) {
          setState(() {});
        }

        // ✅ PERBAIKAN: GUNAKAN SAFE SNACKBAR
        _showSafeSnackBar('$documentName berhasil disimpan ✅');

        print('💾 $documentName saved to temporary storage');
        
        // ✅ CHECK AUTO UPLOAD SETELAH SIMPAN FILE
        _checkAutoUpload();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _uploadError = 'Error upload $documentName: $e';
        });
      }

      print('❌ Upload failed: $e');
      
      // ✅ PERBAIKAN: GUNAKAN SAFE SNACKBAR
      _showSafeSnackBar('Gagal upload $documentName: $e', isError: true);
    }
  }

  // ✅ PERBAIKAN: TAKE PHOTO DENGAN SAFE CHECK
  Future<void> _takePhoto(String type, String documentName) async {
    try {
      final XFile? pickedFile = await _imagePicker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1200,
        maxHeight: 800,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        if (mounted && !_isNavigating) {
          setState(() {
            _uploadError = null;
          });
        }

        final file = File(pickedFile.path);
        print('📸 Taking photo for $documentName: ${file.path}');
        
        // ✅ VALIDASI FILE - HANYA JPG/JPEG
        if (!await file.exists()) {
          throw Exception('File tidak ditemukan');
        }

        final fileSize = file.lengthSync();
        if (fileSize > 5 * 1024 * 1024) {
          throw Exception('Ukuran file terlalu besar. Maksimal 5MB.');
        }

        // ✅ SIMPAN FILE KE TEMPORARY STORAGE
        switch (type) {
          case 'ktp':
            await _storageService.setKtpFile(file);
            break;
          case 'kk':
            await _storageService.setKkFile(file);
            break;
          case 'diri':
            await _storageService.setDiriFile(file);
            break;
          case 'bukti':
            await _storageService.setBuktiPembayaranFile(file);
            break;
        }

        if (mounted && !_isNavigating) {
          setState(() {});
        }

        // ✅ PERBAIKAN: GUNAKAN SAFE SNACKBAR
        _showSafeSnackBar('$documentName berhasil diambil ✅');

        print('💾 $documentName from camera saved to temporary storage');
        
        // ✅ CHECK AUTO UPLOAD SETELAH SIMPAN FILE
        _checkAutoUpload();
      }
    } catch (e) {
      if (mounted && !_isNavigating) {
        setState(() {
          _uploadError = 'Error mengambil foto $documentName: $e';
        });
      }

      print('❌ Camera failed: $e');
      
      // ✅ PERBAIKAN: GUNAKAN SAFE SNACKBAR
      _showSafeSnackBar('Gagal mengambil foto $documentName: $e', isError: true);
    }
  }

  // ✅ CHECK AUTO UPLOAD JIKA SEMUA FILE LENGKAP
  void _checkAutoUpload() {
    print('🔄 _checkAutoUpload called');
    print('   - isAllFilesWithBuktiComplete: ${_storageService.isAllFilesWithBuktiComplete}');
    print('   - isUploading: ${_storageService.isUploading}');
    print('   - hasKtpFile: ${_storageService.hasKtpFile}');
    print('   - hasKkFile: ${_storageService.hasKkFile}');
    print('   - hasDiriFile: ${_storageService.hasDiriFile}');
    print('   - hasBuktiPembayaranFile: ${_storageService.hasBuktiPembayaran}');
    
    // ✅ CEK APAKAH SUDAH ADA DI SERVER
    final ktpServer = _isDocumentUploadedToServer('ktp');
    final kkServer = _isDocumentUploadedToServer('kk');
    final diriServer = _isDocumentUploadedToServer('diri');
    final buktiServer = _isDocumentUploadedToServer('bukti');
    
    print('   - KTP Server: $ktpServer');
    print('   - KK Server: $kkServer');
    print('   - Diri Server: $diriServer');
    print('   - Bukti Server: $buktiServer');
    
    // ✅ JIKA SEMUA FILE LENGKAP DAN BELUM DIUPLOAD KE SERVER
    if (_storageService.isAllFilesWithBuktiComplete && 
        !_storageService.isUploading &&
        (!ktpServer || !kkServer || !diriServer || !buktiServer)) {
      print('🚀 All files complete, showing upload confirmation...');
      _showUploadConfirmationDialog();
    } else {
      print('⏳ Not ready for auto-upload yet');
    }
  }

  // ✅ UPLOAD KTP
  Future<void> _uploadKTP() async {
    await _uploadDocument('ktp', 'KTP');
  }

  // ✅ UPLOAD KK
  Future<void> _uploadKK() async {
    await _uploadDocument('kk', 'Kartu Keluarga');
  }

  // ✅ UPLOAD FOTO DIRI
  Future<void> _uploadFotoDiri() async {
    await _uploadDocument('diri', 'Foto Diri');
  }

  // ✅ UPLOAD BUKTI PEMBAYARAN
  Future<void> _uploadBuktiPembayaran() async {
    await _uploadDocument('bukti', 'Bukti Pembayaran');
  }

  // ✅ UPLOAD KTP DARI KAMERA
  Future<void> _takePhotoKTP() async {
    await _takePhoto('ktp', 'KTP');
  }

  // ✅ UPLOAD KK DARI KAMERA
  Future<void> _takePhotoKK() async {
    await _takePhoto('kk', 'Kartu Keluarga');
  }

  // ✅ UPLOAD FOTO DIRI DARI KAMERA
  Future<void> _takePhotoFotoDiri() async {
    await _takePhoto('diri', 'Foto Diri');
  }

  // ✅ UPLOAD BUKTI PEMBAYARAN DARI KAMERA
  Future<void> _takePhotoBuktiPembayaran() async {
    await _takePhoto('bukti', 'Bukti Pembayaran');
  }

  // ✅ PERBAIKAN: CLEAR FILE DENGAN SAFE CHECK
  Future<void> _clearFile(String type, String documentName) async {
    await _storageService.clearFile(type);
    if (mounted) {
      setState(() {});
    }
    
    // ✅ PERBAIKAN: GUNAKAN SAFE SNACKBAR
    _showSafeSnackBar('$documentName dihapus');
  }

  // ✅ PERBAIKAN: MANUAL UPLOAD ALL FILES DENGAN SAFE CHECK
  Future<void> _uploadAllFiles() async {
    // ✅ VALIDASI SEBELUM UPLOAD
    if (!_validateBeforeUpload()) {
      return;
    }

    if (_storageService.isUploading) {
      _showSafeSnackBar('Upload sedang berjalan, harap tunggu...', isError: false);
      return;
    }

    _showUploadConfirmationDialog();
  }

// ✅ PERBAIKAN: DIALOG KONFIRMASI UPLOAD - COMMIT FILE SEBELUM EDIT
void _showUploadConfirmationDialog() {
  // ✅ HITUNG FILE YANG AKAN DIUPLOAD
  final filesToUpload = [
    !_isDocumentUploadedToServer('ktp') && _storageService.hasKtpFile,
    !_isDocumentUploadedToServer('kk') && _storageService.hasKkFile,
    !_isDocumentUploadedToServer('diri') && _storageService.hasDiriFile,
    !_isDocumentUploadedToServer('bukti') && _storageService.hasBuktiPembayaran,
  ].where((e) => e).length;

  // ✅ PERBAIKAN: GUNAKAN SAFE DIALOG
  if (!_isWidgetActive || !mounted || _isNavigating) return;
  
  showDialog(
    context: context,
    barrierDismissible: true,
    builder: (context) => AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.cloud_upload, color: Colors.green),
          SizedBox(width: 8),
          Text('Upload ke Server?'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Sistem akan mengupload $filesToUpload file ke server:\n\n'
            '${!_isDocumentUploadedToServer('ktp') && _storageService.hasKtpFile ? '• KTP\n' : ''}'
            '${!_isDocumentUploadedToServer('kk') && _storageService.hasKkFile ? '• Kartu Keluarga\n' : ''}'
            '${!_isDocumentUploadedToServer('diri') && _storageService.hasDiriFile ? '• Foto Diri\n' : ''}'
            '${!_isDocumentUploadedToServer('bukti') && _storageService.hasBuktiPembayaran ? '• Bukti Pembayaran\n' : ''}'
            '\nPastikan file sudah benar sebelum upload.',
          ),
          const SizedBox(height: 16),
          _buildVerificationStatusInfo(),
        ],
      ),
      actions: [
        // ✅ PERBAIKAN: "EDIT FILE DULU" - COMMIT SEMUA FILE KE PERMANENT STORAGE
        TextButton(
          onPressed: () async {
            Navigator.pop(context);
            await _saveAllFilesToPermanentStorage(); // ✅ INI YANG BARU!
            _showSafeSnackBar('✅ Semua file berhasil disimpan. Silakan edit jika perlu.');
          },
          child: const Text('Edit File Dulu'),
        ),
        // ✅ TOMBOL "UPLOAD SEKARANG" - LANGSUNG UPLOAD
        ElevatedButton(
          onPressed: () {
            Navigator.pop(context);
            _commitAllFilesToStorage(); // ✅ INI JUGA PERLU!
            _startUploadProcess();
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
          ),
          child: const Text('Upload Sekarang'),
        ),
      ],
    ),
  );
}

// ✅ METHOD BARU: SIMPAN SEMUA FILE KE PERMANENT STORAGE
Future<void> _saveAllFilesToPermanentStorage() async {
  try {
    print('💾 SAVE ALL FILES TO PERMANENT STORAGE CALLED');
    
    // ✅ GUNAKAN METHOD BARU DI TEMPORARY STORAGE SERVICE
    await _storageService.commitAllFilesToPermanentStorage();
    
    // ✅ VERIFIKASI LAGI DARI SCREEN INI
    await _verifyFilesAfterSave();
    
    print('🎯 ALL FILES SUCCESSFULLY SAVED TO PERMANENT STORAGE');
    
  } catch (e) {
    print('❌ ERROR saving files to permanent storage: $e');
    _showSafeSnackBar('Gagal menyimpan file: $e', isError: true);
  }
}

// ✅ METHOD BARU: VERIFIKASI FILE SETELAH DISIMPAN
Future<void> _verifyFilesAfterSave() async {
  try {
    print('🔍 VERIFYING FILES AFTER SAVE...');
    
    // ✅ RELOAD DARI STORAGE UNTUK MEMASTIKAN
    await _storageService.loadFilesFromStorage();
    
    // ✅ CEK STATUS SETIAP FILE
    final filesInfo = _storageService.getAllFilesInfo();
    
    print('📊 FILES STATUS AFTER SAVE:');
    print('   - KTP: ${filesInfo['ktp']['exists']}');
    print('   - KK: ${filesInfo['kk']['exists']}');
    print('   - Diri: ${filesInfo['diri']['exists']}');
    print('   - Bukti: ${filesInfo['bukti_pembayaran']['exists']}');
    
    // ✅ UPDATE UI JIKA MASIH MOUNTED
    if (mounted && !_isNavigating) {
      setState(() {});
    }
    
  } catch (e) {
    print('❌ Error during files verification: $e');
  }
}

// ✅ METHOD BARU: DEBUG FILE YANG HILANG
void _debugMissingFiles() {
  print('🐛 === MISSING FILES DEBUG ===');
  print('📄 KTP: ${_storageService.hasKtpFile}');
  print('📄 KK: ${_storageService.hasKkFile}');
  print('📄 Foto Diri: ${_storageService.hasDiriFile}');
  print('💰 Bukti Pembayaran: ${_storageService.hasBuktiPembayaran}');
  print('🎯 All Complete: ${_storageService.isAllFilesWithBuktiComplete}');
  
  // ✅ CEK PATH MASING-MASING FILE
  if (!_storageService.hasKtpFile) print('❌ KTP path: ${_storageService.ktpFile?.path}');
  if (!_storageService.hasKkFile) print('❌ KK path: ${_storageService.kkFile?.path}');
  if (!_storageService.hasDiriFile) print('❌ Diri path: ${_storageService.diriFile?.path}');
  if (!_storageService.hasBuktiPembayaran) print('❌ Bukti path: ${_storageService.buktiPembayaranFile?.path}');
  
  print('🐛 === DEBUG END ===');
}

// ✅ PERBAIKAN: COMMIT SEMUA FILE KE STORAGE (UNTUK UPLOAD DAN EDIT)
Future<void> _commitAllFilesToStorage() async {
  try {
    print('💾 COMMIT ALL FILES TO STORAGE STARTED...');
    
    int savedCount = 0;
    
    // ✅ COMMIT SETIAP FILE DENGAN VALIDASI
    if (_storageService.hasKtpFile) {
      final file = _storageService.ktpFile!;
      if (await file.exists()) {
        await _storageService.setKtpFile(file);
        savedCount++;
        print('✅ KTP committed to storage');
      }
    }
    
    if (_storageService.hasKkFile) {
      final file = _storageService.kkFile!;
      if (await file.exists()) {
        await _storageService.setKkFile(file);
        savedCount++;
        print('✅ KK committed to storage');
      }
    }
    
    if (_storageService.hasDiriFile) {
      final file = _storageService.diriFile!;
      if (await file.exists()) {
        await _storageService.setDiriFile(file);
        savedCount++;
        print('✅ Foto Diri committed to storage');
      }
    }
    
    if (_storageService.hasBuktiPembayaran) {
      final file = _storageService.buktiPembayaranFile!;
      if (await file.exists()) {
        await _storageService.setBuktiPembayaranFile(file);
        savedCount++;
        print('✅ Bukti Pembayaran committed to storage');
      }
    }
    
    print('🎯 COMMIT COMPLETED: $savedCount files saved');
    
    // ✅ VERIFIKASI DENGAN RELOAD
    await _storageService.loadFilesFromStorage();
    
  } catch (e) {
    print('❌ ERROR committing files: $e');
    throw Exception('Gagal menyimpan file: $e');
  }
}

  // ✅ METHOD: PREVIEW IMAGE DENGAN ZOOM
void _showZoomableImagePreview(File imageFile, String title) {
  showDialog(
    context: context,
    builder: (context) => Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(10),
      child: Stack(
        children: [
          // BACKGROUND OVERLAY
          Container(
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.9),
              borderRadius: BorderRadius.circular(16),
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // TITLE
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                
                // ZOOMABLE IMAGE
                Expanded(
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white30),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: PhotoView(
                        imageProvider: FileImage(imageFile),
                        backgroundDecoration: const BoxDecoration(
                          color: Colors.transparent,
                        ),
                        minScale: PhotoViewComputedScale.contained * 0.8,
                        maxScale: PhotoViewComputedScale.covered * 2,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                
                // CLOSE BUTTON
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Tutup'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

// ✅ PERBAIKAN: PREVIEW IMAGE DARI FILE LOKAL
void _showImagePreview(File imageFile, String title) {
  showDialog(
    context: context,
    builder: (context) => Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(20),
      child: Stack(
        children: [
          // BACKGROUND OVERLAY
          Container(
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.8),
              borderRadius: BorderRadius.circular(16),
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // TITLE
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                
                // IMAGE CONTAINER
                Container(
                  width: double.infinity,
                  height: 400,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white30),
                  ),
                  child: FutureBuilder<File>(
                    future: Future.value(imageFile),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return Container(
                          color: Colors.grey[800],
                          child: const Center(
                            child: CircularProgressIndicator(),
                          ),
                        );
                      }
                      
                      if (snapshot.hasError || !snapshot.hasData) {
                        return Container(
                          color: Colors.grey[800],
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.error_outline, color: Colors.red, size: 48),
                              const SizedBox(height: 8),
                              const Text(
                                'Gagal memuat gambar',
                                style: TextStyle(color: Colors.white),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Error: ${snapshot.error}',
                                style: const TextStyle(color: Colors.white60, fontSize: 10),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        );
                      }
                      
                      return ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.file(
                          snapshot.data!,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              color: Colors.grey[800],
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.error_outline, color: Colors.red, size: 48),
                                  const SizedBox(height: 8),
                                  const Text(
                                    'Gagal memuat gambar',
                                    style: TextStyle(color: Colors.white),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
                
                // ACTION BUTTONS
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // CLOSE BUTTON
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close, color: Colors.white),
                        label: const Text('Tutup', style: TextStyle(color: Colors.white)),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.white),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    
                    // DOWNLOAD/SHARE BUTTON (Optional)
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          // Bisa ditambahkan fitur share/save image
                          _showSafeSnackBar('Fitur download akan datang');
                        },
                        icon: const Icon(Icons.download, size: 18),
                        label: const Text('Simpan'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // CLOSE BUTTON (TOP RIGHT)
          Positioned(
            top: 10,
            right: 10,
            child: CircleAvatar(
              backgroundColor: Colors.black54,
              radius: 16,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 18),
                onPressed: () => Navigator.pop(context),
                padding: EdgeInsets.zero,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

  // ✅ METHOD BARU: LIHAT FOTO YANG SUDAH DIUPLOAD
// ✅ MODIFIKASI: LIHAT FOTO HANYA DARI FILE LOKAL (TIDAK DARI SERVER)
void _viewDocument(String type, String documentName) async {
  try {
    print('👀 Viewing document from LOCAL: $documentName ($type)');
    
    // ✅ HANY CEK FILE LOKAL - TIDAK CEK SERVER
    final fileInfo = _storageService.getFileInfo(type);
    final hasLocalFile = fileInfo['exists'] == true;
    
    if (hasLocalFile) {
      // ✅ TAMPILKAN FILE LOKAL
      final localFile = _getLocalFile(type);
      if (localFile != null && await localFile.exists()) {
        _showImagePreview(localFile, documentName);
        return;
      }
    }
    
    // ✅ JIKA TIDAK ADA FILE LOKAL
    _showSafeSnackBar('Tidak ada file $documentName di perangkat. Silakan upload ulang.', isError: true);
    
  } catch (e) {
    print('❌ Error viewing local document: $e');
    _showSafeSnackBar('Gagal membuka $documentName: $e', isError: true);
  }
}

// ✅ METHOD: GET LOCAL FILE BERDASARKAN TYPE
File? _getLocalFile(String type) {
  switch (type) {
    case 'ktp':
      return _storageService.ktpFile;
    case 'kk':
      return _storageService.kkFile;
    case 'diri':
      return _storageService.diriFile;
    case 'bukti':
      return _storageService.buktiPembayaranFile;
    default:
      return null;
  }
}

// ✅ PERBAIKAN: PREVIEW IMAGE DARI SERVER
void _showServerImagePreview(String imageUrl, String title) {
  showDialog(
    context: context,
    builder: (context) => Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(20),
      child: Stack(
        children: [
          // BACKGROUND OVERLAY
          Container(
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.8),
              borderRadius: BorderRadius.circular(16),
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // TITLE
                Text(
                  '$title (Server)',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Dari: ${_shortenUrl(imageUrl)}',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 16),
                
                // IMAGE CONTAINER
                Container(
                  width: double.infinity,
                  height: 400,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white30),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      imageUrl,
                      fit: BoxFit.contain,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Container(
                          color: Colors.grey[800],
                          child: Center(
                            child: CircularProgressIndicator(
                              value: loadingProgress.expectedTotalBytes != null
                                  ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                                  : null,
                            ),
                          ),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: Colors.grey[800],
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.error_outline, color: Colors.red, size: 48),
                              const SizedBox(height: 8),
                              const Text(
                                'Gagal memuat gambar dari server',
                                style: TextStyle(color: Colors.white),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'URL: ${_shortenUrl(imageUrl)}',
                                style: const TextStyle(color: Colors.white60, fontSize: 10),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                
                // ACTION BUTTONS
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // CLOSE BUTTON
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close, color: Colors.white),
                        label: const Text('Tutup', style: TextStyle(color: Colors.white)),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.white),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    
                    // REFRESH BUTTON
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          _viewDocument(_getTypeFromTitle(title), title);
                        },
                        icon: const Icon(Icons.refresh, size: 18),
                        label: const Text('Refresh'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // CLOSE BUTTON (TOP RIGHT)
          Positioned(
            top: 10,
            right: 10,
            child: CircleAvatar(
              backgroundColor: Colors.black54,
              radius: 16,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 18),
                onPressed: () => Navigator.pop(context),
                padding: EdgeInsets.zero,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

String _getTypeFromTitle(String title) {
  if (title.toLowerCase().contains('ktp')) return 'ktp';
  if (title.toLowerCase().contains('kartu keluarga')) return 'kk';
  if (title.toLowerCase().contains('foto diri')) return 'diri';
  if (title.toLowerCase().contains('bukti')) return 'bukti';
  return '';
}

  void _showSafeSnackBar(String message, {bool isError = false, int duration = 3}) {
    if (!_isWidgetActive || !mounted) {
      print('⚠️ Widget not active, skipping snackbar: $message');
      return;
    }
    
    try {
      // ✅ CLEAR DULU SEBELUM SHOW BARU
      ScaffoldMessenger.of(context).clearSnackBars();
      
      // ✅ GUNAKAN FUTURE UNTUK MEMASTIKAN CONTEXT READY
      Future.delayed(Duration.zero, () {
        if (!_isWidgetActive || !mounted) return;
        
        try {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(message),
              backgroundColor: isError ? Colors.red : Colors.green,
              duration: Duration(seconds: duration),
              behavior: SnackBarBehavior.floating,
            ),
          );
        } catch (e) {
          print('❌ Error showing snackbar (delayed): $e');
        }
      });
    } catch (e) {
      print('❌ Error in safe snackbar setup: $e');
    }
  }

// ✅ PERBAIKAN: PROSES UPLOAD YANG LEBIH SIMPLE DAN AMAN
Future<void> _startUploadProcess() async {
  print('🚀 _startUploadProcess called');
  
  if (!_isWidgetActive || !mounted) {
    print('❌ Widget not active, cancelling upload');
    return;
  }

  // ✅ SET LOADING STATE
  if (mounted) {
    setState(() {
      _isLoading = true;
      _uploadError = null;
    });
  }

  try {
    // ✅ COMMIT FILE KE STORAGE
    print('💾 Committing files to storage...');
    await _commitAllFilesToStorage();

    // ✅ VALIDASI FILE LENGKAP
    if (!_storageService.isAllFilesWithBuktiComplete) {
      _debugMissingFiles();
      throw Exception('Semua 4 file belum lengkap');
    }

    print('📁 Starting upload for 4 files...');
    
    // ✅ LANGSUNG GUNAKAN METHOD DARI TEMPORARY STORAGE SERVICE
    final result = await _storageService.uploadAllFilesWithBuktiPembayaran();

    print('📡 Upload result: ${result['success']} - ${result['message']}');
    
    // ✅ HANDLE RESPONSE
    if (!_isWidgetActive || !mounted) return;

    setState(() => _isLoading = false);

    if (result['success'] == true) {
      print('✅ Upload successful!');
      
      _showSafeSnackBar(
        '✅ Upload berhasil! Dokumen sedang diverifikasi admin.',
        duration: 4
      );

      // ✅ REFRESH DATA SETELAH SUKSES
      await _refreshUserData();

      // ✅ NAVIGASI SETELAH DELAY
      Future.delayed(const Duration(milliseconds: 1500), () {
        if (_isWidgetActive && mounted) {
          _navigateToProfileAfterUpload();
        }
      });
      
    } else {
      final errorMsg = result['message'] ?? 'Upload gagal';
      throw Exception(errorMsg);
    }
    
  } catch (e) {
    print('❌ Upload process error: $e');
    
    if (_isWidgetActive && mounted) {
      setState(() {
        _isLoading = false;
        _uploadError = 'Upload gagal: $e';
      });
      
      _showSafeSnackBar('Upload gagal: $e', isError: true, duration: 4);
    }
  }
}

// ✅ METHOD BARU: DAPATKAN USER DATA YANG VALID
Future<Map<String, dynamic>> _getValidUserDataForUpload() async {
  try {
    print('🔍 Getting valid user data for upload...');
    
    // ✅ COBA DARI CURRENT USER DI STATE
    if (_currentUser.isNotEmpty && 
        _currentUser['user_id'] != null && 
        _currentUser['user_key'] != null) {
      print('✅ Using current user from state');
      return _currentUser;
    }
    
    // ✅ COBA DARI API SERVICE
    final userFromApi = await _apiService.getCurrentUserForUpload();
    if (userFromApi != null && 
        userFromApi['user_id'] != null && 
        userFromApi['user_key'] != null) {
      print('✅ Using user from API getCurrentUserForUpload()');
      return userFromApi;
    }
    
    // ✅ COBA DARI getCurrentUser() BIASA
    final userFromApi2 = await _apiService.getCurrentUser();
    if (userFromApi2 != null && 
        userFromApi2['user_id'] != null && 
        userFromApi2['user_key'] != null) {
      print('✅ Using user from API getCurrentUser()');
      return userFromApi2;
    }
    
    // ✅ COBA DARI SHARED PREFERENCES
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('user_id');
    final userKey = prefs.getString('user_key');
    
    if (userId != null && userKey != null) {
      print('✅ Using user from SharedPreferences');
      return {
        'user_id': userId,
        'user_key': userKey,
      };
    }
    
    throw Exception('Data user tidak ditemukan. user_id: $userId, user_key: $userKey');
    
  } catch (e) {
    print('❌ Error getting valid user data: $e');
    rethrow;
  }
}

  // ✅ FIX: REFRESH USER DATA SETELAH UPLOAD
  Future<void> _refreshUserData() async {
    try {
      print('🔄 Refreshing user data from server...');
      
      final profileResult = await _apiService.getUserProfile();
      if (profileResult['success'] == true && profileResult['data'] != null) {
        final newUserData = profileResult['data'];
        
        if (mounted && !_isNavigating) {
          setState(() {
            _currentUser = newUserData;
          });
        }
        
        print('✅ User data refreshed after upload');
        
        // ✅ DEBUG STATUS TERBARU
        print('🐛 === AFTER UPLOAD STATUS ===');
        print('📄 KTP: ${newUserData['foto_ktp']}');
        print('📄 KK: ${newUserData['foto_kk']}');
        print('📄 Foto Diri: ${newUserData['foto_diri']}');
        print('💰 Bukti Pembayaran: ${newUserData['foto_bukti']}');
        
        final ktpUploaded = _isDocumentUploadedToServer('ktp');
        final kkUploaded = _isDocumentUploadedToServer('kk');
        final diriUploaded = _isDocumentUploadedToServer('diri');
        final buktiUploaded = _isDocumentUploadedToServer('bukti');
        
        print('✅ KTP Uploaded: $ktpUploaded');
        print('✅ KK Uploaded: $kkUploaded');
        print('✅ Foto Diri Uploaded: $diriUploaded');
        print('✅ Bukti Pembayaran Uploaded: $buktiUploaded');
        print('🎯 All documents uploaded: ${ktpUploaded && kkUploaded && diriUploaded && buktiUploaded}');
        print('🐛 === DEBUG END ===');
        
      } else {
        print('❌ Failed to refresh user data: ${profileResult['message']}');
      }
    } catch (e) {
      print('❌ Error refreshing user data: $e');
    }
  }

  // ✅ METHOD BARU: PROCEED BERDASARKAN USER STATUS
  void _proceedBasedOnUserStatus() {
    final userStatus = _currentUser['status_user'] ?? 0;
    
    print('🎯 Proceeding based on user status: $userStatus');
    
    if (userStatus == 0) {
      // ✅ STATUS 0: KEMBALI KE PROFILE SCREEN
      _proceedToProfileOnly();
    } else {
      // ✅ STATUS 1: KE DASHBOARD
      _proceedToDashboard();
    }
  }

  // ✅ PERBAIKAN: METHOD PROCEED TO DASHBOARD YANG SIMPLE DAN WORKING
  void _proceedToDashboard() {
    print('🚀 _proceedToDashboard called');
    
    if (_isNavigating) {
      print('⚠️ Already navigating, skipping...');
      return;
    }
    
    _isNavigating = true;

    try {
      // ✅ PASTIKAN WIDGET MASIH MOUNTED
      if (!mounted) {
        print('❌ Widget not mounted, cannot navigate');
        return;
      }

      final updatedUser = Map<String, dynamic>.from(_currentUser);
      
      print('🎯 Navigating to DashboardMain with user status: ${updatedUser['status_user']}');
      
      // ✅ GUNAKAN NAVIGATOR YANG LEBIH SIMPLE
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (context) => DashboardMain(user: updatedUser),
        ),
        (route) => false,
      );
      
      print('✅ Navigation to dashboard completed');
      
    } catch (e) {
      print('❌ Navigation error in _proceedToDashboard: $e');
      _isNavigating = false;
      
      // ✅ FALLBACK: COBA NAVIGATION ALTERNATIF
      if (mounted) {
        try {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => DashboardMain(user: _currentUser)),
            (route) => false,
          );
        } catch (e2) {
          print('❌ Fallback navigation also failed: $e2');
        }
      }
    }
  }

// ✅ PERBAIKAN: SHOW VERIFICATION DIALOG - LANGSUNG KE PROFILE
void _showVerificationDialog() {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.verified_user, color: Colors.green),
          SizedBox(width: 8),
          Text('Upload Berhasil'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Dokumen Anda telah berhasil diupload ke server dan sedang menunggu verifikasi admin.',
            style: TextStyle(fontSize: 14),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange),
            ),
            child: const Text(
              '🔒 Status: Menunggu Verifikasi\n'
              'Saat ini Anda hanya dapat mengakses menu profile. '
              'Setelah diverifikasi, Anda akan mendapatkan akses penuh.',
              style: TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
      actions: [
        // ✅ PERBAIKAN: LANGSUNG KE PROFILE SCREEN (BUKAN AKTIVASI BERHASIL)
        ElevatedButton(
          onPressed: () {
            Navigator.pop(context);
            _navigateToProfileAfterUpload();
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
          ),
          child: const Text('Lanjut ke Profile'),
        ),
      ],
    ),
  );
}

// ✅ PERBAIKAN: NAVIGASI KE PROFILE SETELAH UPLOAD BERHASIL
void _navigateToProfileAfterUpload() {
  print('🚀 _navigateToProfileAfterUpload called');
  
  if (_isNavigating || !_isWidgetActive) {
    print('⚠️ Already navigating or widget inactive, skipping...');
    return;
  }
  
  _isNavigating = true;

  try {
    // ✅ PASTIKAN KITA MASIH DI CONTEXT YANG VALID
    if (!mounted) {
      print('❌ Widget not mounted, cannot navigate');
      _isNavigating = false;
      return;
    }

    final updatedUser = Map<String, dynamic>.from(_currentUser);
    
    print('🎯 Navigating to ProfileScreen with user: ${updatedUser['username']}');
    
    // ✅ GUNAKAN APPROACH YANG LEBIH AMAN
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_isWidgetActive) return;
      
      try {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (context) => ProfileScreen(user: updatedUser),
          ),
          (route) => false,
        );
        print('✅ Navigation to profile completed');
      } catch (e) {
        print('❌ Navigation error in post frame: $e');
        _isNavigating = false;
      }
    });
    
  } catch (e) {
    print('❌ Navigation error in _navigateToProfileAfterUpload: $e');
    _isNavigating = false;
  }
}

  // ✅ METHOD BARU: KE PROFILE SAJA (UNTUK STATUS 0)
  void _proceedToProfileOnly() {
    print('🚀 Navigating to ProfileScreen (status 0 restriction)');
    
    if (_isNavigating) return;
    _isNavigating = true;

    final updatedUser = Map<String, dynamic>.from(_currentUser);
    
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => ProfileScreen(user: updatedUser)),
      (route) => false,
    );
  }

  // ✅ SHOW IMAGE SOURCE DIALOG dengan opsi kamera
  void _showImageSourceDialog(String type, String documentName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Pilih Sumber $documentName'),
        content: Text('Pilih sumber untuk mengambil gambar $documentName'),
        actions: [
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    switch (type) {
                      case 'ktp':
                        _takePhotoKTP();
                        break;
                      case 'kk':
                        _takePhotoKK();
                        break;
                      case 'diri':
                        _takePhotoFotoDiri();
                        break;
                      case 'bukti':
                        _takePhotoBuktiPembayaran();
                        break;
                    }
                  },
                  icon: const Icon(Icons.camera_alt),
                  label: const Text('Kamera'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[700],
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    switch (type) {
                      case 'ktp':
                        _uploadKTP();
                        break;
                      case 'kk':
                        _uploadKK();
                        break;
                      case 'diri':
                        _uploadFotoDiri();
                        break;
                      case 'bukti':
                        _uploadBuktiPembayaran();
                        break;
                    }
                  },
                  icon: const Icon(Icons.photo_library),
                  label: const Text('Galeri'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green[700],
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Batal'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ✅ BUILD DOKUMEN CARD dengan status dari TemporaryStorage + Server
// ✅ PERBAIKAN: BUILD DOKUMEN CARD - TOMBOL LIHAT HANYA UNTUK FILE LOKAL
Widget _buildDokumenCard({
  required String type,
  required String title,
  required String description,
  required IconData icon,
  required Color color,
}) {
  final fileInfo = _storageService.getFileInfo(type);
  final hasLocalFile = fileInfo['exists'] == true;
  final isUploading = _storageService.isUploading;
  
  // ✅ CEK STATUS UPLOAD KE SERVER (Hanya untuk info status)
  final isUploadedToServer = _isDocumentUploadedToServer(type);
  final serverUrl = _getDocumentServerUrl(type);

  print('🎨 Building $type card - Server: $isUploadedToServer, Local: $hasLocalFile');

  // ✅ TOMBOL LIHAT HANYA MUNCUL JIKA ADA FILE LOKAL
  final canViewFile = hasLocalFile; // ← HANYA LOKAL, TIDAK CEK SERVER

  return Card(
    elevation: 2,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          // ICON
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 12),
          
          // CONTENT
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 6),
                
                // ✅ STATUS INDICATOR (Tetap tampilkan status server)
                if (isUploadedToServer) ...[
                  Row(
                    children: [
                      Icon(Icons.cloud_done, color: Colors.green, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        'Terverifikasi di Server',
                        style: TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.w500,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ] else if (hasLocalFile) ...[
                  Row(
                    children: [
                      Icon(Icons.pending, color: Colors.orange, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        'Menunggu Upload',
                        style: TextStyle(
                          color: Colors.orange,
                          fontWeight: FontWeight.w500,
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${(fileInfo['size'] / 1024).toStringAsFixed(1)} KB',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                  if (fileInfo['filename'] != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      fileInfo['filename'],
                      style: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 10,
                        fontStyle: FontStyle.italic,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ] else ...[
                  Row(
                    children: [
                      Icon(Icons.warning, color: Colors.red, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        'Belum Diupload',
                        style: TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.w500,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          
          // BUTTONS COLUMN
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // UPLOAD/GANTI BUTTON
              SizedBox(
                width: 80,
                height: 36,
                child: ElevatedButton(
                  onPressed: isUploading ? null : () => _showImageSourceDialog(type, title),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isUploadedToServer ? Colors.green : 
                                  hasLocalFile ? Colors.orange : color,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  child: isUploading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          isUploadedToServer ? '✓ Verified' : 
                          hasLocalFile ? 'Upload' : 'Pilih',
                          style: const TextStyle(fontSize: 12),
                        ),
                ),
              ),
              
              const SizedBox(height: 4),
              
              // ✅ TOMBOL LIHAT FOTO (HANYA JIKA ADA FILE LOKAL)
              if (canViewFile) ...[
                SizedBox(
                  width: 80,
                  height: 28,
                  child: OutlinedButton(
                    onPressed: isUploading ? null : () => _viewDocument(type, title),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.blue,
                      side: const BorderSide(color: Colors.blue),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.visibility, size: 12),
                        SizedBox(width: 2),
                        Text(
                          'Lihat',
                          style: TextStyle(fontSize: 10),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 4),
              ],
              
              // HAPUS BUTTON (HANYA JIKA ADA FILE LOKAL DAN BELUM DI SERVER)
              if (hasLocalFile && !isUploadedToServer) ...[
                SizedBox(
                  width: 80,
                  height: 28,
                  child: OutlinedButton(
                    onPressed: isUploading ? null : () => _clearFile(type, title),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                    child: const Text(
                      'Hapus',
                      style: TextStyle(fontSize: 10),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    ),
  );
}

  // ✅ PERBAIKAN: BUILD UPLOAD MANUAL SECTION DENGAN STATUS VERIFIKASI
  Widget _buildUploadManualSection() {
    final allFilesComplete = _storageService.isAllFilesWithBuktiComplete;
    final hasAnyFile = _storageService.hasAnyFile;

    // ✅ CEK APAKAH ADA FILE YANG BELUM TERUPLOAD KE SERVER
    final hasPendingUpload = hasAnyFile && 
        (!_isDocumentUploadedToServer('ktp') || 
         !_isDocumentUploadedToServer('kk') || 
         !_isDocumentUploadedToServer('diri') ||
         !_isDocumentUploadedToServer('bukti'));

    if (!hasPendingUpload && !allFilesComplete) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue[200]!),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.cloud_upload, color: Colors.green[700], size: 24),
              const SizedBox(width: 8),
              Text(
                allFilesComplete ? 'Siap Upload 4 File!' : 'Upload Dokumen',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.green[700],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          
          // ✅ TAMBAHKAN INFO VERIFIKASI
          if (allFilesComplete) ...[
            const SizedBox(height: 8),
            _buildVerificationStatusInfo(),
          ],
          
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 45,
            child: ElevatedButton.icon(
              onPressed: _storageService.isUploading ? null : _uploadAllFiles,
              style: ElevatedButton.styleFrom(
                backgroundColor: allFilesComplete ? Colors.green[700] : Colors.green[700],
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.cloud_upload, size: 20),
              label: _storageService.isUploading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      allFilesComplete ? 'Upload 4 File ke Server' : 'Upload Dokumen',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  // ✅ WIDGET BARU: STATUS VERIFIKASI UNTUK USER STATUS 0
  Widget _buildVerificationStatusInfo() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange),
      ),
      child: const Row(
        children: [
          Icon(Icons.schedule, color: Colors.orange, size: 20),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Status: Menunggu Verifikasi Admin\nDokumen akan diverifikasi dalam 1x24 jam',
              style: TextStyle(
                color: Colors.orange,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ✅ WIDGET BARU: VERIFICATION TIMELINE
  Widget _buildVerificationTimeline() {
    final userStatus = _currentUser['status_user'] ?? 0;
    final isVerified = userStatus == 1 || userStatus == '1';
    
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Proses Verifikasi',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.green[800],
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 12),
          _buildTimelineStep(1, 'Upload Dokumen', true, Icons.cloud_upload),
          _buildTimelineStep(2, 'Review Admin', isVerified, Icons.verified_user),
          _buildTimelineStep(3, 'Aktif', isVerified, Icons.check_circle),
        ],
      ),
    );
  }

  Widget _buildTimelineStep(int step, String title, bool isCompleted, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: isCompleted ? Colors.green : Colors.grey[300],
              shape: BoxShape.circle,
            ),
            child: Center(
              child: isCompleted
                  ? Icon(icon, color: Colors.white, size: 16)
                  : Text(
                      '$step',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: isCompleted ? Colors.green[800] : Colors.grey[600],
                fontSize: 14,
              ),
            ),
          ),
          if (isCompleted)
            Icon(Icons.check_circle, color: Colors.green, size: 20),
        ],
      ),
    );
  }

  // ✅ WIDGET BARU: USER STATUS BANNER
  Widget _buildUserStatusBanner() {
    final userStatus = _currentUser['status_user'] ?? 0;
    final isVerified = userStatus == 1 || userStatus == '1';
    
    if (isVerified) {
      return Container(
        padding: const EdgeInsets.all(12),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.green[50],
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.green),
        ),
        child: Row(
          children: [
            Icon(Icons.verified_user, color: Colors.green[700], size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Akun Terverifikasi',
                    style: TextStyle(
                      color: Colors.green[700],
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    'Selamat! Akun Anda sudah aktif dan dapat menggunakan semua fitur',
                    style: TextStyle(
                      color: Colors.green[600],
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    } else {
      return Container(
        padding: const EdgeInsets.all(12),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.orange[50],
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.orange),
        ),
        child: Row(
          children: [
            Icon(Icons.schedule, color: Colors.orange[700], size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Menunggu Verifikasi Admin',
                    style: TextStyle(
                      color: Colors.orange[700],
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    'Dokumen akan diverifikasi dalam 1x24 jam. Anda tetap dapat menggunakan aplikasi',
                    style: TextStyle(
                      color: Colors.orange[600],
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }
  }

@override
Widget build(BuildContext context) {
  // ✅ CEK WIDGET STATUS DI AWAL BUILD
  if (!_isWidgetActive) {
    return const Scaffold(body: Center(child: Text('Loading...')));
  }

  if (_isInitializing) {
    return Scaffold(
      backgroundColor: Colors.green[50],
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              color: Colors.green[700],
            ),
            const SizedBox(height: 16),
            Text(
              'Memuat data dokumen...',
              style: TextStyle(
                color: Colors.green[700],
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }

    final allFilesComplete = _storageService.isAllFilesWithBuktiComplete;
    final uploadedCount = [
      _storageService.hasKtpFile,
      _storageService.hasKkFile,
      _storageService.hasDiriFile,
      _storageService.hasBuktiPembayaran,
    ].where((e) => e).length;

    // ✅ HITUNG DOKUMEN YANG SUDAH DI SERVER
    final serverUploadedCount = [
      _isDocumentUploadedToServer('ktp'),
      _isDocumentUploadedToServer('kk'),
      _isDocumentUploadedToServer('diri'),
      _isDocumentUploadedToServer('bukti'),
    ].where((e) => e).length;

    final userStatus = _currentUser['status_user'] ?? 0;
    final isVerified = userStatus == 1 || userStatus == '1';

    return Scaffold(
      backgroundColor: Colors.green[50],
      appBar: AppBar(
        title: const Text('Upload Dokumen'),
        backgroundColor: Colors.green[800],
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (uploadedCount > 0 || serverUploadedCount > 0)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$uploadedCount/4',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (serverUploadedCount > 0)
                      Text(
                        '$serverUploadedCount server',
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.green,
                        ),
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // HEADER
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.green.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Icon(
                    isVerified ? Icons.verified_user : Icons.verified_user_outlined, 
                    size: 60, 
                    color: isVerified ? Colors.green : Colors.green[700]
                  ),
                  const SizedBox(height: 12),
                  Text(
                    isVerified ? 'Dokumen Terverifikasi' : 'Lengkapi Dokumen',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.green[800],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isVerified 
                        ? 'Semua dokumen sudah terverifikasi dan aktif'
                        : 'Upload 4 dokumen wajib (KTP, KK, Foto Diri, Bukti Pembayaran)',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.green[600],
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  
                  // PROGRESS INDICATOR (4 STEP) - DENGAN BUKTI PEMBAYARAN
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildProgressStep(1, 'KTP', _isDocumentUploadedToServer('ktp') || _storageService.hasKtpFile),
                      Container(width: 10, height: 2, color: (_isDocumentUploadedToServer('ktp') || _storageService.hasKtpFile) ? Colors.green : Colors.grey[300]),
                      _buildProgressStep(2, 'KK', _isDocumentUploadedToServer('kk') || _storageService.hasKkFile),
                      Container(width: 10, height: 2, color: (_isDocumentUploadedToServer('kk') || _storageService.hasKkFile) ? Colors.green : Colors.grey[300]),
                      _buildProgressStep(3, 'Diri', _isDocumentUploadedToServer('diri') || _storageService.hasDiriFile),
                      Container(width: 10, height: 2, color: (_isDocumentUploadedToServer('diri') || _storageService.hasDiriFile) ? Colors.green : Colors.grey[300]),
                      _buildProgressStep(4, 'Bukti', _isDocumentUploadedToServer('bukti') || _storageService.hasBuktiPembayaran),
                      Container(width: 10, height: 2, color: (_isDocumentUploadedToServer('bukti') || _storageService.hasBuktiPembayaran) ? Colors.green : Colors.grey[300]),
                    ],
                  ),

                  // STATUS INFO
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        isVerified ? Icons.verified : Icons.info_outline, 
                        color: isVerified ? Colors.green : Colors.green[700], 
                        size: 16
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isVerified 
                            ? 'Status: Terverifikasi • $serverUploadedCount/4 dokumen'
                            : 'Status: $serverUploadedCount/4 di server • Menunggu verifikasi',
                        style: TextStyle(
                          color: isVerified ? Colors.green : Colors.green[700],
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),

                  // UPLOAD STATUS
                  if (_storageService.isUploading) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue[200]!),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.blue[700],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _storageService.uploadMessage,
                            style: TextStyle(
                              color: Colors.blue[700],
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // USER STATUS BANNER
            _buildUserStatusBanner(),

            // ERROR MESSAGE
            if (_uploadError != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red[200]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: Colors.red[700], size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _uploadError!,
                        style: TextStyle(
                          color: Colors.red[700],
                          fontSize: 12,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close, color: Colors.red[700], size: 16),
                      onPressed: () {
                        if (mounted && !_isNavigating) {
                          setState(() => _uploadError = null);
                        }
                      },
                    ),
                  ],
                ),
              ),
            ],

            // CONTENT
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // VERIFICATION TIMELINE (Hanya untuk status 0)
                    if (!isVerified) _buildVerificationTimeline(),

                    const SizedBox(height: 16),

                    // KTP CARD
                    _buildDokumenCard(
                      type: 'ktp',
                      title: 'KTP (Kartu Tanda Penduduk)',
                      description: 'Upload foto KTP yang jelas dan terbaca\n• Pastikan foto tidak blur\n• Semua informasi terbaca jelas\n• Format JPG/PNG (max 5MB)',
                      icon: Icons.credit_card,
                      color: Colors.blue,
                    ),
                    const SizedBox(height: 16),

                    // KK CARD
                    _buildDokumenCard(
                      type: 'kk',
                      title: 'Kartu Keluarga (KK)',
                      description: 'Upload foto KK yang jelas dan terbaca\n• Pastikan foto tidak blur\n• Semua halaman penting terbaca\n• Format JPG/PNG (max 5MB)',
                      icon: Icons.family_restroom,
                      color: Colors.green,
                    ),
                    const SizedBox(height: 16),

                    // FOTO DIRI CARD
                    _buildDokumenCard(
                      type: 'diri',
                      title: 'Foto Diri Terbaru',
                      description: 'Upload pas foto terbaru\n• Latar belakang polos\n• Wajah terlihat jelas\n• Ekspresi netral\n• Format JPG/PNG (max 5MB)',
                      icon: Icons.person,
                      color: Colors.orange,
                    ),
                    const SizedBox(height: 16),

                    // BUKTI PEMBAYARAN CARD
                    _buildDokumenCard(
                      type: 'bukti',
                      title: 'Bukti Pembayaran',
                      description: 'Foto bukti transfer sebesar Rp. 125.000,-\n• Untuk Simpanan Pokok (SIMPOK) ke\n• Bank Syariah Indonesia(BSI)\n• No Rekening: 333-667-66667\n•An. Koperasi Syirkah Muslim Indonesia',
                      icon: Icons.receipt,
                      color: Colors.purple,
                    ),
                    const SizedBox(height: 24),

                    // UPLOAD MANUAL SECTION (Hanya jika belum verified atau ada file pending)
                    if (!isVerified || !_storageService.isAllFilesWithBuktiComplete) 
                      _buildUploadManualSection(),

                    const SizedBox(height: 16),

                    // TOMBOL LANJUT KE DASHBOARD (Untuk status 1)
                    if (isVerified) ...[
                      SizedBox(
                        width: double.infinity,
                        height: 45,
                        child: ElevatedButton(
                          onPressed: _proceedToDashboard,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green[700],
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'Lanjut ke Dashboard',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // INFO
                    if (!allFilesComplete && !isVerified) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.orange[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.orange[200]!),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline, color: Colors.orange[700], size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Upload semua 4 dokumen untuk pengalaman terbaik. '
                                'Dokumen akan disimpan sementara dan diupload otomatis ketika lengkap.',
                                style: TextStyle(
                                  color: Colors.orange[700],
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressStep(int step, String label, bool isCompleted) {
    return Column(
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: isCompleted ? Colors.green : Colors.grey[300],
            shape: BoxShape.circle,
          ),
          child: Center(
            child: isCompleted 
                ? Icon(Icons.check, color: Colors.white, size: 14)
                : Text(
                    '$step',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 9,
            color: isCompleted ? Colors.green : Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  // ✅ HELPER: GET DOCUMENT SERVER URL
  String? _getDocumentServerUrl(String type) {
    switch (type) {
      case 'ktp':
        return _currentUser['foto_ktp'];
      case 'kk':
        return _currentUser['foto_kk'];
      case 'diri':
        return _currentUser['foto_diri'];
      case 'bukti':
        return _currentUser['foto_bukti'];
      default:
        return null;
    }
  }

  // ✅ HELPER: SHORTEN URL UNTUK DISPLAY
  String _shortenUrl(String url) {
    if (url.length <= 30) return url;
    return '${url.substring(0, 15)}...${url.substring(url.length - 10)}';
  }
}
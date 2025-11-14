import 'dart:io';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DioService {
  static const String baseUrl = 'http://demo.bsdeveloper.id/api';
  
  String _deviceId = '12341231313131';
  String _deviceToken = '1234232423424';

  // ✅ PERBAIKAN: Dio instance dengan konfigurasi yang lebih baik
  Dio get dio => Dio(BaseOptions(
    baseUrl: baseUrl,
    connectTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(seconds: 30),
    sendTimeout: const Duration(seconds: 30),
    validateStatus: (status) => status! < 500, // Terima semua status code kecuali server error
  ));

  // ✅ PERBAIKAN: Interceptor untuk logging dan error handling
  DioService() {
    // Tambah interceptor untuk debugging
    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        print('🌐 DIO REQUEST: ${options.method} ${options.path}');
        print('📤 DIO Headers: ${options.headers}');
        print('📤 DIO Data: ${options.data}');
        return handler.next(options);
      },
      onResponse: (response, handler) {
        print('📡 DIO RESPONSE: ${response.statusCode} ${response.statusMessage}');
        print('📡 DIO Data: ${response.data}');
        return handler.next(response);
      },
      onError: (DioException e, handler) {
        print('❌ DIO ERROR: ${e.type}');
        print('❌ DIO Message: ${e.message}');
        print('❌ DIO Response: ${e.response?.data}');
        print('❌ DIO Status: ${e.response?.statusCode}');
        return handler.next(e);
      },
    ));
  }

  // ✅ PERBAIKAN: GET HEADERS DENGAN DIO - Content-Type yang lebih fleksibel
  Future<Map<String, dynamic>> _getHeaders({bool isMultipart = true}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userKey = prefs.getString('token');
      
      final headers = {
        'DEVICE-ID': _deviceId,
        'DEVICE-TOKEN': _deviceToken,
      };
      
      // ✅ PERBAIKAN: Hanya set Content-Type jika bukan multipart
      if (!isMultipart) {
        headers['Content-Type'] = 'application/x-www-form-urlencoded';
      }
      
      if (userKey != null && userKey.isNotEmpty) {
        headers['x-api-key'] = userKey;
        print('✅ DIO x-api-key found: ${userKey.substring(0, 10)}...');
      } else {
        print('⚠️ DIO x-api-key not found in SharedPreferences');
      }
      
      return headers;
    } catch (e) {
      print('❌ DIO Error getHeaders: $e');
      return {
        'DEVICE-ID': _deviceId,
        'DEVICE-TOKEN': _deviceToken,
      };
    }
  }

  // ✅ PERBAIKAN: Upload foto dengan DIO - lebih robust
  Future<Map<String, dynamic>> uploadFotoWithDio({
    required String type,
    required String filePath,
  }) async {
    try {
      print('🚀 DIO UPLOAD START: $type');
      print('📁 File path: $filePath');
      
      final headers = await _getHeaders(isMultipart: true);
      final file = File(filePath);
      
      // ✅ VALIDASI FILE LEBIH KETAT
      if (!await file.exists()) {
        return {'success': false, 'message': 'File tidak ditemukan: $filePath'};
      }

      final fileSize = await file.length();
      print('📁 DIO File size: ${(fileSize / 1024).toStringAsFixed(2)} KB');
      
      if (fileSize == 0) {
        return {'success': false, 'message': 'File kosong atau tidak dapat diakses'};
      }

      // ✅ VALIDASI FORMAT FILE - HANYA JPG/JPEG
      final fileExtension = filePath.toLowerCase().split('.').last;
      final allowedExtensions = ['jpg', 'jpeg'];
      if (!allowedExtensions.contains(fileExtension)) {
        return {
          'success': false,
          'message': 'Format file .$fileExtension tidak didukung. Hanya JPG/JPEG yang diperbolehkan.'
        };
      }

      // ✅ PERBAIKAN: COBA BERBAGAI FIELD NAME DENGAN PRIORITAS
      final possibleFieldNames = [
        'foto',           // Paling umum
        'photo',          // Alternatif 1
        'image',          // Alternatif 2  
        'file',           // Alternatif 3
        'upload',         // Alternatif 4
        'foto_file',      // Alternatif 5
        'file_upload',    // Alternatif 6
      ];
      
      bool fileAdded = false;
      String usedFieldName = '';
      FormData formData = FormData();

      for (final fieldName in possibleFieldNames) {
        try {
          formData = FormData.fromMap({
            'type': type,
            fieldName: await MultipartFile.fromFile(
              filePath,
              filename: '${type}_${DateTime.now().millisecondsSinceEpoch}.jpg',
            ),
          });
          fileAdded = true;
          usedFieldName = fieldName;
          print('✅ DIO File berhasil dilampirkan dengan field: $fieldName');
          break; // Stop pada field name pertama yang berhasil
        } catch (e) {
          print('❌ DIO Gagal dengan field $fieldName: $e');
          continue;
        }
      }

      if (!fileAdded) {
        return {
          'success': false, 
          'message': 'Gagal menambahkan file ke request DIO dengan semua field name'
        };
      }

      // ✅ PERBAIKAN: TAMBAHKAN USER DATA DENGAN CARA YANG LEBIH BAIK
      final currentUser = await _getCurrentUser();
      if (currentUser != null) {
        if (currentUser['user_id'] != null) {
          formData.fields.add(MapEntry('user_id', currentUser['user_id'].toString()));
          print('✅ DIO Added user_id: ${currentUser['user_id']}');
        }
        
        if (currentUser['user_key'] != null) {
          formData.fields.add(MapEntry('user_key', currentUser['user_key'].toString()));
          print('✅ DIO Added user_key: ${currentUser['user_key']?.toString().substring(0, 10)}...');
        }
      } else {
        print('❌ DIO User data is null');
      }

      print('📤 DIO Headers: ${headers.keys}');
      print('📤 DIO Form data fields: ${formData.fields}');
      print('📤 DIO Used field name: $usedFieldName');

      // ✅ PERBAIKAN: KIRIM DENGAN DIO DENGAN ERROR HANDLING LEBIH BAIK
      final response = await dio.post(
        '/users/setPhoto',
        data: formData,
        options: Options(
          headers: headers,
          contentType: 'multipart/form-data',
          receiveTimeout: const Duration(seconds: 60),
          sendTimeout: const Duration(seconds: 60),
        ),
      );

      print('📡 DIO Response Status: ${response.statusCode}');
      print('📡 DIO Response Data: ${response.data}');

      if (response.statusCode == 200) {
        final data = response.data;
        
        if (data['status'] == true) {
          print('✅ DIO UPLOAD SUCCESS dengan field: $usedFieldName');
          
          return {
            'success': true,
            'message': data['message'] ?? 'Upload berhasil',
            'data': data,
            'field_name': usedFieldName
          };
        } else {
          // ✅ PERBAIKAN: Parse error message yang lebih baik
          String errorMessage = data['message'] ?? 'Upload gagal';
          errorMessage = errorMessage.replaceAll(RegExp(r'<[^>]*>'), ''); // Hapus HTML tags
          
          return {
            'success': false,
            'message': errorMessage,
            'field_name': usedFieldName
          };
        }
      } else {
        String errorMessage = 'Server error ${response.statusCode}';
        try {
          if (response.data != null && response.data['message'] != null) {
            errorMessage = response.data['message'].toString();
            errorMessage = errorMessage.replaceAll(RegExp(r'<[^>]*>'), '');
          }
        } catch (e) {
          errorMessage = response.data?.toString() ?? 'Unknown error';
        }
        
        return {
          'success': false,
          'message': errorMessage,
          'field_name': usedFieldName
        };
      }
    } catch (e) {
      print('❌ DIO UPLOAD ERROR: $e');
      
      // ✅ PERBAIKAN: Handle specific Dio errors
      if (e is DioException) {
        String errorMessage = 'Upload error';
        
        switch (e.type) {
          case DioExceptionType.connectionTimeout:
          case DioExceptionType.sendTimeout:
          case DioExceptionType.receiveTimeout:
            errorMessage = 'Timeout: Koneksi terlalu lama, coba lagi';
            break;
          case DioExceptionType.badResponse:
            errorMessage = 'Server error: ${e.response?.statusCode}';
            if (e.response?.data != null && e.response?.data['message'] != null) {
              errorMessage = e.response!.data['message'].toString();
              errorMessage = errorMessage.replaceAll(RegExp(r'<[^>]*>'), '');
            }
            break;
          case DioExceptionType.cancel:
            errorMessage = 'Upload dibatalkan';
            break;
          case DioExceptionType.unknown:
            if (e.error is SocketException) {
              errorMessage = 'Tidak ada koneksi internet';
            } else {
              errorMessage = 'Unknown error: ${e.message}';
            }
            break;
          default:
            errorMessage = 'Upload error: ${e.message}';
        }
        
        return {
          'success': false,
          'message': errorMessage
        };
      }
      
      return {
        'success': false,
        'message': 'Upload error: ${e.toString()}'
      };
    }
  }

  // ✅ PERBAIKAN: Upload bukti transfer dengan DIO
  Future<Map<String, dynamic>> uploadBuktiTransferWithDio({
    required String transaksiId,
    required String filePath,
    required String jenisTransaksi,
  }) async {
    try {
      print('🚀 DIO UPLOAD BUKTI TRANSFER START');
      print('📁 Transaksi ID: $transaksiId');
      print('📁 Jenis: $jenisTransaksi');
      print('📁 File path: $filePath');
      
      final headers = await _getHeaders(isMultipart: true);
      final file = File(filePath);
      
      // ✅ VALIDASI FILE
      if (!await file.exists()) {
        return {'success': false, 'message': 'File bukti transfer tidak ditemukan'};
      }

      final fileSize = await file.length();
      if (fileSize == 0) {
        return {'success': false, 'message': 'File bukti transfer kosong'};
      }

      if (fileSize > 5 * 1024 * 1024) {
        return {'success': false, 'message': 'Ukuran file terlalu besar. Maksimal 5MB.'};
      }

      // ✅ VALIDASI FORMAT FILE
      final fileExtension = filePath.toLowerCase().split('.').last;
      final allowedExtensions = ['jpg', 'jpeg'];
      if (!allowedExtensions.contains(fileExtension)) {
        return {
          'success': false,
          'message': 'Format file .$fileExtension tidak didukung. Hanya JPG/JPEG yang diperbolehkan.'
        };
      }

      // ✅ PERBAIKAN: BUAT FORM DATA DENGAN BERBAGAI FIELD NAME OPTIONS
      final possibleFieldNames = ['bukti_transfer', 'bukti', 'transfer_proof', 'file'];
      bool fileAdded = false;
      String usedFieldName = '';
      FormData formData = FormData();

      for (final fieldName in possibleFieldNames) {
        try {
          formData = FormData.fromMap({
            'transaksi_id': transaksiId,
            'jenis_transaksi': jenisTransaksi,
            fieldName: await MultipartFile.fromFile(
              filePath,
              filename: 'bukti_${jenisTransaksi}_${DateTime.now().millisecondsSinceEpoch}.jpg',
            ),
          });
          fileAdded = true;
          usedFieldName = fieldName;
          print('✅ DIO Bukti berhasil dilampirkan dengan field: $fieldName');
          break;
        } catch (e) {
          print('❌ DIO Bukti gagal dengan field $fieldName: $e');
          continue;
        }
      }

      if (!fileAdded) {
        return {
          'success': false,
          'message': 'Gagal menambahkan file bukti ke request DIO'
        };
      }

      // ✅ TAMBAH USER DATA
      final currentUser = await _getCurrentUser();
      if (currentUser != null && currentUser['user_id'] != null) {
        formData.fields.add(MapEntry('user_id', currentUser['user_id'].toString()));
        print('✅ DIO Bukti Added user_id: ${currentUser['user_id']}');
      }

      print('📤 DIO Bukti Headers: ${headers.keys}');
      print('📤 DIO Bukti Form data fields: ${formData.fields}');
      print('📤 DIO Bukti Used field name: $usedFieldName');

      // ✅ KIRIM DENGAN DIO
      final response = await dio.post(
        '/transaction/uploadBukti',
        data: formData,
        options: Options(
          headers: headers,
          contentType: 'multipart/form-data',
          receiveTimeout: const Duration(seconds: 60),
          sendTimeout: const Duration(seconds: 60),
        ),
      );

      print('📡 DIO Bukti Response Status: ${response.statusCode}');
      print('📡 DIO Bukti Response Data: ${response.data}');

      if (response.statusCode == 200) {
        final data = response.data;
        
        if (data['status'] == true) {
          return {
            'success': true,
            'message': data['message'] ?? 'Bukti transfer berhasil diupload',
            'file_path': data['file_path'] ?? data['path'] ?? data['url'],
            'field_name': usedFieldName
          };
        } else {
          String errorMessage = data['message'] ?? 'Upload bukti transfer gagal';
          errorMessage = errorMessage.replaceAll(RegExp(r'<[^>]*>'), '');
          
          return {
            'success': false,
            'message': errorMessage,
            'field_name': usedFieldName
          };
        }
      } else if (response.statusCode == 401) {
        await _clearToken();
        return {
          'success': false,
          'message': 'Sesi telah berakhir',
          'token_expired': true
        };
      } else {
        String errorMessage = 'Server error ${response.statusCode}';
        try {
          if (response.data != null && response.data['message'] != null) {
            errorMessage = response.data['message'].toString();
            errorMessage = errorMessage.replaceAll(RegExp(r'<[^>]*>'), '');
          }
        } catch (e) {
          errorMessage = response.data?.toString() ?? 'Unknown error';
        }
        
        return {
          'success': false,
          'message': errorMessage,
          'field_name': usedFieldName
        };
      }
    } catch (e) {
      print('❌ DIO BUKTI UPLOAD ERROR: $e');
      
      if (e is DioException) {
        String errorMessage = 'Upload bukti error';
        
        switch (e.type) {
          case DioExceptionType.connectionTimeout:
          case DioExceptionType.sendTimeout:
          case DioExceptionType.receiveTimeout:
            errorMessage = 'Timeout: Koneksi terlalu lama, coba lagi';
            break;
          case DioExceptionType.badResponse:
            if (e.response?.statusCode == 401) {
              await _clearToken();
              return {
                'success': false,
                'message': 'Sesi telah berakhir',
                'token_expired': true
              };
            }
            errorMessage = 'Server error: ${e.response?.statusCode}';
            if (e.response?.data != null && e.response?.data['message'] != null) {
              errorMessage = e.response!.data['message'].toString();
              errorMessage = errorMessage.replaceAll(RegExp(r'<[^>]*>'), '');
            }
            break;
          case DioExceptionType.unknown:
            if (e.error is SocketException) {
              errorMessage = 'Tidak ada koneksi internet';
            }
            break;
          default:
            errorMessage = 'Upload bukti error: ${e.message}';
        }
        
        return {
          'success': false,
          'message': errorMessage
        };
      }
      
      return {
        'success': false,
        'message': 'Upload bukti error: ${e.toString()}'
      };
    }
  }

  // ✅ METHOD BARU: Upload multiple files dengan DIO
  Future<Map<String, dynamic>> uploadMultipleFilesWithDio({
    required Map<String, String> files, // {'foto_ktp': path, 'foto_kk': path, 'foto_diri': path}
  }) async {
    try {
      print('🚀 DIO UPLOAD MULTIPLE FILES START');
      print('📁 Files to upload: ${files.keys.join(', ')}');
      
      final headers = await _getHeaders(isMultipart: true);
      FormData formData = FormData();

      // ✅ VALIDASI SEMUA FILE SEBELUM UPLOAD
      for (var entry in files.entries) {
        final file = File(entry.value);
        if (!await file.exists()) {
          return {
            'success': false,
            'message': 'File ${entry.key} tidak ditemukan: ${entry.value}'
          };
        }

        final fileSize = await file.length();
        if (fileSize == 0) {
          return {
            'success': false,
            'message': 'File ${entry.key} kosong'
          };
        }

        // Validasi format file - HANYA JPG
        final fileExtension = entry.value.toLowerCase().split('.').last;
        final allowedExtensions = ['jpg', 'jpeg'];
        if (!allowedExtensions.contains(fileExtension)) {
          return {
            'success': false,
            'message': 'Format file .$fileExtension tidak didukung untuk ${entry.key}. Hanya JPG/JPEG yang diperbolehkan.'
          };
        }

        // Tambahkan file ke form data
        formData.files.add(MapEntry(
          entry.key, // 'foto_ktp', 'foto_kk', 'foto_diri'
          await MultipartFile.fromFile(
            entry.value,
            filename: '${entry.key}_${DateTime.now().millisecondsSinceEpoch}.jpg',
          ),
        ));
        print('✅ DIO Added file with field: ${entry.key} -> ${entry.value}');
      }

      // ✅ TAMBAHKAN FORM FIELDS
      formData.fields.add(MapEntry('type', 'foto_ktp'));
      
      // ✅ TAMBAHKAN USER DATA
      final currentUser = await _getCurrentUser();
      if (currentUser != null) {
        if (currentUser['user_id'] != null) {
          formData.fields.add(MapEntry('user_id', currentUser['user_id'].toString()));
          print('✅ DIO Multiple Added user_id: ${currentUser['user_id']}');
        }
        if (currentUser['user_key'] != null) {
          formData.fields.add(MapEntry('user_key', currentUser['user_key'].toString()));
          print('✅ DIO Multiple Added user_key: ${currentUser['user_key']?.toString().substring(0, 10)}...');
        }
      }

      print('📤 DIO Multiple Headers: ${headers.keys}');
      print('📤 DIO Multiple Total files: ${formData.files.length}');

      // ✅ KIRIM REQUEST
      final response = await dio.post(
        '/users/setPhoto',
        data: formData,
        options: Options(
          headers: headers,
          contentType: 'multipart/form-data',
          receiveTimeout: const Duration(seconds: 90),
          sendTimeout: const Duration(seconds: 90),
        ),
      );

      print('📡 DIO Multiple Response Status: ${response.statusCode}');
      print('📡 DIO Multiple Response Data: ${response.data}');

      if (response.statusCode == 200) {
        final data = response.data;
        
        if (data['status'] == true) {
          return {
            'success': true,
            'message': data['message'] ?? 'Semua file berhasil diupload',
            'data': data
          };
        } else {
          String errorMessage = data['message'] ?? 'Upload multiple files gagal';
          errorMessage = errorMessage.replaceAll(RegExp(r'<[^>]*>'), '');
          
          return {
            'success': false,
            'message': errorMessage
          };
        }
      } else {
        String errorMessage = 'Server error ${response.statusCode}';
        try {
          if (response.data != null && response.data['message'] != null) {
            errorMessage = response.data['message'].toString();
            errorMessage = errorMessage.replaceAll(RegExp(r'<[^>]*>'), '');
          }
        } catch (e) {
          errorMessage = response.data?.toString() ?? 'Unknown error';
        }
        
        return {
          'success': false,
          'message': errorMessage
        };
      }
    } catch (e) {
      print('❌ DIO UPLOAD MULTIPLE FILES ERROR: $e');
      
      if (e is DioException) {
        String errorMessage = 'Upload multiple files error';
        
        switch (e.type) {
          case DioExceptionType.connectionTimeout:
          case DioExceptionType.sendTimeout:
          case DioExceptionType.receiveTimeout:
            errorMessage = 'Timeout: Koneksi terlalu lama, coba lagi';
            break;
          case DioExceptionType.badResponse:
            errorMessage = 'Server error: ${e.response?.statusCode}';
            if (e.response?.data != null && e.response?.data['message'] != null) {
              errorMessage = e.response!.data['message'].toString();
              errorMessage = errorMessage.replaceAll(RegExp(r'<[^>]*>'), '');
            }
            break;
          default:
            errorMessage = 'Upload multiple files error: ${e.message}';
        }
        
        return {
          'success': false,
          'message': errorMessage
        };
      }
      
      return {
        'success': false,
        'message': 'Upload multiple files error: ${e.toString()}'
      };
    }
  }

  // ✅ HELPER METHODS

  // Get current user dari SharedPreferences
  Future<Map<String, dynamic>?> _getCurrentUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userString = prefs.getString('user');
      if (userString != null && userString.isNotEmpty) {
        return jsonDecode(userString);
      }
      return null;
    } catch (e) {
      print('❌ DIO Error getting current user: $e');
      return null;
    }
  }

  // Clear token
  Future<void> _clearToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('token');
      await prefs.remove('user');
      print('🔐 DIO Token cleared due to expiration');
    } catch (e) {
      print('❌ DIO Error clearing token: $e');
    }
  }

  // ✅ TEST CONNECTION
  Future<Map<String, dynamic>> testConnection() async {
    try {
      final response = await dio.get(
        '/',
        options: Options(
          headers: await _getHeaders(isMultipart: false),
        ),
      );
      
      return {
        'success': true,
        'status_code': response.statusCode,
        'message': 'DIO Connection successful'
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'DIO Connection failed: $e'
      };
    }
  }

  // ✅ METHOD BARU: Debug upload system
  Future<Map<String, dynamic>> debugUploadSystem() async {
    try {
      print('🐛 === DIO DEBUG UPLOAD SYSTEM START ===');
      
      // 1. Test connection
      final connectionTest = await testConnection();
      print('🌐 DIO Connection test: ${connectionTest['success']}');
      
      // 2. Check token
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      final user = prefs.getString('user');
      
      print('🔐 DIO Token status: ${token != null ? "EXISTS" : "NULL"}');
      print('👤 DIO User data: ${user != null ? "EXISTS" : "NULL"}');
      
      // 3. Test endpoint dengan request kosong
      try {
        final testResponse = await dio.post(
          '/users/setPhoto',
          data: {'test': '1'},
          options: Options(headers: await _getHeaders(isMultipart: false)),
        );
        print('🧪 DIO Endpoint test: ${testResponse.statusCode}');
      } catch (e) {
        print('❌ DIO Endpoint test failed: $e');
      }

      print('🐛 === DIO DEBUG UPLOAD SYSTEM END ===');
      
      return {
        'success': true, 
        'connection': connectionTest['success'],
        'token_exists': token != null,
        'user_exists': user != null
      };
    } catch (e) {
      print('❌ DIO Debug system error: $e');
      return {
        'success': false, 
        'message': 'DIO Debug failed: $e'
      };
    }
  }
}
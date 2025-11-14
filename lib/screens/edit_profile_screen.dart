import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../services/api_service.dart';

class EditProfileScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  final Function(Map<String, dynamic>) onProfileUpdated;

  const EditProfileScreen({
    super.key,
    required this.user,
    required this.onProfileUpdated,
  });

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final ApiService _apiService = ApiService();

  // ✅ CONTROLLERS UNTUK PASSWORD
  final TextEditingController _oldPasswordController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  bool _isLoading = false;
  bool _showOldPassword = false;
  bool _showNewPassword = false;
  bool _showConfirmPassword = false;
  String? _errorMessage;

  // ✅ FIX: GlobalKey untuk ScaffoldMessenger
  final GlobalKey<ScaffoldMessengerState> _scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

  @override
  void initState() {
    super.initState();
    print('👤 EditProfileScreen loaded for user: ${widget.user['username']}');
  }

  // ✅ PERBAIKAN: UPDATE PROFILE DENGAN ERROR HANDLING YANG FIXED
  Future<void> _updateProfile() async {
    if (!_formKey.currentState!.validate()) {
      _showSnackBar(
        content: const Text('Harap perbaiki error pada form terlebih dahulu'),
        backgroundColor: Colors.orange,
      );
      return;
    }

    // ✅ VALIDASI PASSWORD
    if (_oldPasswordController.text.isEmpty) {
      _showSnackBar(
        content: const Text('Harap masukkan password lama'),
        backgroundColor: Colors.orange,
      );
      return;
    }

    if (_newPasswordController.text.isEmpty) {
      _showSnackBar(
        content: const Text('Harap masukkan password baru'),
        backgroundColor: Colors.orange,
      );
      return;
    }

    if (_newPasswordController.text.length < 6) {
      _showSnackBar(
        content: const Text('Password baru minimal 6 karakter'),
        backgroundColor: Colors.orange,
      );
      return;
    }

    if (_newPasswordController.text != _confirmPasswordController.text) {
      _showSnackBar(
        content: const Text('Konfirmasi password tidak cocok'),
        backgroundColor: Colors.orange,
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      print('🔐 Starting password change...');

      // ✅ UPDATE PASSWORD
      final passwordResult = await _apiService.changePassword(
        _oldPasswordController.text.trim(),
        _newPasswordController.text.trim(),
        _confirmPasswordController.text.trim(),
      );

      if (!mounted) return;

      setState(() => _isLoading = false);

      // ✅ HANDLE RESPONSE
      if (passwordResult['success'] == true) {
        _handleSuccessResponse();
      } else {
        _handleErrorResponse(passwordResult);
      }
    } catch (e) {
      _handleException(e);
    }
  }

  // ✅ FIX: METHOD UNTUK SHOW SNACKBAR YANG AMAN
  void _showSnackBar({required Widget content, Color backgroundColor = Colors.red, int durationSeconds = 4}) {
    // Cek jika widget masih mounted
    if (!mounted) return;
    
    // Gunakan ScaffoldMessenger yang aman
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: content,
        backgroundColor: backgroundColor,
        duration: Duration(seconds: durationSeconds),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ✅ METHOD: HANDLE SUCCESS RESPONSE
  void _handleSuccessResponse() {
    print('✅ Password changed successfully');
    
    // ✅ CLEAR PASSWORD FIELDS SETELAH SUKSES
    _oldPasswordController.clear();
    _newPasswordController.clear();
    _confirmPasswordController.clear();
    
    // ✅ SHOW SUCCESS MESSAGE
    _showSnackBar(
      content: const Text('Password berhasil diubah ✅'),
      backgroundColor: Colors.green,
    );
    
    // ✅ PANGGIL CALLBACK DENGAN DATA YANG SAMA
    widget.onProfileUpdated(widget.user);
    
    // ✅ NAVIGATE BACK SETELAH BERHASIL
    if (mounted) {
      Navigator.pop(context);
    }
  }

  // ✅ FIX: METHOD _handleErrorResponse YANG AMAN
  void _handleErrorResponse(Map<String, dynamic> result) {
    print('🐛 === RAW API RESPONSE ===');
    print('Result: $result');
    print('Message: ${result['message']}');
    print('=== END RAW RESPONSE ===');

    // ✅ AMBIL PESAN ERROR REAL DARI API
    String apiMessage = '';
    
    if (result['message'] != null && result['message'].toString().isNotEmpty) {
      apiMessage = result['message'].toString().trim();
    } else if (result['error'] != null && result['error'].toString().isNotEmpty) {
      apiMessage = result['error'].toString().trim();
    } else {
      apiMessage = 'Terjadi kesalahan';
    }

    print('🔍 Extracted API Message: "$apiMessage"');

    // ✅ PAKAI PESAN PERSIS DARI API (sesuai request)
    String userFriendlyMessage = apiMessage;
    
    print('🎯 Final User Message: "$userFriendlyMessage"');

    // ✅ TAMPILKAN ERROR MESSAGE YANG AMAN
    _showSnackBar(
      content: Text(userFriendlyMessage),
      backgroundColor: Colors.red,
    );
    
    // ✅ SET ERROR MESSAGE UNTUK DITAMPILKAN DI FORM
    if (mounted) {
      setState(() {
        _errorMessage = userFriendlyMessage;
      });
    }
  }

  // ✅ FIX: METHOD _handleException YANG AMAN
  void _handleException(dynamic e) {
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
    
    print('❌ Change password exception: $e');
    
    final errorMessage = _getExceptionMessage(e);
    
    // ✅ GUNAKAN METHOD _showSnackBar YANG AMAN
    _showSnackBar(
      content: Text(errorMessage),
      backgroundColor: Colors.red,
    );
    
    if (mounted) {
      setState(() {
        _errorMessage = errorMessage;
      });
    }
  }

  // ✅ METHOD: GET EXCEPTION MESSAGE
  String _getExceptionMessage(dynamic exception) {
    final errorMsg = exception.toString().toLowerCase();
    
    if (errorMsg.contains('timeout')) {
      return 'Koneksi timeout. Periksa internet Anda dan coba lagi';
    }
    
    if (errorMsg.contains('socket') || errorMsg.contains('connection') || errorMsg.contains('network')) {
      return 'Tidak ada koneksi internet. Periksa jaringan Anda';
    }
    
    if (errorMsg.contains('401') || errorMsg.contains('unauthorized')) {
      return 'Sesi telah berakhir. Silakan login kembali';
    }
    
    if (errorMsg.contains('500') || errorMsg.contains('server error')) {
      return 'Server sedang gangguan. Silakan coba lagi nanti';
    }
    
    return 'Terjadi kesalahan: ${exception.toString().replaceAll('Exception: ', '')}';
  }

  // ✅ PERBAIKAN: BUILD ERROR MESSAGE
  Widget _buildErrorMessage() {
    if (_errorMessage == null) return const SizedBox.shrink();
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 16),
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Gagal Mengubah Password',
                  style: TextStyle(
                    color: Colors.red[700],
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _errorMessage!,
                  style: TextStyle(
                    color: Colors.red[700],
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.close, color: Colors.red[700], size: 16),
            onPressed: () {
              if (mounted) {
                setState(() => _errorMessage = null);
              }
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ganti Password'),
        backgroundColor: Colors.green[800],
        foregroundColor: Colors.white,
        actions: [
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              ),
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              // ✅ ERROR MESSAGE
              _buildErrorMessage(),

              // ✅ USER INFO CARD
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.person, color: Colors.green[700]),
                          const SizedBox(width: 8),
                          Text(
                            'Informasi Akun',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.green[700],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _buildInfoRow('Username', widget.user['username'] ?? '-'),
                      _buildInfoRow('Nama', widget.user['nama'] ?? widget.user['fullname'] ?? '-'),
                      _buildInfoRow('Email', widget.user['email'] ?? '-'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // ✅ SECTION: UBAH PASSWORD
              Text(
                'Ubah Password',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.green[700],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Isi form berikut untuk mengubah password akun Anda',
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              ),
              const SizedBox(height: 20),

              // ✅ PASSWORD LAMA
              TextFormField(
                controller: _oldPasswordController,
                obscureText: !_showOldPassword,
                decoration: InputDecoration(
                  labelText: 'Password Lama *',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(_showOldPassword ? Icons.visibility : Icons.visibility_off),
                    onPressed: () {
                      if (mounted) {
                        setState(() => _showOldPassword = !_showOldPassword);
                      }
                    },
                  ),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Password lama wajib diisi';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // ✅ PASSWORD BARU
              TextFormField(
                controller: _newPasswordController,
                obscureText: !_showNewPassword,
                decoration: InputDecoration(
                  labelText: 'Password Baru *',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(_showNewPassword ? Icons.visibility : Icons.visibility_off),
                    onPressed: () {
                      if (mounted) {
                        setState(() => _showNewPassword = !_showNewPassword);
                      }
                    },
                  ),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  hintText: 'Minimal 6 karakter',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Password baru wajib diisi';
                  }
                  if (value.length < 6) {
                    return 'Password minimal 6 karakter';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // ✅ KONFIRMASI PASSWORD
              TextFormField(
                controller: _confirmPasswordController,
                obscureText: !_showConfirmPassword,
                decoration: InputDecoration(
                  labelText: 'Konfirmasi Password Baru *',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(_showConfirmPassword ? Icons.visibility : Icons.visibility_off),
                    onPressed: () {
                      if (mounted) {
                        setState(() => _showConfirmPassword = !_showConfirmPassword);
                      }
                    },
                  ),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Konfirmasi password wajib diisi';
                  }
                  if (value != _newPasswordController.text) {
                    return 'Konfirmasi password tidak cocok';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 32),

              // ✅ ACTION BUTTONS
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: BorderSide(color: Colors.grey[400]!),
                      ),
                      onPressed: () {
                        if (mounted) {
                          Navigator.pop(context);
                        }
                      },
                      child: Text(
                        'Batal',
                        style: TextStyle(fontSize: 16, color: Colors.grey[700], fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green[700],
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: _isLoading ? null : _updateProfile,
                      child: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : Text(
                              'Ganti Password',
                              style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.w600),
                            ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  // ✅ HELPER: BUILD INFO ROW
  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _oldPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }
}
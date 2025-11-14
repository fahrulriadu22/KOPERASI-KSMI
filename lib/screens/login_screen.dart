import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'dashboard_main.dart';
import 'register_screen.dart';
import 'upload_dokumen_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'aktivasi_akun_screen.dart';
import '../services/device_service.dart';

class LoginScreen extends StatefulWidget {
  final Function(Map<String, dynamic>)? onLoginSuccess;

  const LoginScreen({
    Key? key,
    this.onLoginSuccess,
  }) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _inputController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final ApiService _apiService = ApiService();
  
  bool _isLoading = false;
  bool _obscureText = true;
  String _errorMessage = '';
  bool _isDebugMode = false; // Set false untuk production

  @override
  void initState() {
    super.initState();
    _checkExistingSession();
    // ❌ TIDAK PERLU session checker di login screen
  }

void _setupSessionListener() {
  // Listen untuk session changes
  Future.delayed(const Duration(seconds: 10), () {
    if (mounted) {
      _checkForcedLogout();
      _setupSessionListener(); // Loop
    }
  });
}

Future<void> _checkForcedLogout() async {
  try {
    final isSessionValid = await DeviceService.isSessionValid();
    if (!isSessionValid && mounted) {
      print('🚨 Forced logout detected in login screen');
      // Clear local data
      await _apiService.logout();
      // Show message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sesi telah berakhir karena login dari device lain'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  } catch (e) {
    print('❌ Error checking forced logout: $e');
  }
}

  // ✅ CEK SESSION EXISTING (Auto-login jika token masih valid)
// ✅ PERBAIKAN: CEK SESSION EXISTING DENGAN NAVIGATION LANGSUNG
Future<void> _checkExistingSession() async {
  try {
    final isLoggedIn = await _apiService.isLoggedIn();
    if (isLoggedIn) {
      final tokenValid = await _apiService.isTokenValid();
      
      if (tokenValid && mounted) {
        final currentUser = await _apiService.getCurrentUserForUpload();
        if (currentUser != null) {
          print('🔄 Auto-login detected, redirecting directly...');
          // ✅ NAVIGATE LANGSUNG TANPA CALLBACK
          Future.microtask(() {
            if (mounted) {
              _checkDokumenStatusAndNavigate(currentUser);
            }
          });
          return;
        }
      } else {
        // Token expired, clear data
        await _apiService.logout();
      }
    }
  } catch (e) {
    print('❌ Error checking existing session: $e');
  }
}

// ✅ PERBAIKAN: ERROR HANDLING YANG REAL DARI API
void _handleLogin() async {
  // Validasi form
  if (!_formKey.currentState!.validate()) {
    return;
  }

  setState(() {
    _isLoading = true;
    _errorMessage = '';
  });

  try {
    final result = await _apiService.login(
      _inputController.text.trim(), 
      _passwordController.text
    );

    setState(() {
      _isLoading = false;
    });

    if (result['success'] == true) {
      // ✅ LOGIN SUKSES
      print('✅ Login successful for user: ${result['user']?['user_name']}');
      
      // Dapatkan user data dari result atau dari storage
      Map<String, dynamic> userData = result['user'] ?? {};
      if (userData.isEmpty) {
        userData = await _apiService.getCurrentUserForUpload() ?? {};
      }
      
      _handleSuccessfulLogin(userData);
    } else {
      // ✅ LOGIN GAGAL - AMBIL ERROR DARI API SECARA REAL
      final errorMessage = _getRealErrorMessage(result);
      
      setState(() {
        _errorMessage = errorMessage;
      });
      
      // ✅ TAMPILKAN DIALOG ERROR
      _showErrorDialog(errorMessage);
    }
  } catch (e) {
    // ✅ ERROR DARI CATCH (Network, Timeout, dll)
    final errorMessage = _getExceptionErrorMessage(e);
    
    setState(() {
      _isLoading = false;
      _errorMessage = errorMessage;
    });
    
    _showErrorDialog(errorMessage);
  }
}

// ✅ METHOD BARU: AMBIL ERROR MESSAGE REAL DARI API RESPONSE
String _getRealErrorMessage(Map<String, dynamic> result) {
  // Priority 1: Message langsung dari API
  final apiMessage = result['message']?.toString().trim();
  
  // Priority 2: Error code dari API
  final errorCode = result['error_code']?.toString();
  
  // Priority 3: Data error dari API
  final errorData = result['error']?.toString();
  
  print('''
🐛 === API ERROR RESPONSE ===
Message: $apiMessage
Error Code: $errorCode  
Error Data: $errorData
Result: $result
=== END ERROR RESPONSE ===
''');

  // ✅ LOGIC UNTUK MAPPING ERROR REAL DARI API
  if (apiMessage != null && apiMessage.isNotEmpty) {
    // Jika API sudah kasih message yang jelas, pakai itu
    return apiMessage;
  }
  
  // Mapping berdasarkan error code
  switch (errorCode) {
    case 'INVALID_CREDENTIALS':
    case 'LOGIN_FAILED':
    case 'USER_NOT_FOUND':
      return 'Username atau password salah';
    
    case 'ACCOUNT_INACTIVE':
    case 'USER_INACTIVE':
      return 'Akun belum aktif. Silakan hubungi admin';
    
    case 'ACCOUNT_BLOCKED':
      return 'Akun diblokir. Silakan hubungi admin';
    
    case 'VALIDATION_ERROR':
      return 'Format username atau password tidak valid';
    
    default:
      // Coba parse dari error data
      if (errorData != null) {
        if (errorData.toLowerCase().contains('password') || 
            errorData.toLowerCase().contains('credential')) {
          return 'Username atau password salah';
        }
        return errorData;
      }
      
      // Fallback default
      return 'Login gagal. Periksa username dan password Anda';
  }
}

// ✅ METHOD BARU: HANDLE EXCEPTION ERROR (Network, Timeout, dll)
String _getExceptionErrorMessage(dynamic exception) {
  print('❌ Exception Type: ${exception.runtimeType}');
  print('❌ Exception Message: $exception');
  
  final errorMsg = exception.toString().toLowerCase();
  
  if (errorMsg.contains('timeout') || errorMsg.contains('timed out')) {
    return 'Koneksi timeout. Periksa internet Anda dan coba lagi';
  }
  
  if (errorMsg.contains('socket') || errorMsg.contains('connection') || errorMsg.contains('network')) {
    return 'Tidak ada koneksi internet. Periksa jaringan Anda';
  }
  
  if (errorMsg.contains('404') || errorMsg.contains('not found')) {
    return 'Server tidak ditemukan. Silakan coba lagi nanti';
  }
  
  if (errorMsg.contains('401') || errorMsg.contains('unauthorized')) {
    return 'Username atau password salah';
  }
  
  if (errorMsg.contains('500') || errorMsg.contains('server error')) {
    return 'Server sedang gangguan. Silakan coba lagi nanti';
  }
  
  // Default exception message
  return 'Terjadi kesalahan: ${exception.toString().replaceAll('Exception: ', '')}';
}

  // ✅ METHOD UNTUK MENAMPILKAN ERROR DIALOG
  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Login Gagal'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

// ✅ PERBAIKAN TOTAL: HAPUS CALLBACK, SELALU NAVIGATE LANGSUNG
void _handleSuccessfulLogin(Map<String, dynamic> user) {
  try {
    final statusUser = user['status_user']?.toString() ?? '0';
    final userId = user['user_id']?.toString() ?? '';
    
    print('🎉 LOGIN SUCCESS - User Status: $statusUser');
    print('🎉 LOGIN SUCCESS - User ID: $userId');

    // ✅ PASTIKAN DEVICE SERVICE DIPANGGIL SETELAH LOGIN BERHASIL
    if (userId.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await DeviceService.saveLoginSession(userId);
        print('✅ Device session saved for user: $userId');
      });
    }
    
    _saveAuthStatus(statusUser);
    
    Future.microtask(() {
      if (mounted) {
        _checkDokumenStatusAndNavigate(user);
      }
    });
    
  } catch (e) {
    print('❌ Error in successful login handling: $e');
  }
}

// ✅ METHOD BARU: SIMPAN STATUS AUTH KE SHARED PREFERENCES
Future<void> _saveAuthStatus(String statusUser) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_status_user', statusUser);
    print('💾 Auth status saved to SharedPreferences: $statusUser');
  } catch (e) {
    print('❌ Error saving auth status: $e');
  }
}


// ✅ PERBAIKAN: NAVIGATION YANG BENAR UNTUK STATUS 0 -> AKTIVASI AKUN
void _checkDokumenStatusAndNavigate(Map<String, dynamic> user) {
  try {
    final userStatus = user['status_user'] ?? user['status'] ?? 0;
    
    print('''
👤 User Status Check:
  - Status User: $userStatus (${userStatus.runtimeType})
''');
    
    // ✅ FIX: LOGIC YANG BENAR UNTUK STATUS_USER
    if (userStatus == 0 || userStatus == '0') {
      // ✅ STATUS 0 = MENUNGGU VERIFIKASI ADMIN -> Aktivasi Akun (BUKAN Upload Dokumen)
      print('📱 Status 0: Menunggu verifikasi, navigating to AktivasiAkunScreen');
      _navigateToAktivasiAkun(user);
    } else if (userStatus == 1 || userStatus == '1') {
      // ✅ STATUS 1 = SUDAH VERIFIED -> Dashboard
      print('📱 Status 1: Sudah verified, navigating to Dashboard');
      _navigateToDashboard(user);
    } else {
      // ✅ FALLBACK: Default ke Aktivasi Akun untuk safety
      print('📱 Status unknown ($userStatus), default to AktivasiAkunScreen');
      _navigateToAktivasiAkun(user);
    }
  } catch (e) {
    print('❌ Error in user status check navigation: $e');
    // Fallback ke aktivasi akun jika ada error
    _navigateToAktivasiAkun(user);
  }
}

// ✅ METHOD BARU: NAVIGATE KE AKTIVASI AKUN SCREEN
void _navigateToAktivasiAkun(Map<String, dynamic> user) {
  print('🚀 Navigating to AktivasiAkunScreen');
  
  Navigator.of(context).pushAndRemoveUntil(
    MaterialPageRoute(
      builder: (_) => AktivasiAkunScreen(user: user), // ← GANTI DENGAN SCREEN YANG BENAR
    ),
    (route) => false,
  );
}

// ✅ FIX: CEK STATUS DOKUMEN YANG LEBIH AKURAT
Map<String, dynamic> _getDokumenStatus(Map<String, dynamic> user) {
  final ktp = user['foto_ktp'];
  final kk = user['foto_kk'];
  final diri = user['foto_diri'];
  final bukti = user['foto_bukti'];
  
  print('🐛 === DOCUMENT STATUS DEBUG ===');
  print('📄 KTP: $ktp');
  print('📄 KK: $kk');
  print('📄 Foto Diri: $diri');
  print('📄 Foto Bukti: $bukti');
  
  // ✅ FIX: VALIDASI YANG LEBIH BAIK
  final hasKTP = ktp != null && 
                ktp.toString().isNotEmpty && 
                ktp != 'null' &&
                ktp != 'uploaded' &&
                (ktp.toString().contains('.jpg') || ktp.toString().contains('.jpeg') || ktp.toString().contains('.png'));
  
  final hasKK = kk != null && 
               kk.toString().isNotEmpty && 
               kk != 'null' &&
               kk != 'uploaded' &&
               (kk.toString().contains('.jpg') || kk.toString().contains('.jpeg') || kk.toString().contains('.png'));
  
  final hasDiri = diri != null && 
                 diri.toString().isNotEmpty && 
                 diri != 'null' &&
                 diri != 'uploaded' &&
                 (diri.toString().contains('.jpg') || diri.toString().contains('.jpeg') || diri.toString().contains('.png'));
  
  final hasBukti = bukti != null && 
                  bukti.toString().isNotEmpty && 
                  bukti != 'null' &&
                  bukti != 'uploaded' &&
                  (bukti.toString().contains('.jpg') || bukti.toString().contains('.jpeg') || bukti.toString().contains('.png'));
  
  print('✅ KTP Uploaded: $hasKTP');
  print('✅ KK Uploaded: $hasKK');
  print('✅ Foto Diri Uploaded: $hasDiri');
  print('✅ Foto Bukti Uploaded: $hasBukti');
  print('🎯 All Complete: ${hasKTP && hasKK && hasDiri && hasBukti}');
  print('🐛 === DEBUG END ===');
  
  return {
    'ktp': hasKTP,
    'kk': hasKK,
    'diri': hasDiri,
    'bukti': hasBukti,
    'allComplete': hasKTP && hasKK && hasDiri && hasBukti,
  };
}

// ✅ PERBAIKAN: NAVIGATION METHODS YANG SIMPLE DAN WORKING
void _navigateToUploadDokumen(Map<String, dynamic> user) {
  print('🚀 Navigating to UploadDokumenScreen');
  
  Navigator.of(context).pushAndRemoveUntil(
    MaterialPageRoute(
      builder: (_) => UploadDokumenScreen(
        user: user,
        onDocumentsComplete: () {
          print('📄 Documents completed, navigating to dashboard');
          _navigateToDashboard(user);
        },
      ),
    ),
    (route) => false,
  );
}

void _navigateToDashboard(Map<String, dynamic> user) {
  print('🚀 Navigating to DashboardMain');
  
  Navigator.of(context).pushAndRemoveUntil(
    MaterialPageRoute(builder: (_) => DashboardMain(user: user)),
    (route) => false,
  );
}

  // ✅ TEST LOGIN FUNCTION (untuk debugging)
  void _testLogin() async {
    if (_isDebugMode) {
      _inputController.text = 'sonik';
      _passwordController.text = 'sonik';
      _handleLogin();
    }
  }

  // ✅ FORGOT PASSWORD DIALOG
  void _showForgotPasswordDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Lupa Password?'),
        content: const Text(
          'Silakan hubungi admin koperasi untuk reset password. '
          'KSMI Tulungagung : +62 811-3667-666'
          'KSMI Kediri : +62 811-3666-515'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Tutup'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.green[50],
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // ✅ LOGO KSMI
                  _buildLogoSection(),
                  const SizedBox(height: 24),
                  
                  // ✅ TITLE SECTION
                  _buildTitleSection(),
                  const SizedBox(height: 40),

                  // ✅ ERROR MESSAGE
                  if (_errorMessage.isNotEmpty) _buildErrorMessage(),

                  // ✅ INPUT FIELDS
                  _buildInputFieldsSection(),
                  const SizedBox(height: 24),

                  // ✅ LOGIN BUTTON
                  _buildLoginButton(),

                  // ✅ DEBUG BUTTONS (Hanya untuk development)
                  if (_isDebugMode) _buildDebugButtons(),

                  // ✅ REGISTER LINK
                  _buildRegisterSection(),

                  // ✅ INFO SECTION
                  _buildInfoSection(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ✅ BUILD LOGO SECTION
  Widget _buildLogoSection() {
    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.green[300]!,
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Image.asset(
          'assets/images/KSMI_LOGO.png',
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              decoration: BoxDecoration(
                color: Colors.green[800],
                borderRadius: BorderRadius.circular(20),
              ),
              alignment: Alignment.center,
              child: const Icon(
                Icons.account_balance_wallet_rounded,
                color: Colors.white,
                size: 60,
              ),
            );
          },
        ),
      ),
    );
  }

  // ✅ BUILD TITLE SECTION
  Widget _buildTitleSection() {
    return Column(
      children: [
        Text(
          'Koperasi KSMI',
          style: TextStyle(
            fontSize: 28, 
            fontWeight: FontWeight.bold, 
            color: Colors.green[800],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Selamat Datang Kembali',
          style: TextStyle(
            fontSize: 16,
            color: Colors.green[600],
          ),
        ),
      ],
    );
  }

  // ✅ BUILD ERROR MESSAGE
  Widget _buildErrorMessage() {
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
            child: Text(
              _errorMessage,
              style: TextStyle(
                color: Colors.red[700],
                fontSize: 14,
              ),
            ),
          ),
          IconButton(
            icon: Icon(Icons.close, color: Colors.red[700], size: 16),
            onPressed: () => setState(() => _errorMessage = ''),
          ),
        ],
      ),
    );
  }

  // ✅ BUILD INPUT FIELDS SECTION
  Widget _buildInputFieldsSection() {
    return Column(
      children: [
        // USERNAME/EMAIL FIELD
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.green[100]!,
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: TextFormField(
            controller: _inputController,
            decoration: InputDecoration(
              labelText: 'Username / Email',
              labelStyle: TextStyle(color: Colors.grey[700]),
              prefixIcon: Icon(Icons.person_outline, color: Colors.green[700]),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            ),
            validator: (val) => val == null || val.isEmpty ? 'Harap isi username/email' : null,
          ),
        ),
        const SizedBox(height: 16),

        // PASSWORD FIELD
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.green[100]!,
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: TextFormField(
            controller: _passwordController,
            obscureText: _obscureText,
            decoration: InputDecoration(
              labelText: 'Password',
              labelStyle: TextStyle(color: Colors.grey[700]),
              prefixIcon: Icon(Icons.lock_outline, color: Colors.green[700]),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureText ? Icons.visibility_off : Icons.visibility,
                  color: Colors.green[700],
                ),
                onPressed: () => setState(() => _obscureText = !_obscureText),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            ),
            validator: (val) {
              if (val == null || val.isEmpty) return 'Harap isi password';
              if (val.length < 3) return 'Password terlalu pendek';
              return null;
            },
          ),
        ),

        // FORGOT PASSWORD LINK
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: _showForgotPasswordDialog,
            child: Text(
              'Lupa Password?',
              style: TextStyle(
                color: Colors.green[700],
                fontSize: 14,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ✅ BUILD LOGIN BUTTON
  Widget _buildLoginButton() {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _handleLogin,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green[700],
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 4,
          shadowColor: Colors.green[300],
        ),
        child: _isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  color: Colors.white, 
                  strokeWidth: 2
                ),
              )
            : const Text(
                'Login', 
                style: TextStyle(
                  fontSize: 16, 
                  fontWeight: FontWeight.w600
                ),
              ),
      ),
    );
  }

  // ✅ BUILD DEBUG BUTTONS
  Widget _buildDebugButtons() {
    return Column(
      children: [
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          height: 40,
          child: OutlinedButton(
            onPressed: _isLoading ? null : _testLogin,
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.green[700],
              side: BorderSide(color: Colors.green[700]!),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text(
              'Test Login (sonik/sonik)',
              style: TextStyle(fontSize: 14),
            ),
          ),
        ),
      ],
    );
  }

  // ✅ BUILD REGISTER SECTION
  Widget _buildRegisterSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Belum punya akun? ',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 14,
            ),
          ),
          GestureDetector(
            onTap: () {
              Navigator.push(
                context, 
                MaterialPageRoute(builder: (_) => const RegisterScreen())
              );
            },
            child: Text(
              'Daftar',
              style: TextStyle(
                color: Colors.green[700],
                fontSize: 14,
                fontWeight: FontWeight.bold,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ✅ BUILD INFO SECTION
  Widget _buildInfoSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(Icons.info_outline, color: Colors.green[700], size: 24),
          const SizedBox(height: 8),
          Text(
            'Setelah login, Anda akan diminta untuk melengkapi dokumen KTP, KK, dan Foto Diri untuk pengalaman terbaik',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.green[800],
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _inputController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}
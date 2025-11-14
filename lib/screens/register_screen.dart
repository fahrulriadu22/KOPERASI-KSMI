import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'login_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({Key? key}) : super(key: key);

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final ApiService _apiService = ApiService();
  
  // ✅ STATE UNTUK STEP-BY-STEP REGISTER
  int _currentStep = 0;
  final List<GlobalKey<FormState>> _formKeys = [
    GlobalKey<FormState>(),
    GlobalKey<FormState>(),
    GlobalKey<FormState>(),
    GlobalKey<FormState>(),
    GlobalKey<FormState>(),
  ];

  // ✅ CONTROLLERS
  // Data Umum
  final TextEditingController usernameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController = TextEditingController();
  final TextEditingController fullnameController = TextEditingController();
  final TextEditingController birthPlaceController = TextEditingController();
  final TextEditingController faxController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController jobController = TextEditingController();
  DateTime? _selectedBirthDate;

  // Identitas
  String? _selectedAgamaId;
  String? _selectedCabangId;
  String? _selectedJenisIdentitas;
  final TextEditingController nomorIdentitasController = TextEditingController();
  String? _selectedSumberInformasi;
  DateTime? _selectedTanggalBerlaku;

  // Data KTP
  final TextEditingController ktpAlamatController = TextEditingController();
  final TextEditingController ktpNoController = TextEditingController();
  final TextEditingController ktpRtController = TextEditingController();
  final TextEditingController ktpRwController = TextEditingController();
  final TextEditingController ktpPostalController = TextEditingController();
  String? _selectedProvinsiKtp;
  String? _selectedKotaKtp;

  // Data Domisili
  final TextEditingController domisiliAlamatController = TextEditingController();
  final TextEditingController domisiliNoController = TextEditingController();
  final TextEditingController domisiliRtController = TextEditingController();
  final TextEditingController domisiliRwController = TextEditingController();
  final TextEditingController domisiliPostalController = TextEditingController();
  String? _selectedProvinsiDomisili;
  String? _selectedKotaDomisili;
  bool _sameAsKtp = false;

  // Data Ahli Waris
  final TextEditingController namaAhliWarisController = TextEditingController();
  final TextEditingController tempatLahirAhliWarisController = TextEditingController();
  String? _selectedHubungan;
  DateTime? _selectedTanggalLahirAhliWaris;

  // ✅ DATA MASTER DARI API
  List<dynamic> _provinsiList = [];
  List<dynamic> _kotaListKtp = [];
  List<dynamic> _kotaListDomisili = [];
  List<dynamic> _agamaList = [];
  List<dynamic> _cabangList = [];
  List<dynamic> _jenisIdentitasList = [];
  Map<String, String> _sumberInfoMap = {};
  Map<String, String> _hubunganMap = {};

  bool _isLoading = false;
  bool _isLoadingMasterData = false;
  bool _obscureText = true;
  bool _obscureConfirmText = true;
  bool _agreedToTerms = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadAllMasterData();
  }

  // ✅ LOAD SEMUA MASTER DATA DARI API
  Future<void> _loadAllMasterData() async {
    try {
      setState(() {
        _isLoadingMasterData = true;
        _errorMessage = null;
      });

      print('🔄 Loading semua master data...');

      // 1. Load provinsi
      final provinsiResult = await _apiService.getProvince();
      if (provinsiResult['success'] == true) {
        final data = provinsiResult['data'];
        if (data is List) {
          setState(() {
            _provinsiList = data;
          });
          print('📍 Provinsi loaded: ${_provinsiList.length} items');
        } else {
          _setupFallbackProvinsi();
        }
      } else {
        _setupFallbackProvinsi();
      }

      // 2. Load master data utama
      final masterResult = await _apiService.getMasterData();
      if (masterResult['status'] == true) {
        final data = masterResult;
        
        // Handle agama
        if (data['agama'] is List) {
          setState(() {
            _agamaList = data['agama'];
          });
          print('🕌 Agama loaded: ${_agamaList.length} items');
        }
        
        // Handle cabang
        if (data['cabang'] is List) {
          setState(() {
            _cabangList = data['cabang'];
          });
          print('🏢 Cabang loaded: ${_cabangList.length} items');
        }
        
        // Handle jenis identitas
        if (data['jenis_identitas'] is List) {
          setState(() {
            _jenisIdentitasList = data['jenis_identitas'];
          });
          print('🆔 Jenis identitas loaded: ${_jenisIdentitasList.length} items');
        }
        
        // Handle sumber informasi (dari Map)
        if (data['sumber_informasi'] is Map) {
          final sumberInfoData = data['sumber_informasi'] as Map;
          setState(() {
            _sumberInfoMap = Map<String, String>.from(sumberInfoData);
          });
          print('📢 Sumber informasi loaded: ${_sumberInfoMap.length} items');
        }
        
        // Handle hubungan keluarga (dari Map)
        if (data['hubungan_keluarga'] is Map) {
          final hubunganData = data['hubungan_keluarga'] as Map;
          setState(() {
            _hubunganMap = Map<String, String>.from(hubunganData);
          });
          print('👨‍👩‍👧‍👦 Hubungan keluarga loaded: ${_hubunganMap.length} items');
        }
        
      } else {
        _setupFallbackMasterData();
      }
      
    } catch (e) {
      print('❌ Error loading master data: $e');
      _setupFallbackMasterData();
      setState(() {
        _errorMessage = 'Gagal memuat data master: $e';
      });
    } finally {
      setState(() => _isLoadingMasterData = false);
    }
  }

  // ✅ FALLBACK DATA JIKA API ERROR
  void _setupFallbackProvinsi() {
    print('🔄 Setting up fallback provinsi...');
    setState(() {
      _provinsiList = [
        {'id': '35', 'nama': 'JAWA TIMUR'},
        {'id': '11', 'nama': 'ACEH'},
        {'id': '12', 'nama': 'SUMATERA UTARA'},
        {'id': '31', 'nama': 'DKI JAKARTA'},
      ];
    });
  }

  void _setupFallbackMasterData() {
    print('🔄 Setting up fallback master data...');
    
    setState(() {
      _agamaList = [
        {'id': '1', 'nama': 'Islam'},
        {'id': '2', 'nama': 'Kristen'},
        {'id': '3', 'nama': 'Katolik'},
        {'id': '4', 'nama': 'Hindu'},
      ];
      
      _cabangList = [
        {'id': '1', 'nama': 'TULUNGAGUNG'},
        {'id': '2', 'nama': 'KEDIRI'},
      ];
      
      _jenisIdentitasList = [
        {'id': '1', 'nama': 'KTP'},
        {'id': '2', 'nama': 'SIM'},
        {'id': '3', 'nama': 'Passport'},
        {'id': '4', 'nama': 'Lainnya'},
      ];
      
      _sumberInfoMap = {
        'MARKETING': 'MARKETING',
        'BROSUR': 'BROSUR', 
        'TEMAN': 'TEMAN',
        'WEBSITE': 'WEBSITE',
        'LAINNYA': 'LAINNYA',
      };
      
      _hubunganMap = {
        'SUAMI': 'SUAMI',
        'ISTRI': 'ISTRI', 
        'ANAK': 'ANAK',
        'AYAH': 'AYAH',
        'IBU': 'IBU',
      };
    });
  }

  // ✅ LOAD KOTA BERDASARKAN PROVINSI
  Future<void> _loadKota(String idProvinsi, bool forKtp) async {
    try {
      print('🏙️ Loading kota for provinsi: $idProvinsi');
      final result = await _apiService.getRegency(idProvinsi);
      
      if (result['success'] == true) {
        final data = result['data'];
        if (data is List) {
          setState(() {
            if (forKtp) {
              _kotaListKtp = data;
              // Reset selected kota jika tidak ada di list baru
              if (_selectedKotaKtp != null && 
                  !_kotaListKtp.any((kota) => kota['id'].toString() == _selectedKotaKtp)) {
                _selectedKotaKtp = null;
              }
            } else {
              _kotaListDomisili = data;
              // Reset selected kota jika tidak ada di list baru
              if (_selectedKotaDomisili != null && 
                  !_kotaListDomisili.any((kota) => kota['id'].toString() == _selectedKotaDomisili)) {
                _selectedKotaDomisili = null;
              }
            }
          });
        } else {
          setState(() {
            if (forKtp) {
              _kotaListKtp = [];
            } else {
              _kotaListDomisili = [];
            }
          });
        }
      } else {
        setState(() {
          if (forKtp) {
            _kotaListKtp = [];
          } else {
            _kotaListDomisili = [];
          }
        });
      }
    } catch (e) {
      print('❌ Error loading kota: $e');
      setState(() {
        if (forKtp) {
          _kotaListKtp = [];
        } else {
          _kotaListDomisili = [];
        }
      });
    }
  }

  // ✅ HANDLE REGISTER DENGAN DATA MASTER YANG BENAR
  void _handleRegister() async {
    if (!_validateAllForms()) return;

    setState(() => _isLoading = true);

    try {
      // Check user exist
// ✅ PERBAIKAN: CHECK USER EXIST DENGAN FORMAT YANG BENAR
final checkResult = await _apiService.checkUserExist(
  usernameController.text.trim(),
  emailController.text.trim(),
);

print('''
🔍 === CHECK USER EXIST RESPONSE ===
Result: $checkResult
Exists: ${checkResult['exists']}
Status: ${checkResult['status']}
Is Exist: ${checkResult['is_exist']}
Message: ${checkResult['message']}
=== END RESPONSE ===
''');

// ✅ FIX: HANDLE BEDA FORMAT RESPONSE
bool userExists = false;
String errorMessage = 'Username atau email sudah terdaftar.';

// Format 1: { "status": true, "is_exist": 1, "message": "..." }
if (checkResult['is_exist'] == 1) {
  userExists = true;
  errorMessage = checkResult['message'] ?? errorMessage;
}
// Format 2: { "exists": true, "message": "..." }
else if (checkResult['exists'] == true) {
  userExists = true;
  errorMessage = checkResult['message'] ?? errorMessage;
}
// Format 3: { "status": false, "message": "..." } dari register langsung
else if (checkResult['status'] == false) {
  userExists = true; // Anggap user exists jika status false
  errorMessage = checkResult['message'] ?? errorMessage;
}

if (userExists) {
  setState(() => _isLoading = false);
  _showErrorDialog(errorMessage);
  return;
}

      // ✅ PREPARE DATA DENGAN MASTER DATA YANG SESUAI
      final userData = {
        // Data Umum
        'username': usernameController.text.trim(),
        'password': passwordController.text.trim(),
        'email': emailController.text.trim(),
        'fullname': fullnameController.text.trim(),
        'fax': faxController.text.trim().isEmpty ? "-" : faxController.text.trim(),
        'phone': phoneController.text.trim(),
        'job': jobController.text.trim().isEmpty ? "Karyawan Swasta" : jobController.text.trim(),
        'birth_place': birthPlaceController.text.trim(),
        'birth_date': _selectedBirthDate != null 
            ? '${_selectedBirthDate!.year}-${_selectedBirthDate!.month.toString().padLeft(2, '0')}-${_selectedBirthDate!.day.toString().padLeft(2, '0')}' 
            : '2000-01-01',

        // ✅ IDENTITAS - DENGAN DATA MASTER
        'agama_id': _selectedAgamaId ?? "1",
        'cabang_id': _selectedCabangId ?? "1",
        'jenis_identitas': _selectedJenisIdentitas ?? "1",
        'tanggal_berlaku': _selectedTanggalBerlaku != null
            ? '${_selectedTanggalBerlaku!.year}-${_selectedTanggalBerlaku!.month.toString().padLeft(2, '0')}-${_selectedTanggalBerlaku!.day.toString().padLeft(2, '0')}'
            : '2025-12-31',
        'nomor_identitas': nomorIdentitasController.text.trim(),
        'sumber_informasi': _selectedSumberInformasi ?? "MARKETING",

        // ✅ DATA KTP
        'ktp_alamat': ktpAlamatController.text.trim(),
        'ktp_rt': ktpRtController.text.trim().isEmpty ? "001" : ktpRtController.text.trim(),
        'ktp_rw': ktpRwController.text.trim().isEmpty ? "001" : ktpRwController.text.trim(),
        'ktp_id_province': _selectedProvinsiKtp ?? "35",
        'ktp_id_regency': _selectedKotaKtp ?? "3578",
        'ktp_postal': ktpPostalController.text.trim().isEmpty ? "60111" : ktpPostalController.text.trim(),
        'ktp_no': ktpNoController.text.trim().isEmpty ? "01" : ktpNoController.text.trim(),

        // ✅ DATA DOMISILI
        'domisili_alamat': _sameAsKtp ? ktpAlamatController.text.trim() : domisiliAlamatController.text.trim(),
        'domisili_rt': _sameAsKtp ? 
            (ktpRtController.text.trim().isEmpty ? "001" : ktpRtController.text.trim()) : 
            (domisiliRtController.text.trim().isEmpty ? "001" : domisiliRtController.text.trim()),
        'domisili_rw': _sameAsKtp ? 
            (ktpRwController.text.trim().isEmpty ? "001" : ktpRwController.text.trim()) : 
            (domisiliRwController.text.trim().isEmpty ? "001" : domisiliRwController.text.trim()),
        'domisili_id_province': _sameAsKtp ? 
            (_selectedProvinsiKtp ?? "35") : 
            (_selectedProvinsiDomisili ?? "35"),
        'domisili_id_regency': _sameAsKtp ? 
            (_selectedKotaKtp ?? "3578") : 
            (_selectedKotaDomisili ?? "3578"),
        'domisili_postal': _sameAsKtp ? 
            (ktpPostalController.text.trim().isEmpty ? "60111" : ktpPostalController.text.trim()) : 
            (domisiliPostalController.text.trim().isEmpty ? "60111" : domisiliPostalController.text.trim()),
        'domisili_no': _sameAsKtp ? 
            (ktpNoController.text.trim().isEmpty ? "01" : ktpNoController.text.trim()) : 
            (domisiliNoController.text.trim().isEmpty ? "01" : domisiliNoController.text.trim()),

        // ✅ DATA AHLI WARIS
        'nama_ahli_waris': namaAhliWarisController.text.trim().isEmpty ? 
            fullnameController.text.trim() : namaAhliWarisController.text.trim(),
        'tempat_lahir_ahli_waris': tempatLahirAhliWarisController.text.trim().isEmpty ? 
            birthPlaceController.text.trim() : tempatLahirAhliWarisController.text.trim(),
        'tanggal_lahir_ahli_waris': _selectedTanggalLahirAhliWaris != null
            ? '${_selectedTanggalLahirAhliWaris!.year}-${_selectedTanggalLahirAhliWaris!.month.toString().padLeft(2, '0')}-${_selectedTanggalLahirAhliWaris!.day.toString().padLeft(2, '0')}'
            : '2000-01-01',
        'hubungan': _selectedHubungan ?? "ANAK",
      };

      // ✅ DEBUG: Print semua data sebelum dikirim
      print('📤 Sending registration data:');
      userData.forEach((key, value) {
        print('   $key: $value');
      });
      
      // Call register API
      final result = await _apiService.register(userData);

      setState(() => _isLoading = false);

      if (!mounted) return;

      if (result['success'] == true) {
        print('✅ Registration successful');
        
        _showSuccessDialogManualLogin(
          result['message'] ?? 'Pendaftaran berhasil! Silakan login dengan username dan password Anda.'
        );
        
      } else {
        print('❌ Registration failed: ${result['message']}');
        _showErrorDialog(result['message'] ?? 'Registrasi gagal. Silakan coba lagi.');
      }
    } catch (e) {
      setState(() => _isLoading = false);
      print('❌ Register error: $e');
      _showErrorDialog('Terjadi kesalahan: $e');
    }
  }

  // ✅ DIALOG UNTUK LOGIN MANUAL SETELAH REGISTER BERHASIL
  void _showSuccessDialogManualLogin(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green),
            SizedBox(width: 8),
            Text('Pendaftaran Berhasil'),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                (route) => false,
              );
            },
            child: const Text('LOGIN SEKARANG'),
          )
        ],
      ),
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Registrasi Gagal'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  // ✅ VALIDATE ALL FORMS
  bool _validateAllForms() {
    for (int i = 0; i < _formKeys.length; i++) {
      final formKey = _formKeys[i];
      if (formKey.currentState != null && !formKey.currentState!.validate()) {
        setState(() => _currentStep = i + 1);
        return false;
      }
    }
    return true;
  }

  Future<void> _selectDate(Function(DateTime) onDateSelected, DateTime? initialDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate ?? DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      onDateSelected(picked);
    }
  }

  // ✅ VALIDATION METHODS
  String? _validateRequired(String? value, String fieldName) {
    if (value == null || value.isEmpty) {
      return '$fieldName wajib diisi';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password wajib diisi';
    }
    if (value.length < 6) {
      return 'Minimal 6 karakter';
    }
    return null;
  }

  String? _validateConfirmPassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Konfirmasi password wajib diisi';
    }
    if (value != passwordController.text) {
      return 'Password tidak cocok';
    }
    return null;
  }

  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Email wajib diisi';
    }
    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
      return 'Format email tidak valid';
    }
    return null;
  }

  String? _validatePhone(String? value) {
    if (value == null || value.isEmpty) {
      return 'No. telepon wajib diisi';
    }
    if (!RegExp(r'^08[0-9]{8,11}$').hasMatch(value)) {
      return 'Format no. telepon tidak valid';
    }
    return null;
  }

  String? _validateDropdown(String? value, String fieldName) {
    if (value == null || value.isEmpty) {
      return '$fieldName wajib dipilih';
    }
    return null;
  }

  // ✅ BUILD DROPDOWN UNTUK DATA LIST (agama, cabang, jenis identitas)
  Widget _buildDropdownFormField({
    required String label,
    required String? value,
    required List<dynamic> items,
    required Function(String?)? onChanged,
    required String? Function(String?)? validator,
    bool enabled = true,
    String? hintText,
  }) {
    try {
      final uniqueItems = items.where((item) => 
        item != null && 
        item['id'] != null && 
        item['id'].toString().isNotEmpty
      ).toSet().toList();

      final dropdownItems = uniqueItems.map((item) {
        final id = item['id']?.toString() ?? '';
        final nama = item['nama']?.toString() ?? 
                    item['name']?.toString() ?? 
                    'Unknown';
        
        return DropdownMenuItem<String>(
          value: id,
          child: Text(
            nama,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 14),
          ),
        );
      }).toList();

      if (dropdownItems.isEmpty) {
        dropdownItems.add(
          const DropdownMenuItem(
            value: '',
            child: Text('Tidak ada data'),
          ),
        );
      }

      String? validatedValue = value;
      if (value != null && value.isNotEmpty && !dropdownItems.any((item) => item.value == value)) {
        validatedValue = null;
      }

      return DropdownButtonFormField<String>(
        value: validatedValue,
        items: dropdownItems,
        onChanged: enabled ? onChanged : null,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          hintText: hintText,
          filled: !enabled,
          fillColor: !enabled ? Colors.grey[100] : null,
        ),
        validator: validator,
        isExpanded: true,
        style: TextStyle(
          color: enabled ? Colors.black87 : Colors.grey[600],
          fontSize: 14,
        ),
        icon: enabled ? const Icon(Icons.arrow_drop_down) : const Icon(Icons.lock_outline),
        borderRadius: BorderRadius.circular(12),
      );
    } catch (e) {
      print('❌ Error building dropdown $label: $e');
      return TextFormField(
        initialValue: 'Error loading data',
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          filled: true,
          fillColor: Colors.red[50],
        ),
        enabled: false,
      );
    }
  }

  // ✅ BUILD DROPDOWN UNTUK DATA MAP (sumber informasi, hubungan)
  Widget _buildDropdownFromMap({
    required String label,
    required String? value,
    required Map<String, String> items,
    required Function(String?)? onChanged,
    required String? Function(String?)? validator,
    bool enabled = true,
  }) {
    try {
      final dropdownItems = items.entries.map((entry) {
        return DropdownMenuItem<String>(
          value: entry.key,
          child: Text(
            entry.value,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 14),
          ),
        );
      }).toList();

      if (dropdownItems.isEmpty) {
        dropdownItems.add(
          const DropdownMenuItem(
            value: '',
            child: Text('Tidak ada data'),
          ),
        );
      }

      return DropdownButtonFormField<String>(
        value: value,
        items: dropdownItems,
        onChanged: enabled ? onChanged : null,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          filled: !enabled,
          fillColor: !enabled ? Colors.grey[100] : null,
        ),
        validator: validator,
        isExpanded: true,
        style: TextStyle(
          color: enabled ? Colors.black87 : Colors.grey[600],
          fontSize: 14,
        ),
        icon: enabled ? const Icon(Icons.arrow_drop_down) : const Icon(Icons.lock_outline),
        borderRadius: BorderRadius.circular(12),
      );
    } catch (e) {
      print('❌ Error building dropdown $label: $e');
      return TextFormField(
        initialValue: 'Error loading data',
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          filled: true,
          fillColor: Colors.red[50],
        ),
        enabled: false,
      );
    }
  }

  // ✅ STEP CONTENT
  Widget _buildStepContent(int step) {
    switch (step) {
      case 0:
        return _buildInfoStep();
      case 1:
        return _buildDataUmumStep();
      case 2:
        return _buildIdentitasStep();
      case 3:
        return _buildDataKtpStep();
      case 4:
        return _buildDataDomisiliStep();
      case 5:
        return _buildDataAhliWarisStep();
      default:
        return Container();
    }
  }

  // ✅ STEP 0: INFORMASI KOPERASI
  Widget _buildInfoStep() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoCard(
            'Profil Koperasi KSMI',
            'Koperasi Syirkah Muslim Indonesia atau disingkat KSMI merupakan koperasi konsumen yang berkomitmen untuk menerapkan transaksi muamalah sesuai syariah...',
            Icons.business,
            Colors.green[800]!,
          ),
          const SizedBox(height: 16),
          
          _buildInfoCard(
            'Visi Koperasi KSMI',
            'Mewujudkan Koperasi Unggul & Profesional yang mampu meningkatkan kemandirian maupun kesejahteraan anggota...',
            Icons.flag,
            Colors.blue[700]!,
          ),
          const SizedBox(height: 16),
          
          _buildInfoCard(
            'Misi Koperasi KSMI',
            '1. Melaksanakan kegiatan usaha dalam koperasi yang sesuai dengan prinsip-prinsip ekonomi tuntunan syariat\n'
            '2. Meningkatkan dan mengembangkan pelayanan prima bagi koperasi untuk anggota dan masyarakat...',
            Icons.assignment,
            Colors.orange[700]!,
          ),
          const SizedBox(height: 16),
          
          _buildInfoCard(
            'Manfaat Bergabung',
            '• Transaksi dengan akad yang halal sesuai syariat.\n'
            '• Berusaha bermuamalah sesuai dengan hukum syar`i tanpa riba.\n'
            '• Ikut berperan aktif dalam memerangi riba...',
            Icons.emoji_events,
            Colors.purple[700]!,
          ),
          const SizedBox(height: 16),
          
          _buildInfoCard(
            'Manfaat Keanggotaan',
            '• Mendapatkan profit dari bagi hasil SHU setiap tahun...\n'
            '• Mengembangkan networking (jaringan) dengan usaha lain\n'
            '• Ikut berperan dalam perkembangan dakwah...',
            Icons.card_membership,
            Colors.teal[700]!,
          ),
          const SizedBox(height: 24),
          
          Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  CheckboxListTile(
                    title: const Text(
                      'Saya telah membaca dan menyetujui semua ketentuan yang berlaku',
                      style: TextStyle(fontSize: 14),
                    ),
                    value: _agreedToTerms,
                    onChanged: (value) {
                      setState(() => _agreedToTerms = value ?? false);
                    },
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                  if (!_agreedToTerms)
                    Padding(
                      padding: const EdgeInsets.only(left: 16, top: 8),
                      child: Text(
                        'Anda harus menyetujui ketentuan untuk melanjutkan',
                        style: TextStyle(
                          color: Colors.red[600],
                          fontSize: 12,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(String title, String content, IconData icon, Color color) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              content,
              style: const TextStyle(
                fontSize: 14, 
                height: 1.5,
                color: Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ✅ STEP 1: DATA UMUM
  Widget _buildDataUmumStep() {
    return Form(
      key: _formKeys[0],
      child: SingleChildScrollView(
        child: Column(
          children: [
            _buildTextField(
              controller: usernameController,
              label: 'Username *',
              icon: Icons.person_outline,
              validator: (v) => _validateRequired(v, 'Username'),
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: emailController,
              label: 'Email *',
              icon: Icons.email_outlined,
              keyboardType: TextInputType.emailAddress,
              validator: _validateEmail,
            ),
            const SizedBox(height: 16),
            _buildPasswordField(
              controller: passwordController,
              label: 'Password *',
              obscureText: _obscureText,
              onToggle: () => setState(() => _obscureText = !_obscureText),
              validator: _validatePassword,
            ),
            const SizedBox(height: 16),
            _buildPasswordField(
              controller: confirmPasswordController,
              label: 'Konfirmasi Password *',
              obscureText: _obscureConfirmText,
              onToggle: () => setState(() => _obscureConfirmText = !_obscureConfirmText),
              validator: _validateConfirmPassword,
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: fullnameController,
              label: 'Nama Lengkap *',
              icon: Icons.badge_outlined,
              validator: (v) => _validateRequired(v, 'Nama lengkap'),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildTextField(
                    controller: birthPlaceController,
                    label: 'Tempat Lahir *',
                    icon: Icons.place_outlined,
                    validator: (v) => _validateRequired(v, 'Tempat lahir'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildDateField(
                    label: 'Tanggal Lahir *',
                    value: _selectedBirthDate,
                    onTap: () => _selectDate((date) {
                      setState(() => _selectedBirthDate = date);
                    }, DateTime.now().subtract(const Duration(days: 365 * 18))),
                    validator: (v) => _selectedBirthDate == null ? 'Tanggal lahir wajib diisi' : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: phoneController,
              label: 'No. Telepon *',
              icon: Icons.phone_outlined,
              keyboardType: TextInputType.phone,
              validator: _validatePhone,
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: jobController,
              label: 'Pekerjaan *',
              icon: Icons.work_outline,
              validator: (v) => _validateRequired(v, 'Pekerjaan'),
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: faxController,
              label: 'No. Fax',
              icon: Icons.fax_outlined,
              keyboardType: TextInputType.phone,
            ),
          ],
        ),
      ),
    );
  }

  // ✅ STEP 2: IDENTITAS - DENGAN DATA MASTER
  Widget _buildIdentitasStep() {
    return Form(
      key: _formKeys[1],
      child: SingleChildScrollView(
        child: Column(
          children: [
            // AGAMA DROPDOWN
            _buildDropdownFormField(
              label: 'Agama *',
              value: _selectedAgamaId,
              items: _agamaList,
              onChanged: (String? value) {
                setState(() => _selectedAgamaId = value);
                _formKeys[1].currentState?.validate();
              },
              validator: (value) => _validateDropdown(value, 'Agama'),
            ),
            const SizedBox(height: 16),

            // CABANG DROPDOWN
            _buildDropdownFormField(
              label: 'Cabang *',
              value: _selectedCabangId,
              items: _cabangList,
              onChanged: (String? value) {
                setState(() => _selectedCabangId = value);
                _formKeys[1].currentState?.validate();
              },
              validator: (value) => _validateDropdown(value, 'Cabang'),
            ),
            const SizedBox(height: 16),

            // JENIS IDENTITAS
            _buildDropdownFormField(
              label: 'Jenis Identitas *',
              value: _selectedJenisIdentitas,
              items: _jenisIdentitasList,
              onChanged: (String? value) {
                setState(() => _selectedJenisIdentitas = value);
                _formKeys[1].currentState?.validate();
              },
              validator: (value) => _validateDropdown(value, 'Jenis identitas'),
            ),
            const SizedBox(height: 16),

            _buildTextField(
              controller: nomorIdentitasController,
              label: 'Nomor Identitas *',
              icon: Icons.credit_card_outlined,
              keyboardType: TextInputType.number,
              validator: (v) => _validateRequired(v, 'Nomor identitas'),
            ),
            const SizedBox(height: 16),

            _buildDateField(
              label: 'Tanggal Berlaku Identitas',
              value: _selectedTanggalBerlaku,
              onTap: () => _selectDate((date) {
                setState(() => _selectedTanggalBerlaku = date);
              }, DateTime.now().add(const Duration(days: 365 * 5))),
            ),
            const SizedBox(height: 16),

            // SUMBER INFORMASI DARI MAP
            _buildDropdownFromMap(
              label: 'Sumber Informasi *',
              value: _selectedSumberInformasi,
              items: _sumberInfoMap,
              onChanged: (String? value) {
                setState(() => _selectedSumberInformasi = value);
                _formKeys[1].currentState?.validate();
              },
              validator: (value) => _validateDropdown(value, 'Sumber informasi'),
            ),
          ],
        ),
      ),
    );
  }

  // ✅ STEP 3: DATA KTP
  Widget _buildDataKtpStep() {
    return Form(
      key: _formKeys[2],
      child: SingleChildScrollView(
        child: Column(
          children: [
            _buildTextField(
              controller: ktpAlamatController,
              label: 'Alamat KTP *',
              icon: Icons.home_outlined,
              maxLines: 2,
              validator: (v) => _validateRequired(v, 'Alamat KTP'),
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: ktpNoController,
              label: 'No. Rumah *',
              icon: Icons.house_outlined,
              validator: (v) => _validateRequired(v, 'No. Rumah'),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildTextField(
                    controller: ktpRtController,
                    label: 'RT *',
                    icon: Icons.numbers_outlined,
                    keyboardType: TextInputType.number,
                    validator: (v) => _validateRequired(v, 'RT'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildTextField(
                    controller: ktpRwController,
                    label: 'RW *',
                    icon: Icons.numbers_outlined,
                    keyboardType: TextInputType.number,
                    validator: (v) => _validateRequired(v, 'RW'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // PROVINSI DROPDOWN
            _buildDropdownFormField(
              label: 'Provinsi *',
              value: _selectedProvinsiKtp,
              items: _provinsiList,
              onChanged: (String? value) {
                if (value != null) {
                  setState(() {
                    _selectedProvinsiKtp = value;
                    _selectedKotaKtp = null;
                    _kotaListKtp = [];
                  });
                  _loadKota(value, true);
                }
              },
              validator: (value) => _validateDropdown(value, 'Provinsi'),
            ),
            const SizedBox(height: 16),
            
            // KOTA/KABUPATEN DROPDOWN
            _buildDropdownFormField(
              label: 'Kabupaten/Kota *',
              value: _selectedKotaKtp,
              items: _kotaListKtp,
              onChanged: (String? value) {
                if (value != null) {
                  setState(() => _selectedKotaKtp = value);
                }
              },
              validator: (value) => _validateDropdown(value, 'Kabupaten/Kota'),
            ),
            const SizedBox(height: 16),
            
            _buildTextField(
              controller: ktpPostalController,
              label: 'Kode Pos *',
              icon: Icons.markunread_mailbox_outlined,
              keyboardType: TextInputType.number,
              validator: (v) => _validateRequired(v, 'Kode Pos'),
            ),
          ],
        ),
      ),
    );
  }

  // ✅ STEP 4: DATA DOMISILI
  Widget _buildDataDomisiliStep() {
    return Form(
      key: _formKeys[3],
      child: SingleChildScrollView(
        child: Column(
          children: [
            Card(
              child: CheckboxListTile(
                title: const Text('Sama dengan alamat KTP'),
                value: _sameAsKtp,
                onChanged: (value) {
                  setState(() => _sameAsKtp = value ?? false);
                  if (value ?? false) {
                    // Copy data dari KTP ke domisili
                    domisiliAlamatController.text = ktpAlamatController.text;
                    domisiliNoController.text = ktpNoController.text;
                    domisiliRtController.text = ktpRtController.text;
                    domisiliRwController.text = ktpRwController.text;
                    domisiliPostalController.text = ktpPostalController.text;
                    
                    _selectedProvinsiDomisili = _selectedProvinsiKtp;
                    _selectedKotaDomisili = _selectedKotaKtp;
                    
                    if (_selectedProvinsiDomisili != null) {
                      _loadKota(_selectedProvinsiDomisili!, false);
                    }
                  } else {
                    // Reset jika tidak sama dengan KTP
                    domisiliAlamatController.text = '';
                    domisiliNoController.text = '';
                    domisiliRtController.text = '';
                    domisiliRwController.text = '';
                    domisiliPostalController.text = '';
                    _selectedProvinsiDomisili = null;
                    _selectedKotaDomisili = null;
                    _kotaListDomisili = [];
                  }
                },
              ),
            ),
            const SizedBox(height: 16),
            
            _buildTextField(
              controller: domisiliAlamatController,
              label: 'Alamat Domisili *',
              icon: Icons.home_outlined,
              maxLines: 2,
              validator: _sameAsKtp ? null : (v) => _validateRequired(v, 'Alamat domisili'),
              enabled: !_sameAsKtp,
            ),
            const SizedBox(height: 16),
            
            _buildTextField(
              controller: domisiliNoController,
              label: 'No. Rumah *',
              icon: Icons.house_outlined,
              validator: _sameAsKtp ? null : (v) => _validateRequired(v, 'No. Rumah'),
              enabled: !_sameAsKtp,
            ),
            const SizedBox(height: 16),
            
            Row(
              children: [
                Expanded(
                  child: _buildTextField(
                    controller: domisiliRtController,
                    label: 'RT *',
                    icon: Icons.numbers_outlined,
                    keyboardType: TextInputType.number,
                    validator: _sameAsKtp ? null : (v) => _validateRequired(v, 'RT'),
                    enabled: !_sameAsKtp,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildTextField(
                    controller: domisiliRwController,
                    label: 'RW *',
                    icon: Icons.numbers_outlined,
                    keyboardType: TextInputType.number,
                    validator: _sameAsKtp ? null : (v) => _validateRequired(v, 'RW'),
                    enabled: !_sameAsKtp,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // PROVINSI DOMISILI
            _buildDropdownFormField(
              label: 'Provinsi Domisili *',
              value: _sameAsKtp ? _selectedProvinsiKtp : _selectedProvinsiDomisili,
              items: _provinsiList,
              onChanged: _sameAsKtp ? null : (String? value) {
                if (value != null) {
                  setState(() {
                    _selectedProvinsiDomisili = value;
                    _selectedKotaDomisili = null;
                    _kotaListDomisili = [];
                  });
                  _loadKota(value, false);
                }
              },
              validator: _sameAsKtp ? null : (value) => _validateDropdown(value, 'Provinsi domisili'),
              enabled: !_sameAsKtp,
            ),
            const SizedBox(height: 16),
            
            // KOTA DOMISILI
            _buildDropdownFormField(
              label: 'Kabupaten/Kota Domisili *',
              value: _sameAsKtp ? _selectedKotaKtp : _selectedKotaDomisili,
              items: _kotaListDomisili,
              onChanged: _sameAsKtp ? null : (String? value) {
                if (value != null) {
                  setState(() => _selectedKotaDomisili = value);
                }
              },
              validator: _sameAsKtp ? null : (value) => _validateDropdown(value, 'Kabupaten/Kota domisili'),
              enabled: !_sameAsKtp,
            ),
            const SizedBox(height: 16),
            
            _buildTextField(
              controller: domisiliPostalController,
              label: 'Kode Pos *',
              icon: Icons.markunread_mailbox_outlined,
              keyboardType: TextInputType.number,
              validator: _sameAsKtp ? null : (v) => _validateRequired(v, 'Kode Pos'),
              enabled: !_sameAsKtp,
            ),

            if (_sameAsKtp)
              Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green[200]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.green[600], size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Data domisili sama dengan KTP',
                        style: TextStyle(
                          color: Colors.green[700],
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
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

  // ✅ STEP 5: DATA AHLI WARIS - DENGAN HUBUNGAN DARI MASTER DATA
  Widget _buildDataAhliWarisStep() {
    return Form(
      key: _formKeys[4],
      child: SingleChildScrollView(
        child: Column(
          children: [
            _buildTextField(
              controller: namaAhliWarisController,
              label: 'Nama Ahli Waris *',
              icon: Icons.person_outlined,
              validator: (v) => _validateRequired(v, 'Nama ahli waris'),
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: tempatLahirAhliWarisController,
              label: 'Tempat Lahir Ahli Waris *',
              icon: Icons.place_outlined,
              validator: (v) => _validateRequired(v, 'Tempat lahir ahli waris'),
            ),
            const SizedBox(height: 16),
            _buildDateField(
              label: 'Tanggal Lahir Ahli Waris *',
              value: _selectedTanggalLahirAhliWaris,
              onTap: () => _selectDate((date) {
                setState(() => _selectedTanggalLahirAhliWaris = date);
              }, DateTime.now().subtract(const Duration(days: 365 * 18))),
              validator: (v) => _selectedTanggalLahirAhliWaris == null ? 'Tanggal lahir ahli waris wajib diisi' : null,
            ),
            const SizedBox(height: 16),
            // HUBUNGAN KELUARGA DARI MAP
            _buildDropdownFromMap(
              label: 'Hubungan Keluarga *',
              value: _selectedHubungan,
              items: _hubunganMap,
              onChanged: (String? value) {
                setState(() => _selectedHubungan = value);
              },
              validator: (value) => _validateDropdown(value, 'Hubungan keluarga'),
            ),
          ],
        ),
      ),
    );
  }

  // ✅ WIDGET BUILDERS
  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    int maxLines = 1,
    String? Function(String?)? validator,
    bool enabled = true,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      enabled: enabled,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: enabled ? Colors.white : Colors.grey[100],
      ),
      validator: validator,
    );
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String label,
    required bool obscureText,
    required VoidCallback onToggle,
    required String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: const Icon(Icons.lock_outline),
        suffixIcon: IconButton(
          icon: Icon(obscureText ? Icons.visibility_off : Icons.visibility),
          onPressed: onToggle,
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: Colors.white,
      ),
      validator: validator,
    );
  }

  Widget _buildDateField({
    required String label,
    required DateTime? value,
    required VoidCallback onTap,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      readOnly: true,
      onTap: onTap,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: const Icon(Icons.calendar_today_outlined),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        hintText: 'Pilih tanggal',
        filled: true,
        fillColor: Colors.white,
      ),
      controller: TextEditingController(
        text: value != null ? '${value.day}/${value.month}/${value.year}' : '',
      ),
      validator: validator,
    );
  }

  // ✅ NAVIGATION BUTTON LOGIC
  void _handleNextStep() {
    if (_currentStep == 0) {
      // Step 0: Info Koperasi - hanya butuh persetujuan
      if (_agreedToTerms) {
        setState(() => _currentStep++);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Anda harus menyetujui ketentuan terlebih dahulu')),
        );
      }
    } else {
      // Step 1-5: Validasi form
      final formIndex = _currentStep - 1;
      if (formIndex >= 0 && formIndex < _formKeys.length) {
        final formKey = _formKeys[formIndex];
        if (formKey.currentState != null && formKey.currentState!.validate()) {
          setState(() => _currentStep++);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.green[50],
      appBar: AppBar(
        title: const Text('Pendaftaran Anggota KSMI'),
        backgroundColor: Colors.green[800],
        foregroundColor: Colors.white,
      ),
      body: _isLoadingMasterData
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Memuat data master...'),
                ],
              ),
            )
          : SafeArea(
              child: Column(
                children: [
                  // ✅ STEPPER
                  Container(
                    padding: const EdgeInsets.all(16),
                    color: Colors.white,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        for (int i = 0; i < 6; i++) ...[
                          Expanded(
                            child: Container(
                              height: 4,
                              decoration: BoxDecoration(
                                color: i <= _currentStep ? Colors.green[800] : Colors.grey[300],
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                          if (i < 5) const SizedBox(width: 4),
                        ],
                      ],
                    ),
                  ),

                  // ✅ STEP LABELS
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                    color: Colors.white,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: const [
                        Text('Info', style: TextStyle(fontSize: 12)),
                        Text('Data Umum', style: TextStyle(fontSize: 12)),
                        Text('Identitas', style: TextStyle(fontSize: 12)),
                        Text('KTP', style: TextStyle(fontSize: 12)),
                        Text('Domisili', style: TextStyle(fontSize: 12)),
                        Text('Ahli Waris', style: TextStyle(fontSize: 12)),
                      ],
                    ),
                  ),

                  // ✅ STEP CONTENT
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: _buildStepContent(_currentStep),
                    ),
                  ),

                  // ✅ NAVIGATION BUTTONS
                  Container(
                    padding: const EdgeInsets.all(16),
                    color: Colors.white,
                    child: Row(
                      children: [
                        if (_currentStep > 0)
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () {
                                setState(() => _currentStep--);
                              },
                              child: const Text('KEMBALI'),
                            ),
                          ),
                        if (_currentStep > 0) const SizedBox(width: 16),
                        Expanded(
                          child: _currentStep == 5
                              ? ElevatedButton(
                                  onPressed: _isLoading ? null : _handleRegister,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green[800],
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: _isLoading
                                      ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                          ),
                                        )
                                      : const Text(
                                          'DAFTAR SEKARANG',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                        ),
                                )
                              : ElevatedButton(
                                  onPressed: _handleNextStep,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green[800],
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: Text(
                                    _currentStep == 0 ? 'SETUJU & LANJUT' : 'LANJUT',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
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

  @override
  void dispose() {
    usernameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    fullnameController.dispose();
    birthPlaceController.dispose();
    faxController.dispose();
    phoneController.dispose();
    jobController.dispose();
    nomorIdentitasController.dispose();
    ktpAlamatController.dispose();
    ktpNoController.dispose();
    ktpRtController.dispose();
    ktpRwController.dispose();
    ktpPostalController.dispose();
    domisiliAlamatController.dispose();
    domisiliNoController.dispose();
    domisiliRtController.dispose();
    domisiliRwController.dispose();
    domisiliPostalController.dispose();
    namaAhliWarisController.dispose();
    tempatLahirAhliWarisController.dispose();
    super.dispose();
  }
}
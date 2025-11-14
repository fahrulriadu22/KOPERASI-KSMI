class User {
  String username;
  String fullName;
  String email;
  int saldo;
  int angsuran;
  int simpananWajib;
  int siTabung;
  String? photoPath;
  List<Transaction> transactions;

  User({
    required this.username,
    required this.fullName,
    required this.email,
    required this.saldo,
    this.angsuran = 0,
    this.simpananWajib = 0,
    this.siTabung = 0,
    this.photoPath,
    List<Transaction>? transactions,
  }) : transactions = transactions ?? [];

  factory User.fromMap(Map<String, dynamic> map) {
    return User(
      username: map['username'] ?? '',
      fullName: map['fullName'] ?? '',
      email: map['email'] ?? '',
      saldo: map['saldo'] ?? 0,
      angsuran: map['angsuran'] ?? 0,
      simpananWajib: map['simpananWajib'] ?? 0,
      siTabung: map['siTabung'] ?? 0,
      photoPath: map['photoPath'],
      transactions: (map['transactions'] as List<dynamic>? ?? [])
          .map((e) => Transaction.fromMap(e))
          .toList(),
    );
  }

  Map<String, Object?> toMap() {
    return {
      'username': username,
      'fullName': fullName,
      'email': email,
      'saldo': saldo,
      'angsuran': angsuran,
      'simpananWajib': simpananWajib,
      'siTabung': siTabung,
      'photoPath': photoPath,
      'transactions': transactions.map((t) => t.toMap()).toList(),
    };
  }
}

class Transaction {
  String type;
  int amount;
  String date;

  Transaction({required this.type, required this.amount, required this.date});

  factory Transaction.fromMap(Map<String, dynamic> map) {
    return Transaction(
      type: map['type'] ?? '',
      amount: map['amount'] ?? 0,
      date: map['date'] ?? '',
    );
  }

  Map<String, Object?> toMap() {
    return {'type': type, 'amount': amount, 'date': date};
  }
}

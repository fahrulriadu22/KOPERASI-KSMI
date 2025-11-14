import 'package:flutter/material.dart';

class MutasiScreen extends StatelessWidget {
  final Map<String, dynamic> user;
  final List<Map<String, dynamic>> mutasiList;

  const MutasiScreen({
    Key? key,
    required this.user,
    required this.mutasiList,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Riwayat Mutasi",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.blue.shade800,
        centerTitle: true,
        elevation: 0,
      ),
      backgroundColor: Colors.grey[100],
      body: mutasiList.isEmpty
          ? const Center(
              child: Text(
                "Belum ada transaksi",
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: mutasiList.length,
              itemBuilder: (context, index) {
                final mutasi = mutasiList[index];
                final isTopUp = mutasi['type'] == 'Top Up';
                final icon = isTopUp
                    ? Icons.arrow_downward // uang masuk ke user
                    : Icons.arrow_upward;  // uang keluar dari user
                final color = isTopUp ? Colors.green : Colors.red;

                return Card(
                  elevation: 3,
                  margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: ListTile(
                    leading: CircleAvatar(
                      radius: 24,
                      backgroundColor: color.withOpacity(0.15),
                      child: Icon(icon, color: color, size: 24),
                    ),
                    title: Text(
                      mutasi['type'],
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Tanggal: ${mutasi['date']}",
                          style: const TextStyle(fontSize: 13),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "Keterangan: ${mutasi['description'] ?? '-'}",
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                    trailing: Text(
                      "${isTopUp ? '+' : '-'} Rp${mutasi['amount']}",
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}

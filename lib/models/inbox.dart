// models/inbox_model.dart
class InboxModel {
  final String id;
  final String subject;
  final String keterangan;
  final String createdAt;
  final String isRead;
  final String userId;

  InboxModel({
    required this.id,
    required this.subject,
    required this.keterangan,
    required this.createdAt,
    required this.isRead,
    required this.userId,
  });

  factory InboxModel.fromJson(Map<String, dynamic> json) {
    return InboxModel(
      id: json['id']?.toString() ?? '',
      subject: json['subject']?.toString() ?? '',
      keterangan: json['keterangan']?.toString() ?? '',
      createdAt: json['created_at']?.toString() ?? '',
      isRead: json['is_read']?.toString() ?? '0',
      userId: json['user_id']?.toString() ?? '',
    );
  }

  bool get isReadBool => isRead == '1';
}
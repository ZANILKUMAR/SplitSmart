import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationModel {
  final String id;
  final String userId; // User who will receive the notification
  final String
  type; // 'expense_added', 'settlement_received', 'member_added', etc.
  final String title;
  final String message;
  final String? groupId;
  final String? expenseId;
  final String? settlementId;
  final String? actionBy; // User who performed the action
  final bool isRead;
  final DateTime createdAt;

  NotificationModel({
    required this.id,
    required this.userId,
    required this.type,
    required this.title,
    required this.message,
    this.groupId,
    this.expenseId,
    this.settlementId,
    this.actionBy,
    this.isRead = false,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'type': type,
      'title': title,
      'message': message,
      'groupId': groupId,
      'expenseId': expenseId,
      'settlementId': settlementId,
      'actionBy': actionBy,
      'isRead': isRead,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory NotificationModel.fromJson(Map<String, dynamic> json, String id) {
    DateTime createdAt;
    try {
      if (json['createdAt'] == null) {
        createdAt = DateTime.now();
      } else if (json['createdAt'] is Timestamp) {
        createdAt = (json['createdAt'] as Timestamp).toDate();
      } else {
        createdAt = DateTime.now();
      }
    } catch (e) {
      print('NotificationModel: Error parsing createdAt: $e');
      createdAt = DateTime.now();
    }

    return NotificationModel(
      id: id,
      userId: json['userId'] ?? '',
      type: json['type'] ?? '',
      title: json['title'] ?? '',
      message: json['message'] ?? '',
      groupId: json['groupId'],
      expenseId: json['expenseId'],
      settlementId: json['settlementId'],
      actionBy: json['actionBy'],
      isRead: json['isRead'] ?? false,
      createdAt: createdAt,
    );
  }

  NotificationModel copyWith({
    String? id,
    String? userId,
    String? type,
    String? title,
    String? message,
    String? groupId,
    String? expenseId,
    String? settlementId,
    String? actionBy,
    bool? isRead,
    DateTime? createdAt,
  }) {
    return NotificationModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      type: type ?? this.type,
      title: title ?? this.title,
      message: message ?? this.message,
      groupId: groupId ?? this.groupId,
      expenseId: expenseId ?? this.expenseId,
      settlementId: settlementId ?? this.settlementId,
      actionBy: actionBy ?? this.actionBy,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

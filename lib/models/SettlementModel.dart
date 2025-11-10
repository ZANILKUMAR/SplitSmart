import 'package:cloud_firestore/cloud_firestore.dart';

class SettlementModel {
  final String id;
  final String groupId;
  final String paidBy; // User who paid
  final String paidTo; // User who received payment
  final double amount;
  final DateTime date;
  final String? notes;
  final DateTime createdAt;

  SettlementModel({
    required this.id,
    required this.groupId,
    required this.paidBy,
    required this.paidTo,
    required this.amount,
    required this.date,
    this.notes,
    required this.createdAt,
  });

  factory SettlementModel.fromJson(Map<String, dynamic> json, String id) {
    return SettlementModel(
      id: id,
      groupId: json['groupId'] ?? '',
      paidBy: json['paidBy'] ?? '',
      paidTo: json['paidTo'] ?? '',
      amount: (json['amount'] ?? 0).toDouble(),
      date: (json['date'] as Timestamp).toDate(),
      notes: json['notes'],
      createdAt: json['createdAt'] != null
          ? (json['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'groupId': groupId,
      'paidBy': paidBy,
      'paidTo': paidTo,
      'amount': amount,
      'date': Timestamp.fromDate(date),
      'notes': notes,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';

enum SplitType { equal, unequal, percentage }

class ExpenseModel {
  final String id;
  final String groupId;
  final String description;
  final double amount;
  final String paidBy;
  final List<String> splitBetween;
  final DateTime date;
  final String? category;
  final String? notes;
  final DateTime createdAt;
  final SplitType splitType;
  final Map<String, double>?
  customSplits; // For unequal: userId -> amount, For percentage: userId -> percentage

  ExpenseModel({
    required this.id,
    required this.groupId,
    required this.description,
    required this.amount,
    required this.paidBy,
    required this.splitBetween,
    required this.date,
    this.category,
    this.notes,
    required this.createdAt,
    this.splitType = SplitType.equal,
    this.customSplits,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'groupId': groupId,
      'description': description,
      'amount': amount,
      'paidBy': paidBy,
      'splitBetween': splitBetween,
      'date': Timestamp.fromDate(date),
      'category': category,
      'notes': notes,
      'createdAt': Timestamp.fromDate(createdAt),
      'splitType': splitType.toString().split('.').last,
      'customSplits': customSplits,
    };
  }

  factory ExpenseModel.fromJson(Map<String, dynamic> json, String id) {
    String splitTypeStr = json['splitType'] ?? 'equal';
    SplitType splitType = SplitType.values.firstWhere(
      (e) => e.toString().split('.').last == splitTypeStr,
      orElse: () => SplitType.equal,
    );

    Map<String, double>? customSplits;
    if (json['customSplits'] != null) {
      customSplits = Map<String, double>.from(
        (json['customSplits'] as Map).map(
          (key, value) => MapEntry(key.toString(), (value ?? 0).toDouble()),
        ),
      );
    }

    return ExpenseModel(
      id: id,
      groupId: json['groupId'] ?? '',
      description: json['description'] ?? '',
      amount: (json['amount'] ?? 0).toDouble(),
      paidBy: json['paidBy'] ?? '',
      splitBetween: List<String>.from(json['splitBetween'] ?? []),
      date: (json['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      category: json['category'],
      notes: json['notes'],
      createdAt: (json['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      splitType: splitType,
      customSplits: customSplits,
    );
  }

  ExpenseModel copyWith({
    String? id,
    String? groupId,
    String? description,
    double? amount,
    String? paidBy,
    List<String>? splitBetween,
    DateTime? date,
    String? category,
    String? notes,
    DateTime? createdAt,
    SplitType? splitType,
    Map<String, double>? customSplits,
  }) {
    return ExpenseModel(
      id: id ?? this.id,
      groupId: groupId ?? this.groupId,
      description: description ?? this.description,
      amount: amount ?? this.amount,
      paidBy: paidBy ?? this.paidBy,
      splitBetween: splitBetween ?? this.splitBetween,
      date: date ?? this.date,
      category: category ?? this.category,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      splitType: splitType ?? this.splitType,
      customSplits: customSplits ?? this.customSplits,
    );
  }

  // Calculate how much each person owes
  double getShareAmount() {
    if (splitBetween.isEmpty) return 0;

    switch (splitType) {
      case SplitType.equal:
        return amount / splitBetween.length;
      case SplitType.unequal:
      case SplitType.percentage:
        // For unequal and percentage, we need custom calculation
        // This is used for equal split scenarios
        return amount / splitBetween.length;
    }
  }

  // Get share for a specific user
  double getShareForUser(String userId) {
    if (!splitBetween.contains(userId)) return 0;

    switch (splitType) {
      case SplitType.equal:
        return amount / splitBetween.length;
      case SplitType.unequal:
        return customSplits?[userId] ?? 0;
      case SplitType.percentage:
        final percentage = customSplits?[userId] ?? 0;
        return (amount * percentage) / 100;
    }
  }
}

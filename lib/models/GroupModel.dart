import 'package:cloud_firestore/cloud_firestore.dart';

class GroupModel {
  final String id;
  final String name;
  final String description;
  final String createdBy;
  final List<String> members;
  final DateTime createdAt;
  final String? imageUrl;
  final String currency; // Currency code (USD, INR, EUR, etc.)
  final bool simplifyDebts; // Simplify group debts setting

  GroupModel({
    required this.id,
    required this.name,
    required this.description,
    required this.createdBy,
    required this.members,
    required this.createdAt,
    this.imageUrl,
    this.currency = 'USD', // Default to USD
    this.simplifyDebts = false, // Default to false
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'createdBy': createdBy,
      'members': members,
      'createdAt': Timestamp.fromDate(createdAt),
      'imageUrl': imageUrl,
      'currency': currency,
      'simplifyDebts': simplifyDebts,
    };
  }

  factory GroupModel.fromJson(Map<String, dynamic> json, String id) {
    return GroupModel(
      id: id,
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      createdBy: json['createdBy'] ?? '',
      members: List<String>.from(json['members'] ?? []),
      createdAt: (json['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      imageUrl: json['imageUrl'],
      currency: json['currency'] ?? 'USD',
      simplifyDebts: json['simplifyDebts'] ?? false,
    );
  }

  GroupModel copyWith({
    String? id,
    String? name,
    String? description,
    String? createdBy,
    List<String>? members,
    DateTime? createdAt,
    String? imageUrl,
    String? currency,
    bool? simplifyDebts,
  }) {
    return GroupModel(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      createdBy: createdBy ?? this.createdBy,
      members: members ?? this.members,
      createdAt: createdAt ?? this.createdAt,
      imageUrl: imageUrl ?? this.imageUrl,
      currency: currency ?? this.currency,
      simplifyDebts: simplifyDebts ?? this.simplifyDebts,
    );
  }
}

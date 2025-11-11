class UserModel {
  final String? id;
  final String uid;
  final String email;
  final String name;
  final String phoneNumber;
  final bool isRegistered;

  UserModel({
    this.id,
    required this.uid,
    required this.email,
    required this.name,
    required this.phoneNumber,
    this.isRegistered = true,
  });

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'uid': uid,
      'email': email,
      'name': name,
      'phoneNumber': phoneNumber,
      'isRegistered': isRegistered,
    };
  }

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'],
      uid: json['uid'] ?? '',
      email: json['email'] ?? '',
      name: json['name'] ?? '',
      phoneNumber: json['phoneNumber'] ?? '',
      isRegistered: json['isRegistered'] ?? true,
    );
  }
}

class UserModel {
  final String id;
  final String role; // 'ngo' or 'volunteer'
  final String name;
  final String email;
  final String? skills; // For volunteer
  final String? location; // For volunteer
  final String? availability; // For volunteer
  final String? fcmToken; // Firebase Cloud Messaging Token
  final String? phoneNumber; // For WhatsApp notifications

  UserModel({
    required this.id,
    required this.role,
    required this.name,
    required this.email,
    this.skills,
    this.location,
    this.availability,
    this.fcmToken,
    this.phoneNumber,
  });

  factory UserModel.fromMap(Map<String, dynamic> map, String documentId) {
    return UserModel(
      id: documentId,
      role: map['role'] ?? '',
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      skills: map['skills'],
      location: map['location'],
      availability: map['availability'],
      fcmToken: map['fcmToken'],
      phoneNumber: map['phone_number'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'role': role,
      'name': name,
      'email': email,
      if (skills != null) 'skills': skills,
      if (location != null) 'location': location,
      if (availability != null) 'availability': availability,
      if (fcmToken != null) 'fcmToken': fcmToken,
      if (phoneNumber != null) 'phone_number': phoneNumber,
    };
  }
}

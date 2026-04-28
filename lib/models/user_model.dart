class UserModel {
  final String id;
  final String role; // 'ngo' or 'volunteer'
  final String name;
  final String email;
  final List<String> skills; // For volunteer — list of skill tags
  final String? location; // For volunteer
  final String? availability; // For volunteer
  final String? fcmToken; // Firebase Cloud Messaging Token
  final String? phoneNumber; // For WhatsApp notifications

  UserModel({
    required this.id,
    required this.role,
    required this.name,
    required this.email,
    this.skills = const [],
    this.location,
    this.availability,
    this.fcmToken,
    this.phoneNumber,
  });

  factory UserModel.fromMap(Map<String, dynamic> map, String documentId) {
    // skills may be stored as List<String> (new wizard) or String (old self-register)
    List<String> skillsList = [];
    final rawSkills = map['skills'];
    if (rawSkills is List) {
      skillsList = List<String>.from(rawSkills);
    } else if (rawSkills is String && rawSkills.isNotEmpty) {
      skillsList = rawSkills.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
    }
    return UserModel(
      id: documentId,
      role: map['role'] ?? '',
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      skills: skillsList,
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
      if (skills.isNotEmpty) 'skills': skills,
      if (location != null) 'location': location,
      if (availability != null) 'availability': availability,
      if (fcmToken != null) 'fcmToken': fcmToken,
      if (phoneNumber != null) 'phone_number': phoneNumber,
    };
  }
}

class UserProfile {
  final String id;
  final String userId;
  final String firstname;
  final String lastname;
  final String name;
  final String email;
  final String phone;
  final String avatar;
  final String requirement;

  UserProfile({
    required this.id,
    required this.userId,
    required this.firstname,
    required this.lastname,
    required this.name,
    required this.email,
    required this.phone,
    required this.avatar,
    required this.requirement,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    String firstname = json['firstname']?.toString() ?? '';
    String lastname = json['lastname']?.toString() ?? '';
    final name = json['name']?.toString() ?? json['fullName']?.toString() ?? '';

    if (firstname.isEmpty && lastname.isEmpty && name.isNotEmpty) {
      final parts = name.trim().split(' ');
      if (parts.isNotEmpty) {
        firstname = parts.first;
        if (parts.length > 1) {
          lastname = parts.sublist(1).join(' ');
        }
      }
    }

    return UserProfile(
      id: json['id']?.toString() ?? '',
      userId: json['userId']?.toString() ?? '',
      firstname: firstname,
      lastname: lastname,
      name: name,
      email: json['email']?.toString() ?? '',
      phone:
          (json['mobile'] ??
                  json['phone'] ??
                  json['phoneNumber'] ??
                  json['mobileNumber'])
              ?.toString() ??
          '',
      avatar:
          (json['profileImageUrl'] ?? json['profileImage'] ?? json['avatar'])
              ?.toString() ??
          '',
      requirement: json['requirement']?.toString() ?? '',
    );
  }

  UserProfile copyWith({
    String? id,
    String? userId,
    String? firstname,
    String? lastname,
    String? name,
    String? email,
    String? phone,
    String? avatar,
    String? requirement,
  }) {
    return UserProfile(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      firstname: firstname ?? this.firstname,
      lastname: lastname ?? this.lastname,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      avatar: avatar ?? this.avatar,
      requirement: requirement ?? this.requirement,
    );
  }

  String get initials {
    if (firstname.isNotEmpty) {
      final f = firstname.substring(0, 1).toUpperCase();
      final l = lastname.isNotEmpty ? lastname.substring(0, 1).toUpperCase() : '';
      return '$f$l';
    }
    if (name.isNotEmpty) {
      final parts = name.trim().split(' ');
      if (parts.length > 1) {
        return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
      } else if (parts[0].isNotEmpty) {
        return parts[0][0].toUpperCase();
      }
    }
    return 'U';
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'firstname': firstname,
      'lastname': lastname,
      'name': name,
      'email': email,
      'phone': phone,
      'avatar': avatar,
      'requirement': requirement,
    };
  }
}

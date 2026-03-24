import 'package:equatable/equatable.dart';

class AppUser extends Equatable {
  final String       id;
  final String       firstName;
  final String       lastName;
  final String       email;
  final String       userName;
  final List<String> roles;
  final bool         isActive;

  const AppUser({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.userName,
    required this.roles,
    required this.isActive,
  });

  String get fullName {
    final full = '$firstName $lastName'.trim();
    return full.isNotEmpty ? full : (userName.isNotEmpty ? userName : email);
  }

  bool get isAdmin => roles.contains('Admin');

  factory AppUser.fromJson(Map<String, dynamic> j) => AppUser(
    id:        j['id']        as String? ?? j['userId'] as String? ?? '',
    firstName: j['firstName'] as String? ?? '',
    lastName:  j['lastName']  as String? ?? '',
    email:     j['email']     as String? ?? '',
    userName:  j['userName']  as String? ?? j['username'] as String? ?? '',
    roles: List<String>.from(
      (j['roles'] as List?)?.map((e) => e.toString()) ?? [],
    ),
    isActive: j['isActive'] as bool? ?? j['active'] as bool? ?? true,
  );

  @override
  List<Object?> get props =>
      [id, firstName, lastName, email, userName, roles, isActive];
}

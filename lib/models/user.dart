class User {
  int? userId;
  String fullName;
  String email;
  String password;
  String role;

  User({
    this.userId,
    required this.fullName,
    required this.email,
    required this.password,
    required this.role,
  });
}
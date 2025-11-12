class User {
  final String phoneNumber;
  final String name;
  final String companyName; // This comes from API
  final String webhookUrl; // This comes from API
  final String email; // This comes from API
  final String phone; // This comes from API
  final String website; // This comes from API
  final DateTime? lastLogin;

  User({
    required this.phoneNumber,
    required this.name,
    required this.companyName,
    required this.webhookUrl,
    required this.email,
    required this.phone,
    required this.website,
    this.lastLogin,
  });

  // Convert to JSON for storage
  Map<String, dynamic> toJson() {
    return {
      'phoneNumber': phoneNumber,
      'name': name,
      'companyName': companyName,
      'webhookUrl': webhookUrl,
      'email': email,
      'phone': phone,
      'website': website,
      'lastLogin': lastLogin?.toIso8601String(),
    };
  }

  // Create from JSON
  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      phoneNumber: json['phoneNumber'],
      name: json['name'],
      companyName: json['companyName'],
      webhookUrl: json['webhookUrl'],
      email: json['email'],
      phone: json['phone'],
      website: json['website'],
      lastLogin:
          json['lastLogin'] != null ? DateTime.parse(json['lastLogin']) : null,
    );
  }
}

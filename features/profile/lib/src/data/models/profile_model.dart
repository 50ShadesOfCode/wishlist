import '../../domain/entities/profile.dart';

class ProfileModel extends Profile {
  const ProfileModel({
    required super.userId,
    required super.username,
    super.avatarUrl,
    super.dateOfBirth,
    super.city,
  });

  factory ProfileModel.fromJson(Map<String, dynamic> json) => ProfileModel(
    userId: json['user_id'] as String? ?? json['id'] as String,
    username: json['username'] as String? ?? 'user',
    avatarUrl: json['avatar_url'] as String?,
    dateOfBirth: json['date_of_birth'] != null
        ? DateTime.tryParse(json['date_of_birth'] as String)
        : null,
    city: json['city'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'user_id': userId,
    'username': username,
    'avatar_url': avatarUrl,
    'date_of_birth': dateOfBirth?.toIso8601String(),
    'city': city,
  };

  factory ProfileModel.fromEntity(Profile p) => ProfileModel(
    userId: p.userId,
    username: p.username,
    avatarUrl: p.avatarUrl,
    dateOfBirth: p.dateOfBirth,
    city: p.city,
  );
}

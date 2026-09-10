import 'package:equatable/equatable.dart';

class Profile extends Equatable {
  const Profile({
    required this.userId,
    required this.username,
    this.avatarUrl,
    this.dateOfBirth,
    this.city,
  });

  final String userId;
  final String username;
  final String? avatarUrl;
  final DateTime? dateOfBirth;
  final String? city;

  Profile copyWith({
    String? username,
    String? avatarUrl,
    DateTime? dateOfBirth,
    String? city,
  }) => Profile(
    userId: userId,
    username: username ?? this.username,
    avatarUrl: avatarUrl ?? this.avatarUrl,
    dateOfBirth: dateOfBirth ?? this.dateOfBirth,
    city: city ?? this.city,
  );

  /// Nullable fields cannot be cleared via [copyWith] (`null` means "keep"),
  /// so clearing has explicit methods.
  Profile clearAvatar() => Profile(
    userId: userId,
    username: username,
    dateOfBirth: dateOfBirth,
    city: city,
  );

  Profile clearDateOfBirth() => Profile(
    userId: userId,
    username: username,
    avatarUrl: avatarUrl,
    city: city,
  );

  Profile clearCity() => Profile(
    userId: userId,
    username: username,
    avatarUrl: avatarUrl,
    dateOfBirth: dateOfBirth,
  );

  @override
  List<Object?> get props => [userId, username, avatarUrl, dateOfBirth, city];
}

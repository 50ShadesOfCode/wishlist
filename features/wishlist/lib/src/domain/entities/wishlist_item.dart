import 'package:equatable/equatable.dart';

class WishlistItem extends Equatable {
  const WishlistItem({
    required this.id,
    required this.ownerId,
    required this.name,
    this.description,
    this.imageUrls = const [],
    this.latitude,
    this.longitude,
    this.placeLabel,
    this.isHidden = false,
    required this.createdAt,
  });

  final String id;
  final String ownerId;
  final String name;
  final String? description;
  final List<String> imageUrls;
  final double? latitude;
  final double? longitude;
  final String? placeLabel;
  final bool isHidden;
  final DateTime createdAt;

  WishlistItem copyWith({
    String? name,
    String? description,
    List<String>? imageUrls,
    double? latitude,
    double? longitude,
    String? placeLabel,
    bool? isHidden,
  }) => WishlistItem(
    id: id,
    ownerId: ownerId,
    name: name ?? this.name,
    description: description ?? this.description,
    imageUrls: imageUrls ?? this.imageUrls,
    latitude: latitude ?? this.latitude,
    longitude: longitude ?? this.longitude,
    placeLabel: placeLabel ?? this.placeLabel,
    isHidden: isHidden ?? this.isHidden,
    createdAt: createdAt,
  );

  /// Nullable fields cannot be cleared via [copyWith] (`null` means "keep"),
  /// so clearing has explicit methods.
  WishlistItem clearDescription() => WishlistItem(
    id: id,
    ownerId: ownerId,
    name: name,
    imageUrls: imageUrls,
    latitude: latitude,
    longitude: longitude,
    placeLabel: placeLabel,
    isHidden: isHidden,
    createdAt: createdAt,
  );

  WishlistItem clearPlace() => WishlistItem(
    id: id,
    ownerId: ownerId,
    name: name,
    description: description,
    imageUrls: imageUrls,
    isHidden: isHidden,
    createdAt: createdAt,
  );

  WishlistItem clearImages() => WishlistItem(
    id: id,
    ownerId: ownerId,
    name: name,
    description: description,
    latitude: latitude,
    longitude: longitude,
    placeLabel: placeLabel,
    isHidden: isHidden,
    createdAt: createdAt,
  );

  @override
  List<Object?> get props => [
    id,
    ownerId,
    name,
    description,
    imageUrls,
    latitude,
    longitude,
    placeLabel,
    isHidden,
    createdAt,
  ];
}

class Subscription extends Equatable {
  const Subscription({
    required this.subscriberId,
    required this.targetUserId,
    required this.createdAt,
  });

  final String subscriberId;
  final String targetUserId;
  final DateTime createdAt;

  @override
  List<Object?> get props => [subscriberId, targetUserId, createdAt];
}

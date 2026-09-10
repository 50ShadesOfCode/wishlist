import '../../domain/entities/wishlist_item.dart';

class WishlistItemModel extends WishlistItem {
  const WishlistItemModel({
    required super.id,
    required super.ownerId,
    required super.name,
    super.description,
    super.imageUrls,
    super.latitude,
    super.longitude,
    super.placeLabel,
    super.isHidden,
    required super.createdAt,
  });

  factory WishlistItemModel.fromJson(Map<String, dynamic> json) =>
      WishlistItemModel(
        id: json['id'] as String,
        ownerId: json['owner_id'] as String,
        name: json['name'] as String,
        description: json['description'] as String?,
        imageUrls: (json['image_urls'] as List?)?.cast<String>() ?? const [],
        latitude: (json['latitude'] as num?)?.toDouble(),
        longitude: (json['longitude'] as num?)?.toDouble(),
        placeLabel: json['place_label'] as String?,
        isHidden: json['is_hidden'] as bool? ?? false,
        // Never let one malformed row crash the whole list/watch stream.
        createdAt:
            DateTime.tryParse(json['created_at'] as String? ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0),
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'owner_id': ownerId,
    'name': name,
    'description': description,
    'image_urls': imageUrls,
    'latitude': latitude,
    'longitude': longitude,
    'place_label': placeLabel,
    'is_hidden': isHidden,
    'created_at': createdAt.toIso8601String(),
  };

  /// Mutable columns only: `id`/`owner_id`/`created_at` are immutable and
  /// must not be overwritten on update.
  Map<String, dynamic> toUpdateJson() => {
    'name': name,
    'description': description,
    'image_urls': imageUrls,
    'latitude': latitude,
    'longitude': longitude,
    'place_label': placeLabel,
    'is_hidden': isHidden,
  };

  factory WishlistItemModel.fromEntity(WishlistItem e) => WishlistItemModel(
    id: e.id,
    ownerId: e.ownerId,
    name: e.name,
    description: e.description,
    imageUrls: e.imageUrls,
    latitude: e.latitude,
    longitude: e.longitude,
    placeLabel: e.placeLabel,
    isHidden: e.isHidden,
    createdAt: e.createdAt,
  );
}

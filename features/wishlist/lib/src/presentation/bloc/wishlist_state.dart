import 'package:equatable/equatable.dart';

import '../../domain/entities/wishlist_item.dart';

class WishlistState extends Equatable {
  const WishlistState({
    this.items = const [],
    this.isLoading = false,
    this.error,
  });

  final List<WishlistItem> items;
  final bool isLoading;
  final String? error;

  WishlistState copyWith({
    List<WishlistItem>? items,
    bool? isLoading,
    String? error,
  }) => WishlistState(
    items: items ?? this.items,
    isLoading: isLoading ?? this.isLoading,
    error: error,
  );

  @override
  List<Object?> get props => [items, isLoading, error];
}

import 'package:core/core.dart';

import '../../domain/entities/wishlist_item.dart';
import '../../domain/repositories/wishlist_repository.dart';

class GetMyItemsUseCase implements UseCase<List<WishlistItem>, String> {
  GetMyItemsUseCase(this._repo);
  final WishlistRepository _repo;
  @override
  Future<List<WishlistItem>> call(String ownerId) => _repo.getMyItems(ownerId);
}

class DeleteItemUseCase implements UseCase<void, String> {
  /// Prefer dispatching [WishlistDelete] on [WishlistBloc] instead: the bloc
  /// also deletes the item's Firestore chats, while calling this use-case
  /// (or the repository) directly leaks chats.
  DeleteItemUseCase(this._repo);
  final WishlistRepository _repo;
  @override
  Future<void> call(String itemId) => _repo.deleteItem(itemId);
}

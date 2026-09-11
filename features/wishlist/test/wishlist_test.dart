import 'package:flutter_test/flutter_test.dart';
import 'package:wishlist/src/data/models/wishlist_item_model.dart';
import 'package:wishlist/wishlist.dart';

void main() {
  test('WishlistItem model roundtrip', () {
    final item = WishlistItemModel(
      id: '1',
      ownerId: 'u1',
      name: 'Bike',
      createdAt: DateTime.utc(2026, 1, 1),
    );
    final json = item.toJson();
    expect(WishlistItemModel.fromJson(json).name, 'Bike');
  });

  test('WishlistItem clear methods', () {
    final item = WishlistItem(
      id: '1',
      ownerId: 'u1',
      name: 'Bike',
      description: 'red',
      latitude: 41.3,
      longitude: 69.2,
      placeLabel: 'shop',
      createdAt: DateTime.utc(2026, 1, 1),
    );
    final cleared = item.clearPlace();
    expect(cleared.latitude, isNull);
    expect(cleared.longitude, isNull);
    expect(cleared.placeLabel, isNull);
    expect(cleared.description, 'red');
    expect(item.clearDescription().description, isNull);
  });

  test('toUpdateJson excludes immutable columns', () {
    final item = WishlistItemModel(
      id: '1',
      ownerId: 'u1',
      name: 'Bike',
      createdAt: DateTime.utc(2026, 1, 1),
    );
    final json = item.toUpdateJson();
    expect(json.containsKey('id'), isFalse);
    expect(json.containsKey('owner_id'), isFalse);
    expect(json.containsKey('created_at'), isFalse);
    expect(json['name'], 'Bike');
  });

  test('WishlistToggleHide is optimistic with rollback', () async {
    final repo = _FakeWishlistRepo(<String>[]);
    final bloc = WishlistBloc(
      getMyItems: GetMyItemsUseCase(repo),
      addItem: AddItemUseCase(repo),
      updateItem: UpdateItemUseCase(repo),
      deleteItem: DeleteItemUseCase(repo),
      setHidden: SetHiddenUseCase(repo),
    );
    // Seed state through a load, then toggle: no reload event expected,
    // the list is patched in place.
    bloc.add(const WishlistLoad('u1'));
    await bloc.stream.firstWhere((s) => !s.isLoading && s.items.isNotEmpty);
    bloc.add(const WishlistToggleHide('i1', true));
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(bloc.state.items.single.isHidden, isTrue);
    expect(bloc.state.error, isNull);
    await bloc.close();
  });

  test('WishlistBloc deletes the item before its chats', () async {
    final order = <String>[];
    final repo = _FakeWishlistRepo(order);
    final bloc = WishlistBloc(
      getMyItems: GetMyItemsUseCase(repo),
      addItem: AddItemUseCase(repo),
      updateItem: UpdateItemUseCase(repo),
      deleteItem: DeleteItemUseCase(
        repo,
        deleteChatsForItem: (id) async => order.add('chats:$id'),
      ),
      setHidden: SetHiddenUseCase(repo),
    );
    bloc.add(const WishlistDelete('i1'));
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(order, ['item:i1', 'chats:i1']);
    await bloc.close();
  });

  test('WishlistBloc surfaces chat-cleanup failure after item delete', () async {
    final order = <String>[];
    final repo = _FakeWishlistRepo(order);
    final bloc = WishlistBloc(
      getMyItems: GetMyItemsUseCase(repo),
      addItem: AddItemUseCase(repo),
      updateItem: UpdateItemUseCase(repo),
      deleteItem: DeleteItemUseCase(
        repo,
        deleteChatsForItem: (_) async => throw Exception('firestore down'),
      ),
      setHidden: SetHiddenUseCase(repo),
    );
    bloc.add(const WishlistDelete('i1'));
    final failed = await bloc.stream.firstWhere((s) => s.error != null);
    // Item-first ordering: the row is already gone; the error tells the
    // caller to retry the idempotent chat cleanup.
    expect(order, ['item:i1']);
    expect(failed.error, contains('firestore down'));
    await bloc.close();
  });

  test('DeleteItemUseCase deletes the item before its chats', () async {
    final order = <String>[];
    final usecase = DeleteItemUseCase(
      _FakeWishlistRepo(order),
      deleteChatsForItem: (id) async => order.add('chats:$id'),
    );
    await usecase('i1');
    expect(order, ['item:i1', 'chats:i1']);
  });

  test('GetMyItemsUseCase delegates to the repository', () async {
    final repo = _FakeWishlistRepo(<String>[]);
    final items = await GetMyItemsUseCase(repo)('u1');
    expect(items.single.id, 'i1');
  });
}

class _FakeWishlistRepo implements WishlistRepository {
  _FakeWishlistRepo(this.order);
  final List<String> order;

  @override
  Future<void> deleteItem(String itemId) async => order.add('item:$itemId');

  @override
  Future<List<WishlistItem>> getMyItems(String ownerId) async => [
    WishlistItem(
      id: 'i1',
      ownerId: ownerId,
      name: 'Bike',
      createdAt: DateTime.utc(2026, 1, 1),
    ),
  ];
  @override
  Future<List<WishlistItem>> getVisibleItems(String ownerId) =>
      throw UnimplementedError();
  @override
  Future<WishlistItem?> getItemById(String itemId) =>
      throw UnimplementedError();
  @override
  Future<WishlistItem> addItem(WishlistItem item) => throw UnimplementedError();
  @override
  Future<WishlistItem> updateItem(WishlistItem item) =>
      throw UnimplementedError();
  @override
  Future<void> setHidden(String itemId, bool hidden) async {
    order.add('hidden:$itemId:$hidden');
  }
  @override
  Future<String> uploadItemImage({
    required String ownerId,
    required String itemId,
    required String filePath,
  }) => throw UnimplementedError();
  @override
  Future<void> deleteImageByUrl(String imageUrl) => throw UnimplementedError();
  @override
  Future<void> subscribe(String subscriberId, String targetUserId) =>
      throw UnimplementedError();
  @override
  Future<void> unsubscribe(String subscriberId, String targetUserId) =>
      throw UnimplementedError();
  @override
  Future<List<Subscription>> mySubscriptions(String subscriberId) =>
      throw UnimplementedError();
  @override
  Future<void> deleteAllSubscriptionsForUser(String userId) async {
    order.add('subs:$userId');
  }
}

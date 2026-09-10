import 'package:flutter_test/flutter_test.dart';
import 'package:wishlist/wishlist.dart';
void main() {
  test('WishlistItem model roundtrip', () {
    final item = WishlistItemModel(
      id: '1', ownerId: 'u1', name: 'Bike',
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
      id: '1', ownerId: 'u1', name: 'Bike',
      createdAt: DateTime.utc(2026, 1, 1),
    );
    final json = item.toUpdateJson();
    expect(json.containsKey('id'), isFalse);
    expect(json.containsKey('owner_id'), isFalse);
    expect(json.containsKey('created_at'), isFalse);
    expect(json['name'], 'Bike');
  });

  test('WishlistToggleHide carries ownerId', () {
    const e = WishlistToggleHide('i1', true, ownerId: 'u1');
    expect(e.ownerId, 'u1');
    expect(e.props, contains('u1'));
  });

  test('WishlistBloc deletes chats before the item', () async {
    final order = <String>[];
    final bloc = WishlistBloc(
      _FakeWishlistRepo(order),
      deleteChatsForItem: (id) async => order.add('chats:$id'),
    );
    bloc.add(const WishlistDelete('i1'));
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(order, ['chats:i1', 'item:i1']);
    await bloc.close();
  });

  test('WishlistBloc keeps item when chat delete fails', () async {
    final bloc = WishlistBloc(
      _FakeWishlistRepo(<String>[]),
      deleteChatsForItem: (_) async => throw Exception('firestore down'),
    );
    bloc.add(const WishlistDelete('i1'));
    final failed = await bloc.stream.firstWhere((s) => s.error != null);
    expect(failed.error, contains('firestore down'));
    await bloc.close();
  });
}

class _FakeWishlistRepo implements WishlistRepository {
  _FakeWishlistRepo(this.order);
  final List<String> order;

  @override
  Future<void> deleteItem(String itemId) async => order.add('item:$itemId');

  @override
  Future<List<WishlistItem>> getMyItems(String ownerId) => throw UnimplementedError();
  @override
  Future<List<WishlistItem>> getVisibleItems(String ownerId) =>
      throw UnimplementedError();
  @override
  Future<WishlistItem?> getItemById(String itemId) => throw UnimplementedError();
  @override
  Future<WishlistItem> addItem(WishlistItem item) => throw UnimplementedError();
  @override
  Future<WishlistItem> updateItem(WishlistItem item) =>
      throw UnimplementedError();
  @override
  Future<void> setHidden(String itemId, bool hidden) =>
      throw UnimplementedError();
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
  Stream<List<WishlistItem>> watchUserItems(String ownerId) =>
      throw UnimplementedError();
}

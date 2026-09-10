import 'dart:io';

import 'package:core/core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/wishlist_item_model.dart';

class WishlistRemoteDataSource {
  WishlistRemoteDataSource(this._client);
  final SupabaseClient _client;

  Future<List<WishlistItemModel>> fetchMine(String ownerId) async {
    final rows = await _client
        .from(AppConstants.wishlistItemsTable)
        .select()
        .eq('owner_id', ownerId)
        .order('created_at');
    return (rows as List).map((e) => WishlistItemModel.fromJson(e)).toList();
  }

  Future<List<WishlistItemModel>> fetchVisible(String ownerId) async {
    final rows = await _client
        .from(AppConstants.wishlistItemsTable)
        .select()
        .eq('owner_id', ownerId)
        .eq('is_hidden', false)
        .order('created_at');
    return (rows as List).map((e) => WishlistItemModel.fromJson(e)).toList();
  }

  Future<WishlistItemModel?> fetchById(String itemId) async {
    final row = await _client
        .from(AppConstants.wishlistItemsTable)
        .select()
        .eq('id', itemId)
        .maybeSingle();
    if (row == null) return null;
    return WishlistItemModel.fromJson(row);
  }

  Future<WishlistItemModel> insert(WishlistItemModel item) async {
    final row = await _client
        .from(AppConstants.wishlistItemsTable)
        .insert(item.toJson())
        .select()
        .single();
    return WishlistItemModel.fromJson(row);
  }

  Future<WishlistItemModel> update(WishlistItemModel item) async {
    final row = await _client
        .from(AppConstants.wishlistItemsTable)
        .update(item.toUpdateJson())
        .eq('id', item.id)
        .select()
        .single();
    return WishlistItemModel.fromJson(row);
  }

  Future<void> delete(String itemId) async {
    await _client.from(AppConstants.wishlistItemsTable).delete().eq('id', itemId);
  }

  /// Uploads a device-local image for an item and returns its public URL.
  /// The path is scoped under the owner id so the `avatars` bucket RLS
  /// policy (`foldername(name)[1] == firebase_uid claim`) permits it.
  Future<String> uploadItemImage({
    required String ownerId,
    required String itemId,
    required String filePath,
  }) async {
    final ext = safeFileExtension(filePath);
    final fileName = '${DateTime.now().microsecondsSinceEpoch}.$ext';
    final storagePath = '$ownerId/items/$itemId/$fileName';
    await _client.storage
        .from(AppConstants.avatarsBucket)
        .upload(
          storagePath,
          File(filePath),
          fileOptions: const FileOptions(upsert: true),
        );
    return _client.storage
        .from(AppConstants.avatarsBucket)
        .getPublicUrl(storagePath);
  }

  /// Best-effort removal of an uploaded image by its public URL. No-op for
  /// non-bucket URLs (e.g. legacy entries) so cleanup never fails a delete.
  Future<void> deleteImageByUrl(String imageUrl) async {
    final marker = '/${AppConstants.avatarsBucket}/';
    final idx = imageUrl.indexOf(marker);
    if (idx < 0) return;
    final path = imageUrl.substring(idx + marker.length).split('?').first;
    if (path.isEmpty) return;
    await _client.storage.from(AppConstants.avatarsBucket).remove([path]);
  }

  Future<void> subscribe(String subscriberId, String targetUserId) =>
      _client.from(AppConstants.subscriptionsTable).upsert({
        'subscriber_id': subscriberId,
        'target_user_id': targetUserId,
      });

  Future<void> unsubscribe(String subscriberId, String targetUserId) =>
      _client
          .from(AppConstants.subscriptionsTable)
          .delete()
          .eq('subscriber_id', subscriberId)
          .eq('target_user_id', targetUserId);
}

import 'package:core/core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Uploads chat photos to Supabase Storage (the `avatars` bucket, scoped
/// under the sender id to satisfy the bucket RLS policy) and returns a
/// public URL. Using Supabase instead of Firebase Storage avoids a new
/// native dependency; the chat package already depends on supabase_flutter.
class ChatPhotoStorage {
  ChatPhotoStorage(this._client);
  final SupabaseClient _client;

  Future<String> upload({
    required String senderId,
    required String chatId,
    required String filePath,
  }) => uploadToBucket(
    _client,
    bucket: AppConstants.avatarsBucket,
    path: '$senderId/chat/$chatId/${storageFileName(filePath)}',
    filePath: filePath,
  );
}

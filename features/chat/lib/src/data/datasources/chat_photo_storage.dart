import 'dart:io';

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
  }) async {
    final ext = safeFileExtension(filePath);
    final fileName = '${DateTime.now().microsecondsSinceEpoch}.$ext';
    final storagePath = '$senderId/chat/$chatId/$fileName';
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
}

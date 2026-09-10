import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../utils/storage_paths.dart';

/// Uploads a local file to Supabase Storage and returns its public URL.
/// Filename convention (`microsecondsSinceEpoch.ext`) avoids collisions.
Future<String> uploadToBucket(
  SupabaseClient client, {
  required String bucket,
  required String path,
  required String filePath,
}) async {
  await client.storage.from(bucket).upload(
    path,
    File(filePath),
    fileOptions: const FileOptions(upsert: true),
  );
  return publicUrl(client, bucket: bucket, path: path);
}

/// Public URL for an already-uploaded storage [path].
String publicUrl(
  SupabaseClient client, {
  required String bucket,
  required String path,
}) => client.storage.from(bucket).getPublicUrl(path);

/// Collision-free filename preserving the source extension
/// (falls back to `jpg` via [safeFileExtension]).
String storageFileName(String filePath) =>
    '${DateTime.now().microsecondsSinceEpoch}.${safeFileExtension(filePath)}';

/// Best-effort removal of uploaded objects by their public URLs. Non-bucket
/// URLs are skipped; failures never propagate so cleanup can't fail the
/// user-facing operation.
Future<void> removeByUrls(
  SupabaseClient client, {
  required String bucket,
  required Iterable<String> imageUrls,
}) async {
  for (final url in imageUrls) {
    final marker = '/$bucket/';
    final idx = url.indexOf(marker);
    if (idx < 0) continue;
    final path = url.substring(idx + marker.length).split('?').first;
    if (path.isEmpty) continue;
    try {
      await client.storage.from(bucket).remove([path]);
    } catch (_) {
      // Cleanup must never fail the user-facing operation.
    }
  }
}

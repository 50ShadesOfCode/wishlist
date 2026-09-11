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

/// Deterministic filename for retry-safe uploads: the same [seed] (e.g. the
/// op or entity id) always yields the same name, so a retried upload
/// overwrites (`upsert: true`) instead of orphaning a duplicate object.
/// Uses FNV-1a (stable across restarts, unlike [Object.hashCode]).
String stableStorageFileName(String seed, String filePath) =>
    '${fnv1a32('$seed:${_baseName(filePath)}')}.${safeFileExtension(filePath)}';

/// FNV-1a 32-bit hash, hex-encoded. Stable across processes/restarts.
String fnv1a32(String input) {
  var hash = 0x811c9dc5;
  for (final unit in input.codeUnits) {
    hash ^= unit;
    hash = (hash * 0x01000193) & 0xffffffff;
  }
  return hash.toRadixString(16).padLeft(8, '0');
}

String _baseName(String filePath) {
  final idx = filePath.lastIndexOf('/');
  return idx < 0 ? filePath : filePath.substring(idx + 1);
}

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

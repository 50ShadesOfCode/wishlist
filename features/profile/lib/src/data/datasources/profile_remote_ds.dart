import 'dart:io';

import 'package:core/core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/profile_model.dart';

class ProfileRemoteDataSource {
  ProfileRemoteDataSource(this._client);
  final SupabaseClient _client;

  Future<ProfileModel?> getProfile(String userId) async {
    final row = await _client
        .from(AppConstants.profilesTable)
        .select()
        .eq('user_id', userId)
        .maybeSingle();
    if (row == null) return null;
    return ProfileModel.fromJson(row);
  }

  Future<ProfileModel> upsertProfile(ProfileModel profile) async {
    final row = await _client
        .from(AppConstants.profilesTable)
        .upsert(profile.toJson())
        .select()
        .single();
    return ProfileModel.fromJson(row);
  }

  Future<String> uploadAvatar(String userId, String filePath) async {
    final ext = safeFileExtension(filePath);
    final storagePath = '$userId/avatar.$ext';
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

  Future<void> deleteProfile(String userId) async {
    await _client
        .from(AppConstants.profilesTable)
        .delete()
        .eq('user_id', userId);
  }
}

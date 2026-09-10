/// Returns a safe lowercase file extension for a local path, defaulting to
/// `jpg` for extensionless paths, dotfiles, trailing dots, or suspicious
/// values. Supabase Storage needs a sane extension for content-type hints.
String safeFileExtension(String filePath) {
  final dot = filePath.lastIndexOf('.');
  var ext = dot >= 0 ? filePath.substring(dot + 1).toLowerCase() : '';
  if (ext.isEmpty || ext.length > 5 || ext.contains('/')) ext = 'jpg';
  return ext;
}

/// True for already-uploaded remote URLs; anything else is treated as a
/// device-local path that must be uploaded before persisting.
bool isRemoteUrl(String value) =>
    value.startsWith('http://') || value.startsWith('https://');

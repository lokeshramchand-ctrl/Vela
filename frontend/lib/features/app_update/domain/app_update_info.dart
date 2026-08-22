/// Metadata for the latest published build - mirrors backend's
/// AppReleaseResponse (models/schemas.py). Hand-written (no freezed/codegen)
/// since it's a flat, read-only DTO with a single call site.
class AppUpdateInfo {
  const AppUpdateInfo({
    required this.versionCode,
    required this.versionName,
    required this.releaseNotes,
    required this.minSupportedVersionCode,
    required this.sha256,
    required this.sizeBytes,
    required this.downloadUrl,
  });

  final int versionCode;
  final String versionName;
  final String releaseNotes;
  final int? minSupportedVersionCode;
  final String sha256;
  final int sizeBytes;
  final String downloadUrl;

  factory AppUpdateInfo.fromJson(Map<String, dynamic> json) => AppUpdateInfo(
        versionCode: json['version_code'] as int,
        versionName: json['version_name'] as String,
        releaseNotes: (json['release_notes'] as String?) ?? '',
        minSupportedVersionCode: json['min_supported_version_code'] as int?,
        sha256: json['sha256'] as String,
        sizeBytes: json['size_bytes'] as int,
        downloadUrl: json['download_url'] as String,
      );
}

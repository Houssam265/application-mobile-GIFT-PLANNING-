import 'dart:typed_data';

import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// The three public buckets created in Supabase Storage.
enum StorageBucket {
  avatars,
  products,
  covers,
  listCovers,
}

extension StorageBucketName on StorageBucket {
  /// The exact bucket name as created in Supabase.
  String get name {
    switch (this) {
      case StorageBucket.avatars:
        return 'avatars';
      case StorageBucket.products:
        return 'products';
      case StorageBucket.covers:
        return 'covers';
      case StorageBucket.listCovers:
        return 'list-covers';
    }
  }
}

/// Centralised upload service for all Supabase Storage interactions.
///
/// Usage:
/// ```dart
/// final url = await StorageService().upload(
///   bucket : StorageBucket.products,
///   bytes  : imageBytes,
///   fileName: 'photo.jpg',
///   folder  : 'user-id-here',   // optional sub-folder
/// );
/// ```
class StorageService {
  final SupabaseClient _client = Supabase.instance.client;

  /// Compresses [bytes] to JPEG, uploads to [bucket]/[folder]/[timestamp_fileName],
  /// and returns the permanent public URL.
  ///
  /// - [folder]  : optional sub-folder inside the bucket (e.g. the user's UID).
  ///               If null, the file is placed directly at the bucket root.
  /// - [quality] : JPEG compression quality 0–100 (default 80).
  /// - [upsert]  : if true, an existing file at the same path is overwritten.
  Future<String> upload({
    required StorageBucket bucket,
    required Uint8List bytes,
    required String fileName,
    String? folder,
    int quality = 80,
    bool upsert = false,
  }) async {
    // 1. Compress to JPEG.
    final compressed = await FlutterImageCompress.compressWithList(
      bytes,
      quality: quality,
      format: CompressFormat.jpeg,
    );

    // 2. Build a collision-proof storage path.
    final safeName = fileName
        .replaceAll(' ', '_')
        .replaceAll(RegExp(r'[^a-zA-Z0-9._\-]'), '');
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final path = folder != null
        ? '$folder/${timestamp}_$safeName'
        : '${timestamp}_$safeName';

    // 3. Upload.
    await _client.storage.from(bucket.name).uploadBinary(
          path,
          compressed,
          fileOptions: FileOptions(
            contentType: 'image/jpeg',
            upsert: upsert,
          ),
        );

    // 4. Return the permanent public URL.
    return _client.storage.from(bucket.name).getPublicUrl(path);
  }

  /// Deletes a file from [bucket] given its full storage [path]
  /// (the part after the bucket name in the URL).
  ///
  /// Safe to call even if the file does not exist.
  Future<void> delete({
    required StorageBucket bucket,
    required String path,
  }) async {
    await _client.storage.from(bucket.name).remove([path]);
  }

  /// Extracts the storage path from a full Supabase public URL so you can
  /// pass it directly to [delete].
  ///
  /// Example:
  /// ```
  /// https://xxx.supabase.co/storage/v1/object/public/products/uid/ts_photo.jpg
  ///                                                           ^^^^^^^^^^^^^^^^^
  ///                                                           returned path
  /// ```
  static String pathFromUrl(String publicUrl, StorageBucket bucket) {
    final marker = '/object/public/${bucket.name}/';
    final idx = publicUrl.indexOf(marker);
    if (idx == -1) return publicUrl;
    return publicUrl.substring(idx + marker.length);
  }
}

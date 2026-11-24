import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

/// Abstract media storage interface for challenge evidence and voice notes.
abstract class MediaStorageService {
  /// Returns a durable media ID (UUID), never a short-lived download URL.
  Future<String> uploadEvidence({
    required String roomId,
    required String challengeInstanceId,
    required Uint8List bytes,
    required String fileName,
    required String contentType,
    int? durationMs,
  });

  Future<String> getSignedDownloadUrl(String mediaId);
}

/// Supabase Storage implementation using pre-signed private upload and short-lived download URLs.
class SupabaseMediaStorageService implements MediaStorageService {
  SupabaseMediaStorageService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  @override
  Future<String> uploadEvidence({
    required String roomId,
    required String challengeInstanceId,
    required Uint8List bytes,
    required String fileName,
    required String contentType,
    int? durationMs,
  }) async {
    final isVoice = contentType.startsWith('audio/');
    final kind = isVoice ? 'voice' : 'image';

    // 1. Request a short-lived signed upload URL from the Edge Function
    final uploadInit = await _client.functions.invoke(
      'media',
      body: {
        'action': 'getUploadUrl',
        'roomId': roomId,
        'fileName': fileName,
        'kind': kind,
        'mimeType': contentType,
        'sizeBytes': bytes.length,
        if (durationMs != null) 'durationMs': durationMs,
        'challengeInstanceId': challengeInstanceId,
      },
    );

    if (uploadInit.status != 200) {
      throw StateError('فشل الحصول على رابط الرفع: ${uploadInit.data}');
    }

    final initData = Map<String, dynamic>.from(uploadInit.data as Map);
    final uploadUrl = initData['uploadUrl'] as String;
    final path = initData['path'] as String;

    // 2. Upload binary payload via HTTP PUT
    final putResponse = await http.put(
      Uri.parse(uploadUrl),
      headers: {'Content-Type': contentType},
      body: bytes,
    );

    if (putResponse.statusCode < 200 || putResponse.statusCode >= 300) {
      throw StateError('فشل رفع الملف إلى السيرفر (${putResponse.statusCode})');
    }

    // 3. Confirm attachment in database via server RPC
    final attachRes = await _client.functions.invoke(
      'media',
      body: {
        'action': 'attachMedia',
        'roomId': roomId,
        'path': path,
        'kind': kind,
        'mimeType': contentType,
        'sizeBytes': bytes.length,
        if (durationMs != null) 'durationMs': durationMs,
        'challengeInstanceId': challengeInstanceId,
      },
    );

    if (attachRes.status != 200) {
      throw StateError('فشل توثيق الملف في القعدة: ${attachRes.data}');
    }

    final attachData = Map<String, dynamic>.from(attachRes.data as Map);
    final mediaId = attachData['mediaId'] as String;

    // 4. Store/reference the durable media ID in chat and challenge records.
    // Signed URLs expire quickly and must only be fetched when displaying media.
    return mediaId;
  }

  @override
  Future<String> getSignedDownloadUrl(String mediaId) async {
    final res = await _client.functions.invoke(
      'media',
      body: {
        'action': 'getDownloadUrl',
        'mediaId': mediaId,
      },
    );

    if (res.status != 200) {
      throw StateError('فشل جلب رابط الملف: ${res.data}');
    }

    final data = Map<String, dynamic>.from(res.data as Map);
    return data['signedUrl'] as String;
  }
}

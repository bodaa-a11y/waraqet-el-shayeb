import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:image_picker/image_picker.dart';
import '../../../localization/ar_eg_strings.dart';
import '../../../theme/shayeb_theme.dart';
import '../../game/application/game_controller.dart';
import '../../../shayeb_game_bridge.dart';

class RoomChatSheet extends ConsumerStatefulWidget {
  const RoomChatSheet({super.key});

  @override
  ConsumerState<RoomChatSheet> createState() => _RoomChatSheetState();
}

class _RoomChatSheetState extends ConsumerState<RoomChatSheet> {
  final TextEditingController _textController = TextEditingController();
  bool _isUploadingImage = false;

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  void _send() {
    final text = _textController.text.trim();
    if (text.isEmpty) return;
    _textController.clear();
    ref.read(activeGameSessionProvider.notifier).sendChatMessage(text);
  }

  Future<void> _pickAndSendImage() async {
    if (_isUploadingImage) return;
    setState(() => _isUploadingImage = true);
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1280,
        maxHeight: 1280,
        imageQuality: 82,
      );
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      final mime = ActiveGameSessionController.inferImageMimeType(picked.name);
      await ref.read(activeGameSessionProvider.notifier).uploadRoomImage(
            bytes: bytes,
            fileName: picked.name,
            contentType: mime,
          );
    } finally {
      if (mounted) setState(() => _isUploadingImage = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(activeGameSessionProvider);
    final profile = ref.watch(playerProfileProvider);
    final messages = session.messages;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        height: MediaQuery.of(context).size.height * 0.72,
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 14,
          bottom: MediaQuery.of(context).viewInsets.bottom + 14,
        ),
        decoration: const BoxDecoration(
          color: ShayebColors.primaryDarkGreen,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          border: Border(
            top: BorderSide(color: ShayebColors.goldenAccent, width: 2),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Text(
                  ArEgStrings.roomChatTitle,
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                    color: ShayebColors.goldenAccent,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded, color: ShayebColors.cream),
                ),
              ],
            ),
            const Divider(color: Colors.white24),
            Expanded(
              child: messages.isEmpty
                  ? const Center(
                      child: Text(
                        'ابعت أول رسالة لشلتك في القعدة! ☕',
                        style: TextStyle(color: Colors.white60),
                      ),
                    )
                  : ListView.separated(
                      itemCount: messages.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, idx) {
                        final msg = messages[idx];
                        if (msg.isSystem) {
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black26,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '☕ ${msg.text}',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: ShayebColors.softGold,
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          );
                        }

                        final isMe = msg.senderUid == profile.uid;
                        final emoji =
                            ArEgStrings.avatars[msg.senderAvatar]?['emoji'] ?? '🧔🏻‍♂️';

                        return Align(
                          alignment: isMe
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: Container(
                            constraints: const BoxConstraints(maxWidth: 320),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: isMe
                                  ? ShayebColors.warmWoodBrown
                                  : ShayebColors.deepTableGreen,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isMe
                                    ? ShayebColors.goldenAccent
                                    : Colors.white24,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '$emoji ${msg.senderNickname}',
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w800,
                                    color: ShayebColors.softGold,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  msg.text,
                                  style: const TextStyle(
                                    color: ShayebColors.cardWhite,
                                    fontSize: 14.5,
                                  ),
                                ),
                                if (msg.mediaId != null && msg.mediaId!.isNotEmpty)
                                  _PrivateMediaPreview(
                                    key: ValueKey(msg.mediaId),
                                    mediaId: msg.mediaId!,
                                    bridge: ref
                                        .read(activeGameSessionProvider.notifier)
                                        .bridge,
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
            const SizedBox(height: 8),
            // Quick reaction strip inside chat
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: ArEgStrings.quickReactions.map((emoji) {
                  return IconButton(
                    onPressed: () {
                      ref
                          .read(activeGameSessionProvider.notifier)
                          .sendChatMessage(emoji, type: 'reaction');
                    },
                    icon: Text(emoji, style: const TextStyle(fontSize: 22)),
                  );
                }).toList(),
              ),
            ),
            Row(
              children: [
                if (session.isOnlineFirebase && session.room != null) ...[
                  IconButton(
                    tooltip: 'بعت صورة (حتى ٢ ميجا)',
                    onPressed: _isUploadingImage ? null : _pickAndSendImage,
                    icon: _isUploadingImage
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(
                            Icons.photo_camera_back_outlined,
                            color: ShayebColors.goldenAccent,
                          ),
                  ),
                  const SizedBox(width: 4),
                ],
                Expanded(
                  child: TextField(
                    controller: _textController,
                    maxLength: 300,
                    onSubmitted: (_) => _send(),
                    decoration: const InputDecoration(
                      counterText: '',
                      hintText: ArEgStrings.chatInputHint,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _send,
                  child: const Text(ArEgStrings.sendBtn),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Fetches an authorized 60-second URL on demand, not from a public DB field.
/// A private voice/image stays private even if the chat message is shared.
class _PrivateMediaPreview extends StatefulWidget {
  const _PrivateMediaPreview({
    super.key,
    required this.mediaId,
    this.bridge,
  });
  final String mediaId;
  final ShayebGameBridge? bridge;

  @override
  State<_PrivateMediaPreview> createState() => _PrivateMediaPreviewState();
}

class _PrivateMediaPreviewState extends State<_PrivateMediaPreview> {
  bool _loading = false;
  String? _signedUrl;
  String? _kind;
  String? _error;
  AudioPlayer? _audio;

  Future<void> _open() async {
    if (_loading) return;
    setState(() { _loading = true; _error = null; });
    try {
      // Fetch a new URL each time: previous ones can expire after 60 seconds.
      final info = await (widget.bridge ?? ShayebGameBridge())
          .getPrivateMediaDownload(widget.mediaId);
      final signedUrl = info['signedUrl']?.toString() ?? '';
      final kind = info['kind']?.toString() ?? '';
      if (signedUrl.isEmpty || (kind != 'image' && kind != 'voice')) {
        throw StateError('نوع الملف غير معروف');
      }
      if (!mounted) return;
      setState(() { _signedUrl = signedUrl; _kind = kind; });
      if (kind == 'voice') {
        _audio ??= AudioPlayer();
        await _audio!.stop();
        await _audio!.play(UrlSource(signedUrl));
      }
    } catch (_) {
      if (mounted) setState(() => _error = 'تعذر فتح الملف، جرّب تاني');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _audio?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          OutlinedButton.icon(
            onPressed: _loading ? null : _open,
            icon: Icon(_kind == 'voice' ? Icons.play_arrow_rounded : Icons.image_outlined),
            label: Text(_loading ? 'جاري فتح الملف...' : (_kind == 'voice' ? 'تشغيل الفويس' : 'عرض الملف الخاص')),
          ),
          if (_error != null)
            Text(_error!, style: const TextStyle(color: Colors.orangeAccent)),
          if (_signedUrl != null && _kind == 'image')
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 180, maxWidth: 250),
              child: Image.network(
                _signedUrl!,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Text('انتهت صلاحية الرابط، اضغط عرض الملف مرة تانية'),
              ),
            ),
        ],
      ),
    );
  }
}

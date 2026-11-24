import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';

const read = (path) => readFileSync(new URL(path, import.meta.url), 'utf8');
const sql = read('../migrations/20260101000007_predeploy_media_and_challenge_fixes.sql');
const media = read('../functions/media/index.ts');
const game = read('../functions/game/index.ts');
const dartMedia = read('../../lib/core/media/media_storage_service.dart');
const bridge = read('../../lib/shayeb_game_bridge.dart');
const chat = read('../../lib/features/chat/presentation/room_chat_sheet.dart');

test('uploads reject oversized files and long audio before a signed URL is issued', () => {
  assert.match(media, /Number\.isSafeInteger\(sizeBytes\)/);
  assert.match(media, /sizeBytes > maxBytes/);
  assert.match(media, /durationMs > 30000/);
  assert.match(media, /createSignedUploadUrl\(storagePath\)/);
  assert.ok(media.indexOf('durationMs > 30000') < media.indexOf('createSignedUploadUrl'));
});

test('signed download URLs are not persisted as attachment identifiers', () => {
  assert.match(dartMedia, /return mediaId;/);
  assert.doesNotMatch(dartMedia, /return getSignedDownloadUrl\(mediaId\);/);
  assert.match(bridge, /getPrivateMediaDownload/);
  assert.match(chat, /_PrivateMediaPreview/);
});

test('Storage deletions must succeed before database rows can be marked deleted', () => {
  assert.match(media, /if \(removeErr\)/);
  assert.ok(media.indexOf('if (removeErr)') < media.indexOf('rpc_mark_media_deleted'));
  assert.match(media, /if \(markErr\)/);
});

test('SQL verifies file MIME and bucket with real Storage metadata', () => {
  assert.match(sql, /v_real_mime is distinct from v_mime/);
  assert.match(sql, /v_bucket <> 'shayeb-media'/);
  assert.match(sql, /metadata->>''mimetype''/);
});

test('disabled challenge mode cannot be bypassed with the assign-challenge RPC', () => {
  assert.match(sql, /r\.challenge_mode = 'disabled'/);
  assert.match(sql, /r\.challenge_mode = 'end_of_match' and r\.status <> 'finished'/);
  assert.match(sql, /if a\.loser_id <> v_uid then/);
});

test('SQL does not immediately remove media just because a room was closed', () => {
  const cleanupSql = sql.slice(sql.indexOf('create or replace function public.rpc_list_expired_media'), sql.indexOf('create or replace function public.rpc_assign_challenge'));
  assert.match(cleanupSql, /expires_at <= now\(\)/);
  assert.doesNotMatch(cleanupSql, /status = 'closed'/);
});

test('internal SQL diagnostic text is not sent verbatim to users', () => {
  assert.match(game, /e\?\.code === "SH001"/);
  assert.match(game, /console\.error\("game action failed"/);
  assert.match(game, /code: "internal_error"/);
});

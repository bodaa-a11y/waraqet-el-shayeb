import { handleCors, jsonResponse, errorResponse } from "../_shared/cors.ts";
import { getAdminClient, getCallerUid } from "../_shared/client.ts";

const BUCKET_NAME = "shayeb-media";

function parseMediaError(err: unknown): { message: string; code: string; status: number } {
  const e = err as { code?: string; hint?: string; message?: string } | null;
  const raw = typeof e?.message === "string" ? e.message : "";
  const knownHints = new Set([
    "unauthenticated", "forbidden", "not_found", "conflict", "invalid", "rate_limited",
  ]);
  if (e?.code === "SH001" && typeof e.hint === "string" && knownHints.has(e.hint)) {
    const statusMap: Record<string, number> = {
      unauthenticated: 401, forbidden: 403, not_found: 404,
      conflict: 409, invalid: 400, rate_limited: 429,
    };
    return { message: raw || "تعذر تنفيذ العملية", code: e.hint, status: statusMap[e.hint] };
  }
  if (raw.includes("unauthenticated")) {
    return { message: "لازم تسجل دخول الأول", code: "unauthenticated", status: 401 };
  }
  console.error("media action failed", e);
  return { message: "حصلت مشكلة في السيرفر، جرّب تاني", code: "internal_error", status: 500 };
}

Deno.serve(async (req: Request) => {
  const corsRes = handleCors(req);
  if (corsRes) return corsRes;

  if (req.method !== "POST") {
    return errorResponse("طريقة الطلب غير مسموحة", "method_not_allowed", 405);
  }

  try {
    const adminClient = getAdminClient();
    const body = await req.json().catch(() => ({}));
    const action = String(body.action || "").trim();

    let uid = "";
    if (action === "cleanupExpired") {
      const expectedSecret = Deno.env.get("CLEANUP_CRON_SECRET");
      if (!expectedSecret || req.headers.get("x-cron-secret") !== expectedSecret) {
        return errorResponse("غير مصرح بتشغيل التنظيف", "forbidden", 403);
      }
    } else {
      uid = await getCallerUid(req, adminClient);
    }

    switch (action) {
      // ----------------------------------------------------------------------
      // 1. getUploadUrl: creates single-use signed upload URL for client
      // ----------------------------------------------------------------------
      case "getUploadUrl": {
        const roomId = String(body.roomId || "");
        const kind = String(body.kind || ""); // "image" | "voice"
        const mimeType = String(body.mimeType || "");
        const EXT_BY_MIME: Record<string, string> = {
          "image/webp": "webp", "image/jpeg": "jpg", "image/png": "png",
          "audio/ogg": "ogg", "audio/webm": "webm", "audio/mp4": "m4a",
          "audio/aac": "aac", "audio/mpeg": "mp3",
        };
        const ext = EXT_BY_MIME[mimeType];

        const sizeBytes = Number(body.sizeBytes);
        const durationMs = Number(body.durationMs);
        const maxBytes = kind === "voice" ? 1048576 : 2097152;
        if (!Number.isSafeInteger(sizeBytes) || sizeBytes < 1 || sizeBytes > maxBytes) {
          return errorResponse("حجم الملف غير مسموح", "invalid_argument", 400);
        }
        if (kind === "voice" &&
            (!Number.isSafeInteger(durationMs) || durationMs < 1 || durationMs > 30000)) {
          return errorResponse("الفويس لازم يكون أقل من ٣٠ ثانية", "invalid_argument", 400);
        }

        if (!roomId || (kind !== "image" && kind !== "voice") || !ext) {
          return errorResponse("معرّف القعدة ونوع الملف مطلوبان", "invalid_argument", 400);
        }
        if ((kind === "image") !== mimeType.startsWith("image/")) {
          return errorResponse("صيغة الملف غير مدعومة", "invalid_argument", 400);
        }

        // Verify room membership first (service role → explicit uid check)
        const { data: member, error: memErr } = await adminClient
          .from("room_players")
          .select("user_id")
          .eq("room_id", roomId)
          .eq("user_id", uid)
          .maybeSingle();
        if (memErr || !member) {
          return errorResponse("إنت مش عضو في القعدة دي", "forbidden", 403);
        }

        const { data: room } = await adminClient.from("rooms")
          .select("status, expires_at").eq("id", roomId).maybeSingle();
        if (!room || room.status === "closed" || new Date(room.expires_at).getTime() <= Date.now()) {
          return errorResponse("القعدة دي انتهت ومش متاح رفع ملفات", "conflict", 409);
        }

        const fileId = crypto.randomUUID();
        const storagePath = `${roomId}/${uid}/${fileId}.${ext}`;

        const { data: uploadData, error: uploadErr } = await adminClient.storage
          .from(BUCKET_NAME)
          .createSignedUploadUrl(storagePath);

        if (uploadErr || !uploadData) {
          return errorResponse("تعذر إنشاء رابط الرفع، تأكد من إعدادات الـ Storage", "storage_error", 500);
        }

        return jsonResponse({
          uploadUrl: uploadData.signedUrl,
          token: uploadData.token,
          path: storagePath,
          bucket: BUCKET_NAME,
        });
      }

      // ----------------------------------------------------------------------
      // 2. attachMedia: verifies uploaded file and commits to postgres & chat
      // ----------------------------------------------------------------------
      case "attachMedia": {
        const { data, error } = await adminClient.rpc("rpc_attach_media", {
          p: { ...body, uid, bucket: BUCKET_NAME },
        });
        if (error) throw error;
        return jsonResponse(data);
      }

      // ----------------------------------------------------------------------
      // 3. getDownloadUrl: creates short-lived (60s) signed download URL
      // ----------------------------------------------------------------------
      case "getDownloadUrl": {
        const mediaId = String(body.mediaId || "");
        if (!mediaId) {
          return errorResponse("معرّف الملف مطلوب", "invalid_argument", 400);
        }

        const { data: mediaInfo, error: signErr } = await adminClient.rpc("rpc_media_for_signing", {
          p: { uid, mediaId },
        });
        if (signErr || !mediaInfo) {
          return errorResponse("الملف غير متاح أو ليس لديك إذن الوصول", "forbidden", 403);
        }

        const { data: signedData, error: dlErr } = await adminClient.storage
          .from(mediaInfo.bucket)
          .createSignedUrl(mediaInfo.path, 60);

        if (dlErr || !signedData) {
          return errorResponse("تعذر إنشاء رابط التحميل", "storage_error", 500);
        }

        return jsonResponse({
          signedUrl: signedData.signedUrl,
          mimeType: mediaInfo.mimeType,
          kind: mediaInfo.kind,
        });
      }

      // ----------------------------------------------------------------------
      // 4. cleanupExpired: removes files older than 7 days from Storage
      // ----------------------------------------------------------------------
      case "cleanupExpired": {
        const { data: expiredList, error: listErr } = await adminClient.rpc("rpc_list_expired_media", {
          p: {},
        });
        if (listErr || !Array.isArray(expiredList) || expiredList.length === 0) {
          return jsonResponse({ deletedCount: 0 });
        }

        const paths = expiredList.map((item: { path: string }) => item.path);
        const ids = expiredList.map((item: { id: string }) => item.id);

        const { error: removeErr } = await adminClient.storage.from(BUCKET_NAME).remove(paths);
        if (removeErr) {
          // Never mark database rows deleted if Storage removal failed.
          return errorResponse("حذف الملفات لم يكتمل، سيتم إعادة المحاولة", "storage_error", 503);
        }
        const { data: markRes, error: markErr } = await adminClient.rpc("rpc_mark_media_deleted", {
          p: { ids },
        });
        if (markErr) {
          return errorResponse("تم حذف الملفات لكن تعذّر تحديث السجلات؛ أعد المحاولة", "database_error", 503);
        }
        return jsonResponse({ deletedCount: markRes?.deleted ?? paths.length });
      }

      default:
        return errorResponse(`العملية «${action}» غير معروفة`, "unknown_action", 400);
    }
  } catch (err) {
    const { message, code, status } = parseMediaError(err);
    return errorResponse(message, code, status);
  }
});

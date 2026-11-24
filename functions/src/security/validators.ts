import { HttpsError } from "firebase-functions/v2/https";

const FORBIDDEN_NICKNAMES = new Set(["النظام", "سيستم", "system", "admin", "أدمن", "المشرف"]);

export function requireUser(auth: { uid: string } | undefined): string {
  if (!auth?.uid) {
    throw new HttpsError("unauthenticated", "لازم تسجل دخول الأول عشان تلعب");
  }
  return auth.uid;
}

export function asRecord(value: unknown): Record<string, unknown> {
  if (typeof value !== "object" || value === null || Array.isArray(value)) {
    throw new HttpsError("invalid-argument", "بيانات الطلب مش مظبوطة");
  }
  return value as Record<string, unknown>;
}

export function requiredString(value: unknown, label: string, max = 100): string {
  if (typeof value !== "string" || value.trim().length < 1 || value.trim().length > max) {
    throw new HttpsError("invalid-argument", `قيمة ${label} غير صالحة`);
  }
  return value.trim();
}

export function validateNickname(raw: unknown): string {
  const name = requiredString(raw, "nickname", 24).replace(/[<>]/g, "").trim();
  if (name.length < 2) {
    throw new HttpsError("invalid-argument", "الاسم لازم يكون حرفين على الأقل");
  }
  if (FORBIDDEN_NICKNAMES.has(name.toLowerCase())) {
    throw new HttpsError("invalid-argument", "الاسم ده محجوز للنظام، اختار اسم تاني يا معلم");
  }
  return name;
}

export function sanitizeChatText(raw: unknown, maxLength = 300): string {
  const text = requiredString(raw, "text", maxLength).replace(/[<>]/g, "").trim();
  if (text.length < 1) {
    throw new HttpsError("invalid-argument", "الرسالة فاضية");
  }
  return text;
}

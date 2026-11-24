import { type RandomInt, secureRandomInt } from "./shuffle.ts";

export type ChallengeCategory =
  | "acting"
  | "voice"
  | "poetry"
  | "comedy"
  | "in_game"
  | "group"
  | "text"
  | "action"
  | "creative"
  | "photo";

export type ChallengeProofType =
  | "none"
  | "text"
  | "voice"
  | "image"
  | "in_game"
  | "optional";

export interface ChallengeDefinition {
  readonly id: string;
  readonly title: string;
  readonly description: string;
  readonly category: ChallengeCategory;
  readonly proofType: ChallengeProofType;
  readonly estimatedDurationSeconds: number;
  readonly enabled: boolean;
  readonly createdAt?: string;
}

export type Challenge = ChallengeDefinition;

/**
 * 30 Authentic Egyptian Colloquial Arabic Challenges ("الأحكام")
 */
export const EGYPTIAN_CHALLENGES: readonly ChallengeDefinition[] = [
  {
    id: "ch_01",
    title: "نشرة أخبار الهزيمة",
    description: "قدّم نشرة أخبار درامية بصوت مذيع جاد جداً تعلن فيها خبر خسارتك الفادحة ولبسك للشايب قدام كل الموجودين!",
    category: "acting",
    proofType: "voice",
    estimatedDurationSeconds: 25,
    enabled: true,
    createdAt: "2026-01-01T00:00:00Z",
  },
  {
    id: "ch_02",
    title: "ضحكة الشرير الكبير",
    description: "سجّل ضحكة شريرة مدتها ١٠ ثواني زي أشرار الأفلام القديمة بعد ما الشايب قفل عليك القعدة.",
    category: "voice",
    proofType: "voice",
    estimatedDurationSeconds: 15,
    enabled: true,
    createdAt: "2026-01-01T00:00:00Z",
  },
  {
    id: "ch_03",
    title: "أبوخ نكتة في التاريخ",
    description: "قول أو اكتب أسخف وأبوخ نكتة تعرفها، ولازم تضحك عليها لوحدك في الآخر!",
    category: "comedy",
    proofType: "text",
    estimatedDurationSeconds: 20,
    enabled: true,
    createdAt: "2026-01-01T00:00:00Z",
  },
  {
    id: "ch_04",
    title: "اللقب الملكي للفائز",
    description: "اخترع لقب ملكي فخم ومضحك لأول واحد فلت من الشايب في الجولة دي واكتبه في الشات بكل احترام.",
    category: "group",
    proofType: "text",
    estimatedDurationSeconds: 20,
    enabled: true,
    createdAt: "2026-01-01T00:00:00Z",
  },
  {
    id: "ch_05",
    title: "شاعر القهوة",
    description: "اكتب ٣ أبيات شعر بالمصري العامي تمدح فيهم براعة الكسبان وتتحسر على حظك مع الشايب.",
    category: "poetry",
    proofType: "text",
    estimatedDurationSeconds: 45,
    enabled: true,
    createdAt: "2026-01-01T00:00:00Z",
  },
  {
    id: "ch_06",
    title: "معلّق الكورة المصري",
    description: "قلّد معلق كورة مصري متحمس وهو بيوصف اللحظة التاريخية اللي سحبت فيها الشايب في الدقيقة التسعين!",
    category: "voice",
    proofType: "voice",
    estimatedDurationSeconds: 25,
    enabled: true,
    createdAt: "2026-01-01T00:00:00Z",
  },
  {
    id: "ch_07",
    title: "تبّاع الميكروباص",
    description: "قلّد صوت تبّاع ميكروباص بينادي على خط (رمسيس - الجيزة - موقف الشايب) لمدة ١٥ ثانية!",
    category: "voice",
    proofType: "voice",
    estimatedDurationSeconds: 15,
    enabled: true,
    createdAt: "2026-01-01T00:00:00Z",
  },
  {
    id: "ch_08",
    title: "عمو الحاج على القهوة",
    description: "اتكلم لمدة ٢٠ ثانية بصوت راجل عجوز قاعد على القهوة بيلوم الجيل الجديد إنه مش بيعرف يلعب كوتشينة.",
    category: "acting",
    proofType: "voice",
    estimatedDurationSeconds: 20,
    enabled: true,
    createdAt: "2026-01-01T00:00:00Z",
  },
  {
    id: "ch_09",
    title: "قصة حب مع الكشري",
    description: "ابعت ريكورد صوتي بتعلن فيه حبك الدرامي لطبق كشري بالدقة والتقلية كأنه مشهد سينمائي مؤثر.",
    category: "voice",
    proofType: "voice",
    estimatedDurationSeconds: 20,
    enabled: true,
    createdAt: "2026-01-01T00:00:00Z",
  },
  {
    id: "ch_10",
    title: "المؤتمر الصحفي للمدرب",
    description: "اشرح أسباب خسارتك كأنك مدير فني لمنتخب الكوتشينة في مؤتمر صحفي وبتحمل المسؤولية للرطوبة والورق!",
    category: "acting",
    proofType: "text",
    estimatedDurationSeconds: 30,
    enabled: true,
    createdAt: "2026-01-01T00:00:00Z",
  },
  {
    id: "ch_11",
    title: "إعلان شاي في الخمسينة",
    description: "اخترع إعلان تلفزيوني مضحك لكوباية شاي على القهوة بتنسّي الواحد صدمة الخسارة في الشايب.",
    category: "comedy",
    proofType: "text",
    estimatedDurationSeconds: 30,
    enabled: true,
    createdAt: "2026-01-01T00:00:00Z",
  },
  {
    id: "ch_12",
    title: "موزّع الألقاب",
    description: "طلع لقب مصري كوميدي لكل لاعب موجود معاك في القعدة واكتبهم كلهم في رسالة واحدة.",
    category: "group",
    proofType: "text",
    estimatedDurationSeconds: 40,
    enabled: true,
    createdAt: "2026-01-01T00:00:00Z",
  },
  {
    id: "ch_13",
    title: "رئيس رابطة الخسرانين",
    description: "عرّف نفسك رسمياً كـ «رئيس رابطة الخسرانين والملبوسين في الشايب» ووجّه كلمة ترحيب للأعضاء.",
    category: "comedy",
    proofType: "text",
    estimatedDurationSeconds: 25,
    enabled: true,
    createdAt: "2026-01-01T00:00:00Z",
  },
  {
    id: "ch_14",
    title: "خمس أصوات في جملة",
    description: "قول جملة «الشايب لبس فيا يا جدعان» بخمس نبرات صوت خيالية ومختلفة ورا بعض!",
    category: "voice",
    proofType: "voice",
    estimatedDurationSeconds: 25,
    enabled: true,
    createdAt: "2026-01-01T00:00:00Z",
  },
  {
    id: "ch_15",
    title: "الملحمة التاريخية للبطل",
    description: "اوصف اللاعب اللي كسب الجولة كأنه بطل تاريخي أسطوري حرر القهوة من بطش الشايب.",
    category: "poetry",
    proofType: "text",
    estimatedDurationSeconds: 30,
    enabled: true,
    createdAt: "2026-01-01T00:00:00Z",
  },
  {
    id: "ch_16",
    title: "مرافعة محامي الكوتشينة",
    description: "اتقمص دور محامي في محكمة وبتترافع عن طريقة لعبك الكارثية قدام القاضي وبتطالب بالبراءة!",
    category: "acting",
    proofType: "text",
    estimatedDurationSeconds: 35,
    enabled: true,
    createdAt: "2026-01-01T00:00:00Z",
  },
  {
    id: "ch_17",
    title: "اعتذار رسمي للورق",
    description: "اكتب بيان اعتذار رسمي ومؤثر لورق الكوتشينة على الأداء اللي قدمته في الجولة دي.",
    category: "comedy",
    proofType: "text",
    estimatedDurationSeconds: 25,
    enabled: true,
    createdAt: "2026-01-01T00:00:00Z",
  },
  {
    id: "ch_18",
    title: "أفيش الفيلم الهندي",
    description: "ألّف اسم فيلم سينمائي درامي مع شعار دعائي يوصف مأساة الجولة اللي خسرتها دي.",
    category: "comedy",
    proofType: "text",
    estimatedDurationSeconds: 20,
    enabled: true,
    createdAt: "2026-01-01T00:00:00Z",
  },
  {
    id: "ch_19",
    title: "مثل شعبي جديد",
    description: "اخترع مثل شعبي مصري جديد عن سوء الحظ واللبس في الشايب بحيث يبان كأنه مثل قديم بجد!",
    category: "poetry",
    proofType: "text",
    estimatedDurationSeconds: 20,
    enabled: true,
    createdAt: "2026-01-01T00:00:00Z",
  },
  {
    id: "ch_20",
    title: "النشرة الجوية لحظك",
    description: "قدّم نشرة جوية بتحذر فيها من عاصفة نحس شديدة وأمطار شايب رعدية على منطقتك في القعدة.",
    category: "acting",
    proofType: "text",
    estimatedDurationSeconds: 25,
    enabled: true,
    createdAt: "2026-01-01T00:00:00Z",
  },
  {
    id: "ch_21",
    title: "لقب شايب المعمورة",
    description: "لقبك في القعدة بقى رسمياً «شايب المعمورة» للجولة الجاية! اكتب في الشات: أنا شايب المعمورة وافتخر!",
    category: "in_game",
    proofType: "in_game",
    estimatedDurationSeconds: 15,
    enabled: true,
    createdAt: "2026-01-01T00:00:00Z",
  },
  {
    id: "ch_22",
    title: "ختم الشايب 👴",
    description: "استخدم إيموجي الراجل العجوز (👴) في أول وآخر رسالتك في الشات ودلّع الشايب!",
    category: "in_game",
    proofType: "in_game",
    estimatedDurationSeconds: 15,
    enabled: true,
    createdAt: "2026-01-01T00:00:00Z",
  },
  {
    id: "ch_23",
    title: "مانشيت الجورنال",
    description: "اكتب مانشيت جورنال عريض ومثير للجدل عن سقوطك المدوي في فخ الشايب النهارده.",
    category: "comedy",
    proofType: "text",
    estimatedDurationSeconds: 20,
    enabled: true,
    createdAt: "2026-01-01T00:00:00Z",
  },
  {
    id: "ch_24",
    title: "خطاب تنمية بشرية للخسرانين",
    description: "سجّل أو اكتب كلمة تحفيزية ساخرة بتواسي بيها كل اللي بيلبسوا في الشايب وتقولهم إزاي يتصالحوا مع الشايب.",
    category: "voice",
    proofType: "voice",
    estimatedDurationSeconds: 25,
    enabled: true,
    createdAt: "2026-01-01T00:00:00Z",
  },
  {
    id: "ch_25",
    title: "أكلة الشايب المخصوص",
    description: "اخترع صنف أكل جديد في منيو مطعم شعبي مستوحى من كارت الشايب واكتب مكوناته وسعره!",
    category: "comedy",
    proofType: "text",
    estimatedDurationSeconds: 25,
    enabled: true,
    createdAt: "2026-01-01T00:00:00Z",
  },
  {
    id: "ch_26",
    title: "قصة مأساوية في ٣ سطور",
    description: "احكي اللي حصل معاك في الجولة دي على شكل قصة حزينة جداً من ٣ سطور بس.",
    category: "poetry",
    proofType: "text",
    estimatedDurationSeconds: 25,
    enabled: true,
    createdAt: "2026-01-01T00:00:00Z",
  },
  {
    id: "ch_27",
    title: "السيرة الذاتية للشايب",
    description: "ألّف سيرة ذاتية كوميدية لكارت الشايب: اسمه بالكامل، شغله القديم، وليه رافض يتجوز أي كارت تاني!",
    category: "comedy",
    proofType: "text",
    estimatedDurationSeconds: 30,
    enabled: true,
    createdAt: "2026-01-01T00:00:00Z",
  },
  {
    id: "ch_28",
    title: "مذيع التوك شو",
    description: "اعمل حوار تلفزيوني سريع مع الفائز في الجولة واسأله سؤالين عن سر الهروب من الشايب.",
    category: "group",
    proofType: "text",
    estimatedDurationSeconds: 30,
    enabled: true,
    createdAt: "2026-01-01T00:00:00Z",
  },
  {
    id: "ch_29",
    title: "٣ حجج خزعبليّة",
    description: "اكتب ٣ أعذار وحجج خيالية ومستحيلة تبرر بيها ليه إنت اللي سحبت الشايب في الآخر.",
    category: "comedy",
    proofType: "text",
    estimatedDurationSeconds: 25,
    enabled: true,
    createdAt: "2026-01-01T00:00:00Z",
  },
  {
    id: "ch_30",
    title: "خطبة الوداع للورق",
    description: "وجّه خطبة وداع درامية لكارت الشايب قبل ما تبدأ الجولة الجديدة واطلب منه يشوف حد غيرك يلبس فيه!",
    category: "acting",
    proofType: "text",
    estimatedDurationSeconds: 25,
    enabled: true,
    createdAt: "2026-01-01T00:00:00Z",
  },
];

/**
 * Archive A `pickChallenge` function:
 * Unbiased pick among enabled challenges, avoiding `recentIds` when possible.
 * Returns `null` if no enabled challenges exist.
 */
export function pickChallenge(
  all: readonly ChallengeDefinition[] = EGYPTIAN_CHALLENGES,
  recentIds: readonly string[] = [],
  rand: RandomInt = secureRandomInt,
): ChallengeDefinition | null {
  const eligible = all.filter((c) => c.enabled);
  if (eligible.length === 0) return null;
  const recentSet = new Set(recentIds);
  const fresh = eligible.filter((c) => !recentSet.has(c.id));
  const pool = fresh.length > 0 ? fresh : eligible;
  return pool[rand(pool.length)]!;
}

/**
 * Throws if no enabled challenges exist; otherwise returns an unbiased non-repeating challenge.
 */
export function selectRandomChallenge(
  excludeIds: readonly string[] = [],
  pool: readonly ChallengeDefinition[] = EGYPTIAN_CHALLENGES,
  rand: RandomInt = secureRandomInt,
): ChallengeDefinition {
  const picked = pickChallenge(pool, excludeIds, rand);
  if (!picked) {
    throw new Error("No enabled challenges available");
  }
  return picked;
}

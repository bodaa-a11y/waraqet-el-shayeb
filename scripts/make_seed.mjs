import fs from "node:fs";

// Read challenges.ts and extract EGYPTIAN_CHALLENGES items via regex or eval
const content = fs.readFileSync("functions/src/engine/challenges.ts", "utf8");

// Parse items: id, title, description, category, proofType, estimatedDurationSeconds, enabled
const itemRegex = /{\s*id:\s*"([^"]+)",\s*title:\s*"([^"]+)",\s*description:\s*"([^"]+)",\s*category:\s*"([^"]+)",\s*proofType:\s*"([^"]+)",\s*estimatedDurationSeconds:\s*(\d+),\s*enabled:\s*(true|false)/g;

const rows = [];
let match;
while ((match = itemRegex.exec(content)) !== null) {
  const [, id, title, description, category, proofType, estSecs, enabled] = match;
  const q = (s) => "'" + s.replace(/'/g, "''") + "'";
  rows.push(`  (${q(id)}, ${q(title)}, ${q(description)}, ${q(category)}, ${q(proofType)}, ${estSecs}, ${enabled})`);
}

console.log(`Parsed ${rows.length} challenges.`);

const sql = `-- Migration 5/6 — the ${rows.length} Egyptian challenges ("دفتر الأحكام")
insert into public.challenges (id, title, description, category, proof_type, estimated_duration_seconds, enabled)
values
${rows.join(",\n")}
on conflict (id) do update set
  title = excluded.title,
  description = excluded.description,
  category = excluded.category,
  proof_type = excluded.proof_type,
  estimated_duration_seconds = excluded.estimated_duration_seconds,
  enabled = excluded.enabled;
`;

fs.writeFileSync("supabase/migrations/20260101000005_seed_challenges.sql", sql, "utf8");
console.log("Successfully wrote supabase/migrations/20260101000005_seed_challenges.sql");

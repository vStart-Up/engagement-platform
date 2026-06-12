-- ═══════════════════════════════════════════════════════════════
--  Migration 001 · Themes & Session Pricing
--  Run in: Supabase Dashboard → SQL Editor → New query
-- ═══════════════════════════════════════════════════════════════

-- ── Themes table ────────────────────────────────────────────────
create table if not exists themes (
  id          text primary key,
  name        text not null,
  description text,
  color       text    default '#6366f1',   -- hex, used for chip/badge colour
  icon        text    default '🎯',
  sort_order  int     default 0,
  created_at  timestamptz default now()
);

alter table themes enable row level security;
create policy "pub_read_themes"  on themes for select using (true);
create policy "admin_themes"     on themes for all    using (auth.role() = 'authenticated');

-- ── Alter topic_options — add theme association ──────────────────
alter table topic_options
  add column if not exists theme_id text references themes(id) on delete set null;

-- ── Alter sessions — add theme tags and pricing ──────────────────
alter table sessions
  add column if not exists theme_ids text[]       default '{}',
  add column if not exists is_paid   boolean      default false,
  add column if not exists price     numeric(10,2) default 0,
  add column if not exists currency  text         default 'USD';

-- ── Seed themes ─────────────────────────────────────────────────
insert into themes (id, name, description, color, icon, sort_order) values
  ('thm-001', 'Architecture & Systems',
   'System design, enterprise architecture, distributed systems, and platform patterns',
   '#6366f1', '🏗', 1),
  ('thm-002', 'AI & Emerging Tech',
   'AI-native systems, machine learning, generative AI, and emerging technology adoption',
   '#8b5cf6', '🤖', 2),
  ('thm-003', 'Engineering Leadership',
   'Leading engineering teams, scaling organisations, and technology strategy',
   '#ec4899', '🧭', 3),
  ('thm-004', 'Platform & DevEx',
   'Internal developer platforms, golden paths, tooling, and developer experience',
   '#06b6d4', '⚙️', 4),
  ('thm-005', 'Security & Compliance',
   'Secure-by-design, GDPR, SOC2, ISO 27001, and compliance-led engineering',
   '#f59e0b', '🔒', 5)
on conflict (id) do nothing;

-- ── Update existing seed topics with themes ──────────────────────
update topic_options set theme_id = 'thm-001' where id = 'top-001';
update topic_options set theme_id = 'thm-004' where id = 'top-002';
update topic_options set theme_id = 'thm-003' where id = 'top-003';
update topic_options set theme_id = 'thm-005' where id = 'top-004';
update topic_options set theme_id = 'thm-003' where id = 'top-005';

-- ── Update existing sessions with themes ─────────────────────────
update sessions set theme_ids = ARRAY['thm-001','thm-002'], is_paid = false where id = 'ses-001';
update sessions set theme_ids = ARRAY['thm-004'],           is_paid = false where id = 'ses-002';
update sessions set theme_ids = ARRAY['thm-003'],           is_paid = false where id = 'ses-003';

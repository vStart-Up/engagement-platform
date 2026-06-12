-- ═══════════════════════════════════════════════════════════════
--  Courseific Sessions · Supabase Schema
--  Run this once in: Supabase Dashboard → SQL Editor → New query
-- ═══════════════════════════════════════════════════════════════

-- Extensions
create extension if not exists "uuid-ossp";

-- ─────────────────────────────────────────────────────────────────
--  TABLES
-- ─────────────────────────────────────────────────────────────────

create table if not exists platform_settings (
  key   text primary key,
  value text not null default ''
);

create table if not exists speakers (
  id         text primary key,
  name       text        not null,
  title      text,
  bio        text,
  avatar     text,
  linkedin   text,
  twitter    text,
  topics     text[],
  created_at timestamptz default now()
);

create table if not exists sessions (
  id               text primary key,
  title            text        not null,
  description      text,
  date             date,
  time             time,
  timezone         text        default 'UTC',
  duration         int         default 60,
  status           text        default 'upcoming',
  meeting_platform text,
  meeting_url      text,
  recording_url    text,
  capacity         int         default 100,
  registered       int         default 0,
  tags             text[],
  speaker_ids      text[],
  created_at       timestamptz default now()
);

create table if not exists topic_options (
  id          text primary key,
  title       text not null,
  description text,
  tags        text[],
  created_at  timestamptz default now()
);

-- Anonymous votes — deduplicated by (topic_id, voter_id)
create table if not exists votes (
  id         uuid primary key default uuid_generate_v4(),
  topic_id   text not null references topic_options(id) on delete cascade,
  voter_id   text not null,                                -- random UUID stored in visitor's localStorage
  created_at timestamptz default now(),
  unique (topic_id, voter_id)
);

create table if not exists registrations (
  id         uuid primary key default uuid_generate_v4(),
  session_id text not null references sessions(id) on delete cascade,
  name       text not null,
  email      text not null,
  org        text,
  role       text,
  created_at timestamptz default now()
);

create table if not exists speaker_applications (
  id           text primary key,
  status       text        default 'pending',   -- pending | approved | rejected
  personal     jsonb,
  session_info jsonb,
  availability jsonb,
  experience   jsonb,
  submitted_at timestamptz default now()
);

-- ─────────────────────────────────────────────────────────────────
--  VIEWS
-- ─────────────────────────────────────────────────────────────────

-- Vote counts per topic (used by the public voting UI)
create or replace view topic_vote_counts as
  select topic_id, count(*)::int as vote_count
  from votes
  group by topic_id;

-- ─────────────────────────────────────────────────────────────────
--  FUNCTIONS & TRIGGERS
-- ─────────────────────────────────────────────────────────────────

-- Keep sessions.registered in sync automatically
create or replace function sync_registered_count()
returns trigger language plpgsql security definer as $$
begin
  update sessions
  set registered = (
    select count(*) from registrations
    where session_id = coalesce(new.session_id, old.session_id)
  )
  where id = coalesce(new.session_id, old.session_id);
  return coalesce(new, old);
end;
$$;

drop trigger if exists trg_registered_insert on registrations;
create trigger trg_registered_insert
  after insert on registrations
  for each row execute function sync_registered_count();

drop trigger if exists trg_registered_delete on registrations;
create trigger trg_registered_delete
  after delete on registrations
  for each row execute function sync_registered_count();

-- ─────────────────────────────────────────────────────────────────
--  ROW LEVEL SECURITY
-- ─────────────────────────────────────────────────────────────────

alter table platform_settings    enable row level security;
alter table speakers             enable row level security;
alter table sessions             enable row level security;
alter table topic_options        enable row level security;
alter table votes                enable row level security;
alter table registrations        enable row level security;
alter table speaker_applications enable row level security;

-- Public (anon) — read content
create policy "pub_read_settings" on platform_settings for select using (true);
create policy "pub_read_speakers" on speakers          for select using (true);
create policy "pub_read_sessions" on sessions          for select using (true);
create policy "pub_read_topics"   on topic_options     for select using (true);
create policy "pub_read_votes"    on votes             for select using (true);

-- Public — community actions
create policy "pub_cast_vote"    on votes                for insert with check (true);
create policy "pub_remove_vote"  on votes                for delete using (true);
create policy "pub_register"     on registrations        for insert with check (true);
create policy "pub_apply"        on speaker_applications for insert with check (true);

-- Authenticated (admin) — full control
create policy "admin_settings"   on platform_settings    for all using (auth.role() = 'authenticated');
create policy "admin_speakers"   on speakers             for all using (auth.role() = 'authenticated');
create policy "admin_sessions"   on sessions             for all using (auth.role() = 'authenticated');
create policy "admin_topics"     on topic_options        for all using (auth.role() = 'authenticated');
create policy "admin_votes"      on votes                for all using (auth.role() = 'authenticated');
create policy "admin_regs"       on registrations        for select using (auth.role() = 'authenticated');
create policy "admin_apps"       on speaker_applications for all using (auth.role() = 'authenticated');

-- ─────────────────────────────────────────────────────────────────
--  SEED DATA
-- ─────────────────────────────────────────────────────────────────

insert into platform_settings (key, value) values
  ('name',          'Courseific Sessions'),
  ('tagline',       'Community-driven learning, globally connected'),
  ('contact_email', 'naveenjonty@gmail.com')
on conflict (key) do nothing;

insert into speakers (id, name, title, bio, avatar, linkedin, topics) values
  ('spk-001', 'Jonty Naveen', 'Technology Leader & Strategist',
   'Two decades at the intersection of Engineering and Strategy. Specialises in systems design, enterprise architecture, and technology-led transformation across global organisations.',
   'https://ui-avatars.com/api/?name=Jonty+Naveen&background=6366f1&color=fff&size=128',
   'https://linkedin.com/in/',
   ARRAY['Systems Architecture','Enterprise Strategy','Technology Leadership']),
  ('spk-002', 'Priya Mehta', 'Head of Platform Engineering',
   '15 years building distributed systems at scale. Passionate about developer experience, platform thinking, and making complex infrastructure invisible to product teams.',
   'https://ui-avatars.com/api/?name=Priya+Mehta&background=8b5cf6&color=fff&size=128',
   'https://linkedin.com/in/',
   ARRAY['Platform Engineering','DevEx','Distributed Systems']),
  ('spk-003', 'Marcus Chen', 'Principal Architect, Cloud & AI',
   'Designs AI-native architectures for Fortune 500 companies. Former engineering lead at two unicorn startups. Adviser on responsible AI adoption at the enterprise level.',
   'https://ui-avatars.com/api/?name=Marcus+Chen&background=ec4899&color=fff&size=128',
   'https://linkedin.com/in/',
   ARRAY['AI Architecture','Cloud-Native','Enterprise AI'])
on conflict (id) do nothing;

insert into sessions (id, title, description, date, time, timezone, duration, status, meeting_platform, meeting_url, capacity, tags, speaker_ids) values
  ('ses-001', 'Architecting for AI-Native Enterprises',
   'A deep-dive into how enterprise architecture must evolve when AI moves from project to platform. We''ll cover data contracts, model governance, and the org structures that enable AI at scale.',
   '2026-06-25', '17:00', 'UTC', 60, 'upcoming', 'zoom', 'https://zoom.us/j/example',
   200, ARRAY['Architecture','AI','Enterprise'], ARRAY['spk-001','spk-003']),
  ('ses-002', 'Platform Engineering at Scale',
   'From golden paths to self-service infrastructure — a practitioner''s guide to building internal developer platforms that development teams actually adopt.',
   '2026-07-10', '15:00', 'UTC', 60, 'upcoming', 'teams', 'https://teams.microsoft.com/l/meetup-join/example',
   150, ARRAY['Platform','DevEx','Engineering'], ARRAY['spk-002']),
  ('ses-003', 'Engineering Leadership Playbook',
   'A candid conversation on scaling technical leadership — how to stay close to the code while driving org-wide strategy.',
   '2026-05-15', '16:00', 'UTC', 90, 'completed', 'meet', '',
   100, ARRAY['Leadership','Engineering'], ARRAY['spk-001'])
on conflict (id) do nothing;

insert into topic_options (id, title, description, tags) values
  ('top-001', 'Architecting for AI-Native Enterprises',
   'How to redesign organisational and technical architecture when AI is a first-class citizen, not a bolt-on.',
   ARRAY['Architecture','AI','Enterprise']),
  ('top-002', 'Platform Engineering at Scale',
   'Internal developer platforms, golden paths, and the organisational change needed to make them stick.',
   ARRAY['Platform','DevEx','Engineering']),
  ('top-003', 'Technology Strategy for Non-Technical Boards',
   'Communicating complex technical direction to board-level stakeholders — frameworks and real-world patterns.',
   ARRAY['Strategy','Leadership','Communication']),
  ('top-004', 'Compliance-by-Design in Modern Systems',
   'Building GDPR, SOC2, and ISO 27001 compliance into the architecture from day one, not after the fact.',
   ARRAY['Compliance','Security','Architecture']),
  ('top-005', 'Engineering Leadership Playbook',
   'From IC to CTO — how to scale yourself, build high-trust teams, and maintain technical credibility.',
   ARRAY['Leadership','Engineering','Career'])
on conflict (id) do nothing;

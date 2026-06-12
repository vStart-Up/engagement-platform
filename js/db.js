// ─────────────────────────────────────────────────────────────────
//  Courseific Sessions · Data Access Layer
//
//  Clean abstraction over Supabase. All pages talk to DB.*
//  instead of hitting Supabase directly — swap the backend
//  (REST API, Firebase, etc.) here without touching any HTML.
// ─────────────────────────────────────────────────────────────────

const DB = (() => {

  const sb = () => window._supabaseClient;

  // ── Voter identity (anonymous, per-browser) ──────────────────
  function getVoterId() {
    let id = localStorage.getItem('cf_voter_id');
    if (!id) {
      id = (typeof crypto !== 'undefined' && crypto.randomUUID)
        ? crypto.randomUUID()
        : 'v-' + Date.now() + '-' + Math.random().toString(36).slice(2);
      localStorage.setItem('cf_voter_id', id);
    }
    return id;
  }

  // ── Platform settings ────────────────────────────────────────
  async function getPlatformSettings() {
    const { data, error } = await sb()
      .from('platform_settings').select('key,value');
    if (error) throw error;
    const m = Object.fromEntries((data || []).map(r => [r.key, r.value]));
    return {
      name:         m['name']          || 'Courseific Sessions',
      tagline:      m['tagline']       || '',
      contactEmail: m['contact_email'] || ''
    };
  }

  async function savePlatformSettings(s) {
    const rows = [
      { key: 'name',          value: s.name          || '' },
      { key: 'tagline',       value: s.tagline        || '' },
      { key: 'contact_email', value: s.contactEmail   || '' }
    ];
    const { error } = await sb()
      .from('platform_settings').upsert(rows, { onConflict: 'key' });
    if (error) throw error;
  }

  // ── Themes ───────────────────────────────────────────────────
  async function getThemes() {
    const { data, error } = await sb()
      .from('themes').select('*').order('sort_order');
    if (error) throw error;
    return (data || []).map(r => ({
      id:          r.id,
      name:        r.name,
      description: r.description || '',
      color:       r.color       || '#6366f1',
      icon:        r.icon        || '🎯',
      sortOrder:   r.sort_order  || 0
    }));
  }

  async function upsertTheme(t) {
    const { error } = await sb().from('themes').upsert({
      id: t.id, name: t.name, description: t.description || '',
      color: t.color || '#6366f1', icon: t.icon || '🎯',
      sort_order: t.sortOrder || 0
    }, { onConflict: 'id' });
    if (error) throw error;
  }

  async function deleteTheme(id) {
    const { error } = await sb().from('themes').delete().eq('id', id);
    if (error) throw error;
  }

  // ── Sessions ─────────────────────────────────────────────────
  const sessionFromRow = r => ({
    id:              r.id,
    title:           r.title,
    description:     r.description      || '',
    date:            r.date             || '',
    time:            (r.time || '').slice(0, 5),
    timezone:        r.timezone         || 'UTC',
    duration:        r.duration         || 60,
    status:          r.status           || 'upcoming',
    meetingPlatform: r.meeting_platform || '',
    meetingUrl:      r.meeting_url      || '',
    recordingUrl:    r.recording_url    || '',
    capacity:        r.capacity         || 0,
    registered:      r.registered       || 0,
    tags:            r.tags             || [],
    speakerIds:      r.speaker_ids      || [],
    themeIds:        r.theme_ids        || [],
    isPaid:          r.is_paid          || false,
    price:           r.price            || 0,
    currency:        r.currency         || 'USD'
  });

  const sessionToRow = s => ({
    id:               s.id,
    title:            s.title,
    description:      s.description,
    date:             s.date     || null,
    time:             s.time     || null,
    timezone:         s.timezone || 'UTC',
    duration:         s.duration,
    status:           s.status,
    meeting_platform: s.meetingPlatform,
    meeting_url:      s.meetingUrl,
    recording_url:    s.recordingUrl,
    capacity:         s.capacity,
    registered:       s.registered || 0,
    tags:             s.tags       || [],
    speaker_ids:      s.speakerIds || [],
    theme_ids:        s.themeIds   || [],
    is_paid:          s.isPaid     || false,
    price:            s.price      || 0,
    currency:         s.currency   || 'USD'
  });

  async function getSessions() {
    const { data, error } = await sb()
      .from('sessions').select('*').order('date', { ascending: true });
    if (error) throw error;
    return (data || []).map(sessionFromRow);
  }

  async function upsertSession(s) {
    const { error } = await sb()
      .from('sessions').upsert(sessionToRow(s), { onConflict: 'id' });
    if (error) throw error;
  }

  async function deleteSession(id) {
    const { error } = await sb().from('sessions').delete().eq('id', id);
    if (error) throw error;
  }

  // ── Speakers ─────────────────────────────────────────────────
  async function getSpeakers() {
    const { data, error } = await sb()
      .from('speakers').select('*').order('name');
    if (error) throw error;
    return (data || []).map(r => ({
      id:       r.id,
      name:     r.name,
      title:    r.title    || '',
      bio:      r.bio      || '',
      avatar:   r.avatar   || '',
      linkedin: r.linkedin || '',
      twitter:  r.twitter  || '',
      topics:   r.topics   || []
    }));
  }

  async function upsertSpeaker(sp) {
    const { error } = await sb().from('speakers').upsert({
      id: sp.id, name: sp.name, title: sp.title, bio: sp.bio,
      avatar: sp.avatar, linkedin: sp.linkedin,
      twitter: sp.twitter, topics: sp.topics || []
    }, { onConflict: 'id' });
    if (error) throw error;
  }

  async function deleteSpeaker(id) {
    const { error } = await sb().from('speakers').delete().eq('id', id);
    if (error) throw error;
  }

  // ── Topics & Voting ──────────────────────────────────────────
  async function getTopics() {
    const voterId = getVoterId();
    const [
      { data: topicData,  error: te },
      { data: countData           },
      { data: myVoteData          }
    ] = await Promise.all([
      sb().from('topic_options').select('*').order('created_at'),
      sb().from('topic_vote_counts').select('topic_id,vote_count'),
      sb().from('votes').select('topic_id').eq('voter_id', voterId)
    ]);
    if (te) throw te;

    const counts  = Object.fromEntries((countData  || []).map(r => [r.topic_id, r.vote_count]));
    const myVotes = new Set((myVoteData || []).map(r => r.topic_id));

    return (topicData || []).map(t => ({
      id:          t.id,
      title:       t.title,
      description: t.description || '',
      tags:        t.tags        || [],
      themeId:     t.theme_id    || null,
      votes:       counts[t.id]  || 0,
      myVote:      myVotes.has(t.id)
    }));
  }

  async function castVote(topicId) {
    const { error } = await sb().from('votes')
      .insert({ topic_id: topicId, voter_id: getVoterId() });
    // Ignore unique-constraint violation (23505) — means already voted
    if (error && error.code !== '23505') throw error;
  }

  async function removeVote(topicId) {
    const { error } = await sb().from('votes')
      .delete().match({ topic_id: topicId, voter_id: getVoterId() });
    if (error) throw error;
  }

  async function upsertTopic(t) {
    const { error } = await sb().from('topic_options').upsert({
      id: t.id, title: t.title, description: t.description, tags: t.tags || [],
      theme_id: t.themeId || null
    }, { onConflict: 'id' });
    if (error) throw error;
  }

  async function deleteTopic(id) {
    const { error } = await sb().from('topic_options').delete().eq('id', id);
    if (error) throw error;
  }

  // ── Registrations ────────────────────────────────────────────
  async function registerForSession(sessionId, data) {
    const { error } = await sb().from('registrations').insert({
      session_id: sessionId, name: data.name,
      email: data.email, org: data.org || '', role: data.role || ''
    });
    if (error) throw error;
    // sessions.registered is kept in sync by a DB trigger
  }

  async function getRegistrations() {
    const { data, error } = await sb()
      .from('registrations')
      .select('*, sessions(title)')
      .order('created_at', { ascending: false });
    if (error) throw error;
    return data || [];
  }

  // ── Speaker Applications ─────────────────────────────────────
  async function submitApplication(app) {
    const { error } = await sb().from('speaker_applications').insert({
      id:           app.id,
      status:       'pending',
      personal:     app.personal,
      session_info: app.session,
      availability: app.availability,
      experience:   app.experience,
      submitted_at: app.submittedAt
    });
    if (error) throw error;
  }

  async function getApplications() {
    const { data, error } = await sb()
      .from('speaker_applications').select('*')
      .order('submitted_at', { ascending: false });
    if (error) throw error;
    return (data || []).map(a => ({
      id:           a.id,
      status:       a.status,
      personal:     a.personal,
      session:      a.session_info,
      availability: a.availability,
      experience:   a.experience,
      submittedAt:  a.submitted_at
    }));
  }

  async function updateApplicationStatus(id, status) {
    const { error } = await sb()
      .from('speaker_applications').update({ status }).eq('id', id);
    if (error) throw error;
  }

  // ── Admin Auth (Supabase Auth) ───────────────────────────────
  async function signIn(email, password) {
    const { data, error } = await sb().auth
      .signInWithPassword({ email, password });
    if (error) throw error;
    return data.session;
  }

  async function signOut() {
    await sb().auth.signOut();
  }

  async function getSession() {
    const { data } = await sb().auth.getSession();
    return data?.session || null;
  }

  // ── Public API ───────────────────────────────────────────────
  return {
    getVoterId,
    getPlatformSettings, savePlatformSettings,
    getSessions,  upsertSession,  deleteSession,
    getSpeakers,  upsertSpeaker,  deleteSpeaker,
    getThemes,    upsertTheme,    deleteTheme,
    getTopics,    castVote,       removeVote,    upsertTopic, deleteTopic,
    registerForSession, getRegistrations,
    submitApplication,  getApplications, updateApplicationStatus,
    signIn, signOut, getSession
  };

})();

const express = require('express');
const cors = require('cors');
require('dotenv').config();
const { createClient } = require('@supabase/supabase-js');
const { TEMPORARY_PASSWORD, sendWelcomeEmail } = require('./mailService');

const app = express();
app.use(cors());
app.use(express.json());

const SUPABASE_URL = process.env.SUPABASE_URL;
const SERVICE_ROLE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY;

if (!SUPABASE_URL || !SERVICE_ROLE_KEY) {
  console.error('SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY must be set');
  process.exit(1);
}

if (!process.env.SMTP_EMAIL || !process.env.SMTP_APP_PASSWORD) {
  console.warn('SMTP_EMAIL and SMTP_APP_PASSWORD are not set; welcome emails will be skipped.');
}

const supabase = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
  auth: { persistSession: false },
});

// --- Helpers --------------------------------------------------------------
function handleResult(res, result) {
  if (result.error) {
    return res.status(500).json({ error: result.error.message });
  }
  return res.json(result.data);
}

// --- Admin endpoints -----------------------------------------------------

// Create user (and optionally return the created record)
app.post('/admin/create-user', async (req, res) => {
  const { name, email, password, role, phone, courseNames } = req.body || {};
  try {
    const normalizedEmail = String(email || '').trim().toLowerCase();
    if (!name || !normalizedEmail || !role) {
      return res.status(400).json({ error: 'name, email, and role are required' });
    }

    const insert = {
      name,
      email: normalizedEmail,
      password: password || TEMPORARY_PASSWORD,
      role,
      phone,
    };
    const result = await supabase.from('users').insert([insert]).select();
    if (result.error) {
      const status = result.error.code === '23505' ? 409 : 500;
      return res.status(status).json({ error: result.error.message });
    }
    const created = Array.isArray(result.data) && result.data.length > 0 ? result.data[0] : result.data;

    // Optionally attach courses by name (if caller provided them)
    if (courseNames && Array.isArray(courseNames) && courseNames.length > 0) {
      // Lookup course ids by title
      const q = await supabase.from('courses').select('id,title').in('title', courseNames);
      if (!q.error && Array.isArray(q.data)) {
        const inserts = q.data.map(c => ({ user_id: created.id, course_id: c.id }));
        if (inserts.length) {
          await supabase.from('user_courses').insert(inserts);
        }
      }
    }

    try {
      await sendWelcomeEmail(normalizedEmail, {
        username: name,
        password: insert.password,
      });
      return res.status(201).json({ ...created, email_sent: true });
    } catch (emailError) {
      console.error(`Failed to send welcome email to ${normalizedEmail}:`, emailError);
      return res.status(201).json({
        ...created,
        email_sent: false,
        email_warning: 'User created, but welcome email could not be sent. Check SMTP configuration and logs.',
      });
    }
  } catch (err) {
    console.error('Create user failed:', err);
    return res.status(500).json({ error: String(err) });
  }
});

// Update user fields
app.patch('/admin/update-user/:id', async (req, res) => {
  const id = req.params.id;
  const body = req.body || {};
  try {
    const { data, error } = await supabase.from('users').update(body).eq('id', id).select();
    if (error) return res.status(500).json({ error: error.message });
    return res.json(Array.isArray(data) && data.length ? data[0] : data);
  } catch (err) {
    return res.status(500).json({ error: String(err) });
  }
});

// Update user course assignments (replace existing list)
app.post('/admin/update-user/:id/course-assignments', async (req, res) => {
  const id = req.params.id;
  const { courseIds } = req.body || {};
  try {
    // Delete existing assignments
    await supabase.from('user_courses').delete().eq('user_id', id);
    if (Array.isArray(courseIds) && courseIds.length) {
      const inserts = courseIds.map(cid => ({ user_id: id, course_id: cid }));
      await supabase.from('user_courses').insert(inserts);
    }
    return res.json({ ok: true });
  } catch (err) {
    return res.status(500).json({ error: String(err) });
  }
});

app.post('/admin/assign-batch', async (req, res) => {
  const { userId, batchId } = req.body || {};
  if (!userId || !batchId) {
    return res.status(400).json({ error: 'userId and batchId are required' });
  }

  try {
    const existing = await supabase
      .from('users')
      .select('batch_id')
      .eq('id', userId)
      .maybeSingle();
    if (existing.error) return res.status(500).json({ error: existing.error.message });

    if (!existing.data || !existing.data.batch_id) {
      const update = await supabase.from('users').update({ batch_id: batchId }).eq('id', userId);
      if (update.error) return res.status(500).json({ error: update.error.message });
    }

    const membership = await supabase
      .from('student_batches')
      .upsert([{ student_id: userId, batch_id: batchId }], { onConflict: 'student_id,batch_id' });
    if (membership.error) return res.status(500).json({ error: membership.error.message });

    return res.json({ ok: true });
  } catch (err) {
    return res.status(500).json({ error: String(err) });
  }
});

app.post('/admin/remove-batch', async (req, res) => {
  const { userId, batchId } = req.body || {};
  if (!userId || !batchId) {
    return res.status(400).json({ error: 'userId and batchId are required' });
  }

  try {
    const membership = await supabase
      .from('student_batches')
      .delete()
      .eq('student_id', userId)
      .eq('batch_id', batchId);
    if (membership.error) return res.status(500).json({ error: membership.error.message });

    const user = await supabase
      .from('users')
      .select('batch_id')
      .eq('id', userId)
      .maybeSingle();
    if (user.error) return res.status(500).json({ error: user.error.message });

    if (user.data && user.data.batch_id === batchId) {
      const next = await supabase
        .from('student_batches')
        .select('batch_id')
        .eq('student_id', userId)
        .limit(1);
      if (next.error) return res.status(500).json({ error: next.error.message });

      const nextBatchId = Array.isArray(next.data) && next.data.length ? next.data[0].batch_id : null;
      const update = await supabase.from('users').update({ batch_id: nextBatchId }).eq('id', userId);
      if (update.error) return res.status(500).json({ error: update.error.message });
    }

    return res.json({ ok: true });
  } catch (err) {
    return res.status(500).json({ error: String(err) });
  }
});

app.post('/admin/remove-all-batches', async (req, res) => {
  const { userId } = req.body || {};
  if (!userId) return res.status(400).json({ error: 'userId is required' });

  try {
    await supabase.from('student_batches').delete().eq('student_id', userId);
    const update = await supabase.from('users').update({ batch_id: null }).eq('id', userId);
    if (update.error) return res.status(500).json({ error: update.error.message });
    return res.json({ ok: true });
  } catch (err) {
    return res.status(500).json({ error: String(err) });
  }
});

// Assign a single course
app.post('/admin/assign-course', async (req, res) => {
  const { userId, courseId } = req.body || {};
  try {
    const result = await supabase.from('user_courses').insert([{ user_id: userId, course_id: courseId }]);
    if (result.error) return res.status(500).json({ error: result.error.message });
    // Create initial progress entry if needed
    await supabase.from('student_course_progress').insert([{ student_id: userId, course_id: courseId, completed_lessons: [], completed_modules: [], rewarded_modules: [] }]);
    return res.json({ ok: true });
  } catch (err) {
    return res.status(500).json({ error: String(err) });
  }
});

// Delete a user
app.delete('/admin/user/:id', async (req, res) => {
  const id = req.params.id;
  try {
    const { error } = await supabase.from('users').delete().eq('id', id);
    if (error) return res.status(500).json({ error: error.message });
    return res.json({ ok: true });
  } catch (err) {
    return res.status(500).json({ error: String(err) });
  }
});

// Fetch users (optionally filter by role)
app.get('/admin/users', async (req, res) => {
  const role = req.query.role;
  try {
    let q = supabase.from('users').select('*');
    if (role) q = q.eq('role', role);
    const { data, error } = await q;
    if (error) return res.status(500).json({ error: error.message });
    const users = data || [];
    const userIds = users.map((user) => user.id).filter(Boolean);
    if (!userIds.length) return res.json(users);

    const [courseLinks, batchLinks] = await Promise.all([
      supabase
        .from('user_courses')
        .select('user_id,course_id')
        .in('user_id', userIds),
      supabase
        .from('student_batches')
        .select('student_id,batch_id')
        .in('student_id', userIds),
    ]);

    if (courseLinks.error) return res.status(500).json({ error: courseLinks.error.message });
    if (batchLinks.error) return res.status(500).json({ error: batchLinks.error.message });

    const coursesByUser = new Map();
    for (const row of courseLinks.data || []) {
      if (!row.user_id) continue;
      if (!coursesByUser.has(row.user_id)) coursesByUser.set(row.user_id, []);
      coursesByUser.get(row.user_id).push({ course_id: row.course_id });
    }

    const batchesByUser = new Map();
    for (const row of batchLinks.data || []) {
      if (!row.student_id) continue;
      if (!batchesByUser.has(row.student_id)) batchesByUser.set(row.student_id, []);
      batchesByUser.get(row.student_id).push({ batch_id: row.batch_id });
    }

    return res.json(users.map((user) => ({
      ...user,
      user_courses: coursesByUser.get(user.id) || [],
      student_batches: batchesByUser.get(user.id) || [],
    })));
  } catch (err) {
    return res.status(500).json({ error: String(err) });
  }
});

// Course create/update/delete for admin and mentor tooling. These use the
// service-role client so the Flutter app does not need elevated DB grants.
app.post('/admin/courses', async (req, res) => {
  try {
    const { data, error } = await supabase
      .from('courses')
      .insert([req.body || {}])
      .select();
    if (error) return res.status(500).json({ error: error.message });
    return res.status(201).json(Array.isArray(data) && data.length ? data[0] : data);
  } catch (err) {
    return res.status(500).json({ error: String(err) });
  }
});

app.patch('/admin/courses/:id', async (req, res) => {
  try {
    const { data, error } = await supabase
      .from('courses')
      .update(req.body || {})
      .eq('id', req.params.id)
      .select();
    if (error) return res.status(500).json({ error: error.message });
    return res.json(Array.isArray(data) && data.length ? data[0] : data);
  } catch (err) {
    return res.status(500).json({ error: String(err) });
  }
});

app.delete('/admin/courses/:id', async (req, res) => {
  const id = req.params.id;
  try {
    await supabase.from('student_course_progress').delete().eq('course_id', id);
    await supabase.from('user_courses').delete().eq('course_id', id);
    const { error } = await supabase.from('courses').delete().eq('id', id);
    if (error) return res.status(500).json({ error: error.message });
    return res.json({ ok: true });
  } catch (err) {
    return res.status(500).json({ error: String(err) });
  }
});

app.delete('/admin/batches/:id', async (req, res) => {
  const id = req.params.id;
  try {
    await supabase.from('users').update({ batch_id: null }).eq('batch_id', id);

    const tasks = await supabase.from('batch_tasks').select('id').eq('batch_id', id);
    if (!tasks.error && Array.isArray(tasks.data) && tasks.data.length) {
      const taskIds = tasks.data.map((task) => task.id).filter(Boolean);
      if (taskIds.length) {
        await supabase.from('task_submissions').delete().in('task_id', taskIds);
      }
    }

    await supabase.from('batch_tasks').delete().eq('batch_id', id);
    await supabase.from('batch_chat_posts').delete().eq('batch_id', id);
    await supabase.from('batch_chat_members').delete().eq('batch_id', id);

    const { error } = await supabase.from('batches').delete().eq('id', id);
    if (error) return res.status(500).json({ error: error.message });
    return res.json({ ok: true });
  } catch (err) {
    return res.status(500).json({ error: String(err) });
  }
});

app.post('/admin/announcements', async (req, res) => {
  const body = req.body || {};
  try {
    const payload = {
      title: body.title || 'Announcement',
      message: body.message || '',
      type: 'announcement',
      target_group: body.target_group || body.targetGroup || 'both',
      sender_id: body.sender_id || null,
    };
    const { data, error } = await supabase.from('notifications').insert(payload).select();
    if (error) return res.status(500).json({ error: error.message });
    return res.status(201).json(data || []);
  } catch (err) {
    return res.status(500).json({ error: String(err) });
  }
});

app.post('/admin/batches/:id/announcements', async (req, res) => {
  const body = req.body || {};
  try {
    const payload = {
      title: body.title || 'Batch Announcement',
      message: body.message || '',
      type: 'announcement',
      target_group: 'student',
      sender_id: body.sender_id || null,
    };
    const { data, error } = await supabase.from('notifications').insert(payload).select();
    if (error) return res.status(500).json({ error: error.message });
    return res.status(201).json(data || []);
  } catch (err) {
    return res.status(500).json({ error: String(err) });
  }
});

app.patch('/admin/questions/:id/reply', async (req, res) => {
  const reply = (req.body && req.body.reply ? String(req.body.reply) : '').trim();
  if (!reply) {
    return res.status(400).json({ error: 'Reply is required' });
  }

  try {
    const { data, error } = await supabase
      .from('questions')
      .update({ reply, status: 'replied' })
      .eq('id', req.params.id)
      .select()
      .single();
    if (error) return res.status(500).json({ error: error.message });
    return res.json(data);
  } catch (err) {
    return res.status(500).json({ error: String(err) });
  }
});

// Simple health
app.get('/health', (_req, res) => res.json({ ok: true }));

const port = process.env.PORT || 4000;
app.listen(port, () => console.log(`Admin proxy listening on http://localhost:${port}`));

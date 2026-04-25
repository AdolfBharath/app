const express = require('express');
const { pool } = require('../db');
const { authenticate, requireRole } = require('../middleware/auth');

const router = express.Router();

// All batch routes require authentication.
router.use(authenticate);

/**
 * GET /api/batches
 * Returns all batches. Any authenticated user may view batches.
 */
router.get('/', async (_req, res) => {
  try {
    const result = await pool.query(`
      SELECT
        b.*,
        COALESCE(ec.enrolled_count, 0)::int AS enrolled_count,
        COALESCE(lp.avg_progress, 0)::double precision AS progress
      FROM batches b
      LEFT JOIN (
        SELECT
          bs.batch_id,
          COUNT(*)::int AS enrolled_count
        FROM batch_students bs
        GROUP BY bs.batch_id
      ) ec ON ec.batch_id = b.id
      LEFT JOIN (
        SELECT 
          bs.batch_id,
          AVG(
            CASE 
              WHEN jsonb_array_length(c.modules) = 0 THEN 0
              ELSE (jsonb_array_length(COALESCE(scp.completed_lessons, '[]'::jsonb))::float / 
                    GREATEST(1, jsonb_array_length(c.modules))::float)
            END
          ) as avg_progress
        FROM batch_students bs
        JOIN batches b2 ON b2.id = bs.batch_id
        JOIN courses c ON c.id = b2.course_id
        LEFT JOIN student_course_progress scp ON scp.student_id = bs.student_id AND scp.course_id = b2.course_id
        GROUP BY bs.batch_id
      ) lp ON lp.batch_id = b.id
      ORDER BY b.created_at DESC
    `);
    return res.json(result.rows);
  } catch (err) {
    console.error(err);
    return res.status(500).json({ message: 'Server error' });
  }
});

/**
 * POST /api/batches
 * Create a new batch. Admin only.
 */
router.post('/', requireRole('admin'), async (req, res) => {
  const {
    name,
    courseId,
    course_id,
    mentorId,
    mentor_id,
    capacity,
    enrollLimit,
    enroll_limit,
    smartWaitlist,
    smart_waitlist,
  } = req.body;

  const normalizedCourseId = courseId || course_id;
  const normalizedMentorId = mentorId || mentor_id || null;
  const normalizedCapacity = capacity ?? null;
  const normalizedEnrollLimit = enrollLimit ?? enroll_limit ?? null;
  const normalizedSmartWaitlist = smartWaitlist ?? smart_waitlist ?? false;

  if (!name || !normalizedCourseId) {
    return res.status(400).json({ message: 'name and courseId are required' });
  }

  try {
    const result = await pool.query(
      `INSERT INTO batches
        (name, course_id, mentor_id, capacity, enroll_limit, smart_waitlist)
       VALUES ($1, $2, $3, $4, $5, $6)
       RETURNING *`,
      [
        name,
        normalizedCourseId,
        normalizedMentorId,
        normalizedCapacity,
        normalizedEnrollLimit,
        normalizedSmartWaitlist,
      ],
    );
    return res.status(201).json(result.rows[0]);
  } catch (err) {
    console.error(err);
    return res.status(500).json({ message: 'Server error' });
  }
});

/**
 * DELETE /api/batches/:id
 * Delete a batch. Admin only.
 */
router.delete('/:id', requireRole('admin'), async (req, res) => {
  const { id } = req.params;

  try {
    const result = await pool.query('DELETE FROM batches WHERE id = $1 RETURNING id', [id]);

    if (result.rowCount === 0) {
      return res.status(404).json({ message: 'Batch not found' });
    }

    return res.json({ message: 'Batch deleted' });
  } catch (err) {
    console.error(err);
    return res.status(500).json({ message: 'Server error' });
  }
});

/**
 * PUT /api/batches/:id
 * Update a batch. Admin only.
 */
router.put('/:id', requireRole('admin'), async (req, res) => {
  const { id } = req.params;
  const {
    name,
    courseId,
    course_id,
    mentorId,
    mentor_id,
    capacity,
    enrollLimit,
    enroll_limit,
    smartWaitlist,
    smart_waitlist,
    startDate,
    start_date,
    endDate,
    end_date,
  } = req.body;

  const normalizedCourseId = courseId !== undefined ? courseId : course_id;
  const normalizedMentorId = mentorId !== undefined ? mentorId : mentor_id;
  const normalizedEnrollLimit = enrollLimit !== undefined ? enrollLimit : enroll_limit;
  const normalizedSmartWaitlist =
    smartWaitlist !== undefined ? smartWaitlist : smart_waitlist;
  const normalizedStartDate = startDate !== undefined ? startDate : start_date;
  const normalizedEndDate = endDate !== undefined ? endDate : end_date;

  try {
    const updates = [];
    const values = [];

    if (name !== undefined) {
      updates.push('name = $' + (values.length + 1));
      values.push(name);
    }
    if (normalizedCourseId !== undefined) {
      updates.push('course_id = $' + (values.length + 1));
      values.push(normalizedCourseId || null);
    }
    if (normalizedMentorId !== undefined) {
      updates.push('mentor_id = $' + (values.length + 1));
      values.push(normalizedMentorId || null);
    }
    if (capacity !== undefined) {
      updates.push('capacity = $' + (values.length + 1));
      values.push(capacity ?? null);
    }
    if (normalizedEnrollLimit !== undefined) {
      updates.push('enroll_limit = $' + (values.length + 1));
      values.push(normalizedEnrollLimit ?? null);
    }
    if (normalizedSmartWaitlist !== undefined) {
      updates.push('smart_waitlist = $' + (values.length + 1));
      values.push(normalizedSmartWaitlist);
    }
    if (normalizedStartDate !== undefined) {
      updates.push('start_date = $' + (values.length + 1));
      values.push(normalizedStartDate || null);
    }
    if (normalizedEndDate !== undefined) {
      updates.push('end_date = $' + (values.length + 1));
      values.push(normalizedEndDate || null);
    }

    if (updates.length === 0) {
      return res.status(400).json({ message: 'No fields to update' });
    }

    values.push(id);
    const query = `UPDATE batches SET ${updates.join(', ')} WHERE id = $${values.length} RETURNING *`;

    const result = await pool.query(query, values);
    if (result.rows.length === 0) {
      return res.status(404).json({ message: 'Batch not found' });
    }

    return res.json(result.rows[0]);
  } catch (err) {
    console.error(err);
    return res.status(500).json({ message: 'Server error' });
  }
});

/**
 * GET /api/batches/:id/details
 * Returns batch details including mentor and enrolled students.
 * Uses the batch_students junction table for efficient student lookup.
 */
router.get('/:id/details', async (req, res) => {
  const { id } = req.params;

  try {
    const batchResult = await pool.query(
      `
      SELECT
        b.*,
        c.title AS course_name,
        m.id AS mentor_id_ref,
        m.name AS mentor_name,
        m.email AS mentor_email,
        m.username AS mentor_username,
        COALESCE(bs_count.enrolled_count, 0)::int AS enrolled_count,
        COALESCE(lp.avg_progress, 0)::double precision AS progress
      FROM batches b
      LEFT JOIN courses c ON c.id = b.course_id
      LEFT JOIN users m ON m.id = b.mentor_id
      LEFT JOIN (
        SELECT batch_id, COUNT(*) AS enrolled_count
        FROM batch_students
        GROUP BY batch_id
      ) bs_count ON bs_count.batch_id = b.id
      LEFT JOIN (
        SELECT 
          bs.batch_id,
          AVG(
            CASE 
              WHEN jsonb_array_length(c.modules) = 0 THEN 0
              ELSE (jsonb_array_length(COALESCE(scp.completed_lessons, '[]'::jsonb))::float / 
                    GREATEST(1, jsonb_array_length(c.modules))::float)
            END
          ) as avg_progress
        FROM batch_students bs
        JOIN batches b2 ON b2.id = bs.batch_id
        JOIN courses c ON c.id = b2.course_id
        LEFT JOIN student_course_progress scp ON scp.student_id = bs.student_id AND scp.course_id = b2.course_id
        GROUP BY bs.batch_id
      ) lp ON lp.batch_id = b.id
      WHERE b.id = $1
      `,
      [id],
    );

    if (batchResult.rowCount === 0) {
      return res.status(404).json({ message: 'Batch not found' });
    }

    const batchRow = batchResult.rows[0];

    // Use batch_students for a direct, batch-scoped student lookup.
    const studentsResult = await pool.query(
      `
      SELECT
        u.id,
        u.name,
        u.email,
        u.username
      FROM batch_students bs
      JOIN users u ON u.id = bs.student_id
      WHERE bs.batch_id = $1
      ORDER BY u.name ASC
      `,
      [id],
    );

    const topPerformers = studentsResult.rows.slice(0, 10).map((s, index) => ({
      student_id: s.id,
      student_name: s.name,
      student_email: s.email,
      student_username: s.username,
      progress: 0,
      score: 0,
      rank: index + 1,
      completed_assignments: 0,
      total_assignments: 0,
      batch_id: batchRow.id,
    }));

    return res.json({
      batch: batchRow,
      course_name: batchRow.course_name,
      mentor:
        batchRow.mentor_id_ref
          ? {
              id: batchRow.mentor_id_ref,
              name: batchRow.mentor_name,
              email: batchRow.mentor_email,
              username: batchRow.mentor_username,
            }
          : null,
      students: studentsResult.rows,
      top_performers: topPerformers,
      total_students: studentsResult.rowCount,
      average_progress: Math.round((Number(batchRow.progress) || 0) * 100),
    });
  } catch (err) {
    console.error(err);
    return res.status(500).json({ message: 'Server error' });
  }
});

/**
 * GET /api/batches/:id/top-performers?limit=10
 * Returns top students enrolled in the batch's course.
 */
router.get('/:id/top-performers', async (req, res) => {
  const { id } = req.params;
  const limit = Math.max(1, Math.min(50, Number(req.query.limit || 10)));

  try {
    const batchResult = await pool.query(
      'SELECT id, course_id FROM batches WHERE id = $1',
      [id],
    );
    if (batchResult.rowCount === 0) {
      return res.status(404).json({ message: 'Batch not found' });
    }

    const { course_id: courseId } = batchResult.rows[0];
    const studentsResult = await pool.query(
      `
      SELECT DISTINCT
        u.id,
        u.name,
        u.email,
        u.username
      FROM user_courses uc
      JOIN users u ON u.id = uc.user_id
      WHERE uc.course_id = $1
        AND u.role = 'student'
      ORDER BY u.name ASC
      LIMIT $2
      `,
      [courseId, limit],
    );

    return res.json(studentsResult.rows);
  } catch (err) {
    console.error(err);
    return res.status(500).json({ message: 'Server error' });
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// Batch Chat (Reddit-style discussion)
// ─────────────────────────────────────────────────────────────────────────────

const BAD_WORDS = [
  'fuck',
  'shit',
  'bitch',
  'asshole',
  'bastard',
  'dick',
  'cunt',
];

function containsBadWords(text) {
  if (!text) return false;
  const t = String(text).toLowerCase();
  return BAD_WORDS.some((w) => new RegExp(`\\b${w}\\b`, 'i').test(t));
}

async function assertBatchExists(batchId) {
  const result = await pool.query('SELECT id, name, mentor_id FROM batches WHERE id = $1', [batchId]);
  if (result.rowCount === 0) {
    const err = new Error('Batch not found');
    err.status = 404;
    throw err;
  }
  return result.rows[0];
}

async function assertUserCanAccessBatchChat(req, batchId) {
  const batch = await assertBatchExists(batchId);
  const user = req.user;

  if (user.role === 'admin') return batch;

  if (user.role === 'mentor') {
    if (batch.mentor_id && String(batch.mentor_id) === String(user.id)) return batch;
    const err = new Error('Forbidden: not assigned to this batch');
    err.status = 403;
    throw err;
  }

  // student
  const membership = await pool.query(
    'SELECT 1 FROM batch_students WHERE batch_id = $1 AND student_id = $2',
    [batchId, user.id],
  );
  if (membership.rowCount === 0) {
    const err = new Error('Forbidden: not enrolled in this batch');
    err.status = 403;
    throw err;
  }

  return batch;
}

async function isUserBanned(batchId, userId) {
  const result = await pool.query(
    'SELECT 1 FROM batch_chat_bans WHERE batch_id = $1 AND user_id = $2 AND active = TRUE',
    [batchId, userId],
  );
  return result.rowCount > 0;
}

function isModerator(req) {
  return req.user?.role === 'admin' || req.user?.role === 'mentor';
}

/**
 * GET /api/batches/:id/chat
 * Returns posts + replies (threaded), and the caller's ban status.
 */
router.get('/:id/chat', async (req, res) => {
  const { id: batchId } = req.params;

  try {
    const batch = await assertUserCanAccessBatchChat(req, batchId);
    const banned = await isUserBanned(batchId, req.user.id);

    const postsResult = await pool.query(
      `
      SELECT
        p.id,
        p.batch_id,
        p.content,
        p.created_at,
        p.deleted_at,
        u.id AS author_id,
        u.name AS author_name,
        u.username AS author_username,
        u.role AS author_role,
        COALESCE(v.vote_count, 0)::int AS upvotes,
        COALESCE(uv.did_upvote, FALSE) AS did_upvote
      FROM batch_chat_posts p
      JOIN users u ON u.id = p.author_id
      LEFT JOIN (
        SELECT post_id, COUNT(*) AS vote_count
        FROM batch_chat_post_votes
        GROUP BY post_id
      ) v ON v.post_id = p.id
      LEFT JOIN (
        SELECT post_id, TRUE AS did_upvote
        FROM batch_chat_post_votes
        WHERE user_id = $2
      ) uv ON uv.post_id = p.id
      WHERE p.batch_id = $1
      ORDER BY p.created_at DESC
      LIMIT 100
      `,
      [batchId, req.user.id],
    );

    const postIds = postsResult.rows.map((r) => r.id);
    let replies = [];
    if (postIds.length > 0) {
      const repliesResult = await pool.query(
        `
        SELECT
          r.id,
          r.post_id,
          r.parent_reply_id,
          r.content,
          r.created_at,
          r.deleted_at,
          u.id AS author_id,
          u.name AS author_name,
          u.username AS author_username,
          u.role AS author_role
        FROM batch_chat_replies r
        JOIN users u ON u.id = r.author_id
        WHERE r.post_id = ANY($1::uuid[])
        ORDER BY r.created_at ASC
        `,
        [postIds],
      );
      replies = repliesResult.rows;
    }

    return res.json({
      batch: { id: batch.id, name: batch.name },
      isBanned: banned,
      posts: postsResult.rows,
      replies,
    });
  } catch (err) {
    console.error(err);
    const status = err.status || 500;
    return res.status(status).json({ message: err.message || 'Server error' });
  }
});

/**
 * POST /api/batches/:id/chat/posts
 * Body: { content }
 */
router.post('/:id/chat/posts', async (req, res) => {
  const { id: batchId } = req.params;
  const { content } = req.body;

  try {
    await assertUserCanAccessBatchChat(req, batchId);

    if (await isUserBanned(batchId, req.user.id)) {
      return res.status(403).json({ message: 'You are banned from this chat' });
    }

    const text = String(content || '').trim();
    if (!text) return res.status(400).json({ message: 'Content is required' });
    if (text.length > 1000) return res.status(400).json({ message: 'Content is too long' });
    if (containsBadWords(text)) {
      return res.status(400).json({ message: 'Inappropriate content not allowed' });
    }

    const result = await pool.query(
      `
      INSERT INTO batch_chat_posts (batch_id, author_id, content)
      VALUES ($1, $2, $3)
      RETURNING id
      `,
      [batchId, req.user.id, text],
    );

    return res.status(201).json({ id: result.rows[0].id });
  } catch (err) {
    console.error(err);
    const status = err.status || 500;
    return res.status(status).json({ message: err.message || 'Server error' });
  }
});

/**
 * POST /api/batches/:id/chat/posts/:postId/replies
 * Body: { content, parentReplyId? }
 */
router.post('/:id/chat/posts/:postId/replies', async (req, res) => {
  const { id: batchId, postId } = req.params;
  const { content, parentReplyId } = req.body;

  try {
    await assertUserCanAccessBatchChat(req, batchId);

    if (await isUserBanned(batchId, req.user.id)) {
      return res.status(403).json({ message: 'You are banned from this chat' });
    }

    const text = String(content || '').trim();
    if (!text) return res.status(400).json({ message: 'Content is required' });
    if (text.length > 1000) return res.status(400).json({ message: 'Content is too long' });
    if (containsBadWords(text)) {
      return res.status(400).json({ message: 'Inappropriate content not allowed' });
    }

    // Ensure the post belongs to this batch.
    const postResult = await pool.query(
      'SELECT id FROM batch_chat_posts WHERE id = $1 AND batch_id = $2',
      [postId, batchId],
    );
    if (postResult.rowCount === 0) {
      return res.status(404).json({ message: 'Post not found' });
    }

    const result = await pool.query(
      `
      INSERT INTO batch_chat_replies (post_id, author_id, parent_reply_id, content)
      VALUES ($1, $2, $3, $4)
      RETURNING id
      `,
      [postId, req.user.id, parentReplyId || null, text],
    );

    return res.status(201).json({ id: result.rows[0].id });
  } catch (err) {
    console.error(err);
    const status = err.status || 500;
    return res.status(status).json({ message: err.message || 'Server error' });
  }
});

/**
 * POST /api/batches/:id/chat/posts/:postId/upvote
 * Toggles the caller's upvote.
 */
router.post('/:id/chat/posts/:postId/upvote', async (req, res) => {
  const { id: batchId, postId } = req.params;

  try {
    await assertUserCanAccessBatchChat(req, batchId);

    // Ensure the post belongs to this batch.
    const postResult = await pool.query(
      'SELECT id FROM batch_chat_posts WHERE id = $1 AND batch_id = $2',
      [postId, batchId],
    );
    if (postResult.rowCount === 0) {
      return res.status(404).json({ message: 'Post not found' });
    }

    const existing = await pool.query(
      'SELECT id FROM batch_chat_post_votes WHERE post_id = $1 AND user_id = $2',
      [postId, req.user.id],
    );

    if (existing.rowCount > 0) {
      await pool.query('DELETE FROM batch_chat_post_votes WHERE post_id = $1 AND user_id = $2', [postId, req.user.id]);
      return res.json({ didUpvote: false });
    }

    await pool.query(
      'INSERT INTO batch_chat_post_votes (post_id, user_id) VALUES ($1, $2) ON CONFLICT (post_id, user_id) DO NOTHING',
      [postId, req.user.id],
    );

    return res.json({ didUpvote: true });
  } catch (err) {
    console.error(err);
    const status = err.status || 500;
    return res.status(status).json({ message: err.message || 'Server error' });
  }
});

/**
 * DELETE /api/batches/:id/chat/posts/:postId
 * Admin/Mentor only.
 */
router.delete('/:id/chat/posts/:postId', requireRole('admin', 'mentor'), async (req, res) => {
  const { id: batchId, postId } = req.params;

  try {
    const batch = await assertUserCanAccessBatchChat(req, batchId);
    if (req.user.role === 'mentor' && batch.mentor_id && String(batch.mentor_id) !== String(req.user.id)) {
      return res.status(403).json({ message: 'Forbidden: not assigned to this batch' });
    }

    const result = await pool.query(
      `
      UPDATE batch_chat_posts
      SET deleted_at = NOW(), deleted_by = $3
      WHERE id = $1 AND batch_id = $2 AND deleted_at IS NULL
      RETURNING id
      `,
      [postId, batchId, req.user.id],
    );

    if (result.rowCount === 0) {
      return res.status(404).json({ message: 'Post not found' });
    }

    return res.json({ message: 'Post deleted' });
  } catch (err) {
    console.error(err);
    const status = err.status || 500;
    return res.status(status).json({ message: err.message || 'Server error' });
  }
});

/**
 * DELETE /api/batches/:id/chat/replies/:replyId
 * Admin/Mentor only.
 */
router.delete('/:id/chat/replies/:replyId', requireRole('admin', 'mentor'), async (req, res) => {
  const { id: batchId, replyId } = req.params;

  try {
    const batch = await assertUserCanAccessBatchChat(req, batchId);
    if (req.user.role === 'mentor' && batch.mentor_id && String(batch.mentor_id) !== String(req.user.id)) {
      return res.status(403).json({ message: 'Forbidden: not assigned to this batch' });
    }

    const result = await pool.query(
      `
      UPDATE batch_chat_replies r
      SET deleted_at = NOW(), deleted_by = $3
      FROM batch_chat_posts p
      WHERE r.id = $1
        AND r.post_id = p.id
        AND p.batch_id = $2
        AND r.deleted_at IS NULL
      RETURNING r.id
      `,
      [replyId, batchId, req.user.id],
    );

    if (result.rowCount === 0) {
      return res.status(404).json({ message: 'Reply not found' });
    }

    return res.json({ message: 'Reply deleted' });
  } catch (err) {
    console.error(err);
    const status = err.status || 500;
    return res.status(status).json({ message: err.message || 'Server error' });
  }
});

/**
 * POST /api/batches/:id/chat/ban
 * Body: { userId, reason? }
 * Admin/Mentor only.
 */
router.post('/:id/chat/ban', requireRole('admin', 'mentor'), async (req, res) => {
  const { id: batchId } = req.params;
  const { userId, reason } = req.body;

  try {
    const batch = await assertUserCanAccessBatchChat(req, batchId);
    if (req.user.role === 'mentor' && batch.mentor_id && String(batch.mentor_id) !== String(req.user.id)) {
      return res.status(403).json({ message: 'Forbidden: not assigned to this batch' });
    }

    if (!userId) return res.status(400).json({ message: 'userId is required' });

    await pool.query(
      `
      INSERT INTO batch_chat_bans (batch_id, user_id, banned_by, reason, active)
      VALUES ($1, $2, $3, $4, TRUE)
      ON CONFLICT (batch_id, user_id)
      DO UPDATE SET
        banned_by = EXCLUDED.banned_by,
        reason = EXCLUDED.reason,
        active = TRUE,
        banned_at = NOW(),
        unbanned_at = NULL
      `,
      [batchId, userId, req.user.id, reason || null],
    );

    return res.json({ message: 'User banned' });
  } catch (err) {
    console.error(err);
    const status = err.status || 500;
    return res.status(status).json({ message: err.message || 'Server error' });
  }
});

/**
 * POST /api/batches/:id/chat/unban
 * Body: { userId }
 * Admin/Mentor only.
 */
router.post('/:id/chat/unban', requireRole('admin', 'mentor'), async (req, res) => {
  const { id: batchId } = req.params;
  const { userId } = req.body;

  try {
    const batch = await assertUserCanAccessBatchChat(req, batchId);
    if (req.user.role === 'mentor' && batch.mentor_id && String(batch.mentor_id) !== String(req.user.id)) {
      return res.status(403).json({ message: 'Forbidden: not assigned to this batch' });
    }

    if (!userId) return res.status(400).json({ message: 'userId is required' });

    await pool.query(
      `
      UPDATE batch_chat_bans
      SET active = FALSE, unbanned_at = NOW()
      WHERE batch_id = $1 AND user_id = $2
      `,
      [batchId, userId],
    );

    return res.json({ message: 'User unbanned' });
  } catch (err) {
    console.error(err);
    const status = err.status || 500;
    return res.status(status).json({ message: err.message || 'Server error' });
  }
});

module.exports = router;

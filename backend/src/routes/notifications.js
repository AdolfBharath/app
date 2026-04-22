const express = require('express');
const { pool } = require('../db');
const { authenticate } = require('../middleware/auth');
const { requireRole } = require('../middleware/auth');

const router = express.Router();

router.use(authenticate);

/**
 * GET /api/notifications
 * Returns role-scoped notifications.
 */
router.get('/', async (req, res) => {
  try {
    const role = req.user.role;
    let result;

    if (role === 'student') {
      result = await pool.query(
        `
        SELECT
          n.id,
          n.title,
          n.message,
          n.type,
          n.target_group,
          n.batch_id,
          n.sender_id,
          n.sender_role,
          n.created_at,
          COALESCE(u.name, 'System') AS sender
        FROM notifications n
        LEFT JOIN users u ON u.id = n.sender_id
        WHERE n.target_group IN ('students', 'both', 'all')
          AND (
            n.batch_id IS NULL
            OR EXISTS (
              SELECT 1
              FROM users su
              LEFT JOIN batch_students bs ON bs.student_id = su.id
              WHERE su.id = $1
                AND (su.batch_id = n.batch_id OR bs.batch_id = n.batch_id)
            )
          )
        ORDER BY n.created_at DESC
        LIMIT 100
        `,
        [req.user.id],
      );
    } else if (role === 'mentor') {
      result = await pool.query(
        `
        SELECT
          n.id,
          n.title,
          n.message,
          n.type,
          n.target_group,
          n.batch_id,
          n.sender_id,
          n.sender_role,
          n.created_at,
          COALESCE(u.name, 'System') AS sender
        FROM notifications n
        LEFT JOIN users u ON u.id = n.sender_id
        WHERE n.target_group IN ('mentors', 'both', 'all')
           OR (
             n.target_group = 'students'
             AND n.batch_id IS NOT NULL
             AND EXISTS (
               SELECT 1
               FROM batches b
               LEFT JOIN user_courses uc ON uc.course_id = b.course_id AND uc.user_id = $1
               WHERE b.id = n.batch_id
                 AND (b.mentor_id = $1 OR uc.user_id IS NOT NULL)
             )
           )
        ORDER BY n.created_at DESC
        LIMIT 100
        `,
        [req.user.id],
      );
    } else if (role === 'admin') {
      result = await pool.query(
        `
        SELECT
          n.id,
          n.title,
          n.message,
          n.type,
          n.target_group,
          n.batch_id,
          n.sender_id,
          n.sender_role,
          n.created_at,
          COALESCE(u.name, 'System') AS sender
        FROM notifications n
        LEFT JOIN users u ON u.id = n.sender_id
        WHERE n.target_group IN ('admins', 'both', 'all')
        ORDER BY n.created_at DESC
        LIMIT 100
        `,
      );
    } else {
      return res.json([]);
    }

    const rows = result.rows.map((row) => ({
      ...row,
      read: false,
    }));

    return res.json(rows);
  } catch (err) {
    console.error(err);
    return res.status(500).json({ message: 'Server error' });
  }
});

/**
 * POST /api/notifications/announcements
 * Admin can create announcements for students, mentors, or both.
 */
router.post('/announcements', requireRole('admin'), async (req, res) => {
  const { title, message, targetGroup } = req.body;

  if (!message || !targetGroup) {
    return res.status(400).json({ message: 'message and targetGroup are required' });
  }

  const normalizedTargetGroup =
    targetGroup === 'student'
      ? 'students'
      : targetGroup === 'mentor'
          ? 'mentors'
          : targetGroup === 'admin'
              ? 'admins'
              : targetGroup === 'all'
                  ? 'all'
          : targetGroup;

  if (!['students', 'mentors', 'admins', 'both', 'all'].includes(normalizedTargetGroup)) {
    return res.status(400).json({ message: 'Invalid targetGroup' });
  }

  try {
    const result = await pool.query(
      `
      INSERT INTO notifications (
        title,
        message,
        type,
        target_group,
        batch_id,
        sender_id,
        sender_role
      )
      VALUES ($1, $2, 'announcement', $3, NULL, $4, $5)
      RETURNING id, title, message, type, target_group, batch_id, sender_id, sender_role, created_at
      `,
      [title || 'Announcement', message, normalizedTargetGroup, req.user.id, req.user.role],
    );

    return res.status(201).json(result.rows[0]);
  } catch (err) {
    console.error(err);
    return res.status(500).json({ message: 'Server error' });
  }
});

router.post('/batches/:batchId/announcements', requireRole('mentor', 'admin'), async (req, res) => {
  const { batchId } = req.params;
  const { title, message } = req.body;

  if (!message || !String(message).trim()) {
    return res.status(400).json({ message: 'message is required' });
  }

  try {
    if (req.user.role === 'mentor') {
      const access = await pool.query(
        `
        SELECT 1
        FROM batches b
        LEFT JOIN user_courses uc ON uc.course_id = b.course_id AND uc.user_id = $1
        WHERE b.id = $2
          AND (b.mentor_id = $1 OR uc.user_id IS NOT NULL)
        LIMIT 1
        `,
        [req.user.id, batchId],
      );

      if (access.rowCount === 0) {
        return res.status(403).json({ message: 'Forbidden: no access to this batch' });
      }
    }

    const result = await pool.query(
      `
      INSERT INTO notifications (
        title,
        message,
        type,
        target_group,
        batch_id,
        sender_id,
        sender_role
      )
      VALUES ($1, $2, 'announcement', 'students', $3, $4, $5)
      RETURNING id, title, message, type, target_group, batch_id, sender_id, sender_role, created_at
      `,
      [title || 'Batch Announcement', String(message).trim(), batchId, req.user.id, req.user.role],
    );

    return res.status(201).json(result.rows[0]);
  } catch (err) {
    console.error(err);
    return res.status(500).json({ message: 'Server error' });
  }
});

/**
 * POST /api/notifications/admin-updates
 * Admins and mentors can notify admins.
 */
router.post('/admin-updates', requireRole('admin', 'mentor'), async (req, res) => {
  const { title, message } = req.body;

  if (!message) {
    return res.status(400).json({ message: 'message is required' });
  }

  try {
    const result = await pool.query(
      `
      INSERT INTO notifications (
        title,
        message,
        type,
        target_group,
        sender_id,
        sender_role
      )
      VALUES ($1, $2, 'admin_notice', 'admins', $3, $4)
      RETURNING id, title, message, type, target_group, sender_id, sender_role, created_at
      `,
      [title || 'Admin Update', message, req.user.id, req.user.role],
    );

    return res.status(201).json(result.rows[0]);
  } catch (err) {
    console.error(err);
    return res.status(500).json({ message: 'Server error' });
  }
});

/**
 * GET /api/notifications/admin-inbox
 * Admin-only inbox showing updates from other admins and mentors.
 */
router.get('/admin-inbox', requireRole('admin'), async (req, res) => {
  try {
    const result = await pool.query(
      `
      SELECT
        n.id,
        n.title,
        n.message,
        n.type,
        n.target_group,
        n.sender_id,
        n.sender_role,
        n.created_at,
        COALESCE(u.name, 'System') AS sender
      FROM notifications n
      LEFT JOIN users u ON u.id = n.sender_id
      WHERE n.target_group IN ('admins', 'both')
        AND n.sender_role IN ('admin', 'mentor')
        AND (n.sender_id IS NULL OR n.sender_id <> $1)
      ORDER BY n.created_at DESC
      LIMIT 100
      `,
      [req.user.id],
    );

    return res.json(result.rows);
  } catch (err) {
    console.error(err);
    return res.status(500).json({ message: 'Server error' });
  }
});

module.exports = router;
